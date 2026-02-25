# Velero

Velero provides backup and disaster recovery capabilities for Kubernetes clusters.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `velero` |
| **Type** | Backup & DR |
| **Default** | Disabled |
| **Config Key** | `flux_apps.velero` |
| **Deployment** | Flux HelmRelease |


## Official Documentation

- [Velero Documentation](https://velero.io/docs/)
- [Backup Reference](https://velero.io/docs/main/backup-reference/)
- [Restore Reference](https://velero.io/docs/main/restore-reference/)
- [Troubleshooting](https://velero.io/docs/main/troubleshooting/)

## Purpose

Velero lets you back up and restore your Kubernetes cluster resources and persistent volumes. In a dev environment, it's useful for:

- Snapshotting a known-good state
- Recovering from failed experiments
- Migrating workloads between clusters

## Enabling

```json
{
  "flux_apps": {
    "velero": true
  }
}
```

## Usage

### Create a Backup

```bash
velero backup create my-backup --include-namespaces=airflow,keycloak
```

### Restore from Backup

```bash
velero restore create --from-backup my-backup
```

### Schedule Regular Backups

```bash
velero schedule create daily --schedule="0 2 * * *" --ttl 72h
```

### List Backups

```bash
velero backup get
velero restore get
```

## Storage

In the dev environment, Velero stores backups locally using an emulated object store (MinIO or local path). For production, configure cloud storage (S3, GCS, Azure Blob).

## Troubleshooting

```bash
# Check Velero status
velero get backup-locations
kubectl logs -n velero -l app.kubernetes.io/name=velero

# Debug a failed backup
velero backup describe my-backup --details
velero backup logs my-backup
```
