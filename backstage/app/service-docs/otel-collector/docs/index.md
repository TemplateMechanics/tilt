# OpenTelemetry Collector

The OpenTelemetry Collector is a vendor-agnostic telemetry pipeline that receives, processes, and exports traces, metrics, and logs to observability backends.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `opentelemetry` |
| **Type** | Observability Pipeline |
| **Default** | Disabled |
| **Config Key** | `flux_apps.otel-collector` |
| **Deployment** | Flux HelmRelease |
| **Chart** | `open-telemetry/opentelemetry-collector` v0.98.0 |

## Official Documentation

- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)
- [Collector Configuration](https://opentelemetry.io/docs/collector/configuration/)
- [Collector Helm Chart](https://github.com/open-telemetry/opentelemetry-helm-charts)
- [OTLP Specification](https://opentelemetry.io/docs/specs/otlp/)

## Purpose

The OpenTelemetry Collector serves as the unified telemetry pipeline connecting applications to the observability stack:

- **Traces** — Collected via OTLP and exported to Tempo for distributed tracing
- **Metrics** — Received from instrumented apps and forwarded to Prometheus
- **Logs** — Gathered and shipped to Loki for centralized log aggregation
- Decouples instrumentation from backend, allowing backend changes without app modifications

## Pipeline Architecture

```
┌──────────────────────────────────────────────────────────┐
│              OpenTelemetry Collector                      │
│                                                          │
│  ┌────────────┐   ┌─────────────┐   ┌────────────────┐  │
│  │ Receivers   │──▶│ Processors  │──▶│  Exporters     │  │
│  │            │   │             │   │                │  │
│  │ • OTLP     │   │ • Batch     │   │ • OTLP (Tempo) │  │
│  │   (gRPC)   │   │ • Memory    │   │ • Prometheus   │  │
│  │ • OTLP     │   │   Limiter   │   │   RemoteWrite  │  │
│  │   (HTTP)   │   │ • Resource  │   │ • Loki         │  │
│  │ • Prometheus│   │   Detection │   │                │  │
│  └────────────┘   └─────────────┘   └────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

## Configured Pipelines

| Pipeline | Receiver | Processors | Exporter | Backend |
|----------|----------|------------|----------|---------|
| **Traces** | OTLP gRPC/HTTP | Batch, Memory Limiter | OTLP | Tempo |
| **Metrics** | OTLP, Prometheus | Batch, Memory Limiter | Prometheus RemoteWrite | Prometheus |
| **Logs** | OTLP | Batch, Memory Limiter | Loki | Loki |

## OTLP Endpoints

| Protocol | Endpoint | Port |
|----------|----------|------|
| **gRPC** | `otel-collector-opentelemetry-collector.opentelemetry:4317` | 4317 |
| **HTTP** | `otel-collector-opentelemetry-collector.opentelemetry:4318` | 4318 |

Applications can send telemetry using either protocol. Set the `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable to point to the appropriate endpoint.

## Enabling

```json
{
  "flux_apps": {
    "otel-collector": true
  }
}
```

## Integration with Observability Stack

The collector integrates with the existing platform services:

- **Prometheus** — Metrics are remote-written to the Prometheus instance in the `prometheus` namespace
- **Loki** — Logs are pushed to Loki in the `loki` namespace
- **Tempo** — Traces are exported via OTLP to Tempo in the `tempo` namespace
- **Grafana** — A dedicated dashboard is available in the Observability folder for collector health

## ServiceMonitor

A ServiceMonitor is configured to scrape the collector's internal metrics, providing visibility into:

- Received, processed, and exported spans/metrics/logs
- Pipeline throughput and error rates
- Queue and batch sizes

## Related Services

| Service | Relationship |
|---------|-------------|
| **Prometheus** | Receives metrics from the collector |
| **Loki** | Receives logs from the collector |
| **Tempo** | Receives traces from the collector |
| **Grafana** | Visualizes collector health and telemetry |

## Troubleshooting

```bash
# Check collector pods
kubectl get pods -n opentelemetry

# View collector logs
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector --tail=50

# Check HelmRelease status
kubectl get helmrelease -n opentelemetry

# Verify OTLP gRPC endpoint is reachable
kubectl run -n default --rm -it otel-test --image=busybox -- wget -qO- http://otel-collector-opentelemetry-collector.opentelemetry:4318/v1/status

# Check collector internal metrics
kubectl port-forward -n opentelemetry svc/otel-collector-opentelemetry-collector 8888:8888
# Then visit http://localhost:8888/metrics

# Verify pipeline health via logs
kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-collector --tail=100 | grep -i "error\|dropped\|refused"
```
