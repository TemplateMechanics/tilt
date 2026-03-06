# macOS VM

Experimental macOS virtual machine on Kubernetes, supporting two deployment approaches: KubeVirt VM (recommended) and Docker-OSX container (legacy).

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `macos` |
| **Type** | Virtual Machine (Experimental) |
| **Default** | Disabled |
| **Config Key** | `raw_apps.macos` |
| **Deployment** | Raw Manifests (Kustomize) |
| **URL** | [macos.localhost](http://macos.localhost) (Web VNC) |

## Official Documentation

- [Docker-OSX](https://github.com/sickcodes/Docker-OSX)
- [KubeVirt User Guide](https://kubevirt.io/user-guide/)
- [macOS Virtualization Guide](https://github.com/sickcodes/Docker-OSX#kubernetes)

## Deployment Approaches

### KubeVirt VM (Recommended)

Uses a KubeVirt VirtualMachine CR with:
- q35 machine type with UEFI boot
- 4 CPU cores, 8Gi RAM
- `host-passthrough` CPU model
- System disk PVC (100Gi) + Data disk PVC (50Gi)

### Docker-OSX Container (Legacy)

Uses `sickcodes/docker-osx:ventura` with:
- Privileged StatefulSet with hostNetwork
- KVM device mount required (`/dev/kvm`)
- VNC on port 5900, Web-VNC on port 5800, SSH on port 10022
- 4 SMP cores, 8GB RAM

## Resource Requirements

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 4 | 8 |
| Memory | 8Gi | 16Gi |

## Requirements

> **Warning**: Requires Linux host with KVM support. Does **NOT** work on Docker Desktop for Mac/Windows.

- Linux host with KVM (`/dev/kvm`)
- KubeVirt operator installed (for VM approach)
- Nested virtualization (if running in a VM)

## Enabling

```json
{
  "raw_apps": {
    "macos": true
  }
}
```

Requires KubeVirt to be enabled:
```json
{
  "raw_apps": {
    "kubevirt": true,
    "macos": true
  }
}
```
