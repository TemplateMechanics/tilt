###############################################################################
# TILT DEVELOPMENT ENVIRONMENT
# 
# This Tiltfile demonstrates three deployment patterns:
# 1. Crossplane DevApplication - For services with sub-resource management
# 2. Tilt + Flux HelmRelease - For standard GitOps Helm deployments
# 3. Tilt + Raw Manifests - For simple local dev tools
###############################################################################

load("ext://helm_remote", "helm_remote")
load("ext://namespace", "namespace_yaml")

###############################################################################
# CONFIGURATION
###############################################################################

# Toggle services on/off (set to True to enable)
CONFIG = {
    # ==========================================================================
    # CROSSPLANE-MANAGED APPS (via DevApplication XRD)
    # Best for: Services that need sub-resource management (repos, users, jobs)
    # ==========================================================================
    "crossplane_apps": {
        # CI/CD
        "harbor": False,      # Container registry ✅ tested
        "jenkins": False,     # CI/CD automation ✅ tested
        
        # AI/ML
        "langfuse": False,    # LLM observability ✅ tested
        "qdrant": False,      # Vector database ✅ tested
        
        # Cloud Emulators
        "localstack": False,  # AWS services emulator ✅ tested
    },
    
    # ==========================================================================
    # FLUX-MANAGED APPS (via HelmRelease + Kustomize)
    # Best for: Helm charts from external repos with GitOps reconciliation
    # ==========================================================================
    "flux_apps": {
        # AI/ML
        "ollama": False,          # Local LLM runner ✅ tested
        
        # Security & Policy
        "kyverno": False,         # Kubernetes policy engine ✅ tested
        "falco": False,           # Runtime security monitoring ✅ tested
        "policy-reporter": False, # Kyverno policy reports (requires kyverno)
        "1pass": False,           # 1Password Connect (requires secrets)
        
        # Infrastructure
        "keda": False,            # Event-driven autoscaling ✅ tested
        "velero": False,          # Backup and DR (needs full CRD install)
        "cert-manager": False,    # Certificate management ✅ tested
    },
    
    # ==========================================================================
    # RAW MANIFEST APPS (via direct Kustomize - official images)
    # Best for: Simple deployments, custom configs, avoiding Helm complexity
    # ==========================================================================
    "raw_apps": {
        # Developer Portal
        "backstage": False,       # Backstage Developer Portal (control plane UI) ✅ tested
        
        # Databases (official images)
        "mongodb": False,         # MongoDB document database (mongo:8.0) ✅ tested
        "postgresql": False,      # PostgreSQL database (postgres:17) ✅ tested
        "redis": False,           # Redis cache (redis:8-alpine) ✅ tested
        "rabbitmq": False,        # RabbitMQ broker (rabbitmq:4-management) ✅ tested
        "mssql": True,            # Microsoft SQL Server (local Helm chart)
        
        # Identity & Workflow (official images)
        "keycloak": False,        # Identity management (quay.io/keycloak) ✅ tested
        "airflow": False,         # Workflow orchestration (apache/airflow) ✅ tested
        "jupyterhub": False,      # Jupyter notebooks (jupyterhub/k8s-hub) ✅ tested
        
        # Demo Apps
        "wordpress": False,       # WordPress blog (wordpress:6.4) ✅ tested
        
        # Cloud Emulators
        "mailhog": False,         # Email testing SMTP server ✅ tested
        "azurite": False,         # Azure Storage emulator ✅ tested
        "gcp-emulators": False,   # GCP emulators ✅ tested
        
        # Infrastructure
        "azure": False,           # Azure storage classes and PVCs
        "kubevirt": False,        # KubeVirt VM operator (requires Linux with KVM) ⚠️ Won't work on Mac
        
        # Experimental (require KubeVirt + KVM)
        "macos": False,           # macOS VM via KubeVirt (requires kubevirt)
        "eyeos": False,           # iOS VM via KubeVirt (requires kubevirt)
    },
}

###############################################################################
# AUTO-CLEANUP: Delete resources for disabled apps
###############################################################################

# Build list of disabled app namespaces to clean up
disabled_namespaces = []

# Crossplane apps (namespace = app name)
for app, enabled in CONFIG["crossplane_apps"].items():
    if not enabled:
        disabled_namespaces.append(app)

