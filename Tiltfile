###############################################################################
# TILT DEVELOPMENT ENVIRONMENT
# 
# This Tiltfile demonstrates three deployment patterns:
# 1. Crossplane DevApplication - For services with sub-resource management
# 2. Tilt + Flux HelmRelease - For standard GitOps Helm deployments
# 3. Tilt + Raw Manifests - For simple local dev tools
#
# Configuration is stored in a K8s ConfigMap (tilt-config in tilt-system),
# with tilt-config.json as the seed file checked into git. A config-server
# pod exposes a REST API; Backstage reaches it via its proxy plugin.
# A sync loop on the host polls the ConfigMap for Backstage-initiated changes
# and writes them to tilt-config.json, triggering Tilt reload via watch_file().
###############################################################################

load("ext://helm_remote", "helm_remote")
load("ext://namespace", "namespace_yaml")

###############################################################################
# CROSS-PLATFORM SHELL HELPER
#
# On Windows, Tilt runs local_resource commands through cmd.exe by default,
# which doesn't understand bash syntax ($(…), for-loops, grep, awk, etc.).
# Wrapping every command with sh() forces execution through bash (Git Bash
# on Windows, /bin/bash everywhere else), making the Tiltfile portable.
#
# IMPORTANT: On Windows, 'bash' on PATH may resolve to WSL's /bin/bash
# which can be broken. We detect Windows first (using raw local() through
# cmd.exe), then locate Git for Windows' bash.exe explicitly.
###############################################################################

# Detect platform BEFORE defining sh(). Raw local() uses cmd.exe on Windows
# and /bin/sh on Unix. 'echo %OS%' outputs 'Windows_NT' on cmd.exe and
# the literal '%OS%' on Unix shells — no bash needed.
_os_probe = str(local('echo %OS%', quiet=True)).strip()
_IS_WINDOWS = 'Windows' in _os_probe

if _IS_WINDOWS:
    # Find Git for Windows bash (avoids WSL conflict).
    # 'git --exec-path' returns e.g. C:/Program Files/Git/mingw64/libexec/git-core
    _git_exec = str(local('git --exec-path', quiet=True)).strip().replace('\\', '/')
    _mingw_idx = _git_exec.find('/mingw')
    if _mingw_idx > 0:
        _BASH = _git_exec[:_mingw_idx] + '/bin/bash.exe'
    else:
        # Fallback: standard Git for Windows install path
        _BASH = 'C:/Program Files/Git/bin/bash.exe'
    print('Windows detected — using Git Bash: ' + _BASH)
else:
    _BASH = 'bash'

def sh(script):
    """Wrap a bash script so it runs through bash on ALL platforms (including Windows).
    
    Returns a list [bash_path, '-c', script] which Tilt executes directly,
    bypassing cmd.exe on Windows.
    """
    return [_BASH, '-c', script]

###############################################################################
# CONFIGURATION (loaded from tilt-config.json)
###############################################################################

# Watch the config file so Tilt reloads when Backstage changes it
watch_file("./tilt-config.json")

# Default config (used if tilt-config.json doesn't exist or is malformed)
DEFAULT_CONFIG = {
    "crossplane_apps": {
        "harbor": {"enabled": False}, "jenkins": {"enabled": False},
        "langfuse": {"enabled": False}, "qdrant": {"enabled": False},
        "localstack": {"enabled": False},
    },
    "flux_apps": {
        "ollama": {"enabled": False}, "kyverno": {"enabled": False},
        "falco": {"enabled": False}, "policy-reporter": {"enabled": False},
        "1pass": {"enabled": False}, "keda": {"enabled": False},
        "velero": {"enabled": False}, "cert-manager": {"enabled": False},
        "trivy": {"enabled": False}, "otel-collector": {"enabled": False},
        "nats": {"enabled": False}, "dapr": {"enabled": False},
        "argo-workflows": {"enabled": False}, "argocd": {"enabled": False},
        "opencost": {"enabled": False},
        "thanos": {"enabled": False},
    },
    "raw_apps": {
        "backstage": {"enabled": False}, "mongodb": {"enabled": False},
        "postgresql": {"enabled": False}, "redis": {"enabled": False},
        "rabbitmq": {"enabled": False}, "mssql": {"enabled": False},
        "keycloak": {"enabled": False}, "airflow": {"enabled": False},
        "jupyterhub": {"enabled": False}, "wordpress": {"enabled": False},
        "mailhog": {"enabled": False}, "azurite": {"enabled": False},
        "gcp-emulators": {"enabled": False}, "azure": {"enabled": False},
        "kubevirt": {"enabled": False}, "macos": {"enabled": False},
        "eyeos": {"enabled": False}, "wazuh": {"enabled": False},
        "knative": {"enabled": False},
    },
}

def load_config():
    """Load config from tilt-config.json, falling back to defaults."""
    config_raw = read_json("./tilt-config.json", DEFAULT_CONFIG)
    
    # Convert rich config format to simple True/False for backward compatibility
    result = {}
    for group in ["crossplane_apps", "flux_apps", "raw_apps"]:
        result[group] = {}
        group_data = config_raw.get(group, {})
        for app, app_config in group_data.items():
            if type(app_config) == "dict":
                result[group][app] = app_config.get("enabled", False)
            else:
                result[group][app] = bool(app_config)
    return result

CONFIG = load_config()

###############################################################################
# CONFIG SERVER (K8s-native control plane API)
#
# Config is stored in a ConfigMap (tilt-config) in the tilt-system namespace.
# The config-server pod reads/writes it via the K8s API. Backstage reaches
# the config-server through its backend proxy plugin (in-cluster routing).
# A sync loop on the host watches for Backstage-initiated changes and writes
# them back to tilt-config.json, which triggers Tilt reload via watch_file().
###############################################################################

# Bootstrap: create namespace, seed ConfigMap from local file, deploy app script
local_resource(
    "tilt-config-seed",
    cmd=sh(" && ".join([
        "kubectl create namespace tilt-system --dry-run=client -o yaml | kubectl apply -f -",
        "kubectl create configmap tilt-config -n tilt-system"
          + " --from-file=config.json=./tilt-config.json"
          + " --dry-run=client -o yaml | kubectl apply -f -",
        "kubectl create configmap tilt-config-server-app -n tilt-system"
          + " --from-file=config-server.py=./scripts/config-server.py"
          + " --dry-run=client -o yaml | kubectl apply -f -",
    ])),
    deps=["./scripts/config-server.py", "./tilt-config.json"],
    labels=["Platform"],
    auto_init=True,
)

