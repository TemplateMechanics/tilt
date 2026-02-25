# Crossplane Integration

## Overview

This setup uses Tilt for development workflow orchestration and Crossplane for declarative resource management.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                 TILT                                        │
│  (Development Workflow Orchestration)                                       │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │    Flux     │───▶│  Crossplane │───▶│   Harbor    │───▶│  Harbor     │  │
│  │   (GitOps)  │    │    (IaC)    │    │   XRD       │    │  Projects   │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│         │                 │                   │                  │          │
│         ▼                 ▼                   ▼                  ▼          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │ HelmRepos   │    │  Providers  │    │ DevApps     │    │ HarborProj  │  │
│  │ (repos)     │    │ (k8s, helm) │    │ (claims)    │    │ (claims)    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              KUBERNETES                                     │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                         CROSSPLANE                                    │  │
│  │                                                                       │  │
│  │  XRD: DevApplication ──────┬──▶ Namespace                            │  │
│  │                            ├──▶ HelmRelease                          │  │
│  │                            ├──▶ IngressRoute                         │  │
│  │                            └──▶ ServiceMonitor                       │  │
│  │                                                                       │  │
│  │  XRD: HarborProject ───────┬──▶ ConfigMap                            │  │
│  │                            └──▶ Job (API call)                       │  │
│  │                                                                       │  │
│  │  (Future XRDs)                                                        │  │
│  │  XRD: JenkinsJob ──────────┬──▶ ConfigMap (job-dsl)                  │  │
│  │                            └──▶ Job (create via API)                 │  │
│  │                                                                       │  │
│  │  XRD: PostgresDatabase ────┬──▶ Secret (credentials)                 │  │
│  │                            └──▶ Job (CREATE DATABASE)                │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
helm/crossplane/
├── namespace.yaml              # crossplane-system namespace
├── helm-repo.yaml              # Crossplane Helm repository
├── helm-release.yaml           # Crossplane core installation
├── providers/
│   ├── providers.yaml          # Helm & Kubernetes providers
│   └── provider-configs.yaml   # Provider configurations
└── compositions/
    ├── xrd.yaml                # DevApplication API definition
    └── composition.yaml        # DevApplication implementation

apps/
├── kustomization.yaml
├── harbor.yaml                 # DevApplication claim
├── jenkins.yaml
├── langfuse.yaml
└── harbor-resources/
    ├── kustomization.yaml
    └── projects.yaml           # HarborProject claims
```

## DevApplication Composite Resource

The `DevApplication` is a custom resource that simplifies deploying applications:

- Helm chart deployment via Flux HelmRelease
- Automatic Traefik IngressRoute with TLS
- Prometheus ServiceMonitor (optional)
- Namespace creation
- Consistent naming and labeling

### Example Usage

```yaml
apiVersion: devplatform.systechs.io/v1alpha1
kind: DevApplication
metadata:
  name: my-app
  namespace: default
spec:
  name: my-app
  domain: my-app.localhost

  chart:
    repository: jenkins
    name: jenkins
    version: "*"
    values:
      controller:
        admin:
          username: admin
          password: password

  ingress:
    enabled: true
    serviceName: my-app
    servicePort: 8080

  monitoring:
    enabled: true
    metrics: true
    logs: true
    metricsPort: 9090
    metricsPath: /metrics
```

## What Crossplane Creates

When you create a `DevApplication`, Crossplane automatically provisions:

1. **Namespace** — `spec.name` namespace
2. **HelmRelease** — Flux HelmRelease deploying your chart
3. **IngressRoute** — Traefik ingress at `spec.domain` with HTTPS
4. **ServiceMonitor** — Prometheus scraping (if `monitoring.enabled: true`)

## Deployment Flow

1. **Tilt starts** and applies resources in dependency order
2. **Flux HelmRepositories** are created first
3. **Crossplane core** is deployed via Flux HelmRelease
4. **Crossplane providers** (kubernetes, helm) are installed
5. **Provider configs** are applied once providers are healthy
6. **Base compositions** (DevApplication XRD) are created
7. **Service-specific compositions** (HarborProject XRD) are created
8. **DevApplication claims** deploy the actual services
9. **Service resource claims** (HarborProject) configure the services

## Adding New Service Resources

### Example: Adding a Jenkins Job via Crossplane

1. Create XRD in `helm/crossplane/compositions/jenkins/xrd-job.yaml`
2. Create Composition in `helm/crossplane/compositions/jenkins/composition-job.yaml`
3. Add to the kustomization and Tiltfile

### Example: Adding a New DevApplication

```bash
cat <<EOF > apps/my-new-service.yaml
apiVersion: devplatform.systechs.io/v1alpha1
kind: DevApplication
metadata:
  name: my-service
spec:
  name: my-service
  domain: my-service.localhost
  chart:
    repository: bitnami
    name: postgresql
    version: "*"
  ingress:
    serviceName: my-service-postgresql
    servicePort: 5432
  monitoring:
    enabled: true
EOF

echo "  - my-new-service.yaml" >> apps/kustomization.yaml
```

## Benefits

- **Less YAML** — One resource instead of 3–4
- **Consistency** — All services follow the same pattern
- **Abstraction** — Hides Flux, Traefik, Prometheus integration details
- **Composability** — Easy to add new features (e.g., auto-create Harbor projects)
- **Self-service** — Developers just need to know the DevApplication API

## Current Services Using Crossplane

| Service | Claim | Location |
|---------|-------|----------|
| Harbor | DevApplication + HarborProject | `apps/harbor.yaml` |
| Jenkins | DevApplication | `apps/jenkins.yaml` |
| Langfuse | DevApplication | `apps/langfuse.yaml` |
| Qdrant | DevApplication | `apps/qdrant.yaml` |
| LocalStack | DevApplication | `apps/localstack.yaml` |

## Migration Path

Services still using direct deployments can be migrated to Crossplane by creating a `DevApplication` claim in `apps/<service>.yaml`.
