# Apache Airflow

Apache Airflow is a workflow orchestration platform for building and managing data pipelines.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `airflow` |
| **Type** | Workflow Orchestration |
| **Default** | Disabled |
| **Config Key** | `raw_apps.airflow` |
| **Dashboard** | [airflow.localhost](https://airflow.localhost) |
| **Deployment** | Kustomize (raw manifests) |


## Official Documentation

- [Airflow Documentation](https://airflow.apache.org/docs/)
- [DAG Authoring Guide](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html)
- [Airflow REST API](https://airflow.apache.org/docs/apache-airflow/stable/stable-rest-api-ref.html)
- [Operators & Hooks](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/operators.html)

## Architecture

```
┌─────────────────────────────────────────┐
│              Airflow System             │
│                                         │
│  ┌───────────┐  ┌───────────────────┐  │
│  │ Webserver │  │    Scheduler      │  │
│  │  :8080    │  │  (DAG parsing)    │  │
│  └───────────┘  └───────┬───────────┘  │
│                         │ tasks        │
│                 ┌───────▼───────────┐  │
│                 │     Workers       │  │
│                 │  (Celery/Local)   │  │
│                 └───────────────────┘  │
│                                         │
│  ┌─────────────┐  ┌────────────────┐  │
│  │ PostgreSQL  │  │     Redis      │  │
│  │  (metadata) │  │   (broker)     │  │
│  └─────────────┘  └────────────────┘  │
└─────────────────────────────────────────┘
```

## Components

| Component | Description |
|-----------|-------------|
| **Webserver** | Web UI and REST API |
| **Scheduler** | Parses DAGs, schedules task execution |
| **Worker** | Executes tasks via Celery or local executor |
| **PostgreSQL** | Metadata database for DAG runs and task state |
| **Redis** | Message broker for Celery executor |

## Enabling

```json
{
  "raw_apps": {
    "airflow": true
  }
}
```

## Accessing

- **Web UI**: [https://airflow.localhost](https://airflow.localhost)
- **Default credentials**: `admin` / `admin`
- **REST API**: `https://airflow.localhost/api/v1/`

## Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Airflow Web | `admin` | `admin` |
| PostgreSQL | `airflow` | `airflow` |

!!! warning
    These are development-only credentials. Never use in production.

## Provided APIs

| API | Type | Description |
|-----|------|-------------|
| `airflow-api` | REST | DAG management, trigger runs, task state |

## Dependencies

- `resource:airflow-postgresql` — Metadata database
- `resource:airflow-redis` — Celery task broker

## Adding DAGs

Mount your DAGs directory into the Airflow pods. By default, DAGs are loaded from the built-in examples.

To add custom DAGs:

1. Create a ConfigMap with your DAG files
2. Mount it at `/opt/airflow/dags` in the scheduler and worker pods
3. Alternatively, use git-sync for DAG synchronization

## Troubleshooting

```bash
# Check all Airflow components
kubectl get pods -n airflow

# Scheduler logs
kubectl logs -n airflow -l component=scheduler --tail=50

# Webserver logs
kubectl logs -n airflow -l component=webserver --tail=50

# Database connectivity
kubectl exec -n airflow deploy/airflow-scheduler -- airflow db check

# Reset the database (destructive!)
kubectl exec -n airflow deploy/airflow-scheduler -- airflow db reset -y
```