# Flux apps (check namespace map)
FLUX_NS_MAP = {
    "policy-reporter": "policy-reporter",
    "1pass": "1password-system",
    "cert-manager": "cert-manager",
}
for app, enabled in CONFIG["flux_apps"].items():
    if not enabled:
        ns = FLUX_NS_MAP.get(app, app)
        disabled_namespaces.append(ns)

# Raw apps (check namespace map)
RAW_NS_MAP = {
    "backstage": "backstage",
    "gcp-emulators": "gcp-emulators",
    "mailhog": "mailhog", 
    "azurite": "azurite",
    "kubevirt": "kubevirt",
    "macos": "macos",
    "eyeos": "eyeos",
    "mongodb": "mongodb",
    "postgresql": "postgresql",
    "redis": "redis",
    "rabbitmq": "rabbitmq",
    "mssql": "mssql",
    "keycloak": "keycloak",
    "airflow": "airflow",
    "jupyterhub": "jupyterhub",
    "wordpress": "wordpress",
}
for app, enabled in CONFIG["raw_apps"].items():
    if not enabled:
        ns = RAW_NS_MAP.get(app)
        if ns:
            disabled_namespaces.append(ns)

# Create cleanup resource that runs once at startup
if disabled_namespaces:
    # Build cleanup command
    cleanup_cmd = "for ns in {}; do kubectl delete namespace $ns --ignore-not-found --wait=false 2>/dev/null || true; done".format(" ".join(disabled_namespaces))
    
    # Add Kyverno-specific cleanup (webhooks, CRDs) if kyverno is disabled
    if not CONFIG["flux_apps"].get("kyverno"):
        cleanup_cmd += " && kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno --ignore-not-found 2>/dev/null || true"
        cleanup_cmd += " && kubectl delete clusterpolicy --all --ignore-not-found 2>/dev/null || true"
    
    cleanup_cmd += " && echo '✓ Cleanup complete'"
    
    local_resource(
        "cleanup-disabled-apps",
        cmd=cleanup_cmd,
        labels=["Infrastructure"],
        auto_init=True,
    )

###############################################################################
# HELPER FUNCTIONS
###############################################################################

def get_os_type():
    """Detect OS type for platform-specific commands"""
    windows_check = str(local("echo %OS%", quiet=True)).strip().lower()
    if "windows" in windows_check:
        return "windows"
    uname_result = str(local("uname", quiet=True)).strip().lower()
    if "darwin" in uname_result:
        return "macos"
    elif "linux" in uname_result:
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
        cmd="kubectl get pods -n {} 2>/dev/null | head -10 || echo 'Namespace not ready'".format(name),
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

cert_exists = str(local("test -f {}/intermediateCA/certs/localhost-chain.cert.pem && echo 'yes' || echo 'no'".format(cert_path), quiet=True)).strip()

local_resource(
    "dev-certificate-install",
    cmd="cd {} && kubectl delete secret wildcard-tls-dev --ignore-not-found -n traefik && kubectl create secret tls wildcard-tls-dev -n traefik --key ./intermediateCA/private/localhost.key.pem --cert ./intermediateCA/certs/localhost-chain.cert.pem".format(cert_path) if cert_exists == "yes" else "echo 'Run certificate generation first'",
    labels=["Infrastructure"],
    auto_init=(cert_exists == "yes")
)

