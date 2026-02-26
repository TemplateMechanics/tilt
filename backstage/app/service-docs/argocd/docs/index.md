# Argo CD

Argo CD is a declarative, GitOps-based continuous delivery tool for Kubernetes. It continuously monitors your Git repositories and automatically syncs the desired application state to your cluster.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `argocd` |
| **Type** | GitOps CD Platform |
| **Default** | Disabled |
| **Config Key** | `flux_apps.argocd` |
| **Deployment** | Flux HelmRelease |
| **Chart** | `argo-cd` v7.7.5 from argoproj.github.io |
| **Dashboard** | [argocd.localhost](https://argocd.localhost) |

## Official Documentation

- [Argo CD Docs](https://argo-cd.readthedocs.io/)
- [Argo CD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [Application CRD](https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/)
- [Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                  Argo CD Server                      │
│                argocd.localhost:443                   │
│  ┌─────────────┐  ┌────────────┐  ┌──────────────┐  │
│  │  API Server  │  │    UI      │  │  Dex (SSO)   │  │
│  │  (gRPC/REST) │  │  (React)   │  │  (disabled)  │  │
│  └──────┬───────┘  └────────────┘  └──────────────┘  │
│         │                                            │
│  ┌──────▼────────────────────────────────────────┐   │
│  │          Application Controller                │   │
│  │  (Watches Git repos, reconciles state)         │   │
│  └──────┬────────────────────────────────────────┘   │
│         │                                            │
│  ┌──────▼────────────────────────────────────────┐   │
│  │            Repo Server                         │   │
│  │  (Generates K8s manifests from Git)            │   │
│  └──────┬────────────────────────────────────────┘   │
│         │                                            │
│  ┌──────▼────────────────────────────────────────┐   │
│  │            Redis (Cache)                       │   │
│  └───────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
         │                    │
    ┌────▼────┐         ┌────▼────────┐
    │ Git Repo │         │ K8s Cluster │
    │ (Source) │         │ (Target)    │
    └─────────┘         └─────────────┘
```

## Components

| Component | Purpose |
|-----------|---------|
| **Server** | API server + UI, handles authentication and RBAC |
| **Controller** | Monitors applications, detects drift, reconciles state |
| **Repo Server** | Clones Git repos, generates manifests (Helm, Kustomize, plain YAML) |
| **ApplicationSet** | Manages multiple applications from templates |
| **Redis** | In-memory cache for repo and cluster state |

## Configuration

Key settings in this deployment:

```yaml
configs:
  params:
    server.insecure: true        # TLS handled by Traefik
  cm:
    admin.enabled: "true"        # Admin user enabled
    exec.enabled: "true"         # Pod exec from UI
```

## Access

1. Visit [https://argocd.localhost](https://argocd.localhost)
2. Default username: `admin`
3. Get the initial password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

## Enabling

```json
{
  "flux_apps": {
    "argocd": true
  }
}
```

## Argo CD vs Argo Workflows

| Feature | Argo CD | Argo Workflows |
|---------|---------|----------------|
| **Purpose** | Continuous Delivery (GitOps) | Workflow Orchestration |
| **What it does** | Syncs Git → Cluster | Runs DAG/step workflows |
| **CRD** | Application, AppProject | Workflow, CronWorkflow |
| **Use case** | Deploy apps automatically | CI pipelines, data processing |

Both can be enabled independently. Together they provide a complete CI/CD platform:
- **Argo Workflows**: Build, test, and create artifacts
- **Argo CD**: Deploy those artifacts to Kubernetes

## Monitoring

Metrics are exposed on `/metrics` endpoints for:
- Server (API request rates, sync durations)
- Controller (reconciliation counts, app health)
- Repo Server (git request rates, cache hits)
- ApplicationSet (generation counts)

A ServiceMonitor and Grafana dashboard are included for observability.
