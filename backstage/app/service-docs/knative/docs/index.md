# Knative

Knative is a Kubernetes-based platform for deploying and managing serverless workloads with automatic scaling, including scale-to-zero, and traffic splitting.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `knative-serving` |
| **Type** | Serverless Platform |
| **Default** | Disabled |
| **Config Key** | `raw_apps.knative` |
| **Deployment** | Raw Manifests via Operator |
| **Operator Image** | `gcr.io/knative-releases/knative.dev/operator/cmd/operator` v1.16.0 |

## Official Documentation

- [Knative Documentation](https://knative.dev/docs/)
- [Knative Serving](https://knative.dev/docs/serving/)
- [Knative Eventing](https://knative.dev/docs/eventing/)
- [Knative Operator](https://knative.dev/docs/install/operator/knative-with-operators/)

## Purpose

Knative provides serverless capabilities on Kubernetes:

- **Scale-to-Zero** — Automatically scale idle workloads to zero pods, saving resources
- **Auto-Scaling** — Scale up based on concurrency, RPS, or CPU utilization
- **Traffic Splitting** — Gradually roll out new revisions with percentage-based routing
- **Revisions** — Immutable snapshots of code and configuration for safe rollbacks
- **Event-Driven** — Connect workloads to event sources via Eventing

## Components

### Serving

Manages serverless workloads with automatic scaling and routing:

| Resource | Description |
|----------|-------------|
| **Service** | Top-level resource managing routes and configurations |
| **Route** | Maps network traffic to one or more revisions |
| **Revision** | Immutable snapshot of code + config (point-in-time) |
| **Configuration** | Desired state of the workload, creates revisions on change |

### Eventing

Provides event-driven architecture primitives:

| Resource | Description |
|----------|-------------|
| **Broker** | Event hub that receives and distributes events |
| **Trigger** | Filters events from a Broker and delivers to a subscriber |
| **Source** | Generates events from external systems (Kafka, GitHub, Cron, etc.) |

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                  Knative Operator                     │
│         (manages Serving & Eventing CRDs)            │
└──────────┬────────────────────────┬──────────────────┘
           │                        │
┌──────────▼──────────┐  ┌─────────▼─────────────────┐
│  Knative Serving    │  │  Knative Eventing         │
│                     │  │                           │
│  Service ──▶ Route  │  │  Source ──▶ Broker        │
│        └──▶ Config  │  │             └──▶ Trigger  │
│              └──▶   │  │                  └──▶ Svc │
│             Revision│  │                           │
│                     │  │                           │
│  Activator (scale   │  └───────────────────────────┘
│   from zero)        │
│  Autoscaler (KPA)   │
└─────────────────────┘
         │
  ┌──────▼──────┐
  │  Traefik    │
  │  (Ingress)  │
  └─────────────┘
```

## Enabling

```json
{
  "raw_apps": {
    "knative": true
  }
}
```

## Knative Service Example

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: hello
  namespace: default
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "0"
        autoscaling.knative.dev/maxScale: "10"
    spec:
      containers:
        - image: ghcr.io/knative/helloworld-go:latest
          ports:
            - containerPort: 8080
          env:
            - name: TARGET
              value: "World"
```

## Autoscaling Configuration

| Annotation | Description | Default |
|------------|-------------|---------|
| `autoscaling.knative.dev/minScale` | Minimum number of replicas | `0` (scale-to-zero) |
| `autoscaling.knative.dev/maxScale` | Maximum number of replicas | `0` (unbounded) |
| `autoscaling.knative.dev/target` | Concurrency target per pod | `100` |
| `autoscaling.knative.dev/metric` | Scaling metric (`concurrency`, `rps`, `cpu`) | `concurrency` |
| `autoscaling.knative.dev/scale-down-delay` | Delay before scaling down | `0s` |

## Integration with Traefik

Knative is configured to use Traefik as the ingress controller. Knative Services are automatically routed through Traefik with URLs in the format:

```
https://<service>.<namespace>.knative.localhost
```

## Related Services

| Service | Relationship |
|---------|-------------|
| **Traefik** | Ingress controller for Knative Services |
| **Prometheus** | Scrapes Knative autoscaler and activator metrics |
| **Grafana** | Visualizes request latency, concurrency, and scaling metrics |

## Troubleshooting

```bash
# Check Knative operator
kubectl get pods -n knative-operator

# Check Serving components
kubectl get pods -n knative-serving

# Check Eventing components
kubectl get pods -n knative-eventing

# List Knative Services
kubectl get ksvc -A

# View a service's revisions
kubectl get revisions -n <namespace>

# Check autoscaler logs
kubectl logs -n knative-serving -l app=autoscaler --tail=50

# Check activator logs
kubectl logs -n knative-serving -l app=activator --tail=50

# Describe a Knative Service for status
kubectl describe ksvc <name> -n <namespace>
```