# Flux GitOps
local_resource(
    "flux-install",
    cmd="flux check --pre && flux install || echo 'Flux already installed'",
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

k8s_yaml(kustomize("./helm/repositories/"), allow_duplicates=True)

# Apply and wait for HelmRepositories to be ready
local_resource(
    "helm-repositories",
    cmd="""
        echo "Applying HelmRepositories..."
        kubectl apply -k ./helm/repositories/ || true
        
        echo "Waiting for HelmRepositories to be ready..."
        for i in $(seq 1 60); do
            COUNT=$(kubectl get helmrepository -n flux-system --no-headers 2>/dev/null | wc -l | tr -d ' ')
            if [ "$COUNT" -gt 5 ]; then
                echo "✓ $COUNT HelmRepositories found"
                kubectl get helmrepository -n flux-system | head -10
                exit 0
            fi
            echo "  Attempt $i/60 (found: $COUNT repositories)..."; sleep 2
        done
        echo "Timeout waiting for HelmRepositories"; exit 1
    """,
    labels=["Platform"],
    resource_deps=["flux-install"]
)

k8s_yaml(kustomize("./helm/prometheus/"), allow_duplicates=True)
local_resource("prometheus", cmd="kubectl get pods -n monitoring | head -5", labels=["Observability"], links=["https://prometheus.localhost"])

k8s_yaml(kustomize("./helm/loki/"), allow_duplicates=True)
local_resource("loki", cmd="kubectl get pods -n logging | head -5", labels=["Observability"])

k8s_yaml(kustomize("./helm/tempo/"), allow_duplicates=True)
local_resource("tempo", cmd="kubectl get pods -n tracing | head -5", labels=["Observability"])

###############################################################################
# CROSSPLANE PLATFORM
###############################################################################

k8s_yaml(kustomize("./helm/crossplane/"), allow_duplicates=True)

# Wait for Crossplane to be fully ready (HelmRelease + Pods + Webhooks)
local_resource(
    "crossplane-core-ready",
    cmd="""
        echo "Applying Crossplane manifests..."
        kubectl apply -k ./helm/crossplane/ || true
        
        echo "Waiting for Crossplane to be fully ready..."
        echo "(This can take 3-5 minutes on cold start)"
        
        # Phase 1: Wait for HelmRelease to exist and be ready (up to 5 min)
        echo "Phase 1: Waiting for HelmRelease..."
        for i in $(seq 1 150); do
            if kubectl get helmrelease crossplane -n crossplane-system >/dev/null 2>&1; then
                HR_STATUS=$(kubectl get helmrelease crossplane -n crossplane-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
                if [ "$HR_STATUS" = "True" ]; then
                    echo "✓ HelmRelease ready"; break
                fi
                echo "  Attempt $i/150 (status: ${HR_STATUS:-pending})..."; sleep 2
            else
                echo "  Attempt $i/150 (waiting for HelmRelease)..."; sleep 2
            fi
        done
        
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
        echo "Timeout waiting for Crossplane"; exit 1
    """,
    labels=["Platform"],
    resource_deps=["helm-repositories"]
)

local_resource(
    "crossplane-providers",
    cmd="kubectl apply -f ./helm/crossplane/providers/providers.yaml && echo '✓ Providers applied'",
    labels=["Platform"],
    resource_deps=["crossplane-core-ready"]
)

local_resource(
    "crossplane-providers-ready",
    cmd="""
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
    """,
    labels=["Platform"],
    resource_deps=["crossplane-providers"]
)

local_resource(
    "crossplane-rbac",
    cmd="kubectl apply -f ./helm/crossplane/providers/configs/rbac.yaml && echo '✓ RBAC applied'",
    labels=["Platform"],
    resource_deps=["crossplane-providers-ready"]
)

local_resource(
    "crossplane-provider-configs",
    cmd="kubectl apply -f ./helm/crossplane/providers/configs/provider-configs.yaml && echo '✓ ProviderConfigs applied'",
    labels=["Platform"],
    resource_deps=["crossplane-rbac"]
)

local_resource(
    "crossplane-compositions",
    cmd="kubectl apply -k ./helm/crossplane/compositions/ && echo '✓ Compositions applied'",
    labels=["Platform"],
    resource_deps=["crossplane-provider-configs"]
)

###############################################################################
# CROSSPLANE APPLICATIONS (Pattern 1: DevApplication XRD)
###############################################################################

# Only apply if any crossplane apps are enabled
if any(CONFIG["crossplane_apps"].values()):
    watch_file("./apps/")
    local_resource(
        "crossplane-applications",
        cmd="kubectl apply -k ./apps/ && echo '✓ DevApplications applied'",
        labels=["Applications"],
        resource_deps=["crossplane-compositions"]
    )
    
    # Create watchers for enabled apps
    for app, enabled in CONFIG["crossplane_apps"].items():
        if enabled:
            local_resource(
                "{}-app".format(app),
                serve_cmd="""
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
                """.format(app, app, app, app),
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
}

# Label mappings for categorization in Tilt UI
FLUX_LABEL_MAP = {
    "ollama": "AI-ML",
    "keycloak": "Security",
    "kyverno": "Security",
    "falco": "Security",
    "policy-reporter": "Security",
    "1pass": "Security",
    "airflow": "Data",
    "jupyterhub": "Data",
    "keda": "Infrastructure",
    "velero": "Infrastructure",
    "wordpress": "Demo",
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
                cmd="""
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
                """,
                labels=[label],
                links=["https://{}.localhost".format(app)],
                resource_deps=["helm-repositories"]
            )
            # Apply policies after kyverno is ready
            local_resource(
                "kyverno-policies",
                cmd="""
                    echo "Applying Kyverno policies..."
                    kubectl apply -k ./helm/kyverno-policies/
                    echo "✓ Policies applied"
                    kubectl get clusterpolicy | head -5
                """,
                labels=["Security"],
                resource_deps=[app]
            )
        else:
            local_resource(
                "{}-status".format(app),
                cmd="kubectl get pods -n {} | head -5".format(ns),
                labels=[label],
                links=["https://{}.localhost".format(app)],
                resource_deps=["helm-repositories"]
            )

###############################################################################
# RAW MANIFEST APPLICATIONS (Pattern 3: Direct Kubernetes Manifests)
###############################################################################

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
}

