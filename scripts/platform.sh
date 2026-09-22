#!/usr/bin/env bash
# One entry point for the platform. Works from Git Bash on Windows, and from
# bash on macOS/Linux. `make <target>` delegates here for people who have make.
#
#   ./scripts/platform.sh up      create the kind cluster if missing, then tilt up
#   ./scripts/platform.sh down    tilt down (cluster stays; state stays)
#   ./scripts/platform.sh reset   destroy the kind cluster and rebuild it empty
#   ./scripts/platform.sh check   render every enabled service in a real browser
#   ./scripts/platform.sh ci      run the same checks CI runs, locally
#   ./scripts/platform.sh hello   deploy examples/hello-world and prove it works
#   ./scripts/platform.sh lab NN  run the grader for labs/NN-*
#   ./scripts/platform.sh test    run the steady-state lab graders (01, 03, 07 if its fixture is up)
#
#   PROFILE=full ./scripts/platform.sh up      bring up every tier (see Tiltfile)
#
# `reset` is the important one for learning. It makes breaking things cheap:
# whatever state the cluster is in, a minute later it is empty again.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# The cluster name, and therefore the kube context. Overridable so a second
# cluster can run beside the first — one on Docker and one on Podman, say —
# without the two claiming the same context name in your kubeconfig and
# silently pointing your kubectl at the wrong cluster.
CLUSTER="${CLUSTER:-tiltdev}"
CONTEXT="kind-${CLUSTER}"
# 10350 is Tilt's default. A second Tilt on the same machine (another repo,
# another cluster) collides silently — override with TILT_PORT.
TILT_PORT="${TILT_PORT:-10350}"
# 443 is the default and gives portless URLs. Set GATEWAY_PORT=8443 together
# with KIND_CONFIG=kind/cluster-alt-ports.yaml when 443/80 are taken locally.
GATEWAY_PORT="${GATEWAY_PORT:-443}"
# Certificate revocation is fetched over plaintext HTTP even though services
# use HTTPS. Keep the two host-port mappings paired for the supported kind
# topologies, while allowing an explicit value for custom mappings.
if [ -z "${GATEWAY_HTTP_PORT:-}" ]; then
    case "$GATEWAY_PORT" in
        443)  GATEWAY_HTTP_PORT=80 ;;
        8443) GATEWAY_HTTP_PORT=8080 ;;
        *)
            echo "GATEWAY_HTTP_PORT is required when GATEWAY_PORT is $GATEWAY_PORT" >&2
            exit 2
            ;;
    esac
fi
if [ "$GATEWAY_HTTP_PORT" = "80" ]; then
    CRL_BASE_URL="${CRL_BASE_URL:-http://crl.localhost}"
else
    CRL_BASE_URL="${CRL_BASE_URL:-http://crl.localhost:${GATEWAY_HTTP_PORT}}"
fi
export CLUSTER CONTEXT GATEWAY_PORT GATEWAY_HTTP_PORT CRL_BASE_URL
KIND_CONFIG="${KIND_CONFIG:-kind/cluster.yaml}"
# Which tiers Tilt brings up: minimal | observability | gitops | full.
# minimal is the default on purpose — it is the ten-minute path to a working
# app, and everything above it can be added later without restarting.
PROFILE="${PROFILE:-minimal}"
# ":443" is implicit in https URLs; only print the port when it is non-standard.
url_port() { [ "$GATEWAY_PORT" = "443" ] && echo "" || echo ":${GATEWAY_PORT}"; }

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }; }
need_python_yaml() {
    python -c 'import yaml' >/dev/null 2>&1 || {
        echo "missing Python module: PyYAML (install with: python -m pip install pyyaml)" >&2
        exit 1
    }
}

cluster_exists() { kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; }

