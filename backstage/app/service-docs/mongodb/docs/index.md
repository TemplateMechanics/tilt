# MongoDB

MongoDB is a NoSQL document database providing flexible, JSON-like document storage.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `mongodb` |
| **Type** | Document Database |
| **Default** | Disabled |
| **Config Key** | `raw_apps.mongodb` |
| **Deployment** | Kustomize (raw manifests) |


## Official Documentation

- [MongoDB Documentation](https://www.mongodb.com/docs/manual/)
- [MongoDB Shell (mongosh)](https://www.mongodb.com/docs/mongodb-shell/)
- [CRUD Operations](https://www.mongodb.com/docs/manual/crud/)
- [Aggregation Pipeline](https://www.mongodb.com/docs/manual/aggregation/)

## Enabling

```json
{
  "raw_apps": {
    "mongodb": true
  }
}
```

## Accessing

- **In-cluster**: `mongodb.mongodb.svc.cluster.local:27017`
- **Port forward**: `kubectl port-forward -n mongodb svc/mongodb 27017:27017`
- **Connection string**: `mongodb://root:root@mongodb.mongodb.svc.cluster.local:27017`

## Default Credentials

| Property | Value |
|----------|-------|
| Username | `root` |
| Password | `root` |
| Auth DB | `admin` |

## Usage

### mongosh

```bash
kubectl exec -it -n mongodb deploy/mongodb -- mongosh -u root -p root

# Create a database and collection
use mydb
db.users.insertOne({ name: "Alice", age: 30 })
db.users.find()
```

### Python (pymongo)

```python
from pymongo import MongoClient

client = MongoClient("mongodb://root:root@mongodb.mongodb:27017")
db = client.mydb

db.users.insert_one({"name": "Alice", "age": 30})
users = list(db.users.find())
```

### Node.js

```javascript
const { MongoClient } = require('mongodb');

const client = new MongoClient('mongodb://root:root@mongodb.mongodb:27017');
await client.connect();

const db = client.db('mydb');
await db.collection('users').insertOne({ name: 'Alice', age: 30 });
```

## Troubleshooting

```bash
kubectl get pods -n mongodb
kubectl logs -n mongodb -l app=mongodb --tail=50

# Check connectivity
kubectl exec -n mongodb deploy/mongodb -- mongosh -u root -p root --eval "db.runCommand({ping: 1})"
```
