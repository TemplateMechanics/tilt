# Crossplane

Crossplane is the cloud-native control plane framework that powers declarative service provisioning in the dev platform.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `crossplane-system` |
| **Type** | Control Plane |
| **Always On** | Yes (infrastructure) |
| **Deployment** | Kustomize + Helm |


## Official Documentation

- [Crossplane Documentation](https://docs.crossplane.io/)
- [Compositions Guide](https://docs.crossplane.io/latest/concepts/compositions/)
- [Provider Helm](https://marketplace.upbound.io/providers/crossplane-contrib/provider-helm/)
- [XRD Reference](https://docs.crossplane.io/latest/concepts/composite-resource-definitions/)

## Architecture

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
```

## DevApplication Composite Resource

The `DevApplication` is a custom resource that simplifies deploying applications with:

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

## How It Works with Tilt

```python
# Tiltfile
k8s_kustomize("./helm/crossplane/", "crossplane-core")
k8s_kustomize("./helm/crossplane/providers/", "crossplane-providers")
k8s_kustomize("./helm/crossplane/compositions/", "crossplane-compositions")
k8s_kustomize("./apps/", "applications")
```

When you run `tilt up`:

1. Crossplane core is installed
2. Providers (Helm, Kubernetes) are installed
3. DevApplication composition is registered
4. Your apps in `./apps/` are created
5. Crossplane reconciles and creates all child resources

## Adding New Services

Instead of creating HelmRelease + IngressRoute + ServiceMonitor manually:

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

# Add to apps/kustomization.yaml
echo "  - my-new-service.yaml" >> apps/kustomization.yaml
```

## Current Services Using Crossplane

| Service | File |
|---------|------|
| Harbor | `apps/harbor.yaml` |
| Jenkins | `apps/jenkins.yaml` |
| Langfuse | `apps/langfuse.yaml` |
| Qdrant | `apps/qdrant.yaml` |
| LocalStack | `apps/localstack.yaml` |

## Benefits

- **Less YAML** — One resource instead of 3-4
- **Consistency** — All services follow the same pattern
- **Abstraction** — Hide Flux, Traefik, Prometheus complexity
- **Composability** — Easy to add features (e.g., auto-create Harbor projects)
- **Self-service** — Developers just need the DevApplication API

## Troubleshooting

### XRD not ready

```bash
kubectl get xrd
kubectl describe xrd devapplications.devplatform.systechs.io
```

### Provider not healthy

```bash
kubectl get providers
kubectl describe provider provider-helm
kubectl describe provider provider-kubernetes
```

### Composition not creating resources

```bash
kubectl get devapplication -A
kubectl describe devapplication <name>
kubectl get managed -A  # Show all Crossplane-managed resources
```
