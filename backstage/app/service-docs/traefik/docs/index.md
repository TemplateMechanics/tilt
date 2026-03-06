# Traefik

Traefik is the cloud-native ingress controller and reverse proxy for the dev platform. It handles all HTTPS routing for every service in the cluster.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `traefik` |
| **Type** | Ingress Controller |
| **Always On** | Yes (infrastructure) |
| **Dashboard** | [traefik.localhost/dashboard/](https://traefik.localhost/dashboard/) |
| **Deployment** | Helm (remote chart) |


## Official Documentation

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Traefik Helm Chart](https://github.com/traefik/traefik-helm-chart)
- [IngressRoute CRD Reference](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)
- [Middleware Reference](https://doc.traefik.io/traefik/middlewares/overview/)

## Architecture

Traefik is deployed as the primary ingress controller using a Helm chart managed by Tilt. It provides:

- **HTTPS termination** with locally-generated TLS certificates
- **Automatic routing** via IngressRoute CRDs
- **Dashboard** for real-time traffic monitoring
- **Middleware** support for rate limiting, headers, and authentication

```
Internet/Local Browser
        │
        ▼
   ┌─────────┐
   │ Traefik  │ :443 (HTTPS) / :80 (HTTP → redirect)
   └────┬─────┘
        │ IngressRoute CRDs
        ├──→ backstage.localhost
        ├──→ prometheus.localhost
        ├──→ airflow.localhost
        ├──→ harbor.localhost
        ├──→ keycloak.localhost
        └──→ ... (all services)
```

## Configuration

Traefik is always enabled and cannot be disabled. It's configured in `helm/traefik.yaml`:

```yaml
# Tilt config - always on
tilt_config = {
    "infrastructure": {
        "traefik": True  # Cannot be disabled
    }
}
```

### TLS

Traefik uses locally-generated certificates from the `certificates/` directory. The root CA is automatically trusted on the host machine.

### Default Headers

All proxied requests include:

- `X-Forwarded-For` — Client IP
- `X-Forwarded-Proto` — `https`
- `X-Real-IP` — Client IP

## Accessing the Dashboard

Navigate to [https://traefik.localhost/dashboard/](https://traefik.localhost/dashboard/) to view:

- Active routers and their rules
- Configured services and load balancers
- Health checks and middleware chains
- TLS certificate status

## Provided APIs

| API | Type | Description |
|-----|------|-------------|
| `traefik-api` | REST | Dashboard and management API |

## Adding Routes

To add a route for a new service, create an `IngressRoute`:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-service
  namespace: my-namespace
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`my-service.localhost`)
      kind: Rule
      services:
        - name: my-service
          port: 8080
  tls: {}
```

## Troubleshooting

### Service not accessible

1. Check the IngressRoute exists: `kubectl get ingressroute -A`
2. Verify the service is running: `kubectl get svc -n <namespace>`
3. Check Traefik logs: `kubectl logs -n traefik -l app.kubernetes.io/name=traefik`
4. Ensure DNS resolves: `*.localhost` should resolve to `127.0.0.1`

### Certificate errors

The Traefik certificates are generated locally. If you see certificate warnings:

1. Re-run cert generation: `tilt trigger dev-certificate-generate`
2. Trust the root CA: `tilt trigger dev-certificate-trust`
