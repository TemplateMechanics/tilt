# Tempo

Tempo is the distributed tracing backend by Grafana Labs, providing cost-effective trace storage and querying.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `tracing` |
| **Type** | Distributed Tracing |
| **Always On** | Yes (observability) |
| **Deployment** | Kustomize |


## Official Documentation

- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [TraceQL Reference](https://grafana.com/docs/tempo/latest/traceql/)
- [Tempo Helm Chart](https://github.com/grafana/helm-charts/tree/main/charts/tempo)
- [Tempo HTTP API](https://grafana.com/docs/tempo/latest/api_docs/)

## Architecture

```
┌──────────────┐              ┌────────────────┐
│  Your Apps   │── traces ──▶│     Tempo      │
│  (OTLP)     │              │   :4317 gRPC   │
└──────────────┘              │   :4318 HTTP   │
                              └───────┬────────┘
                                      │ TraceQL
                                      ▼
                              ┌────────────────┐
                              │   Grafana /    │
                              │   API Clients  │
                              └────────────────┘
```

## Accessing

- **OTLP gRPC**: `tempo.tracing.svc.cluster.local:4317`
- **OTLP HTTP**: `tempo.tracing.svc.cluster.local:4318`
- **Query API**: `tempo.tracing.svc.cluster.local:3200`

## Sending Traces

### OpenTelemetry SDK (Python)

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

provider = TracerProvider()
exporter = OTLPSpanExporter(endpoint="tempo.tracing:4317", insecure=True)
provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer(__name__)
with tracer.start_as_current_span("my-operation"):
    # Your code here
    pass
```

### OpenTelemetry SDK (Node.js)

```javascript
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const provider = new NodeTracerProvider();
const exporter = new OTLPTraceExporter({ url: 'grpc://tempo.tracing:4317' });
provider.addSpanProcessor(new BatchSpanProcessor(exporter));
provider.register();
```

## Querying Traces

### By Trace ID

```bash
curl http://tempo.tracing:3200/api/traces/<trace-id>
```

### TraceQL

```traceql
{ span.http.method = "GET" && span.http.status_code >= 500 }
{ resource.service.name = "my-service" && duration > 1s }
```

## Integration

| Service | Integration |
|---------|------------|
| **Prometheus** | Exemplars link metrics to traces |
| **Loki** | Trace ID in logs links to Tempo |

## Troubleshooting

```bash
kubectl get pods -n tracing
kubectl logs -n tracing -l app=tempo --tail=50
curl http://tempo.tracing:3200/ready
```
