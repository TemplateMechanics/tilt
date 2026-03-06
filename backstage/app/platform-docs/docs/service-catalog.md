# Service Catalog

## Always-On Infrastructure

These services are deployed automatically and cannot be toggled off:

| Service | Description | URL |
|---------|-------------|-----|
| Traefik | Ingress controller | [traefik.localhost](https://traefik.localhost) |
| Prometheus | Metrics & alerting | [prometheus.localhost](https://prometheus.localhost) |
| Loki | Log aggregation | — |
| Tempo | Distributed tracing | — |
| Crossplane | Infrastructure as Code | — |
| Flux | GitOps engine | — |
| Config Server | Tilt config REST API | [tilt-config.localhost](http://tilt-config.localhost) |

## Crossplane-Managed Apps

Deployed via the `DevApplication` XRD. Configured under `crossplane_apps` in `tilt-config.json`.

| Service | Image | Description |
|---------|-------|-------------|
| Harbor | `goharbor/harbor` | Container registry with project management |
| Jenkins | `jenkins/jenkins` | CI/CD with job/credential management |
| Langfuse | `langfuse/langfuse` | LLM observability and tracing |
| Qdrant | `qdrant/qdrant` | Vector database for AI/ML |
| LocalStack | `localstack/localstack` | AWS services emulator |

## Flux-Managed Apps

Deployed via Flux HelmRelease. Configured under `flux_apps` in `tilt-config.json`.

| Service | Chart | Description |
|---------|-------|-------------|
| Ollama | `ollama/ollama` | Local LLM runner |
| Kyverno | `kyverno/kyverno` | Kubernetes policy engine |
| Falco | `falcosecurity/falco` | Runtime security |
| KEDA | `kedacore/keda` | Event-driven autoscaling |
| Velero | `vmware-tanzu/velero` | Backup & disaster recovery |
| Cert-Manager | `jetstack/cert-manager` | Certificate management |
| 1Password | `1password/connect` | Secrets management |
| Policy Reporter | `policy-reporter` | Kyverno policy reports |

## Raw Manifest Apps

Deployed directly as Kubernetes manifests via Kustomize. Configured under `raw_apps` in `tilt-config.json`.

| Service | Image | Description |
|---------|-------|-------------|
| Backstage | custom image | Developer portal & infrastructure control plane |
| MongoDB | `mongo:8.0` | Document database |
| PostgreSQL | `postgres:17-alpine` | Relational database |
| Redis | `redis:8-alpine` | In-memory cache |
| RabbitMQ | `rabbitmq:4-management` | Message broker |
| MSSQL | `mcr.microsoft.com/mssql/server` | SQL Server |
| Keycloak | `quay.io/keycloak/keycloak:24` | Identity management |
| Airflow | `apache/airflow:2.9` | Workflow orchestration |
| JupyterHub | `jupyterhub/k8s-hub:3.3` | Jupyter notebooks |
| WordPress | `wordpress:6.4` + `mysql:8.0` | Blog/CMS demo |
| Mailhog | `mailhog/mailhog` | Email testing |
| Azurite | `mcr.microsoft.com/azure-storage/azurite` | Azure Storage emulator |
| GCP Emulators | Various | Firestore, PubSub, Bigtable |
| KubeVirt | — | VM operator (Linux with KVM only) |
| macOS | — | macOS VM via KubeVirt (experimental) |
| eyeOS | — | iOS VM via KubeVirt (experimental) |

## Backstage Catalog Annotations

Each service is registered in the Backstage catalog with annotations linking it to Tilt:

```yaml
annotations:
  dev.tilt/resource: harbor        # Tilt resource name
  dev.tilt/namespace: harbor       # Kubernetes namespace
  dev.tilt/config-key: crossplane_apps.harbor  # Key in tilt-config.json
```

These annotations enable the Tilt plugin to show live status and allow toggling from the catalog entity page.
