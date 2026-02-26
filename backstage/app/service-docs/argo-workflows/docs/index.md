# Argo Workflows

Argo Workflows is a container-native workflow engine for orchestrating parallel jobs and complex DAG-based pipelines on Kubernetes.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `argo` |
| **Type** | Workflow Engine |
| **Default** | Disabled |
| **Config Key** | `flux_apps.argo-workflows` |
| **Deployment** | Flux HelmRelease |
| **Chart** | `argo/argo-workflows` v0.45.0 |
| **UI** | [argo.localhost](https://argo.localhost) |

## Official Documentation

- [Argo Workflows Documentation](https://argo-workflows.readthedocs.io/)
- [Workflow Templates](https://argo-workflows.readthedocs.io/en/latest/workflow-templates/)
- [DAG Templates](https://argo-workflows.readthedocs.io/en/latest/walk-through/dag/)
- [Argo Workflows Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-workflows)

## Purpose

Argo Workflows enables container-native orchestration on Kubernetes:

- **DAG Workflows** — Define complex directed acyclic graph pipelines with dependencies
- **Step Workflows** — Sequential and parallel step execution
- **Artifact Management** — Pass data between workflow steps via S3-compatible storage
- **Template Library** — Reusable workflow templates shared across teams
- **Cron Workflows** — Scheduled workflow execution
- **Retry & Error Handling** — Automatic retries with configurable backoff strategies

## Architecture

```
┌──────────────────────────────────────────────┐
│               Argo Workflows                  │
│                                              │
│  ┌──────────────────┐  ┌──────────────────┐  │
│  │ Workflow          │  │ Argo Server      │  │
│  │ Controller        │  │ (UI + API)       │  │
│  │                  │  │ argo.localhost    │  │
│  │ Watches Workflow │  │                  │  │
│  │ CRDs & manages  │  │ REST API         │  │
│  │ pod execution    │  │ SSE streaming    │  │
│  └────────┬─────────┘  └──────────────────┘  │
│           │                                   │
│  ┌────────▼─────────────────────────────────┐ │
│  │  Workflow Pods (one per step/task)        │ │
│  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐        │ │
│  │  │Step1│ │Step2│ │Step3│ │Step4│        │ │
│  │  └─────┘ └─────┘ └─────┘ └─────┘        │ │
│  └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

## Enabling

```json
{
  "flux_apps": {
    "argo-workflows": true
  }
}
```

## Workflow Template Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: hello-world-
  namespace: argo
spec:
  entrypoint: whalesay
  templates:
    - name: whalesay
      container:
        image: docker/whalesay
        command: [cowsay]
        args: ["Hello from Argo!"]
```

## DAG Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-pipeline-
  namespace: argo
spec:
  entrypoint: pipeline
  templates:
    - name: pipeline
      dag:
        tasks:
          - name: build
            template: run-step
            arguments: { parameters: [{ name: step, value: "build" }] }
          - name: test
            template: run-step
            dependencies: [build]
            arguments: { parameters: [{ name: step, value: "test" }] }
          - name: deploy
            template: run-step
            dependencies: [test]
            arguments: { parameters: [{ name: step, value: "deploy" }] }
    - name: run-step
      inputs:
        parameters: [{ name: step }]
      container:
        image: alpine
        command: [echo]
        args: ["Running {{inputs.parameters.step}}"]
```

## UI Features

The Argo Workflows UI at [argo.localhost](https://argo.localhost) provides:

- Workflow list with status filtering and search
- Real-time DAG visualization with node status
- Pod logs and artifact viewing per step
- Workflow submission and resubmission
- Cron workflow management

## Comparison with Airflow

| Feature | Argo Workflows | Airflow |
|---------|---------------|---------|
| **Runtime** | Container-native (K8s pods) | Python processes |
| **Definition** | YAML CRDs | Python DAGs |
| **Scaling** | Horizontal via K8s | Celery/K8s executor |
| **Isolation** | Full container isolation | Shared Python env |
| **Use Case** | CI/CD, ML pipelines, data eng | Data pipelines, ETL |

## Related Services

| Service | Relationship |
|---------|-------------|
| **Prometheus** | Scrapes workflow controller metrics |
| **Grafana** | Visualizes workflow execution metrics |
| **LocalStack** | Can serve as S3-compatible artifact storage |

## Troubleshooting

```bash
# Check Argo pods
kubectl get pods -n argo

# View workflow controller logs
kubectl logs -n argo -l app.kubernetes.io/name=argo-workflows-workflow-controller --tail=50

# Check HelmRelease status
kubectl get helmrelease -n argo

# List workflows
kubectl get workflows -n argo

# View a specific workflow status
kubectl get workflow <name> -n argo -o yaml

# Submit a workflow
argo submit -n argo workflow.yaml --watch

# List cron workflows
kubectl get cronworkflows -n argo
```
