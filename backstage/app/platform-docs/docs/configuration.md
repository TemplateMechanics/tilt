# Configuration

## tilt-config.json

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

## Config Groups

| Group | Pattern | Description |
|-------|---------|-------------|
| `crossplane_apps` | Crossplane DevApplication XRD | Services deployed via Crossplane compositions |
| `flux_apps` | Flux HelmRelease | Services deployed via Flux Helm lifecycle |
| `raw_apps` | Raw Kustomize manifests | Services deployed directly as K8s manifests |

## Config Fields

| Field | Type | Description |
|-------|------|-------------|
| `enabled` | boolean | Whether the service should be deployed |
| `description` | string | Human-readable description shown in Backstage |
| `category` | string | Grouping category for Infrastructure Dashboard |
| `tested` | boolean | Whether the service has been verified working |

## How Config Changes Propagate

Changes made via any method follow the same path:

1. **Backstage UI** / **Config API** / **manual edit** writes to `tilt-config.json`
2. If the change originated from Backstage or the API, it first writes to the `tilt-config` ConfigMap in `tilt-system`
3. A sync loop on the host polls the ConfigMap every 3 seconds
4. The sync loop writes changes back to `tilt-config.json`
5. Tilt's `watch_file()` detects the change and triggers a reload
6. The Tiltfile re-evaluates the config and deploys or removes services

## Config Server

The config server is a Python service running in Kubernetes (`tilt-system` namespace) that provides a REST API for reading and writing `tilt-config.json` through the K8s ConfigMap.

### Environment

- **Namespace**: `tilt-system`
- **Service**: `tilt-config-server:10351`
- **RBAC**: Scoped to get/update/patch on the `tilt-config` ConfigMap only

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/config` | Read full config |
| `GET` | `/config/{group}` | Read one group |
| `PATCH` | `/config` | Merge partial updates |
| `PUT` | `/config` | Replace entire config |
| `GET` | `/health` | Health check |

### Examples

```bash
# Read full config
curl http://tilt-config.localhost/config

# Enable Redis
curl -X PATCH http://tilt-config.localhost/config \
  -H 'Content-Type: application/json' \
  -d '{"raw_apps":{"redis":{"enabled":true}}}'

# Disable Harbor
curl -X PATCH http://tilt-config.localhost/config \
  -H 'Content-Type: application/json' \
  -d '{"crossplane_apps":{"harbor":{"enabled":false}}}'
```
