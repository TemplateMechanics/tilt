#!/usr/bin/env bash
# Run this BEFORE the class. It answers one question: will the platform come up
# on this machine?
#
# It exists because "I installed everything" and "it works" are different
# claims, and the gap between them costs the first hour of a session. Every
# check here failed for somebody at least once: a missing Flux CLI, a kubectl
# two minors behind the cluster, a container daemon that was installed but not
# running, a machine with no room left for ~10 GB of images.
#
# Safe to run at any time. It reads; it changes nothing and pulls nothing.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${CONTEXT:-kind-tiltdev}"
CLUSTER="${CLUSTER:-tiltdev}"
GATEWAY_PORT="${GATEWAY_PORT:-443}"
if [ -z "${GATEWAY_HTTP_PORT:-}" ]; then
    case "$GATEWAY_PORT" in
        443) GATEWAY_HTTP_PORT=80 ;;
        8443) GATEWAY_HTTP_PORT=8080 ;;
        *)
            echo "GATEWAY_HTTP_PORT is required when GATEWAY_PORT is $GATEWAY_PORT" >&2
            exit 2
            ;;
    esac
fi
if [ "${GATEWAY_HTTP_PORT:-80}" = "80" ]; then
    CRL_BASE_URL="${CRL_BASE_URL:-http://crl.localhost}"
else
    CRL_BASE_URL="${CRL_BASE_URL:-http://crl.localhost:${GATEWAY_HTTP_PORT}}"
fi
port_suffix=""; [ "$GATEWAY_PORT" = "443" ] || port_suffix=":$GATEWAY_PORT"
hello_url="https://hello.localhost$port_suffix/"

pass=0; fail=0; warn=0
ok()   { pass=$((pass+1)); printf '  \033[32mok\033[0m    %s\n' "$*"; }
bad()  { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$*"; }
warn() { warn=$((warn+1)); printf '  \033[33mwarn\033[0m  %s\n' "$*"; }
note() { printf '        %s\n' "$*"; }

echo "Student pre-flight — $(date '+%Y-%m-%d %H:%M')"
echo
echo "== tools"
for t in kind kubectl helm flux tilt python curl openssl; do
    if command -v "$t" >/dev/null 2>&1; then ok "$t found"
    else bad "$t is not on PATH"; note "see the Prerequisites table in README.md"; fi
done
if command -v python >/dev/null 2>&1; then
    if python -c 'import yaml' >/dev/null 2>&1; then ok "Python module PyYAML found"
    else bad "Python module PyYAML is missing"; note "install it with: python -m pip install pyyaml"; fi
fi

# bash 3.x (macOS's system bash) cannot run these scripts.
if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then ok "bash ${BASH_VERSION%%(*}"
else bad "bash ${BASH_VERSION%%(*} is too old - needs 4+"; fi

echo
echo "== container daemon"
# Podman is a supported runtime (docs/CONTAINER-RUNTIMES.md); checking only
# for docker failed every Podman user whose setup worked.
rt=""
if docker info >/dev/null 2>&1; then rt=docker
elif podman info >/dev/null 2>&1; then rt=podman; fi
if [ -n "$rt" ]; then
    ok "container daemon is running ($rt)"
    # kind pulls images into the node, not the host, so a reset re-downloads
    # up to ~10 GB (measured: 9.7 GB with every profile on). A full disk shows up as pods stuck in ContainerCreating with no
    # obvious error.
    # Measured on the host filesystem, not inside the daemon's VM: a VM
    # reports its sparse virtual disk and cheerfully claims 1.5 TB free on a
    # laptop that has 12 GB left.
    home_fs="${HOME:-/}"
    # -Pk is POSIX: the same columns from GNU df, busybox df and macOS's BSD
    # df. -BG is GNU-only, and on a Mac this check silently never ran.
    free_gb=$(df -Pk "$home_fs" 2>/dev/null | awk 'NR==2{print int($4/1048576)}')
    if [ -n "${free_gb:-}" ] && [ "$free_gb" -lt 20 ] 2>/dev/null; then
        warn "only ${free_gb}G free on $home_fs - the platform stores up to ~10G of images; keep 15G free"
    elif [ -n "${free_gb:-}" ]; then ok "${free_gb}G free on $home_fs"
        note "if your container daemon stores images on another disk, check that one instead"
    else warn "could not measure free disk space - check by hand that ~15G is free"; fi
else
    bad "no container daemon - install/start Docker Desktop (or Podman)"
    note "docs/CONTAINER-RUNTIMES.md covers Podman, including the WSL kernel requirement"
fi

echo
echo "== version skew"
# An older kubectl prints a warning on every single command, and students
# chase the warning instead of the lab.
if command -v kubectl >/dev/null 2>&1; then
    # No python: stock macOS and recent Debian/Ubuntu ship only python3, and on
    # Windows `python3` is usually the Microsoft Store stub, which prompts to
    # install rather than running. The JSON lists client then server, so the
    # first "minor" is the client's and the second the server's.
    minors() { sed -n 's/.*"minor": *"\([0-9]*\).*/\1/p'; }
    cv=$(kubectl version --client -o json 2>/dev/null | minors | head -1)
    # Prefer the running cluster; kind/cluster.yaml pins no node image, so the
    # version is whatever the installed kind defaults to.
    want=$(kubectl --context "$CONTEXT" version -o json 2>/dev/null | minors | sed -n 2p)
    [ -n "$want" ] || want=$(grep -oE 'kindest/node:v1\.[0-9]+' "$ROOT/kind/cluster.yaml" 2>/dev/null | head -1 | grep -oE '[0-9]+$')
    # Both must be plain integers before any arithmetic. A bad parse once
    # produced a non-empty control character here: it passed a -n test, the
    # arithmetic then failed, and this whole section printed nothing while the
    # summary said "Ready". Garbage must reach the warn branch, not vanish.
    case "$cv$want" in *[!0-9]*) cv=""; want="" ;; esac
    if [ -n "$cv" ] && [ -n "$want" ]; then
        d=$((want - cv)); [ "$d" -lt 0 ] && d=$(( -d ))
        if [ "$d" -le 1 ]; then ok "kubectl 1.$cv against cluster 1.$want"
        else warn "kubectl 1.$cv vs cluster 1.$want - expect a skew warning on every command"; fi
    else warn "could not compare kubectl and cluster versions"; fi
