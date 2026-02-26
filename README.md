# Tilt Development Environment

A comprehensive Kubernetes development environment using [Tilt](https://tilt.dev/), demonstrating three deployment patterns with 25+ services. Includes a [Backstage](https://backstage.io/) developer portal with a custom plugin that serves as a GUI control plane for toggling infrastructure on and off.

## Quick Start

```bash
# Prerequisites: Docker Desktop (with Kubernetes), Tilt, Helm, Flux CLI

# Start the environment
tilt up

# Access services at https://<service>.localhost
# Access the Tilt dashboard at http://localhost:10350
# Access the config API at http://tilt-config.localhost/config
```

## Architecture

This workspace demonstrates **three deployment patterns**, with configuration stored in a K8s ConfigMap and a Backstage-powered control plane:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          BACKSTAGE DEVELOPER PORTAL                         │
│                         https://backstage.localhost                          │
│  ┌──────────────────────┐  ┌────────────────────────────────────────────┐   │
│  │  Service Catalog      │  │  Infrastructure Dashboard                 │   │
│  │  (catalog entities)   │  │  (toggle services on/off per category)    │   │
│  └──────────┬───────────┘  └──────────────────┬─────────────────────────┘   │
│             │                                  │                             │
│  ┌──────────┴──────────────────────────────────┴─────────────────────────┐  │
│  │                     Tilt Plugin (TiltClient)                          │  │
│  │               uses Backstage proxy → in-cluster routing               │  │
│  └──────────┬──────────────────────────────────┬─────────────────────────┘  │
└─────────────┼──────────────────────────────────┼────────────────────────────┘
              │ (browser → host:10350)           │ (proxy → K8s Service)
     ┌────────▼────────┐              ┌──────────▼──────────┐
     │  Tilt API        │              │  Config Server Pod   │
     │  :10350 (host)   │              │  tilt-system ns      │
     │  (runtime ctrl)  │              │  (K8s API backend)   │
     └─────────────────┘              └──────────┬───────────┘
                                                 │ reads/writes
                                        ┌────────▼────────┐
                                        │  ConfigMap       │
                                        │  tilt-config     │
                                        │  (tilt-system)   │
                                        └────────┬────────┘
                                                 │ sync loop (host)
                                        ┌────────▼────────┐
                                        │ tilt-config.json │
                                        │  (watch_file)    │
                                        └────────┬────────┘
                                                 │ auto-reload
┌────────────────────────────────────────────────▼────────────────────────────┐
│                                  TILTFILE                                   │
│                     (Development Workflow Orchestration)                    │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │   CROSSPLANE    │  │      FLUX       │  │  RAW MANIFESTS  │             │
│  │  DevApplication │  │   HelmRelease   │  │   (Kustomize)   │             │
│  │       XRD       │  │                 │  │                 │             │
│  ├─────────────────┤  ├─────────────────┤  ├─────────────────┤             │
│  │ harbor          │  │ ollama          │  │ backstage       │             │
│  │ jenkins         │  │ kyverno         │  │ mongodb         │             │
│  │ langfuse        │  │ falco           │  │ postgresql      │             │
│  │ qdrant          │  │ keda            │  │ redis           │             │
│  │ localstack      │  │ velero          │  │ rabbitmq        │             │
│  │                 │  │ cert-manager    │  │ mssql           │             │
│  │                 │  │ 1pass           │  │ keycloak        │             │
│  │                 │  │ policy-reporter │  │ airflow         │             │
│  │                 │  │ trivy           │  │ wazuh           │             │
│  │                 │  │                 │  │ wordpress ...   │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow: Toggling a Service via Backstage

1. Developer clicks toggle in Backstage Infrastructure Dashboard
2. Frontend calls `PATCH /api/proxy/tilt-config/config` through the Backstage backend
3. Backstage proxy routes to `tilt-config-server.tilt-system.svc:10351` (in-cluster)
4. Config server writes the change to the `tilt-config` ConfigMap via K8s API
5. Sync loop on host detects the ConfigMap change (polls every 3s)
6. Sync loop writes updated config to `tilt-config.json`
7. Tilt's `watch_file()` detects the change and triggers a reload
8. Tilt re-evaluates the config and deploys/removes the service

### Pattern 1: Crossplane DevApplication (XRD)

**Best for**: Services needing sub-resource management (projects, jobs, credentials)

- Creates Namespace, HelmRelease, IngressRoute, ServiceMonitor
- Supports additional XRDs (e.g., HarborProject for managing repos)
- Location: `apps/*.yaml`

### Pattern 2: Flux HelmRelease

**Best for**: External Helm charts with GitOps reconciliation

- Uses Flux to manage Helm lifecycle
- Declarative chart versions and values
- Location: `helm/<service>/helm-release.yaml`

### Pattern 3: Raw Manifests

**Best for**: Simple deployments using official images (no Helm complexity)

- Direct Kubernetes manifests via Kustomize
- Uses official Docker images (no Bitnami)
- Location: `helm/<service>/*.yaml`

## Configuration

Service configuration is stored in `tilt-config.json` at the project root. Each service has metadata used by both the Tiltfile and the Backstage Infrastructure Dashboard:

```json
{
  "crossplane_apps": {
    "harbor": { "enabled": false, "description": "Container registry", "category": "CI/CD", "tested": true },
    "jenkins": { "enabled": false, "description": "CI/CD automation", "category": "CI/CD", "tested": true }
  },
  "flux_apps": {
    "ollama": { "enabled": false, "description": "Local LLM runner", "category": "AI/ML", "tested": true }
  },
  "raw_apps": {
    "mssql": { "enabled": true, "description": "Microsoft SQL Server", "category": "Databases", "tested": true },
    "backstage": { "enabled": false, "description": "Developer Portal", "category": "Developer Portal", "tested": true }
  }
}
```

You can edit this file directly, or toggle services through:
- **Backstage UI** — Infrastructure Dashboard at https://backstage.localhost/infra
- **Config API** — `curl -X PATCH http://tilt-config.localhost/config -H 'Content-Type: application/json' -d '{"raw_apps":{"redis":{"enabled":true}}}'`
- **Manual edit** — Edit `tilt-config.json`; Tilt auto-reloads via `watch_file()`

Changes made via the Backstage UI or Config API are written to the `tilt-config` ConfigMap in the `tilt-system` namespace. A sync loop on the host polls the ConfigMap every 3 seconds and writes changes back to `tilt-config.json`, which triggers Tilt reload.

### Config Server (K8s-native)

The config server runs as a K8s Deployment in the `tilt-system` namespace. It reads and writes the `tilt-config` ConfigMap via the K8s API using a ServiceAccount with scoped RBAC (only get/update/patch on the `tilt-config` ConfigMap).

**Access paths:**
- **From Backstage** — Routed via the Backstage proxy plugin (`/api/proxy/tilt-config/...`)
- **Direct (Traefik)** — `http://tilt-config.localhost/config`
- **Port-forward** — `kubectl port-forward -n tilt-system svc/tilt-config-server 10351:10351`

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/config` | Read full config |
| `GET` | `/config/{group}` | Read one group (`crossplane_apps`, `flux_apps`, `raw_apps`) |
| `PATCH` | `/config` | Merge partial updates (toggle individual services) |
| `PUT` | `/config` | Replace entire config |
| `GET` | `/health` | Health check |

## Service Inventory

### Always-On Infrastructure
| Service | Description | URL |
|---------|-------------|-----|
| Traefik | Ingress controller | https://traefik.localhost |
| Prometheus | Metrics & alerting | https://prometheus.localhost |
| Loki | Log aggregation | - |
| Tempo | Distributed tracing | - |
| Crossplane | Infrastructure as Code | - |
| Flux | GitOps engine | - |
| Config Server | Tilt config REST API (K8s pod) | http://tilt-config.localhost |

### Crossplane-Managed Apps
| Service | Image | Description |
|---------|-------|-------------|
| Harbor | goharbor/harbor | Container registry with project management |
| Jenkins | jenkins/jenkins | CI/CD with job/credential management |
| Langfuse | langfuse/langfuse | LLM observability and tracing |
| Qdrant | qdrant/qdrant | Vector database for AI/ML |
| LocalStack | localstack/localstack | AWS services emulator |

### Flux-Managed Apps
| Service | Chart | Description |
|---------|-------|-------------|
| Ollama | ollama/ollama | Local LLM runner |
| Kyverno | kyverno/kyverno | Kubernetes policy engine |
| Falco | falcosecurity/falco | Runtime security (with falcosidekick metrics) |
| Trivy Operator | aquasecurity/trivy-operator | Kubernetes vulnerability & compliance scanning |
| KEDA | kedacore/keda | Event-driven autoscaling |
| Velero | vmware-tanzu/velero | Backup & disaster recovery |
| Cert-Manager | jetstack/cert-manager | Certificate management |
| 1Password | 1password/connect | Secrets management |
| Policy-Reporter | policy-reporter | Kyverno policy reports |

### Raw Manifest Apps (Official Images)
| Service | Image | Description |
|---------|-------|-------------|
| Backstage | `roadiehq/community-backstage-image` | Developer portal & infrastructure control plane |
| MongoDB | `mongo:8.0` | Document database |
| PostgreSQL | `postgres:17-alpine` | Relational database |
| Redis | `redis:8-alpine` | In-memory cache |
| RabbitMQ | `rabbitmq:4-management` | Message broker |
| MSSQL | `mcr.microsoft.com/mssql/server` | SQL Server (local Helm chart) |
| Keycloak | `quay.io/keycloak/keycloak:24` | Identity management |
| Airflow | `apache/airflow:2.9` | Workflow orchestration |
| JupyterHub | `jupyterhub/k8s-hub:3.3` | Jupyter notebooks |
| Wazuh | `wazuh/wazuh-indexer:4.9.0` + `wazuh-manager` + `wazuh-dashboard` | SIEM platform (threat detection, log analysis) |
| WordPress | `wordpress:6.4` + `mysql:8.0` | Blog/CMS demo |
| Mailhog | `mailhog/mailhog` | Email testing |
| Azurite | `mcr.microsoft.com/azure-storage/azurite` | Azure Storage emulator |
| GCP Emulators | Various | Firestore, PubSub, Bigtable |
| Azure | - | Azure storage classes and PVCs |
| KubeVirt | - | VM operator (Linux with KVM only) |
| macOS | - | macOS VM via KubeVirt (experimental) |
| eyeOS | - | iOS VM via KubeVirt (experimental) |

## Backstage Integration

Backstage acts as a **developer portal and infrastructure control plane**. When enabled (`raw_apps.backstage` in `tilt-config.json`), it provides:

- **Service Catalog** — Every service is registered as a Backstage Component with annotations linking to Tilt resources
- **Infrastructure Dashboard** — Toggle services on/off from a web UI; changes persist to `tilt-config.json` and trigger a Tilt reload
- **Scaffolder Templates** — Create new services from a form that generates Kubernetes manifests and Tiltfile entries
- **Kubernetes Plugin** — View pods, deployments, and logs for catalog components

### Backstage Plugin Architecture

The custom `@internal/backstage-plugin-tilt` plugin provides:

| Component | Mount Point | Description |
|-----------|-------------|-------------|
| `TiltPage` | `/tilt` | Table of all Tilt resources with status, labels, and actions |
| `InfrastructureDashboardPage` | `/infra` | Category-grouped service toggles with live status |
| `TiltResourceCard` | Entity page | Status card for a single Tilt resource |
| `EntityTiltContent` | Entity tab | Tilt details for catalog components annotated with `tilt.dev/resource` |

### Connecting Catalog Entries to Tilt

Each component in the Backstage catalog uses annotations to link to Tilt:

```yaml
annotations:
  dev.tilt/resource: harbor        # Tilt resource name
  dev.tilt/namespace: harbor       # Kubernetes namespace
  dev.tilt/config-key: crossplane_apps.harbor  # Key in tilt-config.json
```

## Project Structure

```
.
├── Tiltfile                    # Main orchestration file
├── tilt-config.json            # Service config (seed file, synced to ConfigMap)
├── scripts/
│   └── config-server.py        # REST API server (deployed as K8s pod)
├── apps/                       # Crossplane DevApplication claims
│   ├── harbor.yaml
│   ├── jenkins.yaml
│   ├── langfuse.yaml
│   ├── qdrant.yaml
│   ├── localstack.yaml
│   └── harbor-resources/       # HarborProject claims
├── backstage/
│   ├── catalog/
│   │   └── all.yaml            # Backstage catalog entities (all services)
│   ├── plugins/
│   │   └── tilt/               # Custom Backstage Tilt plugin
│   │       └── src/
│   │           ├── api.ts      # TiltClient — Tilt API + Config Server API
│   │           ├── plugin.ts   # Plugin registration & extensions
│   │           └── components/
│   │               ├── TiltPage.tsx               # Resource table
│   │               ├── InfrastructureDashboard.tsx # Service toggle UI
│   │               ├── TiltResourceCard.tsx        # Single resource card
│   │               └── EntityTiltContent.tsx       # Entity page integration
│   └── templates/
│       └── dev-application/    # Scaffolder template for new services
├── helm/
│   ├── tilt-config-server/     # Config server K8s manifests (Deployment, Service, RBAC)
│   ├── crossplane/             # Crossplane core + providers
│   │   ├── compositions/       # XRDs and Compositions
│   │   └── providers/          # Provider configs
│   ├── repositories/           # Flux HelmRepositories
│   ├── backstage/              # Backstage K8s manifests
│   ├── prometheus/             # Observability stack
│   ├── loki/
│   ├── tempo/
│   ├── <service>/              # Service-specific configs
│   └── traefik.yaml            # Ingress values
├── certificates/               # TLS certificate generation
└── docs/                       # Additional documentation
```

## Prerequisites

| Tool | Version | Installation |
|------|---------|--------------|
| Docker Desktop | Latest | https://docs.docker.com/get-docker/ |
| Kubernetes | 1.25+ | Enable in Docker Desktop |
| Tilt | 0.33+ | https://docs.tilt.dev/install.html |
| Helm | 3.12+ | https://helm.sh/docs/intro/install/ |
| Flux CLI | 2.0+ | https://fluxcd.io/docs/installation/ |
| kubectl | 1.25+ | https://kubernetes.io/docs/tasks/tools/ |

## TLS Certificates

Generate local development certificates:

```bash
cd certificates
pwsh ./generate-certs.ps1
```

This creates a local CA and wildcard certificate for `*.localhost`.

## Adding New Services

### As a Crossplane App (with sub-resources)

1. Create DevApplication claim in `apps/<service>.yaml`
2. Optionally create service-specific XRD in `helm/crossplane/compositions/<service>/`
3. Add an entry to `tilt-config.json` under `crossplane_apps`

### As a Flux App (external Helm chart)

1. Add HelmRepository to `helm/repositories/<repo>.yaml`
2. Create `helm/<service>/helm-release.yaml`
3. Add an entry to `tilt-config.json` under `flux_apps`

### As Raw Manifests

1. Create `helm/<service>/` folder with:
   - `namespace.yaml`
   - `deployment.yaml` / `statefulset.yaml`
   - `service.yaml`
   - `kustomization.yaml`
2. Add an entry to `tilt-config.json` under `raw_apps`

### Register in Backstage Catalog

Add a Component entry to `backstage/catalog/all.yaml` (and/or `helm/backstage/catalog-configmap.yaml`) with appropriate `dev.tilt/*` annotations.

## Troubleshooting

### Crossplane providers not healthy
```bash
# Check provider status
kubectl get providers.pkg.crossplane.io

# Fix CRD ownership conflicts
kubectl get providerrevision
# Then patch CRD ownerReferences if needed
```

### Service not accessible
```bash
# Check IngressRoute
kubectl get ingressroute -A

# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik
```

### Config server not responding
```bash
# Check pod status
kubectl get pods -n tilt-system -l app=tilt-config-server

# Check pod logs
kubectl logs -n tilt-system -l app=tilt-config-server

# Verify ConfigMap exists
kubectl get configmap tilt-config -n tilt-system

# Health check via IngressRoute
curl http://tilt-config.localhost/health

# Direct port-forward access
kubectl port-forward -n tilt-system svc/tilt-config-server 10351:10351
curl http://localhost:10351/health
```

### Backstage not loading catalog
```bash
# Check Backstage pod logs
kubectl logs -n backstage -l app=backstage

# Verify catalog ConfigMap is mounted
kubectl get configmap backstage-catalog -n backstage -o yaml
```

### View Tilt dashboard
Open http://localhost:10350 in your browser

## License

MIT

## Production Notes

> **This repository is designed for local development only.** The following items should be addressed before adapting any manifests for production use:
>
> - **KubeVirt operator RBAC** (`helm/kubevirt/operator.yaml`): Uses wildcard `*` permissions for convenience. In production, use the [official KubeVirt operator manifest](https://github.com/kubevirt/kubevirt/releases) which defines granular per-resource RBAC, or install via OLM.
> - **Backstage guest auth** (`helm/backstage/configmap.yaml`): Uses `dangerouslyAllowOutsideDevelopment` for guest access. Replace with a proper auth provider (GitHub, OIDC, etc.) in production.
> - **Hardcoded credentials**: All services use plaintext dev passwords for convenience. In production, these must be replaced with securely generated secrets managed via a secrets manager (e.g., HashiCorp Vault, AWS Secrets Manager, 1Password Operator) or sealed/external secrets. Affected services:
>   - `helm/backstage/secrets.yaml` — Postgres password, GitHub token
>   - `helm/backstage/postgresql.yaml` — Postgres password (`bstage-dev-password`)
>   - `helm/keycloak/deployment.yaml` / `postgresql.yaml` — Keycloak admin & DB passwords (`kc-dev-password`)
>   - `helm/mssql/values.yaml` — SA password (`P@ssw0rd`)
>   - `helm/jenkins/helm-release.yaml` — Admin password (`P@ssw0rd`)
>   - `helm/harbor/helm-release.yaml` — Harbor admin password (`P@ssw0rd`)
>   - `helm/mongodb/manifests/secret.yaml` — Root password (`mongo-dev-password`)
>   - `helm/rabbitmq/manifests/secret.yaml` — RabbitMQ password (`rmq-dev-password`)
>   - `helm/redis/manifests/secret.yaml` — Redis password (`redis-dev-password`)
> - **TLS certificates**: Local self-signed CA. Replace with real certificates or cert-manager with a trusted issuer.