# Deploy config server (Deployment + Service + RBAC + IngressRoute)
k8s_yaml(kustomize("./helm/tilt-config-server/"), allow_duplicates=True)
k8s_resource(
    "tilt-config-server",
    labels=["Platform"],
    links=["http://tilt-config.localhost/config"],
    resource_deps=["tilt-config-seed"],
)

# Sync loop: watches ConfigMap for Backstage-initiated changes and writes
# them to tilt-config.json so watch_file() triggers a Tilt reload.
local_resource(
    "tilt-config-sync",
    serve_cmd=sh("""
        echo "Watching ConfigMap tilt-config for Backstage changes..."
        LAST_HASH=""
        while true; do
            DATA=$(kubectl get configmap tilt-config -n tilt-system \
                -o jsonpath='{.data.config\\.json}' 2>/dev/null || echo "")
            if [ -n "$DATA" ]; then
                HASH=$(echo "$DATA" | shasum -a 256 | cut -d' ' -f1)
                if [ -n "$LAST_HASH" ] && [ "$HASH" != "$LAST_HASH" ]; then
                    echo "$DATA" > ./tilt-config.json
                    echo "[$(date +%T)] ConfigMap change detected -> synced to tilt-config.json"
                fi
                LAST_HASH="$HASH"
            fi
            sleep 3
        done
    """),
    labels=["Platform"],
    resource_deps=["tilt-config-server"],
)

###############################################################################
# AUTO-CLEANUP: Delete resources for disabled apps
#
# Order matters for proper teardown:
# 1. Delete Crossplane DevApplication CRs first (lets Crossplane cascade-
#    delete namespace, HelmRelease, IngressRoute, ServiceMonitor).
# 2. Wait briefly for Crossplane to process the cascade.
# 3. Delete any remaining namespaces that weren't fully cleaned up.
# 4. Force-clear Terminating namespaces whose finalizers are stuck.
# 5. Handle special cases (Kyverno webhooks, azure cluster-scoped resources).
###############################################################################

# ── Phase 1: Crossplane DevApplication CR cleanup ──────────────────────
# The DevApplication CRs live in the default namespace, NOT in the app
# namespace. Deleting just the namespace leaves the CR behind, which causes
# Crossplane to keep trying to recreate resources.
disabled_crossplane_apps = []
for app, enabled in CONFIG["crossplane_apps"].items():
    if not enabled:
        disabled_crossplane_apps.append(app)

# When ALL Crossplane apps are disabled, the "crossplane-applications"
# local_resource never runs kubectl apply -k ./apps/, so stale CRs from a
# previous enable cycle persist. Clean them up explicitly.
crossplane_cr_cleanup_cmd = ""
if disabled_crossplane_apps:
    crossplane_cr_cleanup_cmd = (
        "echo 'Cleaning up Crossplane DevApplication CRs...'"
        + " && for app in " + " ".join(disabled_crossplane_apps) + "; do"
        + " kubectl delete devapplication $app -n default --ignore-not-found --wait=false 2>/dev/null || true;"
        + " done"
        + " && echo 'Waiting for Crossplane cascade-delete (10s)...'"
        + " && sleep 10"
    )

# ── Phase 2: Build namespace lists for each group ─────────────────────
disabled_namespaces = []

# Crossplane apps (namespace = app name)
for app in disabled_crossplane_apps:
    disabled_namespaces.append(app)

# Flux apps (check namespace map)
FLUX_NS_MAP = {
    "policy-reporter": "policy-reporter",
    "1pass": "1password-system",
    "cert-manager": "cert-manager",
    "trivy": "trivy-system",
    "otel-collector": "opentelemetry",
    "dapr": "dapr-system",
    "argo-workflows": "argo",
    "argocd": "argocd",
}
for app, enabled in CONFIG["flux_apps"].items():
    if not enabled:
        ns = FLUX_NS_MAP.get(app, app)
        disabled_namespaces.append(ns)

# Raw apps (check namespace map — must match RAW_NAMESPACE_MAP below)
RAW_NS_MAP = {
    "backstage": "backstage",
    "gcp-emulators": "gcp-emulators",
    "mailhog": "mailhog",
    "azurite": "azurite",
    "kubevirt": "kubevirt",
    "macos": "macos",
    "eyeos": "eyeos",
    "mongodb": "mongodb",
    "postgresql": "postgres",  # NOTE: actual namespace is "postgres", not "postgresql"
    "redis": "redis",
    "rabbitmq": "rabbitmq",
    "mssql": "mssql",
    "keycloak": "keycloak",
    "airflow": "airflow",
    "jupyterhub": "jupyterhub",
    "wordpress": "wordpress",
    "wazuh": "wazuh",
    "knative": "knative-serving",
}
# Knative creates additional namespaces beyond its primary one
RAW_EXTRA_NS_MAP = {
    "knative": ["knative-operator", "knative-eventing"],
}
for app, enabled in CONFIG["raw_apps"].items():
    if not enabled:
        ns = RAW_NS_MAP.get(app)
        if ns:
            disabled_namespaces.append(ns)
        for extra_ns in RAW_EXTRA_NS_MAP.get(app, []):
            disabled_namespaces.append(extra_ns)

# ── Phase 3: Build the unified cleanup command ────────────────────────
cleanup_parts = []

# 3a. Crossplane CR deletion (must happen BEFORE namespace deletion)
if crossplane_cr_cleanup_cmd:
    cleanup_parts.append(crossplane_cr_cleanup_cmd)

# 3b. Namespace deletion
if disabled_namespaces:
    cleanup_parts.append(
        "echo 'Deleting disabled namespaces...'"
        + " && for ns in " + " ".join(disabled_namespaces) + "; do"
        + " kubectl delete namespace $ns --ignore-not-found --wait=false 2>/dev/null || true;"
        + " done"
    )

# 3c. Force-clear stuck Terminating namespaces
cleanup_parts.append(
    "echo 'Clearing stuck Terminating namespaces...'"
    + " && for ns in $(kubectl get ns --field-selector status.phase=Terminating -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do"
    + " echo \"  Force-finalizing $ns\";"
    + " kubectl get ns \"$ns\" -o json | jq '.spec.finalizers = []' | kubectl replace --raw \"/api/v1/namespaces/$ns/finalize\" -f - >/dev/null 2>&1 || true;"
    + " done"
)

