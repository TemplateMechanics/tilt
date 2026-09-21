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

pass=0; fail=0; warn=0
ok()   { pass=$((pass+1)); printf '  \033[32mok\033[0m    %s\n' "$*"; }
bad()  { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$*"; }
warn() { warn=$((warn+1)); printf '  \033[33mwarn\033[0m  %s\n' "$*"; }
note() { printf '        %s\n' "$*"; }

echo "Student pre-flight — $(date '+%Y-%m-%d %H:%M')"
echo
echo "== tools"
for t in kind kubectl helm flux tilt; do
    if command -v "$t" >/dev/null 2>&1; then ok "$t found"
    else bad "$t is not on PATH"; note "see the Prerequisites table in README.md"; fi
done

# bash 3.x (macOS's system bash) cannot run these scripts.
if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then ok "bash ${BASH_VERSION%%(*}"
else bad "bash ${BASH_VERSION%%(*} is too old - needs 4+"; fi

echo
echo "== container daemon"
if docker info >/dev/null 2>&1; then
    ok "container daemon is running"
    # kind pulls images into the node, not the host, so a reset re-downloads
    # up to ~10 GB (measured: 9.7 GB with every profile on). A full disk shows up as pods stuck in ContainerCreating with no
    # obvious error.
    # Measured on the host filesystem, not inside the daemon's VM: a VM
    # reports its sparse virtual disk and cheerfully claims 1.5 TB free on a
    # laptop that has 12 GB left.
    home_fs="${HOME:-/}"
    free_gb=$(df -BG "$home_fs" 2>/dev/null | awk 'NR==2{gsub("G","",$4); print $4}')
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
    cv=$(kubectl version --client -o json 2>/dev/null | python -c "import sys,json;print(json.load(sys.stdin)['clientVersion']['minor'])" 2>/dev/null)
    # Prefer the running cluster; kind/cluster.yaml pins no node image, so the
    # version is whatever the installed kind defaults to.
    want=$(kubectl --context "$CONTEXT" version -o json 2>/dev/null | python -c "import sys,json;print(json.load(sys.stdin)['serverVersion']['minor'].strip('+'))" 2>/dev/null)
    [ -n "$want" ] || want=$(grep -oE 'kindest/node:v1\.[0-9]+' "$ROOT/kind/cluster.yaml" 2>/dev/null | head -1 | grep -oE '[0-9]+$')
    if [ -n "$cv" ] && [ -n "$want" ]; then
        d=$((want - cv)); [ "$d" -lt 0 ] && d=$(( -d ))
        if [ "$d" -le 1 ]; then ok "kubectl 1.$cv against cluster 1.$want"
        else warn "kubectl 1.$cv vs cluster 1.$want - expect a skew warning on every command"; fi
    else warn "could not compare kubectl and cluster versions"; fi
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
        # The real question is not "did it install" but "does it answer".
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -k https://hello.localhost/ 2>/dev/null)
        if [ "$code" = "200" ]; then ok "https://hello.localhost answers 200"
        else bad "https://hello.localhost returned '${code:-no response}'"
             note "if Tilt is still building, wait for hello-world to go green and re-run"; fi
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
