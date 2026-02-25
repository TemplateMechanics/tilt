# Langfuse

Langfuse is an open-source LLM engineering platform for tracing, analytics, prompt management, and evaluation.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `langfuse` |
| **Type** | LLM Observability |
| **Default** | Disabled |
| **Config Key** | `crossplane_apps.langfuse` |
| **Dashboard** | [langfuse.localhost](https://langfuse.localhost) |
| **Deployment** | Crossplane DevApplication |


## Official Documentation

- [Langfuse Documentation](https://langfuse.com/docs)
- [Python SDK](https://langfuse.com/docs/sdk/python)
- [Tracing Guide](https://langfuse.com/docs/tracing)
- [Self-Hosting Guide](https://langfuse.com/docs/deployment/self-host)

## Enabling

```json
{
  "crossplane_apps": {
    "langfuse": true
  }
}
```

## Accessing

- **Dashboard**: [https://langfuse.localhost](https://langfuse.localhost)
- **API**: `https://langfuse.localhost/api/public/`

## Provided APIs

| API | Type | Description |
|-----|------|-------------|
| `langfuse-api` | REST | Trace ingestion, prompt management, analytics |

## Dependencies

- `resource:langfuse-postgresql` — Stores traces, prompts, and analytics data

## Usage

### Python SDK

```python
from langfuse import Langfuse

langfuse = Langfuse(
    public_key="pk-...",
    secret_key="sk-...",
    host="https://langfuse.localhost"
)

# Create a trace
trace = langfuse.trace(name="my-rag-pipeline")

# Log a generation (LLM call)
generation = trace.generation(
    name="llm-completion",
    model="llama2",
    input="What is Kubernetes?",
    output="Kubernetes is a container orchestration platform...",
    usage={"input": 5, "output": 20}
)

langfuse.flush()
```

### OpenAI Integration

```python
from langfuse.openai import openai

# Drop-in replacement - automatically traces all calls
response = openai.ChatCompletion.create(
    model="gpt-3.5-turbo",
    messages=[{"role": "user", "content": "Hello"}]
)
```

### Decorator Pattern

```python
from langfuse.decorators import observe

@observe()
def my_rag_pipeline(query: str):
    # Embedding step
    embedding = get_embedding(query)
    
    # Retrieval step
    docs = search_qdrant(embedding)
    
    # Generation step
    return generate_response(query, docs)
```

## Features

| Feature | Description |
|---------|-------------|
| **Tracing** | Full trace of LLM chains and RAG pipelines |
| **Analytics** | Cost, latency, and quality metrics |
| **Prompt Management** | Version and A/B test prompts |
| **Evaluation** | Score traces manually or with LLM judges |
| **Datasets** | Build evaluation datasets from production traces |

## Integration with Platform

- **Ollama** — Local LLM inference, traced through Langfuse
- **Qdrant** — Vector search, logged as retrieval spans

## Troubleshooting

```bash
kubectl get pods -n langfuse
kubectl logs -n langfuse -l app.kubernetes.io/name=langfuse --tail=50

# Check API health
curl https://langfuse.localhost/api/public/health
```