# 3d. Kyverno-specific cleanup (webhooks, ClusterPolicies, CRDs are cluster-scoped)
if not CONFIG["flux_apps"].get("kyverno"):
    cleanup_parts.append(
        "kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration"
        + " -l app.kubernetes.io/instance=kyverno --ignore-not-found 2>/dev/null || true"
        + " && kubectl delete clusterpolicy --all --ignore-not-found 2>/dev/null || true"
        + " && kubectl delete clusterrole,clusterrolebinding -l app.kubernetes.io/instance=kyverno --ignore-not-found 2>/dev/null || true"
        + " && for crd in $(kubectl get crd -o name 2>/dev/null | grep kyverno.io); do"
        + " kubectl delete $crd --ignore-not-found --wait=false 2>/dev/null || true; done"
    )

# 3e. Azure cluster-scoped resource cleanup (StorageClass, PVs)
if not CONFIG["raw_apps"].get("azure"):
    cleanup_parts.append(
        "kubectl delete storageclass azure-disk azure-file --ignore-not-found 2>/dev/null || true"
    )

# 3f. Orphaned PV cleanup — PVs bound to deleted namespaces can get stuck
#     in Terminating with finalizers that will never resolve. We must also
#     clear the claimRef to break the PVC bind, otherwise the delete hangs.
if disabled_namespaces:
    cleanup_parts.append(
        "echo 'Cleaning up orphaned PVs...'"
        + " && for ns in " + " ".join(disabled_namespaces) + "; do"
        + " for pv in $(kubectl get pv -o json 2>/dev/null | jq -r '.items[] | select(.spec.claimRef.namespace==\"'\"$ns\"'\") | .metadata.name'); do"
        + " echo \"  Force-cleaning PV $pv (ns=$ns)\";"
        + " kubectl patch pv \"$pv\" --type=merge -p '{\"metadata\":{\"finalizers\":null},\"spec\":{\"claimRef\":null}}' 2>/dev/null || true;"
        + " kubectl delete pv \"$pv\" --ignore-not-found --wait=false 2>/dev/null || true;"
        + " done; done"
    )

# 3g. Named cluster-scoped resources from raw apps (ClusterRole, CRB, CRDs)
#     These are NOT deleted when their namespace is removed.
RAW_CLUSTER_CLEANUP = {
    "backstage": "kubectl delete clusterrolebinding backstage-cluster-reader --ignore-not-found 2>/dev/null || true",
    "wazuh": (
        "kubectl delete clusterrole wazuh-filebeat --ignore-not-found 2>/dev/null || true"
        + " && kubectl delete clusterrolebinding wazuh-filebeat --ignore-not-found 2>/dev/null || true"
    ),
    "velero": (
        "kubectl delete clusterrolebinding velero --ignore-not-found 2>/dev/null || true"
        + " && kubectl delete crd -l component=velero --ignore-not-found --wait=false 2>/dev/null || true"
        + " && for crd in $(kubectl get crd -o name 2>/dev/null | grep velero.io); do"
        + " kubectl delete $crd --ignore-not-found --wait=false 2>/dev/null || true; done"
    ),
    "knative": (
        "kubectl delete clusterrole knative-operator --ignore-not-found 2>/dev/null || true"
        + " && kubectl delete clusterrolebinding knative-operator --ignore-not-found 2>/dev/null || true"
        + " && for crd in $(kubectl get crd -o name 2>/dev/null | grep knative.dev); do"
        + " kubectl delete $crd --ignore-not-found --wait=false 2>/dev/null || true; done"
    ),
    "kubevirt": (
        "kubectl delete clusterrole,clusterrolebinding -l kubevirt.io --ignore-not-found 2>/dev/null || true"
        + " && kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l kubevirt.io --ignore-not-found 2>/dev/null || true"
        + " && kubectl delete apiservice -l kubevirt.io --ignore-not-found 2>/dev/null || true"
        + " && for crd in $(kubectl get crd -o name 2>/dev/null | grep kubevirt.io); do"
        + " kubectl delete $crd --ignore-not-found --wait=false 2>/dev/null || true; done"
    ),
}
raw_cluster_cmds = []
for app, enabled in CONFIG["raw_apps"].items():
    if not enabled and app in RAW_CLUSTER_CLEANUP:
        raw_cluster_cmds.append(RAW_CLUSTER_CLEANUP[app])
if raw_cluster_cmds:
    cleanup_parts.append(
        "echo 'Cleaning up cluster-scoped resources from raw apps...'"
        + " && " + " && ".join(raw_cluster_cmds)
    )

# 3h. Label-based cleanup for Flux HelmRelease apps
#     Helm charts install ClusterRoles, CRBs, CRDs, and webhooks that survive
#     namespace deletion. Clean up by Helm instance label.
FLUX_HELM_LABELS = {
    "cert-manager": "app.kubernetes.io/instance=cert-manager",
    "keda": "app.kubernetes.io/instance=keda",
    "falco": "app.kubernetes.io/instance=falco",
    "trivy": "app.kubernetes.io/instance=trivy-operator",
    "dapr": "app.kubernetes.io/part-of=dapr",
    "argocd": "app.kubernetes.io/instance=argocd",
    "argo-workflows": "app.kubernetes.io/instance=argo-workflows",
    "1pass": "app.kubernetes.io/instance=connect",
}
for app, enabled in CONFIG["flux_apps"].items():
    if not enabled and app in FLUX_HELM_LABELS:
        label = FLUX_HELM_LABELS[app]
        cleanup_parts.append(
            "echo '  Cleaning cluster-scoped resources for {app}...'".format(app=app)
            + " && kubectl delete clusterrole,clusterrolebinding -l {label} --ignore-not-found 2>/dev/null || true".format(label=label)
            + " && kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l {label} --ignore-not-found 2>/dev/null || true".format(label=label)
            + " && kubectl delete crd -l {label} --ignore-not-found --wait=false 2>/dev/null || true".format(label=label)
        )
        # Some CRDs don't have labels — clean up by API group for known apps
        if app == "cert-manager":
            cleanup_parts.append(
                "for crd in $(kubectl get crd -o name 2>/dev/null | grep cert-manager.io); do"
                + " kubectl delete $crd --ignore-not-found --wait=false 2>/dev/null || true; done"
            )
        elif app == "keda":
            cleanup_parts.append(
                "for crd in $(kubectl get crd -o name 2>/dev/null | grep keda.sh); do"
                + " kubectl delete $crd --ignore-not-found --wait=false 2>/dev/null || true; done"
            )
        elif app == "dapr":
            cleanup_parts.append(
                "for crd in $(kubectl get crd -o name 2>/dev/null | grep dapr.io); do"
                + " kubectl delete $crd --ignore-not-found --wait=false 2>/dev/null || true; done"
            )
        elif app == "argocd":
            cleanup_parts.append(
                "for crd in $(kubectl get crd -o name 2>/dev/null | grep argoproj.io); do"
                + " kubectl delete $crd --ignore-not-found --wait=false 2>/dev/null || true; done"
            )
        elif app == "argo-workflows":
            cleanup_parts.append(
                "for crd in $(kubectl get crd -o name 2>/dev/null | grep argoproj.io); do"
                + " kubectl delete $crd --ignore-not-found --wait=false 2>/dev/null || true; done"
            )
        elif app == "trivy":
            cleanup_parts.append(
                "for crd in $(kubectl get crd -o name 2>/dev/null | grep aquasecurity.github.io); do"
                + " kubectl delete $crd --ignore-not-found --wait=false 2>/dev/null || true; done"
            )
        elif app == "1pass":
            cleanup_parts.append(
                "for crd in $(kubectl get crd -o name 2>/dev/null | grep onepassword.com); do"
                + " kubectl delete $crd --ignore-not-found --wait=false 2>/dev/null || true; done"
            )