# Podman only. netavark 2.x builds one `inet netavark` table whose NAT chains
# open with `fib daddr type local`, so a kernel without nft_fib_inet cannot
# apply the ruleset and NO bridge network can be created. netavark treats the
# kernel's "No such file or directory" as "table not created yet" and swallows
# it, so podman reports `nftables error: "nft" did not return successfully
# while applying ruleset:` with an EMPTY message and kind dies with nothing to
# search for. Microsoft's WSL kernel 6.6.87.2 lacked the module; WSL 2.7.13
# (kernel 6.18.33.2) has it. Checked read-only, and only when podman is chosen.
podman_preflight() {
    [ "${KIND_EXPERIMENTAL_PROVIDER:-}" = "podman" ] || return 0
    need podman
    local probe='modinfo nft_fib_inet >/dev/null 2>&1 || zcat /proc/config.gz 2>/dev/null | grep -q "^CONFIG_NFT_FIB_INET=y"'
    local run="sh -c"
    # On Windows and macOS podman runs in a VM, and it is that VM's kernel that
    # matters, not the host's.
    if podman machine list --format '{{.Name}}' 2>/dev/null | grep -q .; then
        run="podman machine ssh --"
    fi
    if $run "$probe" >/dev/null 2>&1; then
        echo "podman preflight: kernel provides nft_fib_inet"
    else
        echo "podman preflight FAILED: this kernel has no nft_fib_inet." >&2
        echo "  netavark cannot build its nftables ruleset, so no bridge network" >&2
        echo "  can be created and kind will fail with an EMPTY nftables error." >&2
        echo "  Windows: run 'wsl --update' (2.7.13 ships kernel 6.18.33.2), then" >&2
        echo "  'wsl --shutdown'. Elsewhere: use a kernel built with CONFIG_NFT_FIB_INET." >&2
        exit 1
    fi
}


cmd_up() {
    need kind; need kubectl; need tilt; need helm; need flux
    need python; need curl; need openssl
    need_python_yaml
    podman_preflight
    if cluster_exists; then
        echo "kind cluster '$CLUSTER' already exists"
    else
        echo "creating kind cluster '$CLUSTER' from $KIND_CONFIG"
        kind create cluster --name "$CLUSTER" --config "$KIND_CONFIG" --wait 120s
    fi
    kubectl config use-context "$CONTEXT" >/dev/null
    echo
    echo "starting Tilt on http://localhost:${TILT_PORT} with --profile=${PROFILE}"
    echo "services will be at https://<name>.localhost$(url_port)"
    echo "first run installs Istio, cert-manager and the observability stack;"
    echo "allow ~10 minutes before hello.localhost answers."
    exec tilt up --port "$TILT_PORT" --context "$CONTEXT" -- --profile="$PROFILE"
}

cmd_down() {
    need tilt
    tilt down --context "$CONTEXT" || true
    echo "cluster '$CLUSTER' still exists; use 'reset' to destroy it"
}

cmd_reset() {
    need kind
    if cluster_exists; then
        echo "destroying kind cluster '$CLUSTER'"
        kind delete cluster --name "$CLUSTER"
    fi
    echo "recreating from $KIND_CONFIG"
    kind create cluster --name "$CLUSTER" --config "$KIND_CONFIG" --wait 120s
    kubectl config use-context "$CONTEXT" >/dev/null
    echo
    echo "empty cluster ready. run 'up' to bring the platform back."
}

cmd_check() {
    need node; need npm
    # browser-check.mjs is an ES module, and ESM resolves `import 'playwright'`
    # by walking up from the importing FILE's directory — NODE_PATH is ignored
    # entirely. So the dependency has to live beside the script:
    # scripts/validate/package.json + node_modules (gitignored). A first version
    # of this set NODE_PATH to a cache dir and failed with ERR_MODULE_NOT_FOUND
    # on every run; it only ever appeared to work when the script had been
    # copied next to node_modules by hand.
    if [ ! -d "scripts/validate/node_modules/playwright" ]; then
        echo "installing playwright into scripts/validate/node_modules (one time)"
        (cd scripts/validate && npm install --no-audit --no-fund >/dev/null)
    fi
    local out="${ROOT}/.browser-check"
    node scripts/validate/browser-check.mjs         --services scripts/validate/services.json --port "$GATEWAY_PORT" --out "$out" "$@"
    echo "screenshots: $out/"
}

