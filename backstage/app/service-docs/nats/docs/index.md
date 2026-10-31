# NATS

NATS is a high-performance, cloud-native messaging system for distributed applications, IoT, and microservice architectures.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `nats` |
| **Type** | Messaging |
| **Default** | Disabled |
| **Config Key** | `flux_apps.nats` |
| **Deployment** | Flux HelmRelease |
| **Chart** | `nats/nats` v1.2.6 |

## Official Documentation

- [NATS Documentation](https://docs.nats.io/)
- [JetStream Documentation](https://docs.nats.io/nats-concepts/jetstream)
- [NATS CLI Reference](https://docs.nats.io/using-nats/nats-tools/nats_cli)
- [NATS Helm Chart](https://github.com/nats-io/k8s/tree/main/helm/charts/nats)

## Purpose

NATS provides lightweight, high-performance messaging with multiple patterns:

- **Publish/Subscribe** — Fan-out messaging to multiple subscribers
- **Request/Reply** — Synchronous RPC-style communication
- **Queue Groups** — Load-balanced message distribution across consumers
- **JetStream** — Persistent messaging with at-least-once and exactly-once delivery

## Architecture

```
┌─────────────────────────────────────────┐
│            NATS Server                  │
│                                         │
│  ┌─────────┐  ┌──────────┐             │
│  │  Core   │  │ JetStream│             │
│  │ Pub/Sub │  │ (Streams │             │
│  │ Req/Rep │  │  & KV)   │             │
│  └────┬────┘  └─────┬────┘             │
│       │              │                  │
│  :4222 client   :8222 monitor           │
│  :7777 metrics                          │
└─────────────────────────────────────────┘
       │                │
  ┌────▼────┐     ┌─────▼─────┐
  │  Apps   │     │ Prometheus │
  │ (client │     │ (metrics)  │
  │  conns) │     └───────────┘
  └─────────┘
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| **4222** | TCP | Client connections (pub/sub, request/reply) |
| **8222** | HTTP | Monitoring and health endpoints |
| **7777** | HTTP | Prometheus metrics |

## Enabling

```json
{
  "flux_apps": {
    "nats": { "enabled": true }
  }
}
```

## JetStream

JetStream adds persistence and streaming capabilities:

- **Streams** — Durable message storage with configurable retention (limits, interest, work queue)
- **Consumers** — Push or pull-based message delivery with acknowledgement tracking
- **Key-Value Store** — Distributed key-value storage built on streams
- **Object Store** — Large object storage built on streams

## NATS CLI Examples

```bash
# Port-forward to access NATS
kubectl port-forward -n nats svc/nats 4222:4222

# Publish a message
nats pub orders.new '{"id": 123, "item": "widget"}'

# Subscribe to a subject
nats sub "orders.>"

# Request/reply
nats request orders.status '{"id": 123}'

# List streams (JetStream)
nats stream ls

# Create a stream
nats stream add ORDERS --subjects "orders.>" --retention limits --max-msgs 10000

# Create a consumer
nats consumer add ORDERS order-processor --pull --deliver all --ack explicit
```

## Comparison with RabbitMQ

| Feature | NATS | RabbitMQ |
|---------|------|----------|
| **Latency** | Ultra-low (sub-millisecond) | Low (millisecond) |
| **Protocol** | NATS protocol, WebSocket | AMQP, MQTT, STOMP |
| **Persistence** | JetStream (opt-in) | Built-in by default |
| **Clustering** | Built-in mesh | Requires configuration |
| **Use Case** | Microservices, IoT, edge | Enterprise messaging, task queues |
| **Overhead** | Minimal (~10MB RAM) | Moderate (~100MB+ RAM) |

## Related Services

| Service | Relationship |
|---------|-------------|
| **Prometheus** | Scrapes NATS metrics on port 7777 |
| **Grafana** | Visualizes NATS throughput and connection metrics |
| **Dapr** | Can use NATS as a pub/sub component |

## Troubleshooting

```bash
# Check NATS pods
kubectl get pods -n nats

# View NATS logs
kubectl logs -n nats -l app.kubernetes.io/name=nats --tail=50

# Check HelmRelease status
kubectl get helmrelease -n nats

# Check server health
kubectl exec -n nats -it deployment/nats-box -- nats server check connection

# List JetStream streams
kubectl exec -n nats -it deployment/nats-box -- nats stream ls

# View server info
kubectl exec -n nats -it deployment/nats-box -- nats server info

# Monitor connections in real time
kubectl exec -n nats -it deployment/nats-box -- nats server report connections
```