# 3i. Force-clear stuck CRD finalizers (CRDs stuck in Terminating because
#     their namespace was already deleted but the customresourcecleanup
#     finalizer can't reach the CRs)
cleanup_parts.append(
    "echo 'Clearing stuck CRD finalizers...'"
    + " && for crd in $(kubectl get crd -o json 2>/dev/null"
    + " | jq -r '.items[] | select(.metadata.deletionTimestamp != null) | .metadata.name'); do"
    + " echo \"  Force-finalizing CRD $crd\";"
    + " kubectl patch crd \"$crd\" --type=merge -p '{\"metadata\":{\"finalizers\":null}}' 2>/dev/null || true;"
    + " done"
)

cleanup_parts.append("echo '✓ Cleanup complete'")

if disabled_namespaces or disabled_crossplane_apps:
    # resource_deps on crossplane-compositions ensures Crossplane CRDs exist
    # before we try to `kubectl delete devapplication`.  For non-Crossplane-only
    # cleanup the commands already use --ignore-not-found so ordering is safe.
    local_resource(
        "cleanup-disabled-apps",
        cmd=sh(" && ".join(cleanup_parts)),
        labels=["Infrastructure"],
        auto_init=True,
        resource_deps=["crossplane-compositions"],
    )

###############################################################################
# HELPER FUNCTIONS
###############################################################################

def get_os_type():
    """Detect OS type for platform-specific commands.
    Uses _IS_WINDOWS from the early platform detection, plus uname for macOS/Linux.
    """
    if _IS_WINDOWS:
        return "windows"
    uname_result = str(local(sh("uname -s"), quiet=True)).strip()
    if "Darwin" in uname_result:
        return "macos"
    elif "Linux" in uname_result:
        return "linux"
    return "unknown"

def k8s_namespace(namespace_name, allow_duplicates=False):
    """Create a Kubernetes namespace"""
    k8s_yaml(namespace_yaml(namespace_name), allow_duplicates=allow_duplicates)

def k8s_kustomize_simple(path, name, labels=[], links=[], resource_deps=[]):
    """Deploy via kustomize with optional Tilt resource tracking"""
    k8s_yaml(kustomize(path), allow_duplicates=True)
    local_resource(
        name=name,
        cmd=sh("kubectl get pods -n {} 2>/dev/null | head -10 || echo 'Namespace not ready'".format(name)),
        labels=labels,
        links=links,
        resource_deps=resource_deps,
        allow_parallel=True
    )

###############################################################################
# INFRASTRUCTURE (Always On)
###############################################################################

# Required namespaces
k8s_namespace("flux")
k8s_namespace("traefik")
k8s_namespace("monitoring")
k8s_namespace("logging")
k8s_namespace("tracing")

# Local TLS Certificates
os_type = get_os_type()
cert_path = "./certificates"

cert_exists = str(local(sh("test -f {}/intermediateCA/certs/localhost-chain.cert.pem && echo 'yes' || echo 'no'".format(cert_path)), quiet=True)).strip()

local_resource(
    "dev-certificate-generate",
    cmd=sh("""
        cd {cert_path}
        # Fix root-owned CA dirs via macOS GUI sudo prompt
        for d in rootCA intermediateCA; do
            if [ -d "$d" ]; then
                TEST_FILE="$d/index.txt"
                if [ -f "$TEST_FILE" ] && ! [ -w "$TEST_FILE" ]; then
                    echo "$d has root-owned files — requesting admin privileges to fix..."
                    bash ./sudo-helper.sh "chown -R $(whoami) $(pwd)/rootCA $(pwd)/intermediateCA"
                    echo "✓ Fixed ownership on CA directories"
                    break
                fi
            fi
        done
        SKIP_CERT_TRUST=true bash ./generate-certs.sh
    """.format(cert_path=cert_path)),
    labels=["Infrastructure"],
    auto_init=(cert_exists != "yes")
)

local_resource(
    "dev-certificate-trust",
    cmd=sh("""
        cd {cert_path}
        ROOT_CERT="rootCA/certs/ca.cert.pem"
        if [ ! -f "$ROOT_CERT" ]; then
            echo "No root CA cert found — skipping trust"
            exit 0
        fi
        FULL_CERT_PATH="$(pwd)/$ROOT_CERT"
        OS_TYPE="$(uname -s)"

        case "$OS_TYPE" in
            Darwin)
                if security verify-cert -c "$ROOT_CERT" 2>/dev/null; then
                    echo "✓ Root CA is already trusted (macOS)"
                    exit 0
                fi
                echo "Installing Root CA into macOS System keychain..."
                bash ./sudo-helper.sh "security add-trusted-cert -d -r trustRoot -p ssl -k /Library/Keychains/System.keychain $FULL_CERT_PATH"
                echo "✓ Root CA trusted in macOS System keychain"
                ;;
            Linux)
                TARGET="/usr/local/share/ca-certificates/dev-root-ca.crt"
                if [ -f "$TARGET" ]; then
                    EXISTING=$(openssl x509 -in "$TARGET" -noout -fingerprint -sha256 2>/dev/null || echo "")
                    CURRENT=$(openssl x509 -in "$FULL_CERT_PATH" -noout -fingerprint -sha256 2>/dev/null || echo "none")
                    if [ "$EXISTING" = "$CURRENT" ]; then
                        echo "✓ Root CA is already trusted (Linux)"
                        exit 0
                    fi
                fi
                echo "Installing Root CA into Linux trusted certificates..."
                bash ./sudo-helper.sh "cp $FULL_CERT_PATH $TARGET && update-ca-certificates"
                echo "✓ Root CA trusted in Linux certificate store"
                ;;
            MINGW*|MSYS*|CYGWIN*)
                if certutil -verify "$FULL_CERT_PATH" 2>/dev/null | grep -q "UNTRUSTED"; then
                    echo "Installing Root CA into Windows certificate store..."
                    certutil -addstore -user Root "$FULL_CERT_PATH" || {{
                        echo "ERROR: Could not trust Root CA. Run in an admin PowerShell:"
                        echo "  certutil -addstore Root $FULL_CERT_PATH"
                        exit 1
                    }}
                    echo "✓ Root CA trusted in Windows certificate store"
                else
                    echo "✓ Root CA is already trusted (Windows)"
                fi
                ;;
            *)
                echo "Unsupported OS for automatic trust: $OS_TYPE"
                echo "Manually trust: $FULL_CERT_PATH"
                ;;
        esac
    """.format(cert_path=cert_path)),
    labels=["Infrastructure"],
    resource_deps=["dev-certificate-generate"]
)

