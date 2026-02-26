# Dapr

Dapr (Distributed Application Runtime) is a portable, event-driven runtime that simplifies building resilient microservice applications using a sidecar architecture.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `dapr-system` |
| **Type** | Application Runtime |
| **Default** | Disabled |
| **Config Key** | `flux_apps.dapr` |
| **Deployment** | Flux HelmRelease |
| **Chart** | `dapr/dapr` v1.14.4 |
| **Dashboard** | [dapr.localhost](https://dapr.localhost) |

## Official Documentation

- [Dapr Documentation](https://docs.dapr.io/)
- [Dapr Building Blocks](https://docs.dapr.io/developing-applications/building-blocks/)
- [Dapr API Reference](https://docs.dapr.io/reference/api/)
- [Dapr Helm Chart](https://github.com/dapr/dapr/tree/master/charts/dapr)

## Purpose

Dapr provides building blocks for common microservice patterns, abstracting away complexity:

- **Service Invocation** — Service-to-service calls with mTLS, retries, and tracing
- **State Management** — Pluggable state stores (Redis, PostgreSQL, etc.)
- **Pub/Sub** — Publish and subscribe messaging across components
- **Bindings** — Input/output bindings to external systems (queues, databases, SaaS)
- **Actors** — Virtual actor pattern for stateful, concurrent workloads
- **Secrets** — Unified secrets API across secret stores
- **Configuration** — Dynamic configuration with subscriptions
- **Workflows** — Orchestrate long-running, fault-tolerant business processes

## Architecture

```
┌──────────────────────────────────────────────────┐
│                  Kubernetes Cluster               │
│                                                  │
│  ┌─────────────────────────────────────────────┐ │
│  │  Application Pod                            │ │
│  │  ┌──────────┐    ┌──────────────────────┐   │ │
│  │  │  App     │◄──▶│  Dapr Sidecar        │   │ │
│  │  │ Container│    │  (daprd)             │   │ │
│  │  │          │    │  :3500 HTTP API      │   │ │
│  │  │          │    │  :50001 gRPC API     │   │ │
│  │  └──────────┘    └──────────┬───────────┘   │ │
│  └─────────────────────────────┼───────────────┘ │
│                                │                 │
│  ┌─────────────┐  ┌───────────▼──────────────┐  │
│  │ Dapr        │  │ Component Resources      │  │
│  │ Control     │  │ (State, PubSub, Bindings)│  │
│  │ Plane       │  └──────────────────────────┘  │
│  │ • Operator  │                                 │
│  │ • Sentry    │                                 │
│  │ • Placement │                                 │
│  └─────────────┘                                 │
└──────────────────────────────────────────────────┘
```

## Enabling

```json
{
  "flux_apps": {
    "dapr": true
  }
}
```

## Annotating Pods for Sidecar Injection

Add these annotations to your pod spec to enable the Dapr sidecar:

```yaml
annotations:
  dapr.io/enabled: "true"
  dapr.io/app-id: "my-app"
  dapr.io/app-port: "8080"
  dapr.io/app-protocol: "http"
```

## Dashboard

The Dapr Dashboard is available at [dapr.localhost](https://dapr.localhost) and provides:

- Overview of all Dapr-enabled applications
- Component status and configuration
- Real-time logs and metadata
- Configuration and secret inspection

## Component Examples

### State Store (Redis)

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
  namespace: dapr-system
spec:
  type: state.redis
  version: v1
  metadata:
    - name: redisHost
      value: redis-master.redis:6379
```

### Pub/Sub (NATS)

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
  namespace: dapr-system
spec:
  type: pubsub.nats
  version: v1
  metadata:
    - name: natsURL
      value: nats://nats.nats:4222
```

## Related Services

| Service | Relationship |
|---------|-------------|
| **Redis** | Default state store and pub/sub backend |
| **NATS** | Alternative pub/sub messaging backend |
| **Prometheus** | Scrapes Dapr sidecar and control plane metrics |
| **Grafana** | Visualizes Dapr performance metrics |

## Troubleshooting

```bash
# Check Dapr control plane pods
kubectl get pods -n dapr-system

# View Dapr operator logs
kubectl logs -n dapr-system -l app=dapr-operator --tail=50

# Check HelmRelease status
kubectl get helmrelease -n dapr-system

# List Dapr components
kubectl get components -A

# Check sidecar status for a specific app
kubectl get pods -l dapr.io/enabled=true -A

# View sidecar logs for an app
kubectl logs <pod-name> -c daprd --tail=50

# Dashboard access
kubectl port-forward -n dapr-system svc/dapr-dashboard 8080:8080
```
