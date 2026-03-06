# Architecture

## Overview

This workspace demonstrates **three deployment patterns**, with configuration stored in a K8s ConfigMap and a Backstage-powered control plane.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          BACKSTAGE DEVELOPER PORTAL                         │
│                         https://backstage.localhost                          │
│  ┌──────────────────────┐  ┌────────────────────────────────────────────┐   │
│  │  Service Catalog      │  │  Infrastructure Dashboard                 │   │
│  │  (catalog entities)   │  │  (toggle services on/off per category)    │   │
│  └──────────┬───────────┘  └──────────────────┬─────────────────────────┘   │
│             │                                  │                             │
│  ┌──────────┴──────────────────────────────────┴─────────────────────────┐  │
│  │                     Tilt Plugin (TiltClient)                          │  │
│  │               uses Backstage proxy → in-cluster routing               │  │
│  └──────────┬──────────────────────────────────┬─────────────────────────┘  │
└─────────────┼──────────────────────────────────┼────────────────────────────┘
              │ (browser → host:10350)           │ (proxy → K8s Service)
     ┌────────▼────────┐              ┌──────────▼──────────┐
     │  Tilt API        │              │  Config Server Pod   │
     │  :10350 (host)   │              │  tilt-system ns      │
     │  (runtime ctrl)  │              │  (K8s API backend)   │
     └─────────────────┘              └──────────┬───────────┘
                                                 │ reads/writes
                                        ┌────────▼────────┐
                                        │  ConfigMap       │
                                        │  tilt-config     │
                                        │  (tilt-system)   │
                                        └────────┬────────┘
                                                 │ sync loop (host)
                                        ┌────────▼────────┐
                                        │ tilt-config.json │
                                        │  (watch_file)    │
                                        └────────┬────────┘
                                                 │ auto-reload
┌────────────────────────────────────────────────▼────────────────────────────┐
│                                  TILTFILE                                   │
│                     (Development Workflow Orchestration)                    │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │   CROSSPLANE    │  │      FLUX       │  │  RAW MANIFESTS  │             │
│  │  DevApplication │  │   HelmRelease   │  │   (Kustomize)   │             │
│  │       XRD       │  │                 │  │                 │             │
│  ├─────────────────┤  ├─────────────────┤  ├─────────────────┤             │
│  │ harbor          │  │ ollama          │  │ backstage       │             │
│  │ jenkins         │  │ kyverno         │  │ mongodb         │             │
│  │ langfuse        │  │ falco           │  │ postgresql      │             │
│  │ qdrant          │  │ keda            │  │ redis           │             │
│  │ localstack      │  │ velero          │  │ rabbitmq        │             │
│  │                 │  │ cert-manager    │  │ mssql           │             │
│  │                 │  │ 1pass           │  │ keycloak        │             │
│  │                 │  │ policy-reporter │  │ airflow         │             │
│  │                 │  │                 │  │ wordpress ...   │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow: Toggling a Service via Backstage

1. Developer clicks toggle in Backstage Infrastructure Dashboard
2. Frontend calls `PATCH /api/proxy/tilt-config/config` through the Backstage backend
3. Backstage proxy routes to `tilt-config-server.tilt-system.svc:10351` (in-cluster)
4. Config server writes the change to the `tilt-config` ConfigMap via K8s API
5. Sync loop on host detects the ConfigMap change (polls every 3s)
6. Sync loop writes updated config to `tilt-config.json`
7. Tilt's `watch_file()` detects the change and triggers a reload
8. Tilt re-evaluates the config and deploys/removes the service

## Deployment Patterns

### Pattern 1: Crossplane DevApplication (XRD)

**Best for**: Services needing sub-resource management (projects, jobs, credentials)

- Creates Namespace, HelmRelease, IngressRoute, ServiceMonitor
- Supports additional XRDs (e.g., HarborProject for managing repos)
- Location: `apps/*.yaml`

### Pattern 2: Flux HelmRelease

**Best for**: External Helm charts with GitOps reconciliation

- Uses Flux to manage Helm lifecycle
- Declarative chart versions and values
- Location: `helm/<service>/helm-release.yaml`

### Pattern 3: Raw Manifests

**Best for**: Simple deployments using official images (no Helm complexity)

- Direct Kubernetes manifests via Kustomize
- Uses official Docker images (no Bitnami)
- Location: `helm/<service>/*.yaml`

## Config Server

The config server runs as a K8s Deployment in the `tilt-system` namespace. It reads and writes the `tilt-config` ConfigMap via the K8s API using a ServiceAccount with scoped RBAC.

**Access paths:**

- **From Backstage** — Routed via the Backstage proxy plugin (`/api/proxy/tilt-config/...`)
- **Direct (Traefik)** — `http://tilt-config.localhost/config`
- **Port-forward** — `kubectl port-forward -n tilt-system svc/tilt-config-server 10351:10351`

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/config` | Read full config |
| `GET` | `/config/{group}` | Read one group (`crossplane_apps`, `flux_apps`, `raw_apps`) |
| `PATCH` | `/config` | Merge partial updates (toggle individual services) |
| `PUT` | `/config` | Replace entire config |
| `GET` | `/health` | Health check |

## Tilt Resource Dependency Chain

```
flux-install
  └── helm-repositories
        └── crossplane-core-ready
              └── crossplane-providers
                    └── crossplane-compositions
                          └── [crossplane apps]

dev-certificate-generate
  └── dev-certificate-trust
        └── dev-certificate-install

traefik (always-on)
prometheus, loki, tempo (always-on observability)
```
