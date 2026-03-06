# GCP Emulators

Local emulators for Google Cloud Platform services running in Kubernetes.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `gcp-emulators` |
| **Type** | GCP Service Emulators |
| **Default** | Disabled |
| **Config Key** | `raw_apps.gcp-emulators` |
| **Deployment** | Kustomize (raw manifests) |


## Official Documentation

- [Pub/Sub Emulator](https://cloud.google.com/pubsub/docs/emulator)
- [Firestore Emulator](https://firebase.google.com/docs/emulator-suite/connect_firestore)
- [Bigtable Emulator](https://cloud.google.com/bigtable/docs/emulator)
- [Google Cloud Client Libraries](https://cloud.google.com/apis/docs/cloud-client-libraries)

## Enabling

```json
{
  "raw_apps": {
    "gcp-emulators": true
  }
}
```

## Emulators Included

### Firestore Emulator

| Property | Value |
|----------|-------|
| **Port** | 8080 |
| **Service** | `firestore-emulator.gcp-emulators.svc.cluster.local:8080` |
| **Env Var** | `FIRESTORE_EMULATOR_HOST=firestore-emulator:8080` |

### Cloud Pub/Sub Emulator

| Property | Value |
|----------|-------|
| **Port** | 8085 |
| **Service** | `pubsub-emulator.gcp-emulators.svc.cluster.local:8085` |
| **Env Var** | `PUBSUB_EMULATOR_HOST=pubsub-emulator:8085` |

### Cloud Bigtable Emulator

| Property | Value |
|----------|-------|
| **Port** | 8086 |
| **Service** | `bigtable-emulator.gcp-emulators.svc.cluster.local:8086` |
| **Env Var** | `BIGTABLE_EMULATOR_HOST=bigtable-emulator:8086` |

### Cloud Spanner Emulator

| Property | Value |
|----------|-------|
| **gRPC Port** | 9010 |
| **HTTP Port** | 9020 |
| **Service** | `spanner-emulator.gcp-emulators.svc.cluster.local:9010` |
| **Env Var** | `SPANNER_EMULATOR_HOST=spanner-emulator:9010` |

### Cloud Datastore Emulator

| Property | Value |
|----------|-------|
| **Port** | 8081 |
| **Service** | `datastore-emulator.gcp-emulators.svc.cluster.local:8081` |
| **Env Var** | `DATASTORE_EMULATOR_HOST=datastore-emulator:8081` |

## Usage

### Python Example

```python
import os
from google.cloud import firestore

# Set emulator host
os.environ['FIRESTORE_EMULATOR_HOST'] = 'firestore-emulator:8080'

# Use Firestore normally
db = firestore.Client(project='test-project')
doc_ref = db.collection('users').document('user1')
doc_ref.set({'name': 'Alice', 'age': 30})
```

### Node.js Example

```javascript
// Set emulator host
process.env.FIRESTORE_EMULATOR_HOST = 'firestore-emulator:8080';

const { Firestore } = require('@google-cloud/firestore');
const db = new Firestore({ projectId: 'test-project' });

const doc = db.collection('users').doc('user1');
await doc.set({ name: 'Alice', age: 30 });
```

### Java Example

```java
// Pub/Sub with emulator
ChannelProvider channelProvider = FixedTransportChannelProvider.create(
    GrpcTransportChannel.create(
        ManagedChannelBuilder.forTarget("pubsub-emulator:8085")
            .usePlaintext().build()));

TopicAdminClient topicAdmin = TopicAdminClient.create(
    TopicAdminSettings.newBuilder()
        .setTransportChannelProvider(channelProvider)
        .setCredentialsProvider(NoCredentialsProvider.create())
        .build());
```

## Port Forwarding for Local Access

```bash
# Firestore
kubectl port-forward -n gcp-emulators svc/firestore-emulator 8080:8080

# Pub/Sub
kubectl port-forward -n gcp-emulators svc/pubsub-emulator 8085:8085

# Bigtable
kubectl port-forward -n gcp-emulators svc/bigtable-emulator 8086:8086

# Spanner
kubectl port-forward -n gcp-emulators svc/spanner-emulator 9010:9010

# Datastore
kubectl port-forward -n gcp-emulators svc/datastore-emulator 8081:8081
```

## Notes

- All emulators use project ID: `test-project`
- Data is ephemeral (not persisted across restarts)
- Spanner emulator is official Google image, others use Cloud SDK

## Troubleshooting

```bash
kubectl get pods -n gcp-emulators
kubectl logs -n gcp-emulators -l app=firestore-emulator --tail=50
kubectl logs -n gcp-emulators -l app=pubsub-emulator --tail=50
```