# Apps with web UIs accessible via ingress
RAW_APPS_WITH_UI = ["backstage", "mailhog", "macos", "eyeos", "rabbitmq", "keycloak", "airflow", "jupyterhub", "wordpress"]

# Custom URL mappings (app -> subdomain, defaults to app name)
RAW_APP_URLS = {
    "keycloak": "auth",
}

###############################################################################
# MSSQL (Local Helm Chart)
###############################################################################
if CONFIG["raw_apps"].get("mssql"):
    # Create namespace first
    local_resource(
        "mssql-ns",
        cmd="kubectl create namespace mssql --dry-run=client -o yaml | kubectl apply -f -",
        labels=["Databases"],
    )
    
    # Deploy MSSQL using local helm chart
    local_resource(
        "mssql",
        cmd="helm upgrade --install mssql ./helm/mssql -n mssql --wait --timeout=5m && kubectl get pods -n mssql",
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
        
        # First, create namespace via local_resource to ensure it exists before workloads
        if ns:
            local_resource(
                "{}-ns".format(app),
                cmd="kubectl create namespace {} --dry-run=client -o yaml | kubectl apply -f -".format(ns),
                labels=[label],
            )
        
        # Apply kustomize manifests
        k8s_yaml(kustomize("./helm/{}/".format(app)), allow_duplicates=True)
        
        # Special handling for KubeVirt - install operator and CR sequentially
        if app == "kubevirt":
            # Install the KubeVirt operator from official release
            local_resource(
                "kubevirt-operator",
                cmd="kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v1.3.1/kubevirt-operator.yaml",
                labels=[label],
                resource_deps=["kubevirt-ns"],
            )
            # Apply CR after operator is ready
            local_resource(
                "kubevirt-cr",
                cmd="kubectl wait --for=condition=Available deployment/virt-operator -n kubevirt --timeout=180s && kubectl apply -f ./helm/kubevirt/kubevirt-cr.yaml",
                labels=[label],
                resource_deps=["kubevirt-operator"],
            )
        
        # Set workload dependencies on namespace
        workloads = RAW_WORKLOADS.get(app, [app])
        for workload in workloads:
            url_subdomain = RAW_APP_URLS.get(app, app)
            k8s_resource(
                workload,
                labels=[label],
                resource_deps=["{}-ns".format(app)] if ns else [],
                links=["https://{}.localhost".format(url_subdomain)] if app in RAW_APPS_WITH_UI else []
            )

###############################################################################
# HARBOR RESOURCES (Example: Sub-resources via Crossplane)
###############################################################################

if CONFIG["crossplane_apps"].get("harbor"):
    # Apply Harbor XRD for project management
    local_resource(
        "harbor-xrd",
        cmd="kubectl apply -k ./helm/crossplane/compositions/harbor/ 2>/dev/null || echo 'Harbor XRD not ready yet'",
        labels=["App-Resources"],
        resource_deps=["crossplane-compositions"]
    )
    
    # Apply Harbor projects
    local_resource(
        "harbor-resources",
        cmd="kubectl apply -k ./apps/harbor-resources/ 2>/dev/null || echo 'Waiting for Harbor XRD...'",
        labels=["App-Resources"],
        resource_deps=["harbor-app", "harbor-xrd"]
    )