else
    # Say so. An empty section reads as "nothing wrong here".
    warn "skipped - kubectl not found (see tools, above)"
fi

echo
echo "== the platform itself"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
    ok "kind cluster '$CLUSTER' exists"
    if kubectl --context "$CONTEXT" get nodes >/dev/null 2>&1; then
        ok "cluster answers kubectl"
        notready=$(kubectl --context "$CONTEXT" get pods -A --no-headers 2>/dev/null \
                   | awk '$4!="Running" && $4!="Completed"' | wc -l | tr -d ' ')
        [ "${notready:-0}" -eq 0 ] && ok "all pods Running" || warn "$notready pod(s) not Running yet - give it a few minutes"
        # Test application routing against the cluster CA, independently of
        # whether the host trust prompt was accepted.
        ca="$(mktemp "${TMPDIR:-/tmp}/student-root-ca.XXXXXX")"
        kubectl --context "$CONTEXT" -n cert-manager get secret local-root-ca \
            -o go-template='{{index .data "tls.crt"}}' 2>/dev/null \
            | base64 -d > "$ca"
        code=""
        if [ -s "$ca" ] && openssl x509 -in "$ca" -noout >/dev/null 2>&1; then
            code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
                --cacert "$ca" --resolve "hello.localhost:$GATEWAY_PORT:127.0.0.1" \
                "$hello_url" 2>/dev/null)
        fi
        /bin/rm -f "$ca"
        if [ "$code" = "200" ]; then ok "$hello_url answers 200 with the cluster CA"
        else bad "$hello_url returned '${code:-no response}'"
             note "if Tilt is still building, wait for hello-world to go green and re-run"; fi

        crls_ok=1
        for crl in root intermediate; do
            curl -fsS --max-time 10 "$CRL_BASE_URL/$crl.crl" 2>/dev/null \
                | openssl crl -inform DER -noout >/dev/null 2>&1 || crls_ok=0
        done
        [ "$crls_ok" -eq 1 ] \
            && ok "root and intermediate CRLs are reachable and parse" \
            || bad "local CA revocation endpoints are unavailable"

        case "$(uname -s)" in
          Darwin)
            security verify-cert -R require "$hello_url" >/dev/null 2>&1 \
                && ok "macOS user trust and required revocation succeed" \
                || bad "macOS rejects the CA or cannot obtain revocation status"
            ;;
          *)
            native=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
                --resolve "hello.localhost:$GATEWAY_PORT:127.0.0.1" \
                "$hello_url" 2>/dev/null)
            [ -n "$native" ] && [ "$native" != "000" ] \
                && ok "OS trust store accepts the platform CA" \
                || bad "OS trust store rejects the platform CA"
            ;;
        esac
    else bad "cluster exists but kubectl cannot reach it"; fi
else
    warn "no cluster yet - run ./scripts/platform.sh up (first run downloads several GB)"
    note "do this at home, on good wifi, NOT in the room on the day"
fi

echo
printf '  %d passed, %d failed, %d warning(s)\n' "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then
    echo "  Bring this output to your instructor before the session starts."
    exit 1
fi
echo "  Ready."
