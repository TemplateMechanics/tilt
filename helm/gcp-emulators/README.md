# GCP Emulators

Local emulators for Google Cloud Platform services running in Kubernetes.

## Emulators Included

### Firestore Emulator
- **Port**: 8080
- **Service**: `firestore-emulator.gcp-emulators.svc.cluster.local:8080`
- **Environment Variable**: `FIRESTORE_EMULATOR_HOST=firestore-emulator:8080`

### Cloud Pub/Sub Emulator
- **Port**: 8085
- **Service**: `pubsub-emulator.gcp-emulators.svc.cluster.local:8085`
- **Environment Variable**: `PUBSUB_EMULATOR_HOST=pubsub-emulator:8085`

### Cloud Bigtable Emulator
- **Port**: 8086
- **Service**: `bigtable-emulator.gcp-emulators.svc.cluster.local:8086`
- **Environment Variable**: `BIGTABLE_EMULATOR_HOST=bigtable-emulator:8086`

### Cloud Spanner Emulator
- **gRPC Port**: 9010
- **HTTP Port**: 9020
- **Service**: `spanner-emulator.gcp-emulators.svc.cluster.local:9010`
- **Environment Variable**: `SPANNER_EMULATOR_HOST=spanner-emulator:9010`

### Cloud Datastore Emulator
- **Port**: 8081
- **Service**: `datastore-emulator.gcp-emulators.svc.cluster.local:8081`
- **Environment Variable**: `DATASTORE_EMULATOR_HOST=datastore-emulator:8081`

## Usage

### Python Example
```python
from google.cloud import firestore

# Set emulator host
os.environ['FIRESTORE_EMULATOR_HOST'] = 'firestore-emulator:8080'

# Use Firestore normally
db = firestore.Client(project='test-project')
```

### Node.js Example
```javascript
// Set emulator host
process.env.FIRESTORE_EMULATOR_HOST = 'firestore-emulator:8080';

const { Firestore } = require('@google-cloud/firestore');
const db = new Firestore({ projectId: 'test-project' });
```

### Port Forwarding for Local Access
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
- For production-like testing, consider adding PersistentVolumeClaims
- Spanner emulator is official Google image, others use Cloud SDK
