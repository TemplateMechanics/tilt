# Thanos

Thanos is a highly available Prometheus setup with long-term storage, global query view, and unlimited retention for metrics data.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `thanos` |
| **Type** | Long-Term Metrics Storage |
| **Default** | Disabled |
| **Config Key** | `flux_apps.thanos` |
| **Deployment** | Flux HelmRelease |
| **Chart** | `bitnami/thanos` v15.7.19 |
| **Query UI** | [thanos.localhost](https://thanos.localhost) |

## Official Documentation

- [Thanos Documentation](https://thanos.io/tip/thanos/getting-started.md/)
- [Thanos Components](https://thanos.io/tip/thanos/design.md/)
- [Thanos Helm Chart (Bitnami)](https://github.com/bitnami/charts/tree/main/bitnami/thanos)
- [Prometheus Integration](https://thanos.io/tip/thanos/quick-tutorial.md/)

## Purpose

Thanos extends Prometheus with enterprise-grade features:

- **Unlimited Retention** — Store metrics indefinitely in object storage
- **Global Query View** — Query across multiple Prometheus instances from a single endpoint
- **Downsampling** — Automatic resolution reduction for older data (5m, 1h)
- **High Availability** — Deduplicated queries across Prometheus replicas
- **Cost-Effective** — Leverage cheap object storage for long-term data

## Components

```
┌─────────────────────────────────────────────────────────┐
│                      Thanos                              │
│                                                         │
│  ┌──────────────────┐    ┌────────────────────────────┐ │
│  │  Query           │    │  Query Frontend            │ │
│  │  (PromQL engine) │◄───│  (caching, splitting)      │ │
│  │  thanos.localhost│    │  Splits large queries      │ │
│  └──────┬───────────┘    └────────────────────────────┘ │
│         │                                               │
│    ┌────┴─────────────────────┐                         │
│    │                          │                         │
│  ┌─▼────────────┐   ┌────────▼───────────┐             │
│  │ Sidecar      │   │ Store Gateway      │             │
│  │ (Prometheus  │   │ (reads historical  │             │
│  │  companion)  │   │  data from object  │             │
│  │              │   │  storage)          │             │
│  └──────┬───────┘   └────────────────────┘             │
│         │                                               │
│  ┌──────▼───────┐   ┌────────────────────┐             │
│  │ Prometheus   │   │ Compactor          │             │
│  │ (real-time   │   │ (downsamples &     │             │
│  │  metrics)    │   │  compacts blocks)  │             │
│  └──────────────┘   └────────────────────┘             │
└─────────────────────────────────────────────────────────┘
```

## Component Details

| Component | Role |
|-----------|------|
| **Query** | Central PromQL endpoint that fans out to Sidecars and Store Gateways |
| **Query Frontend** | Caches and splits large range queries for performance |
| **Store Gateway** | Serves historical metrics from object storage |
| **Compactor** | Downsamples and compacts TSDB blocks in object storage |
| **Sidecar** | Runs alongside Prometheus, uploads blocks and proxies real-time queries |

## Enabling

```json
{
  "flux_apps": {
    "thanos": true
  }
}
```

## Data Flow

1. **Prometheus** collects real-time metrics and stores them in local TSDB
2. **Thanos Sidecar** uploads completed TSDB blocks to object storage
3. **Store Gateway** indexes and serves historical blocks from object storage
4. **Compactor** merges and downsamples blocks for efficient long-range queries
5. **Query** federates across Sidecar (recent) and Store Gateway (historical)
6. **Query Frontend** caches results and splits large queries

## Integration with Prometheus

Thanos requires the Prometheus Sidecar to be enabled. The sidecar:

- Exposes Prometheus data via the Thanos StoreAPI
- Uploads completed TSDB blocks to object storage
- Enables real-time queries through Thanos Query

## Related Services

| Service | Relationship |
|---------|-------------|
| **Prometheus** | Primary metrics source via Thanos Sidecar |
| **Grafana** | Can use Thanos Query as a Prometheus-compatible data source |
| **OpenCost** | Benefits from long-term metrics for historical cost analysis |

## Troubleshooting

```bash
# Check Thanos pods
kubectl get pods -n thanos

# View Query logs
kubectl logs -n thanos -l app.kubernetes.io/component=query --tail=50

# Check Store Gateway
kubectl logs -n thanos -l app.kubernetes.io/component=storegateway --tail=50

# Check Compactor
kubectl logs -n thanos -l app.kubernetes.io/component=compactor --tail=50

# Check HelmRelease status
kubectl get helmrelease -n thanos

# Verify stores connected to Query
kubectl port-forward -n thanos svc/thanos-query 9090:9090
# Visit http://localhost:9090 and check Stores tab

# Test PromQL via Thanos Query
curl -g 'http://thanos.localhost/api/v1/query?query=up'
```
