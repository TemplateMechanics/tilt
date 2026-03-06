# JupyterHub

JupyterHub is a multi-user Jupyter notebook server for interactive data science and machine learning development.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `jupyterhub` |
| **Type** | Notebook Server |
| **Default** | Disabled |
| **Config Key** | `raw_apps.jupyterhub` |
| **Dashboard** | [jupyterhub.localhost](https://jupyterhub.localhost) |
| **Deployment** | Kustomize (raw manifests) |


## Official Documentation

- [JupyterHub Documentation](https://jupyterhub.readthedocs.io/en/stable/)
- [Zero to JupyterHub on K8s](https://z2jh.jupyter.org/en/stable/)
- [JupyterHub REST API](https://jupyterhub.readthedocs.io/en/stable/reference/rest-api.html)
- [Spawner Reference](https://jupyterhub.readthedocs.io/en/stable/reference/spawners.html)

## Enabling

```json
{
  "raw_apps": {
    "jupyterhub": true
  }
}
```

## Accessing

- **Web UI**: [https://jupyterhub.localhost](https://jupyterhub.localhost)
- **Default**: Any username with any password (dummy authenticator)

## Features

| Feature | Description |
|---------|-------------|
| **Multi-user** | Each user gets their own Jupyter server pod |
| **Persistent storage** | Notebooks survive pod restarts |
| **Multiple kernels** | Python, R, Julia support |
| **Extensions** | JupyterLab extensions for productivity |

## Usage

### Connecting to Platform Services

From a Jupyter notebook, connect to other dev platform services:

```python
# Connect to PostgreSQL
import psycopg2
conn = psycopg2.connect(
    host="postgresql.postgresql.svc.cluster.local",
    database="postgres",
    user="postgres",
    password="postgres"
)

# Connect to MongoDB
from pymongo import MongoClient
client = MongoClient("mongodb://root:root@mongodb.mongodb.svc.cluster.local:27017")

# Connect to Redis
import redis
r = redis.Redis(host="redis.redis.svc.cluster.local", port=6379)

# Use Ollama for LLM
import requests
response = requests.post("http://ollama.ollama:11434/api/generate", json={
    "model": "llama2", "prompt": "Hello", "stream": False
})
```

### Installing Packages

In a notebook cell:

```python
!pip install pandas numpy scikit-learn matplotlib seaborn
```

## Troubleshooting

```bash
kubectl get pods -n jupyterhub
kubectl logs -n jupyterhub -l app=jupyterhub --tail=50

# Check user server pods
kubectl get pods -n jupyterhub -l component=singleuser-server
```
