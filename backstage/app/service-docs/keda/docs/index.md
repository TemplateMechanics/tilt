# KEDA (Kubernetes Event-Driven Autoscaling)

KEDA is a CNCF graduated project that provides event-driven autoscaling for Kubernetes workloads. It scales deployments based on external event sources like Azure Service Bus queues, storage queues, and more.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `keda` |
| **Type** | Autoscaler |
| **Default** | Disabled |
| **Config Key** | `flux_apps.keda` |
| **Deployment** | Flux HelmRelease |
| **Chart** | `keda` v2.14.2 from kedacore.github.io |

## Official Documentation

- [KEDA Documentation](https://keda.sh/docs/)
- [KEDA Scalers](https://keda.sh/docs/scalers/)
- [KEDA FAQ](https://keda.sh/docs/faq/)
- [Helm Chart](https://github.com/kedacore/charts)

## Architecture

```
┌─────────────────────────────────────────┐
│           KEDA Controller               │
│  ┌─────────────┐  ┌──────────────────┐  │
│  │   Operator   │  │ Metrics Adapter  │  │
│  │  (Scaler     │  │ (External        │  │
│  │   Manager)   │  │  Metrics API)    │  │
│  └──────┬───────┘  └────────┬────────┘  │
│         │                   │           │
│  ┌──────▼───────────────────▼────────┐  │
│  │    ScaledObject / ScaledJob CRDs   │  │
│  └──────┬────────────────────────────┘  │
│         │                               │
└─────────┼───────────────────────────────┘
          │
   ┌──────▼──────────────┐
   │  Event Sources       │
   │  - Azure Service Bus │
   │  - Azure Storage     │
   │  - Prometheus        │
   │  - RabbitMQ          │
   │  - And 50+ more      │
   └──────────────────────┘
```

## Features

- **60+ Scalers**: Azure Service Bus, Storage Queues, Kafka, RabbitMQ, Prometheus, and more
- **Scale to Zero**: Automatically scale deployments down to zero replicas
- **ScaledObject CRD**: Declarative autoscaling configuration
- **ClusterTriggerAuthentication**: Cluster-wide auth for scalers

## Configured Trigger Authentications

This deployment includes pre-configured `ClusterTriggerAuthentication` resources:

| Name | Source | Purpose |
|------|--------|---------|
| `keda-trigger-auth-azure-servicebus` | Azure Service Bus | Queue/topic autoscaling |
| `keda-trigger-auth-azure-storage-account` | Azure Storage | Storage queue autoscaling |
| `keda-trigger-auth-secondary-azure-storage-account` | Azure Storage (SFTP) | SFTP storage autoscaling |

## Enabling

```json
{
  "flux_apps": {
    "keda": true
  }
}
```

## Example ScaledObject

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: my-app-scaler
spec:
  scaleTargetRef:
    name: my-deployment
  minReplicaCount: 0
  maxReplicaCount: 10
  triggers:
    - type: azure-servicebus
      metadata:
        queueName: my-queue
        messageCount: "5"
      authenticationRef:
        name: keda-trigger-auth-azure-servicebus
        kind: ClusterTriggerAuthentication
```