cmd_ci() {
    need python; need kubectl
    need_python_yaml
    local fail=0
    echo "== kustomize build =="
    local pass=0
    while IFS= read -r k; do
        d=$(dirname "$k")
        if kubectl kustomize "$d" >/dev/null 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAILED $d"; fi
    done < <(find . -name kustomization.yaml -not -path "./backstage/app/node_modules/*" \
               -not -path "*/skeleton/*" -not -path "./archive/*" | sort)
    echo "  $pass passed, $fail failed"
    echo "== routed hostnames have SANs =="; python scripts/ci/check-route-hostnames.py || fail=$((fail+1))
    echo "== local PKI revocation ==";       python scripts/ci/check-local-pki.py        || fail=$((fail+1))
    echo "== charts pinned ==";              python scripts/ci/check-chart-pins.py     || fail=$((fail+1))
    echo "== AI Ops dashboard safety ==";    python scripts/ci/check-ai-ops-dashboard.py || fail=$((fail+1))
    echo "== MCP config safety ==";           python scripts/validate/mcp-check.py --config-only || fail=$((fail+1))
    echo "== scripts executable in git ==";  python scripts/ci/check-exec-bits.py      || fail=$((fail+1))
    [ "$fail" -eq 0 ] && echo "all checks passed" || { echo "$fail failure(s)"; exit 1; }
}

cmd_hello() {
    need kubectl
    kubectl --context "$CONTEXT" apply -k examples/hello-world
    echo "waiting for the pod to be Ready..."
    kubectl --context "$CONTEXT" -n hello rollout status deploy/hello --timeout=120s
    echo
    echo "https://hello.localhost$(url_port)"
    echo "proving it in a real browser:"
    cmd_check --only hello
}

cmd_lab() {
    local n="${1:-}"; [ -n "$n" ] || { echo "usage: lab NN"; exit 2; }
    local dir; dir=$(ls -d "labs/${n}-"* 2>/dev/null | head -1)
    [ -n "$dir" ] || { echo "no lab matching labs/${n}-*"; exit 2; }
    CONTEXT="$CONTEXT" GATEWAY_PORT="$GATEWAY_PORT" bash "$dir/check.sh"
}

cmd_test() {
    # Only labs that pass in the platform's steady state, with no per-lab
    # setup. 02, 04, 05 and 06 each stage something first (a second route, a
    # broken cert, an HPA under load, a Canary) and would fail here by design
    # — and 06 hands `hello` to Flagger, which breaks 01 and 03 until it is
    # undone. Run those with `lab NN` after following their README.
    local labs="01 03" rc=0
    # Lab 07 owns its fixture now (labs/07-stateful-rollout/mysql.yaml); it used
    # to borrow the wordpress app, which meant the lab silently skipped unless
    # wordpress happened to be enabled in tilt-config.json.
    kubectl --context "$CONTEXT" -n lab07 get deploy mysql >/dev/null 2>&1 && labs="$labs 07"
    echo "steady-state labs: $labs"
    for n in $labs; do echo; cmd_lab "$n" || rc=1; done
    echo; [ "$rc" -eq 0 ] && echo "all graders passed" || { echo "some graders failed"; exit 1; }
}

case "${1:-}" in
    up)    cmd_up ;;
    down)  cmd_down ;;
    reset) cmd_reset ;;
    check) shift; cmd_check "$@" ;;
    ci)    cmd_ci ;;
    hello) cmd_hello ;;
    lab)   shift; cmd_lab "$@" ;;
    test)  cmd_test ;;
    *) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
