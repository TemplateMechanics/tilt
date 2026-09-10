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
#
#   PROFILE=full ./scripts/platform.sh up      bring up every tier (see Tiltfile)
#
# `reset` is the important one for learning. It makes breaking things cheap:
# whatever state the cluster is in, a minute later it is empty again.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CLUSTER="tiltdev"
CONTEXT="kind-${CLUSTER}"
# 10350 is Tilt's default. A second Tilt on the same machine (another repo,
# another cluster) collides silently — override with TILT_PORT.
TILT_PORT="${TILT_PORT:-10350}"
# 443 is the default and gives portless URLs. Set GATEWAY_PORT=8443 together
# with KIND_CONFIG=kind/cluster-alt-ports.yaml when 443/80 are taken locally.
GATEWAY_PORT="${GATEWAY_PORT:-443}"
KIND_CONFIG="${KIND_CONFIG:-kind/cluster.yaml}"
# Which tiers Tilt brings up: minimal | observability | gitops | full.
# minimal is the default on purpose — it is the ten-minute path to a working
# app, and everything above it can be added later without restarting.
PROFILE="${PROFILE:-minimal}"
# ":443" is implicit in https URLs; only print the port when it is non-standard.
url_port() { [ "$GATEWAY_PORT" = "443" ] && echo "" || echo ":${GATEWAY_PORT}"; }

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }; }

cluster_exists() { kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; }

cmd_up() {
    need kind; need kubectl; need tilt; need helm; need flux
    if cluster_exists; then
        echo "kind cluster '$CLUSTER' already exists"
    else
        echo "creating kind cluster '$CLUSTER' from $KIND_CONFIG"
        kind create cluster --config "$KIND_CONFIG" --wait 120s
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
    kind create cluster --config "$KIND_CONFIG" --wait 120s
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
    echo "== charts pinned ==";              python scripts/ci/check-chart-pins.py     || fail=$((fail+1))
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

case "${1:-}" in
    up)    cmd_up ;;
    down)  cmd_down ;;
    reset) cmd_reset ;;
    check) shift; cmd_check "$@" ;;
    ci)    cmd_ci ;;
    hello) cmd_hello ;;
    *) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
