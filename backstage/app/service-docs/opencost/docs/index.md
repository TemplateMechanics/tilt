# OpenCost

OpenCost is a real-time Kubernetes cost monitoring tool that provides granular cost allocation by namespace, deployment, label, and more.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `opencost` |
| **Type** | Cost Monitoring |
| **Default** | Disabled |
| **Config Key** | `flux_apps.opencost` |
| **Deployment** | Flux HelmRelease |
| **Chart** | `opencost/opencost` v1.42.0 |
| **UI** | [opencost.localhost](https://opencost.localhost) |

## Official Documentation

- [OpenCost Documentation](https://www.opencost.io/docs/)
- [OpenCost API](https://www.opencost.io/docs/integrations/api)
- [OpenCost Specification](https://www.opencost.io/docs/specification)
- [OpenCost Helm Chart](https://github.com/opencost/opencost-helm-chart)

## Purpose

OpenCost provides real-time Kubernetes cost monitoring and allocation:

- **CPU Costs** — Per-core cost allocation across workloads
- **Memory Costs** — RAM usage cost tracking at container granularity
- **Storage Costs** — Persistent volume cost attribution
- **Network Costs** — Ingress/egress cost estimation
- **Idle Costs** — Identify unallocated cluster resources

## How It Works

```
┌─────────────────────────────────────────────┐
│              OpenCost                        │
│                                             │
│  ┌───────────────┐   ┌──────────────────┐   │
│  │  OpenCost     │   │  OpenCost UI     │   │
│  │  Server       │   │  opencost.       │   │
│  │               │◄──│  localhost       │   │
│  │  Reads K8s    │   └──────────────────┘   │
│  │  resource     │                          │
│  │  usage from   │   ┌──────────────────┐   │
│  │  Prometheus   │◄──│  REST API        │   │
│  │               │   │  :9003           │   │
│  └───────┬───────┘   └──────────────────┘   │
│          │                                   │
│  ┌───────▼──────────────────────────────┐   │
│  │  Prometheus                           │   │
│  │  (resource usage metrics: CPU, mem,   │   │
│  │   storage, network from cAdvisor)     │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

## Cost Allocation

OpenCost provides cost breakdowns across multiple dimensions:

| Dimension | Description |
|-----------|-------------|
| **Namespace** | Cost per Kubernetes namespace |
| **Deployment** | Cost per deployment/statefulset |
| **Label** | Cost by arbitrary Kubernetes labels |
| **Pod** | Individual pod-level cost |
| **Container** | Container-level resource cost |
| **Controller** | Cost by controller (Deployment, DaemonSet, etc.) |

## Enabling

```json
{
  "flux_apps": {
    "opencost": true
  }
}
```

## API Endpoints

The OpenCost API is available on port 9003:

```bash
# Get allocation data for the last 24 hours by namespace
curl http://opencost.localhost/allocation/compute?window=24h&aggregate=namespace

# Get allocation by deployment for the last 7 days
curl http://opencost.localhost/allocation/compute?window=7d&aggregate=deployment

# Get allocation by label
curl http://opencost.localhost/allocation/compute?window=24h&aggregate=label:app
```

## Integration with Prometheus

OpenCost requires Prometheus for resource usage metrics. It queries:

- `container_cpu_usage_seconds_total` — CPU consumption per container
- `container_memory_working_set_bytes` — Memory usage per container
- `kubelet_volume_stats_used_bytes` — PV storage usage
- `node_cpu_hourly_cost` / `node_ram_hourly_cost` — Node pricing (custom metrics)

## Related Services

| Service | Relationship |
|---------|-------------|
| **Prometheus** | Source of resource usage metrics |
| **Grafana** | Can visualize OpenCost data via API |
| **Thanos** | Provides long-term cost data via Prometheus queries |

## Troubleshooting

```bash
# Check OpenCost pods
kubectl get pods -n opencost

# View OpenCost logs
kubectl logs -n opencost -l app.kubernetes.io/name=opencost --tail=50

# Check HelmRelease status
kubectl get helmrelease -n opencost

# Verify Prometheus connection
kubectl logs -n opencost -l app.kubernetes.io/name=opencost --tail=100 | grep -i "prometheus\|error"

# Test API response
kubectl port-forward -n opencost svc/opencost 9003:9003
curl http://localhost:9003/allocation/compute?window=1h&aggregate=namespace

# Check OpenCost UI
# Visit https://opencost.localhost
```