local_resource(
    "dev-certificate-install",
    cmd=sh("cd {} && kubectl delete secret wildcard-tls-dev --ignore-not-found -n traefik && kubectl create secret tls wildcard-tls-dev -n traefik --key ./intermediateCA/private/localhost.key.pem --cert ./intermediateCA/certs/localhost-chain.cert.pem".format(cert_path)),
    labels=["Infrastructure"],
    resource_deps=["dev-certificate-trust"]
)

# Flux GitOps
local_resource(
    "flux-install",
    cmd=sh("""
        # Check if Flux CLI is available; install it if not
        if ! command -v flux >/dev/null 2>&1; then
            echo "Flux CLI not found — installing..."
            if command -v brew >/dev/null 2>&1; then
                brew install fluxcd/tap/flux
            elif command -v choco >/dev/null 2>&1; then
                choco install flux -y
            elif command -v curl >/dev/null 2>&1; then
                curl -s https://fluxcd.io/install.sh | bash
            else
                echo "ERROR: Cannot install Flux CLI. Install it manually:"
                echo "  https://fluxcd.io/flux/installation/#install-the-flux-cli"
                exit 1
            fi
        fi

        echo "Installing / upgrading Flux on cluster..."
        flux install

        echo "Waiting for all Flux controllers to be ready..."
        kubectl -n flux-system wait --for=condition=available deployment/source-controller --timeout=120s
        kubectl -n flux-system wait --for=condition=available deployment/helm-controller --timeout=120s
        kubectl -n flux-system wait --for=condition=available deployment/kustomize-controller --timeout=120s
        kubectl -n flux-system wait --for=condition=available deployment/notification-controller --timeout=120s
        echo "✓ All Flux controllers ready"

        # Detect available Flux API versions and patch YAMLs to match
        echo "Detecting Flux API versions..."
        HR_API=$(kubectl api-versions | grep helm.toolkit.fluxcd.io | sort -rV | head -1)
        SR_API=$(kubectl api-versions | grep source.toolkit.fluxcd.io | sort -rV | head -1)
        echo "  HelmRelease API: $HR_API"
        echo "  HelmRepository API: $SR_API"

        if [ -n "$HR_API" ]; then
            echo "Patching HelmRelease YAMLs to use $HR_API..."
            find ./helm -name '*.yaml' -exec grep -l 'helm.toolkit.fluxcd.io' {} \\; | while read f; do
                sed -i.bak "s|helm.toolkit.fluxcd.io/[a-z0-9]*|$HR_API|g" "$f" && rm -f "$f.bak"
            done
        fi
        if [ -n "$SR_API" ]; then
            echo "Patching HelmRepository YAMLs to use $SR_API..."
            find ./helm -name '*.yaml' -exec grep -l 'source.toolkit.fluxcd.io' {} \\; | while read f; do
                sed -i.bak "s|source.toolkit.fluxcd.io/[a-z0-9]*|$SR_API|g" "$f" && rm -f "$f.bak"
            done
        fi
        echo "✓ Flux API versions aligned"
    """),
    labels=["Infrastructure"]
)

# Traefik Ingress
helm_remote(
    repo_name="traefik",
    repo_url="https://helm.traefik.io/traefik",
    values="./helm/traefik.yaml",
    namespace="traefik",
    release_name="traefik",
    chart="traefik",
)
k8s_resource("traefik", labels=["Infrastructure"])
watch_file("./helm/traefik.yaml")

###############################################################################
# OBSERVABILITY STACK (Always On)
###############################################################################

# Apply and wait for HelmRepositories to be ready
# NOTE: We do NOT call k8s_yaml(kustomize("./helm/repositories/")) at load time
# because Flux CRDs (HelmRepository) may not exist yet on a fresh cluster.
# Instead, helm-repositories applies them at runtime after flux-install completes.
local_resource(
    "helm-repositories",
    cmd=sh("""
        EXPECTED=$(grep -rl 'kind: HelmRepository' ./helm/repositories/ | xargs grep -c 'kind: HelmRepository' | awk -F: '{s+=$2} END{print s}')
        echo "Expecting $EXPECTED HelmRepositories..."

        echo "Applying HelmRepositories (will retry until all appear)..."
        for i in $(seq 1 30); do
            kubectl apply -k ./helm/repositories/ 2>&1 || true
            sleep 3
            COUNT=$(kubectl get helmrepository -n flux-system --no-headers 2>/dev/null | wc -l | tr -d ' ')
            if [ "$COUNT" -ge "$EXPECTED" ]; then
                echo "✓ $COUNT/$EXPECTED HelmRepositories ready"
                kubectl get helmrepository -n flux-system
                exit 0
            fi
            echo "  Attempt $i/30 ($COUNT/$EXPECTED repositories)..."
        done
        echo "Timeout: only $COUNT/$EXPECTED HelmRepositories created"; exit 1
    """),
    labels=["Platform"],
    resource_deps=["flux-install"]
)

k8s_yaml(kustomize("./helm/prometheus/"), allow_duplicates=True)
local_resource("prometheus", cmd=sh("kubectl get pods -n monitoring | head -5"), labels=["Observability"], links=["https://prometheus.localhost"])

