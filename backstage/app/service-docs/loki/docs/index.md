# Loki

Loki is the log aggregation system by Grafana Labs, designed for storing and querying logs efficiently.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `logging` |
| **Type** | Log Aggregation |
| **Always On** | Yes (observability) |
| **Deployment** | Kustomize |


## Official Documentation

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Reference](https://grafana.com/docs/loki/latest/query/)
- [Loki Helm Chart](https://github.com/grafana/loki/tree/main/production/helm/loki)
- [Loki HTTP API](https://grafana.com/docs/loki/latest/reference/loki-http-api/)

## Architecture

```
┌──────────────┐              ┌────────────────┐
│  Your Apps   │──── logs ───▶│     Loki       │
│  (stdout)    │              │   :3100        │
└──────────────┘              └───────┬────────┘
                                      │ LogQL
                                      ▼
                              ┌────────────────┐
                              │   Grafana /    │
                              │   API Clients  │
                              └────────────────┘
```

Loki collects logs from all pods in the cluster. Unlike Elasticsearch, it indexes only labels (not the full log text), making it lightweight and cost-effective.

## Accessing

- **In-cluster**: `loki.logging.svc.cluster.local:3100`
- **API**: `http://loki.logging:3100/loki/api/v1/query`

## Querying Logs

### LogQL Examples

```logql
# All logs from a namespace
{namespace="airflow"}

# Filter by container name
{namespace="backstage", container="backstage"}

# Search for errors
{namespace="airflow"} |= "error"

# Regex matching
{namespace="default"} |~ "timeout|connection refused"

# Rate of error logs
rate({namespace="airflow"} |= "error" [5m])
```

### API Query

```bash
curl -G 'http://loki.logging:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={namespace="airflow"}' \
  --data-urlencode 'limit=100'
```

## Integration with Other Services

| Service | Integration |
|---------|------------|
| **Prometheus** | Metrics about Loki's own performance |
| **Tempo** | Correlate logs with traces via trace IDs |
| **Grafana** | Query and visualize logs (if deployed) |

## Troubleshooting

```bash
# Check Loki status
kubectl get pods -n logging
kubectl logs -n logging -l app=loki --tail=50

# Verify log ingestion
curl http://loki.logging:3100/ready
curl http://loki.logging:3100/loki/api/v1/labels
```
