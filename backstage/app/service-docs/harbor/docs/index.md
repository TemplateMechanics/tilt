# Harbor Registry

Harbor is a cloud-native container registry with vulnerability scanning, access control, and image replication.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `harbor` |
| **Type** | Container Registry |
| **Default** | Disabled |
| **Config Key** | `crossplane_apps.harbor` |
| **Portal** | [harbor.localhost](https://harbor.localhost) |
| **Deployment** | Crossplane DevApplication |


## Official Documentation

- [Harbor Documentation](https://goharbor.io/docs/)
- [Harbor API Reference](https://editor.swagger.io/?url=https://raw.githubusercontent.com/goharbor/harbor/main/api/v2.0/swagger.yaml)
- [Harbor Helm Chart](https://github.com/goharbor/harbor-helm)
- [Vulnerability Scanning](https://goharbor.io/docs/latest/administration/vulnerability-scanning/)

## Architecture

```
┌─────────────────────────────────────────┐
│              Harbor System              │
│                                         │
│  ┌──────────┐  ┌────────────────────┐  │
│  │   Core   │  │      Trivy         │  │
│  │  (API)   │  │  (vulnerability    │  │
│  │  :8080   │  │   scanner)         │  │
│  └──────────┘  └────────────────────┘  │
│                                         │
│  ┌──────────┐  ┌────────────────────┐  │
│  │ Registry │  │    PostgreSQL      │  │
│  │ (storage)│  │    (metadata)      │  │
│  └──────────┘  └────────────────────┘  │
│                                         │
│  ┌──────────┐  ┌────────────────────┐  │
│  │  Redis   │  │   Job Service      │  │
│  │ (cache)  │  │   (async tasks)    │  │
│  └──────────┘  └────────────────────┘  │
└─────────────────────────────────────────┘
```

## Components

| Component | Description |
|-----------|-------------|
| **Core** | Main API server and web portal |
| **Trivy** | Container image vulnerability scanner |
| **Registry** | Docker distribution storage backend |
| **PostgreSQL** | Metadata database |
| **Redis** | Session cache and job queue |
| **Job Service** | Asynchronous task processing |

## Enabling

```json
{
  "crossplane_apps": {
    "harbor": true
  }
}
```

## Accessing

- **Portal**: [https://harbor.localhost](https://harbor.localhost)
- **Default credentials**: `admin` / `Harbor12345`
- **Registry**: `harbor.localhost`

## Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Harbor Portal | `admin` | `Harbor12345` |

## Pushing Images

```bash
# Login
docker login harbor.localhost -u admin -p Harbor12345

# Tag and push
docker tag my-image:latest harbor.localhost/library/my-image:latest
docker push harbor.localhost/library/my-image:latest
```

## Provided APIs

| API | Type | Description |
|-----|------|-------------|
| `harbor-api` | REST | Project, repository, and artifact management |

## Dependencies

- `resource:harbor-postgresql` — Metadata database
- `resource:harbor-redis` — Cache and job queue

## Troubleshooting

```bash
# Check Harbor components
kubectl get pods -n harbor

# Core API logs
kubectl logs -n harbor -l component=core --tail=50

# Trivy scanner logs
kubectl logs -n harbor -l component=trivy --tail=50

# Test registry connectivity
curl -u admin:Harbor12345 https://harbor.localhost/api/v2.0/projects
```