# Apply ServiceMonitors/PodMonitors after Prometheus Operator CRDs are available
local_resource(
    "prometheus-monitors",
    cmd=sh("""
        echo "Waiting for Prometheus Operator CRDs..."
        for i in $(seq 1 60); do
            if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1 && \
               kubectl get crd podmonitors.monitoring.coreos.com >/dev/null 2>&1; then
                echo "CRDs ready — applying monitors..."
                kubectl apply -k ./helm/prometheus/servicemonitors/ 2>&1
                kubectl apply -k ./helm/prometheus/podmonitors/ 2>&1
                echo "ServiceMonitors and PodMonitors applied."
                exit 0
            fi
            echo "  Attempt $i/60 — CRDs not yet available..."
            sleep 5
        done
        echo "Timeout waiting for Prometheus Operator CRDs"; exit 1
    """),
    labels=["Observability"],
    resource_deps=["prometheus"]
)

k8s_yaml(kustomize("./helm/loki/"), allow_duplicates=True)
local_resource("loki", cmd=sh("kubectl get pods -n logging | head -5"), labels=["Observability"])

k8s_yaml(kustomize("./helm/tempo/"), allow_duplicates=True)
local_resource("tempo", cmd=sh("kubectl get pods -n tracing | head -5"), labels=["Observability"])

###############################################################################
# CROSSPLANE PLATFORM
###############################################################################

k8s_yaml(kustomize("./helm/crossplane/"), allow_duplicates=True)

# Wait for Crossplane to be fully ready (HelmRelease + Pods + Webhooks)
local_resource(
    "crossplane-core-ready",
    cmd=sh("""
        echo "Applying Crossplane manifests..."
        kubectl apply -k ./helm/crossplane/ 2>&1
        
        echo "Verifying resources..."
        kubectl get helmrelease -A 2>&1
        kubectl get helmrepository -n flux-system 2>&1 | head -5
        
        echo "Waiting for Crossplane to be fully ready..."
        echo "(This can take 3-5 minutes on cold start)"
        
        # Phase 1: Wait for HelmRelease to exist and be ready (up to 5 min)
        echo "Phase 1: Waiting for HelmRelease..."
        HR_READY="false"
        for i in $(seq 1 150); do
            if kubectl get helmrelease crossplane -n crossplane-system >/dev/null 2>&1; then
                HR_STATUS=$(kubectl get helmrelease crossplane -n crossplane-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
                if [ "$HR_STATUS" = "True" ]; then
                    echo "✓ HelmRelease ready"; HR_READY="true"; break
                fi
                HR_MSG=$(kubectl get helmrelease crossplane -n crossplane-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null || echo "")
                echo "  Attempt $i/150 (status: ${HR_STATUS:-pending}, msg: ${HR_MSG:-n/a})..."; sleep 2
            else
                echo "  Attempt $i/150 (waiting for HelmRelease)..."; sleep 2
            fi
        done
        if [ "$HR_READY" != "true" ]; then
            echo "Timeout: HelmRelease never became Ready"
            kubectl get helmrelease -n crossplane-system -o yaml 2>/dev/null | tail -30
            exit 1
        fi
        
        # Phase 2: Wait for pods and webhooks (up to 3 min)
        echo "Phase 2: Waiting for pods and webhooks..."
        for i in $(seq 1 90); do
            CP_READY=$(kubectl get pods -n crossplane-system -l app=crossplane -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
            WEBHOOK_EP=$(kubectl get endpoints crossplane-webhooks -n crossplane-system -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || echo "")
            if [ "$CP_READY" = "True" ] && [ -n "$WEBHOOK_EP" ]; then
                echo "✓ Crossplane fully ready!"; exit 0
            fi
            echo "  Attempt $i/90 (pod: $CP_READY, webhook: ${WEBHOOK_EP:-none})..."; sleep 2
        done
        echo "Timeout waiting for Crossplane pods"
        kubectl get pods -n crossplane-system 2>/dev/null
        kubectl describe pods -n crossplane-system -l app=crossplane 2>/dev/null | tail -20
        exit 1
    """),
    labels=["Platform"],
    resource_deps=["helm-repositories"]
)

local_resource(
    "crossplane-providers",
    cmd=sh("kubectl apply -f ./helm/crossplane/providers/providers.yaml && echo '✓ Providers applied'"),
    labels=["Platform"],
    resource_deps=["crossplane-core-ready"]
)

local_resource(
    "crossplane-providers-ready",
    cmd=sh("""
        echo "Waiting for providers..."
        for i in $(seq 1 120); do
            HELM_OK=$(kubectl get providers.pkg.crossplane.io provider-helm -o jsonpath='{.status.conditions[?(@.type=="Healthy")].status}' 2>/dev/null || echo "False")
            K8S_OK=$(kubectl get providers.pkg.crossplane.io provider-kubernetes -o jsonpath='{.status.conditions[?(@.type=="Healthy")].status}' 2>/dev/null || echo "False")
            HELM_CRD=$(kubectl get crd providerconfigs.helm.crossplane.io -o name 2>/dev/null || echo "")
            K8S_CRD=$(kubectl get crd providerconfigs.kubernetes.crossplane.io -o name 2>/dev/null || echo "")
            
            # Fix CRD ownership if needed
            if [ "$HELM_OK" = "False" ] && [ -n "$HELM_CRD" ]; then
                HELM_REV=$(kubectl get providers.pkg.crossplane.io provider-helm -o jsonpath='{.status.currentRevision}' 2>/dev/null)
                HELM_UID=$(kubectl get providerrevision "$HELM_REV" -o jsonpath='{.metadata.uid}' 2>/dev/null)
                if [ -n "$HELM_UID" ]; then
                    for crd in releases.helm.crossplane.io providerconfigs.helm.crossplane.io providerconfigusages.helm.crossplane.io; do
                        kubectl patch crd "$crd" --type=json -p="[{\\"op\\": \\"replace\\", \\"path\\": \\"/metadata/ownerReferences/0/uid\\", \\"value\\": \\"$HELM_UID\\"}]" 2>/dev/null || true
                    done
                fi
            fi
            
            if [ "$HELM_OK" = "True" ] && [ "$K8S_OK" = "True" ] && [ -n "$HELM_CRD" ] && [ -n "$K8S_CRD" ]; then
                echo "✓ Providers healthy"; kubectl get providers.pkg.crossplane.io; exit 0
            fi
            echo "Attempt $i/120: helm=$HELM_OK k8s=$K8S_OK"; sleep 3
        done
        exit 1
    """),
    labels=["Platform"],
    resource_deps=["crossplane-providers"]
)

local_resource(
    "crossplane-rbac",
    cmd=sh("kubectl apply -f ./helm/crossplane/providers/configs/rbac.yaml && echo '✓ RBAC applied'"),
    labels=["Platform"],
    resource_deps=["crossplane-providers-ready"]
)

