# Azure Storage Resources

Azure storage infrastructure resources for local development, providing Azure File CSI StorageClass and PersistentVolumeClaims that emulate Azure storage for applications that depend on Azure-backed volumes.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `app` (PVC) / cluster-scoped (StorageClass) |
| **Type** | Storage Infrastructure |
| **Default** | Disabled |
| **Config Key** | `raw_apps.azure` |
| **Deployment** | Raw Manifests (Kustomize) |

## Official Documentation

- [Azure Files CSI Driver](https://learn.microsoft.com/en-us/azure/aks/azure-files-csi)
- [Kubernetes Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Persistent Volume Claims](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

## Resources Created

### StorageClass: `app-sc-batches`

```yaml
provisioner: file.csi.azure.com
parameters:
  skuName: Standard_LRS
allowVolumeExpansion: true
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - mfsymlinks
```

### PVC: `app-pvc-batches`

| Property | Value |
|----------|-------|
| **Size** | 2Gi |
| **Access Mode** | ReadWriteMany |
| **StorageClass** | app-sc-batches |

## Use Cases

- Applications that need Azure File-compatible storage volumes
- Batch processing workloads requiring shared storage
- Testing Azure-specific storage configurations locally

## Enabling

```json
{
  "raw_apps": {
    "azure": true
  }
}
```

> **Note**: The Azure Files CSI driver must be available in your cluster for the StorageClass to function. In local development, this may require Azurite or a compatible CSI driver.
