# Ollama

Ollama provides a local large language model server for running LLMs like Llama, Mistral, and Code Llama.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `ollama` |
| **Type** | LLM Inference Server |
| **Default** | Disabled |
| **Config Key** | `flux_apps.ollama` |
| **Deployment** | Flux HelmRelease |


## Official Documentation

- [Ollama Documentation](https://github.com/ollama/ollama/blob/main/README.md)
- [Ollama API Reference](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Model Library](https://ollama.com/library)
- [Ollama FAQ](https://github.com/ollama/ollama/blob/main/docs/faq.md)

## Enabling

```json
{
  "flux_apps": {
    "ollama": true
  }
}
```

## Accessing

- **API**: `http://ollama.ollama.svc.cluster.local:11434`
- **Port forward**: `kubectl port-forward -n ollama svc/ollama 11434:11434`

## Provided APIs

| API | Type | Description |
|-----|------|-------------|
| `ollama-api` | REST | Model management, text generation, embeddings |

## Usage

### Generate Completion

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama2",
  "prompt": "Explain Kubernetes in one sentence"
}'
```

### Chat

```bash
curl http://localhost:11434/api/chat -d '{
  "model": "llama2",
  "messages": [
    {"role": "user", "content": "What is a pod in Kubernetes?"}
  ]
}'
```

### Pull a Model

```bash
curl http://localhost:11434/api/pull -d '{"name": "llama2"}'
curl http://localhost:11434/api/pull -d '{"name": "codellama"}'
curl http://localhost:11434/api/pull -d '{"name": "mistral"}'
```

### List Models

```bash
curl http://localhost:11434/api/tags
```

### Generate Embeddings

```bash
curl http://localhost:11434/api/embeddings -d '{
  "model": "llama2",
  "prompt": "Kubernetes is a container orchestration platform"
}'
```

## Python Integration

```python
import requests

response = requests.post("http://ollama.ollama:11434/api/generate", json={
    "model": "llama2",
    "prompt": "Explain microservices",
    "stream": False
})
print(response.json()["response"])
```

## Resource Requirements

Ollama requires significant resources for LLM inference:

| Model | RAM Required | Notes |
|-------|-------------|-------|
| llama2 (7B) | ~4GB | Good for general tasks |
| codellama (7B) | ~4GB | Code generation |
| mistral (7B) | ~4GB | Fast, high quality |
| llama2 (13B) | ~8GB | Better quality, slower |

!!! warning
    Running large models may cause memory pressure on your Docker Desktop. Allocate at least 8GB RAM.

## Troubleshooting

```bash
kubectl get pods -n ollama
kubectl logs -n ollama -l app.kubernetes.io/name=ollama --tail=50
kubectl top pod -n ollama  # Check resource usage
```