local_resource(
    "crossplane-provider-configs",
    cmd=sh("kubectl apply -f ./helm/crossplane/providers/configs/provider-configs.yaml && echo '✓ ProviderConfigs applied'"),
    labels=["Platform"],
    resource_deps=["crossplane-rbac"]
)

local_resource(
    "crossplane-compositions",
    cmd=sh("kubectl apply -k ./helm/crossplane/compositions/ && echo '✓ Compositions applied'"),
    labels=["Platform"],
    resource_deps=["crossplane-provider-configs"]
)

###############################################################################
# CROSSPLANE APPLICATIONS (Pattern 1: DevApplication XRD)
###############################################################################

# Only apply ENABLED crossplane apps (not the whole kustomize directory,
# which would recreate disabled CRs and fight with the cleanup resource).
enabled_crossplane = [app for app, en in CONFIG["crossplane_apps"].items() if en]
if enabled_crossplane:
    watch_file("./apps/")
    apply_cmds = " && ".join(
        ["kubectl apply -f ./apps/{}.yaml".format(app) for app in enabled_crossplane]
    )
    local_resource(
        "crossplane-applications",
        cmd=sh(apply_cmds + " && echo '✓ DevApplications applied'"),
        labels=["Applications"],
        resource_deps=["crossplane-compositions"]
    )
    
    # Create watchers for enabled apps
    for app in enabled_crossplane:
        local_resource(
            "{}-app".format(app),
            serve_cmd=sh("""
                echo "Waiting for {} pods..."
                while true; do
                    POD=$(kubectl get pods -n {} -l app.kubernetes.io/name={} -o jsonpath='{{.items[0].metadata.name}}' 2>/dev/null)
                    if [ -n "$POD" ]; then
                        echo "Streaming logs from $POD..."
                        kubectl logs -n {} -f "$POD" --all-containers 2>/dev/null || sleep 5
                    else
                        sleep 5
                    fi
                done
            """.format(app, app, app, app)),
            labels=["Applications"],
            links=["https://{}.localhost".format(app)],
            resource_deps=["crossplane-applications"],
            allow_parallel=True
        )

###############################################################################
# FLUX APPLICATIONS (Pattern 2: HelmRelease via Kustomize)
###############################################################################

# Namespace mappings for apps that don't match folder name
FLUX_NAMESPACE_MAP = {
    "policy-reporter": "policy-reporter",
    "1pass": "1password-system",
    "trivy": "trivy-system",
    "otel-collector": "opentelemetry",
    "dapr": "dapr-system",
    "argo-workflows": "argo",
    "argocd": "argocd",
}

# Label mappings for categorization in Tilt UI
FLUX_LABEL_MAP = {
    "ollama": "AI-ML",
    "keycloak": "Security",
    "kyverno": "Security",
    "falco": "Security",
    "trivy": "Security",
    "policy-reporter": "Security",
    "1pass": "Security",
    "airflow": "Data",
    "jupyterhub": "Data",
    "keda": "Infrastructure",
    "velero": "Infrastructure",
    "wordpress": "Demo",
    "otel-collector": "Observability",
    "nats": "Messaging",
    "dapr": "Infrastructure",
    "argo-workflows": "CI-CD",
    "argocd": "CI-CD",
    "opencost": "Observability",
    "thanos": "Observability",
}

for app, enabled in CONFIG["flux_apps"].items():
    if enabled:
        ns = FLUX_NAMESPACE_MAP.get(app, app)
        label = FLUX_LABEL_MAP.get(app, "Flux-Apps")
        k8s_namespace(ns)
        k8s_yaml(kustomize("./helm/{}/".format(app)), allow_duplicates=True)
        
        # For kyverno, we need to wait for it to be fully installed before policies can apply
        if app == "kyverno":
            local_resource(
                app,
                cmd=sh("""
                    echo "Waiting for Kyverno HelmRelease to be ready..."
                    for i in $(seq 1 150); do
                        if kubectl get crd clusterpolicies.kyverno.io >/dev/null 2>&1; then
                            echo "✓ Kyverno CRDs exist, checking pods..."
                            if kubectl get pods -n kyverno -l app.kubernetes.io/instance=kyverno 2>/dev/null | grep -q "Running"; then
                                echo "✓ Kyverno is ready!"
                                kubectl get pods -n kyverno | head -5
                                exit 0
                            fi
                        fi
                        echo "  Attempt $i/150..."; sleep 2
                    done
                    echo "Timeout waiting for Kyverno"; exit 1
                """),
                labels=[label],
                links=["https://{}.localhost".format(app)],
                resource_deps=["helm-repositories"]
            )
            # Apply policies after kyverno is ready
            local_resource(
                "kyverno-policies",
                cmd=sh("""
                    echo "Applying Kyverno policies..."
                    kubectl apply -k ./helm/kyverno-policies/
                    echo "✓ Policies applied"
                    kubectl get clusterpolicy | head -5
                """),
                labels=["Security"],
                resource_deps=[app]
            )
        else:
            local_resource(
                "{}-status".format(app),
                cmd=sh("kubectl get pods -n {} | head -5".format(ns)),
                labels=[label],
                links=["https://{}.localhost".format(app)],
                resource_deps=["helm-repositories"]
            )

###############################################################################
# RAW MANIFEST APPLICATIONS (Pattern 3: Direct Kubernetes Manifests)
###############################################################################

# Build custom Backstage image with Tilt plugin when backstage is enabled
if CONFIG["raw_apps"].get("backstage"):
    docker_build(
        'backstage-custom',
        context='./backstage/app',
        dockerfile='./backstage/app/Dockerfile',
    )

# Namespace mappings for raw apps
RAW_NAMESPACE_MAP = {
    "backstage": "backstage",
    "gcp-emulators": "gcp-emulators",
    "mailhog": "mailhog",
    "azurite": "azurite",
    "azure": None,  # Cluster-scoped resources, no namespace
    "kubevirt": "kubevirt",
    "macos": "macos",
    "eyeos": "eyeos",
    "postgresql": "postgres",
    "mongodb": "mongodb",
    "redis": "redis",
    "rabbitmq": "rabbitmq",
    "keycloak": "keycloak",
    "airflow": "airflow",
    "jupyterhub": "jupyterhub",
    "wordpress": "wordpress",
    "wazuh": "wazuh",
}

# Label mappings for raw apps
RAW_LABEL_MAP = {
    "backstage": "Developer-Portal",
    "mailhog": "Dev-Tools",
    "azurite": "Dev-Tools",
    "gcp-emulators": "Dev-Tools",
    "azure": "Infrastructure",
    "kubevirt": "Infrastructure",
    "macos": "Experimental",
    "eyeos": "Experimental",
    "wazuh": "Security",
    "knative": "Infrastructure",
}

