# Tilt + Crossplane Integration Architecture

## Overview

This setup uses Tilt for development workflow orchestration and Crossplane for declarative resource management.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                 TILT                                        │
│  (Development Workflow Orchestration)                                       │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │    Flux     │───▶│  Crossplane │───▶│   Harbor    │───▶│  Harbor     │  │
│  │   (GitOps)  │    │    (IaC)    │    │   XRD       │    │  Projects   │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│         │                 │                   │                  │          │
│         ▼                 ▼                   ▼                  ▼          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │ HelmRepos   │    │  Providers  │    │ DevApps     │    │ HarborProj  │  │
│  │ (repos)     │    │ (k8s, helm) │    │ (claims)    │    │ (claims)    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              KUBERNETES                                     │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                         CROSSPLANE                                    │  │
│  │                                                                       │  │
│  │  XRD: DevApplication ──────┬──▶ Namespace                            │  │
│  │                            ├──▶ HelmRelease                          │  │
│  │                            ├──▶ IngressRoute                         │  │
│  │                            └──▶ ServiceMonitor                       │  │
│  │                                                                       │  │
│  │  XRD: HarborProject ───────┬──▶ ConfigMap                            │  │
│  │                            └──▶ Job (API call)                       │  │
│  │                                                                       │  │
│  │  (Future XRDs)                                                        │  │
│  │  XRD: JenkinsJob ──────────┬──▶ ConfigMap (job-dsl)                  │  │
│  │                            └──▶ Job (create via API)                 │  │
│  │                                                                       │  │
│  │  XRD: PostgresDatabase ────┬──▶ Secret (credentials)                 │  │
│  │                            └──▶ Job (CREATE DATABASE)                │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │   Harbor    │  │   Jenkins   │  │   Qdrant    │  │  Langfuse   │       │
│  │  (registry) │  │    (CI)     │  │  (vectors)  │  │  (observ)   │       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Deployment Flow

1. **Tilt starts** and applies resources in dependency order
2. **Flux HelmRepositories** are created first
3. **Crossplane core** is deployed via Flux HelmRelease
4. **Crossplane providers** (kubernetes, helm) are installed
5. **Provider configs** are applied once providers are healthy
6. **Base compositions** (DevApplication XRD) are created
7. **Service-specific compositions** (HarborProject XRD) are created
8. **DevApplication claims** deploy the actual services
9. **Service resource claims** (HarborProject) configure the services

## File Structure

```
helm/crossplane/
├── kustomization.yaml          # Crossplane core install
├── helm-release.yaml
├── providers/
│   ├── providers.yaml          # provider-kubernetes, provider-helm
│   └── configs/
│       ├── rbac.yaml           # RBAC for providers
│       └── provider-configs.yaml
└── compositions/
    ├── xrd.yaml                # DevApplication XRD
    ├── composition.yaml        # DevApplication composition
    └── harbor/
        ├── xrd-project.yaml    # HarborProject XRD
        └── composition-project.yaml

apps/
├── kustomization.yaml
├── harbor.yaml                 # DevApplication claim
├── jenkins.yaml
├── langfuse.yaml
└── harbor-resources/
    ├── kustomization.yaml
    └── projects.yaml           # HarborProject claims
```

## Adding New Service Resources

### Example: Adding a Jenkins Job via Crossplane

1. Create XRD in `helm/crossplane/compositions/jenkins/xrd-job.yaml`
2. Create Composition in `helm/crossplane/compositions/jenkins/composition-job.yaml`
3. Add kustomization to include in Tiltfile
4. Create claims in `apps/jenkins-resources/jobs.yaml`

### Example: Adding a Postgres Database

1. Create XRD: `PostgresDatabase`
2. Composition creates:
   - Secret with credentials
   - Job that runs `CREATE DATABASE`
3. Claim in `apps/postgres-resources/databases.yaml`

## Benefits

- **Declarative**: All resources defined as YAML, tracked in Git
- **Composable**: XRDs can be composed for complex resources
- **Portable**: Same patterns work across environments
- **Observable**: Crossplane shows resource status in kubectl/Headlamp
- **Recoverable**: Delete namespace, Crossplane recreates everything
