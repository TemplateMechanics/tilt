# Tilt Development Environment

A comprehensive Kubernetes development environment using [Tilt](https://tilt.dev/), demonstrating three deployment patterns with 25+ services.

## Quick Start

```bash
# Prerequisites: Docker Desktop (with Kubernetes), Tilt, Helm, Flux CLI

# Start the environment
tilt up

# Access services at https://<service>.localhost
```

## Architecture

This workspace demonstrates **three deployment patterns**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                 TILT                                        │
│                    (Development Workflow Orchestration)                     │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │   CROSSPLANE    │  │      FLUX       │  │  RAW MANIFESTS  │             │
│  │  DevApplication │  │   HelmRelease   │  │   (Kustomize)   │             │
│  │       XRD       │  │                 │  │                 │             │
│  ├─────────────────┤  ├─────────────────┤  ├─────────────────┤             │
│  │ harbor          │  │ ollama          │  │ mongodb         │             │
│  │ jenkins         │  │ kyverno         │  │ postgresql      │             │
│  │ langfuse        │  │ falco           │  │ redis           │             │
│  │ qdrant          │  │ keda            │  │ rabbitmq        │             │
│  │ localstack      │  │ velero          │  │ keycloak        │             │
│  │                 │  │ cert-manager    │  │ airflow         │             │
│  │                 │  │ 1pass           │  │ wordpress       │             │
│  │                 │  │ policy-reporter │  │ mailhog         │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
└─────────────────────────────────────────────────────────────────────────────┘
```

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

Edit the `CONFIG` dictionary in `Tiltfile` to enable/disable services:

```python
CONFIG = {
    "crossplane_apps": {
        "harbor": True,      # Container registry
        "jenkins": True,     # CI/CD automation
        "langfuse": True,    # LLM observability
        "qdrant": True,      # Vector database
        "localstack": True,  # AWS emulator
    },
    "flux_apps": {
        "ollama": False,     # Local LLM
        "kyverno": False,    # Policy engine
        # ... more services
    },
    "raw_apps": {
        "mongodb": False,    # mongo:8.0
        "postgresql": False, # postgres:17
        "redis": False,      # redis:8-alpine
        # ... more services
    },
}
```

## Service Inventory

### Always-On Infrastructure
| Service | Description | URL |
|---------|-------------|-----|
| Traefik | Ingress controller | https://traefik.localhost |
| Prometheus | Metrics & alerting | https://prometheus.localhost |
| Grafana | Dashboards | https://grafana.localhost |
| Loki | Log aggregation | - |
| Tempo | Distributed tracing | - |
| Crossplane | Infrastructure as Code | - |
| Flux | GitOps engine | - |

### Crossplane-Managed Apps
| Service | Image | Description |
|---------|-------|-------------|
| Harbor | goharbor/harbor | Container registry with project management |
| Jenkins | jenkins/jenkins | CI/CD with job/credential management |
| Langfuse | langfuse/langfuse | LLM observability and tracing |
| Qdrant | qdrant/qdrant | Vector database for AI/ML |
| Localstack | localstack/localstack | AWS services emulator |

### Flux-Managed Apps
| Service | Chart | Description |
|---------|-------|-------------|
| Ollama | ollama/ollama | Local LLM runner |
| Kyverno | kyverno/kyverno | Kubernetes policy engine |
| Falco | falcosecurity/falco | Runtime security |
| KEDA | kedacore/keda | Event-driven autoscaling |
| Velero | vmware-tanzu/velero | Backup & disaster recovery |
| Cert-Manager | jetstack/cert-manager | Certificate management |
| 1Password | 1password/connect | Secrets management |
| Policy-Reporter | policy-reporter | Kyverno policy reports |

### Raw Manifest Apps (Official Images)
| Service | Image | Description |
|---------|-------|-------------|
| MongoDB | `mongo:8.0` | Document database |
| PostgreSQL | `postgres:17-alpine` | Relational database |
| Redis | `redis:8-alpine` | In-memory cache |
| RabbitMQ | `rabbitmq:4-management` | Message broker |
| Keycloak | `quay.io/keycloak/keycloak:24` | Identity management |
| Airflow | `apache/airflow:2.9` | Workflow orchestration |
| JupyterHub | `jupyterhub/k8s-hub:3.3` | Jupyter notebooks |
| WordPress | `wordpress:6.4` + `mysql:8.0` | Blog/CMS demo |
| Mailhog | `mailhog/mailhog` | Email testing |
| Azurite | `mcr.microsoft.com/azure-storage/azurite` | Azure Storage emulator |
| GCP Emulators | Various | Firestore, PubSub, etc. |
| MSSQL | `mcr.microsoft.com/mssql/server` | SQL Server |

## Project Structure

```
.
├── Tiltfile                    # Main orchestration file
├── apps/                       # Crossplane DevApplication claims
│   ├── harbor.yaml
│   ├── jenkins.yaml
│   ├── langfuse.yaml
│   ├── qdrant.yaml
│   ├── localstack.yaml
│   └── harbor-resources/       # HarborProject claims
├── helm/
│   ├── crossplane/             # Crossplane core + providers
│   │   ├── compositions/       # XRDs and Compositions
│   │   └── providers/          # Provider configs
│   ├── repositories/           # Flux HelmRepositories
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

### As a Flux App (external Helm chart)

1. Add HelmRepository to `helm/repositories/<repo>.yaml`
2. Create `helm/<service>/helm-release.yaml`
3. Add to `CONFIG["flux_apps"]` in Tiltfile

### As Raw Manifests

1. Create `helm/<service>/` folder with:
   - `namespace.yaml`
   - `deployment.yaml` / `statefulset.yaml`
   - `service.yaml`
   - `kustomization.yaml`
2. Add to `CONFIG["raw_apps"]` in Tiltfile

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

### View Tilt dashboard
Open http://localhost:10350 in your browser

## License

MIT
