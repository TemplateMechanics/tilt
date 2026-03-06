# Crossplane Integration

This directory contains Crossplane configuration for managing development services declaratively.

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

- ✅ Helm chart deployment via Flux HelmRelease
- ✅ Automatic Traefik IngressRoute with TLS
- ✅ Prometheus ServiceMonitor (optional)
- ✅ Namespace creation
- ✅ Consistent naming and labeling

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
    repository: jenkins  # HelmRepository name in flux-system
    name: jenkins
    version: "*"
    values:
      # Any Helm values
      controller:
        admin:
          username: admin
          password: password
  
  ingress:
    enabled: true
    serviceName: my-app  # defaults to spec.name
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

1. **Namespace** - `spec.name` namespace
2. **HelmRelease** - Flux HelmRelease deploying your chart
3. **IngressRoute** - Traefik ingress at `spec.domain` with HTTPS
4. **ServiceMonitor** - Prometheus scraping (if `monitoring.enabled: true`)

## How It Works with Tilt

```python
# Tiltfile
k8s_kustomize("./helm/crossplane/", "crossplane-core")
k8s_kustomize("./helm/crossplane/providers/", "crossplane-providers")
k8s_kustomize("./helm/crossplane/compositions/", "crossplane-compositions")
k8s_kustomize("./apps/", "applications")  # Your DevApplication resources
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
# Create a single DevApplication
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

Tilt will automatically apply it and Crossplane handles the rest!

## Benefits

- **Less YAML**: One resource instead of 3-4
- **Consistency**: All services follow the same pattern
- **Abstraction**: Hide complexity (Flux, Traefik, Prometheus integration)
- **Composability**: Easy to add new features (e.g., auto-create Harbor projects)
- **Self-service**: Developers just need to know the DevApplication API

## Current Services Using Crossplane

- Jenkins (`apps/jenkins.yaml`)
- Harbor (`apps/harbor.yaml`)

## Migration Path

Services still using direct Helm deployment:
- Airflow
- JupyterHub
- Keycloak
- WordPress

To migrate a service, create a `apps/<service>.yaml` using the DevApplication API.
