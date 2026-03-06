# Prometheus

Prometheus is the open-source monitoring and alerting toolkit that powers metrics collection for the dev platform.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `monitoring` |
| **Type** | Metrics & Monitoring |
| **Always On** | Yes (observability) |
| **Dashboard** | [prometheus.localhost](https://prometheus.localhost) |
| **Deployment** | Kustomize |


## Official Documentation

- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [PromQL Reference](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)

## Architecture

```
┌──────────────┐    scrape     ┌────────────────┐
│  Your Apps   │◄──────────────│   Prometheus    │
│  /metrics    │               │   :9090         │
└──────────────┘               └───────┬────────┘
                                       │ PromQL
                                       ▼
                               ┌────────────────┐
                               │   Grafana /     │
                               │   API Clients   │
                               └────────────────┘
```

Prometheus scrapes metrics from all services with `ServiceMonitor` resources or Prometheus annotations.

## Accessing

- **Web UI**: [https://prometheus.localhost](https://prometheus.localhost)
- **API**: `https://prometheus.localhost/api/v1/query`
- **In-cluster**: `prometheus.monitoring.svc.cluster.local:9090`

## Querying Metrics

### PromQL Examples

```promql
# CPU usage by pod
rate(container_cpu_usage_seconds_total[5m])

# Memory usage
container_memory_working_set_bytes{namespace="airflow"}

# HTTP request rate
rate(http_requests_total[1m])

# 99th percentile latency
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

### API Query

```bash
curl -G 'https://prometheus.localhost/api/v1/query' \
  --data-urlencode 'query=up'
```

## Adding Monitoring to Your Service

### Option 1: ServiceMonitor (Recommended)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-service
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-service
  endpoints:
    - port: metrics
      path: /metrics
      interval: 30s
```

### Option 2: Pod Annotations

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"
```

## Provided APIs

| API | Type | Description |
|-----|------|-------------|
| `prometheus-api` | REST | PromQL query and metadata API |

## Troubleshooting

```bash
# Check targets
curl https://prometheus.localhost/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Check scrape errors
kubectl logs -n monitoring -l app=prometheus --tail=50

# Verify ServiceMonitor
kubectl get servicemonitor -A
```
