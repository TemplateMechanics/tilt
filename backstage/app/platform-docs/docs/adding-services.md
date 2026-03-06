# Adding New Services

## Choose a Deployment Pattern

| Pattern | Best For | Location |
|---------|----------|----------|
| Crossplane DevApplication | Services needing sub-resources (projects, jobs, credentials) | `apps/<service>.yaml` |
| Flux HelmRelease | External Helm charts with GitOps reconciliation | `helm/<service>/helm-release.yaml` |
| Raw Manifests | Simple deployments using official images | `helm/<service>/*.yaml` |

## As a Crossplane App

1. Create a DevApplication claim:

    ```yaml
    # apps/my-service.yaml
    apiVersion: devplatform.systechs.io/v1alpha1
    kind: DevApplication
    metadata:
      name: my-service
    spec:
      name: my-service
      domain: my-service.localhost
      chart:
        repository: bitnami
        name: my-chart
        version: "*"
      ingress:
        serviceName: my-service
        servicePort: 8080
      monitoring:
        enabled: true
    ```

2. Add to `apps/kustomization.yaml`:

    ```yaml
    resources:
      - my-service.yaml
    ```

3. Add config entry to `tilt-config.json`:

    ```json
    {
      "crossplane_apps": {
        "my-service": {
          "enabled": true,
          "description": "My Service",
          "category": "My Category",
          "tested": false
        }
      }
    }
    ```

## As a Flux App

1. Add a HelmRepository (if needed):

    ```yaml
    # helm/repositories/my-repo.yaml
    apiVersion: source.toolkit.fluxcd.io/v1beta2
    kind: HelmRepository
    metadata:
      name: my-repo
      namespace: flux-system
    spec:
      interval: 1h
      url: https://charts.example.com
    ```

2. Create the HelmRelease:

    ```yaml
    # helm/my-service/helm-release.yaml
    apiVersion: helm.toolkit.fluxcd.io/v2beta2
    kind: HelmRelease
    metadata:
      name: my-service
      namespace: my-service
    spec:
      interval: 5m
      chart:
        spec:
          chart: my-chart
          sourceRef:
            kind: HelmRepository
            name: my-repo
            namespace: flux-system
      values:
        # chart values here
    ```

3. Create kustomization:

    ```yaml
    # helm/my-service/kustomization.yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
      - namespace.yaml
      - helm-release.yaml
    ```

4. Add config entry under `flux_apps` in `tilt-config.json`.

## As Raw Manifests

1. Create directory `helm/<service>/` with:
    - `namespace.yaml`
    - `deployment.yaml` or `statefulset.yaml`
    - `service.yaml`
    - `kustomization.yaml`

2. Add config entry under `raw_apps` in `tilt-config.json`.

## Register in Backstage Catalog

Add a Component entry to the catalog ConfigMap (`helm/backstage/catalog-configmap.yaml`):

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-service
  description: My service description
  annotations:
    dev.tilt/resource: my-service
    dev.tilt/namespace: my-service
    dev.tilt/config-key: crossplane_apps.my-service
  tags:
    - my-tag
  links:
    - url: https://my-service.localhost
      title: My Service UI
spec:
  type: service
  lifecycle: production
  owner: platform-team
  system: dev-environment
```
