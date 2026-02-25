# Backstage

Backstage is the developer portal and service catalog for the dev platform, providing a unified interface for documentation, service discovery, and software templates.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `backstage` |
| **Type** | Developer Portal |
| **Default** | Disabled |
| **Config Key** | `raw_apps.backstage` |
| **Portal** | [backstage.localhost](https://backstage.localhost) |
| **Deployment** | Kustomize (raw manifests) |


## Official Documentation

- [Backstage Documentation](https://backstage.io/docs/overview/what-is-backstage)
- [Software Catalog](https://backstage.io/docs/features/software-catalog/)
- [TechDocs](https://backstage.io/docs/features/techdocs/)
- [Plugin Development](https://backstage.io/docs/plugins/)

## Enabling

```json
{
  "raw_apps": {
    "backstage": true
  }
}
```

## Accessing

- **Portal**: [https://backstage.localhost](https://backstage.localhost)
- **Authentication**: Guest mode (no login required)

## Dependencies

- `resource:backstage-postgresql` — Catalog and search index storage

## Features

### Service Catalog

Browse all dev platform services organized by:

- **Domains** — Infrastructure, Developer Tools, AI/ML, Data Platform
- **Systems** — Logical groupings (dev-environment, observability-stack, etc.)
- **Components** — Individual services with metadata, ownership, and dependencies
- **APIs** — Service interfaces with OpenAPI definitions
- **Resources** — Databases, caches, and storage

### TechDocs

Built-in documentation for every service, generated from Markdown + MkDocs.

- Browse at [backstage.localhost/docs](https://backstage.localhost/docs)
- Each service has its own documentation page
- Search across all docs

### Tilt Plugin

Custom plugin showing real-time Tilt resource status:

- Resource health and status
- Build/deploy timing
- Log streaming
- Configuration management via config server

### Software Templates

Scaffold new services using Backstage templates:

- Navigate to `/create`
- Choose a template
- Fill in parameters
- Get a ready-to-deploy service

## Architecture

```
┌──────────────────────────────┐
│       Backstage Portal       │
│                              │
│  ┌────────────────────────┐ │
│  │    Frontend (React)    │ │
│  │   - Catalog UI         │ │
│  │   - TechDocs Reader    │ │
│  │   - Tilt Plugin        │ │
│  └────────┬───────────────┘ │
│           │                  │
│  ┌────────▼───────────────┐ │
│  │   Backend (Node.js)    │ │
│  │   - Catalog API        │ │
│  │   - TechDocs Builder   │ │
│  │   - Proxy to Tilt      │ │
│  └────────┬───────────────┘ │
│           │                  │
│  ┌────────▼───────────────┐ │
│  │     PostgreSQL         │ │
│  └────────────────────────┘ │
└──────────────────────────────┘
```

## Troubleshooting

```bash
kubectl get pods -n backstage
kubectl logs -n backstage -l app=backstage --tail=100

# Check database connectivity
kubectl exec -n backstage deploy/backstage -- node -e "
  const { Client } = require('pg');
  const c = new Client({connectionString: process.env.POSTGRES_CONNECTION});
  c.connect().then(() => console.log('OK')).catch(console.error);
"

# Restart to pick up catalog changes
kubectl rollout restart deployment/backstage -n backstage
```
