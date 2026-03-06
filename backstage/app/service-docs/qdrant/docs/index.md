# Qdrant

Qdrant is a high-performance vector similarity search engine for AI applications including RAG, recommendation systems, and semantic search.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `qdrant` |
| **Type** | Vector Database |
| **Default** | Disabled |
| **Config Key** | `crossplane_apps.qdrant` |
| **Dashboard** | [qdrant.localhost](https://qdrant.localhost) |
| **Deployment** | Crossplane DevApplication |


## Official Documentation

- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [REST API Reference](https://api.qdrant.tech/)
- [Collections Guide](https://qdrant.tech/documentation/concepts/collections/)
- [Search & Filtering](https://qdrant.tech/documentation/concepts/search/)

## Enabling

```json
{
  "crossplane_apps": {
    "qdrant": true
  }
}
```

## Accessing

- **Dashboard**: [https://qdrant.localhost](https://qdrant.localhost)
- **REST API**: `https://qdrant.localhost` or `qdrant.qdrant.svc.cluster.local:6333`
- **gRPC**: `qdrant.qdrant.svc.cluster.local:6334`

## Provided APIs

| API | Type | Description |
|-----|------|-------------|
| `qdrant-api` | REST/gRPC | Collection management, vector search, point operations |

## Usage

### Create a Collection

```bash
curl -X PUT 'https://qdrant.localhost/collections/my-docs' \
  -H 'Content-Type: application/json' \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }'
```

### Insert Vectors

```bash
curl -X PUT 'https://qdrant.localhost/collections/my-docs/points' \
  -H 'Content-Type: application/json' \
  -d '{
    "points": [
      {"id": 1, "vector": [0.1, 0.2, ...], "payload": {"text": "Hello world"}},
      {"id": 2, "vector": [0.3, 0.4, ...], "payload": {"text": "Kubernetes pods"}}
    ]
  }'
```

### Search

```bash
curl -X POST 'https://qdrant.localhost/collections/my-docs/points/search' \
  -H 'Content-Type: application/json' \
  -d '{
    "vector": [0.1, 0.2, ...],
    "limit": 5
  }'
```

## Python Integration (RAG pattern)

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

client = QdrantClient(host="qdrant.qdrant", port=6333)

# Create collection
client.create_collection(
    collection_name="docs",
    vectors_config=VectorParams(size=384, distance=Distance.COSINE)
)

# Upsert vectors
client.upsert(
    collection_name="docs",
    points=[
        PointStruct(id=1, vector=[0.1, 0.2, ...], payload={"text": "doc 1"}),
    ]
)

# Search
results = client.search(
    collection_name="docs",
    query_vector=[0.1, 0.2, ...],
    limit=5
)
```

## Integration with Ollama + Langfuse

Qdrant pairs well with:

- **Ollama** — Generate embeddings and completions locally
- **Langfuse** — Trace and monitor your RAG pipeline

## Troubleshooting

```bash
kubectl get pods -n qdrant
kubectl logs -n qdrant -l app.kubernetes.io/name=qdrant --tail=50
curl https://qdrant.localhost/collections  # List collections
```