# Workload names in each raw app (for setting dependencies)
RAW_WORKLOADS = {
    "backstage": ["backstage", "bstage-db"],
    "gcp-emulators": ["firestore-emulator", "pubsub-emulator", "bigtable-emulator"],
    "mailhog": ["mailhog"],
    "azurite": ["azurite"],
    "kubevirt": [],  # Installed via local_resource, not kustomize
    "macos": ["macos-vm"],  # KubeVirt VirtualMachine
    "eyeos": ["ios-vm"],    # KubeVirt VirtualMachine
    "postgresql": ["postgres"],
    "keycloak": ["keycloak", "keycloak-postgresql"],
    "airflow": ["airflow-webserver", "airflow-scheduler", "airflow-postgresql", "airflow-redis"],
    "jupyterhub": ["jupyterhub"],
    "wordpress": ["wordpress", "mysql"],
    "wazuh": ["wazuh-indexer", "wazuh-manager", "wazuh-dashboard", "wazuh-filebeat", "wazuh-dashboard-provisioner"],
    "knative": ["knative-operator"],
}

# Apps with web UIs accessible via ingress
RAW_APPS_WITH_UI = ["backstage", "mailhog", "macos", "eyeos", "rabbitmq", "keycloak", "airflow", "jupyterhub", "wordpress", "wazuh"]

# Custom URL mappings (app -> subdomain, defaults to app name)
RAW_APP_URLS = {
    "keycloak": "auth",
}

###############################################################################
# MSSQL (Local Helm Chart)
###############################################################################
if CONFIG["raw_apps"].get("mssql"):
    # Create namespace first (handle stuck Terminating state)
    local_resource(
        "mssql-ns",
        cmd=sh("""
            NS_PHASE=$(kubectl get ns mssql -o jsonpath='{.status.phase}' 2>/dev/null || echo '')
            if [ "$NS_PHASE" = "Terminating" ]; then
                echo 'Namespace mssql is Terminating, clearing finalizers...'
                kubectl get ns mssql -o json | jq '.spec.finalizers = []' | kubectl replace --raw /api/v1/namespaces/mssql/finalize -f - >/dev/null 2>&1 || true
                for i in $(seq 1 30); do kubectl get ns mssql >/dev/null 2>&1 || break; sleep 1; done
            fi
            kubectl create namespace mssql --dry-run=client -o yaml | kubectl apply -f -
        """),
        labels=["Databases"],
    )
    
    # Deploy MSSQL using local helm chart
    local_resource(
        "mssql",
        cmd=sh("helm upgrade --install mssql ./helm/mssql -n mssql --wait --timeout=5m && kubectl get pods -n mssql"),
        labels=["Databases"],
        resource_deps=["mssql-ns"],
        links=["https://mssql.localhost"],
    )

for app, enabled in CONFIG["raw_apps"].items():
    if enabled:
        # Skip MSSQL - handled separately as a Helm chart above
        if app == "mssql":
            continue
            
        ns = RAW_NAMESPACE_MAP.get(app, app)
        label = RAW_LABEL_MAP.get(app, "Dev-Tools")
        
        # First, create namespace via local_resource to ensure it exists before workloads.
        # If the namespace is stuck Terminating, force-clear its finalizers and wait.
        if ns:
            local_resource(
                "{}-ns".format(app),
                cmd=sh("""
                    NS_PHASE=$(kubectl get ns {ns} -o jsonpath='{{.status.phase}}' 2>/dev/null || echo '')
                    if [ "$NS_PHASE" = "Terminating" ]; then
                        echo 'Namespace {ns} is Terminating, clearing finalizers...'
                        kubectl get ns {ns} -o json | jq '.spec.finalizers = []' | kubectl replace --raw /api/v1/namespaces/{ns}/finalize -f - >/dev/null 2>&1 || true
                        echo 'Waiting for namespace to be fully removed...'
                        for i in $(seq 1 30); do
                            kubectl get ns {ns} >/dev/null 2>&1 || break
                            sleep 1
                        done
                    fi
                    kubectl create namespace {ns} --dry-run=client -o yaml | kubectl apply -f -
                """.format(ns=ns)),
                labels=[label],
            )
        
        # Apply kustomize manifests
        k8s_yaml(kustomize("./helm/{}/".format(app)), allow_duplicates=True)
        
        # Special handling for KubeVirt - install operator and CR sequentially
        if app == "kubevirt":
            # Install the KubeVirt operator from official release
            local_resource(
                "kubevirt-operator",
                cmd=sh("kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v1.3.1/kubevirt-operator.yaml"),
                labels=[label],
                resource_deps=["kubevirt-ns"],
            )
            # Apply CR after operator is ready
            local_resource(
                "kubevirt-cr",
                cmd=sh("kubectl wait --for=condition=Available deployment/virt-operator -n kubevirt --timeout=180s && kubectl apply -f ./helm/kubevirt/kubevirt-cr.yaml"),
                labels=[label],
                resource_deps=["kubevirt-operator"],
            )
        
        # Set workload dependencies on namespace
        workloads = RAW_WORKLOADS.get(app, [app])
        for workload in workloads:
            url_subdomain = RAW_APP_URLS.get(app, app)
            # Provisioner job depends on dashboard, not just namespace
            extra_deps = []
            if workload == "wazuh-dashboard-provisioner":
                extra_deps = ["wazuh-dashboard"]
            k8s_resource(
                workload,
                labels=[label],
                resource_deps=(["{}-ns".format(app)] if ns else []) + extra_deps,
                links=["https://{}.localhost".format(url_subdomain)] if app in RAW_APPS_WITH_UI and workload not in ["wazuh-dashboard-provisioner"] else []
            )

###############################################################################
# HARBOR RESOURCES (Example: Sub-resources via Crossplane)
###############################################################################

if CONFIG["crossplane_apps"].get("harbor"):
    # Apply Harbor XRD for project management
    local_resource(
        "harbor-xrd",
        cmd=sh("kubectl apply -k ./helm/crossplane/compositions/harbor/ 2>/dev/null || echo 'Harbor XRD not ready yet'"),
        labels=["App-Resources"],
        resource_deps=["crossplane-compositions"]
    )
    
    # Apply Harbor projects
    local_resource(
        "harbor-resources",
        cmd=sh("kubectl apply -k ./apps/harbor-resources/ 2>/dev/null || echo 'Waiting for Harbor XRD...'"),
        labels=["App-Resources"],
        resource_deps=["harbor-app", "harbor-xrd"]
    )

