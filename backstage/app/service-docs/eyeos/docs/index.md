# eyeOS (iOS VM)

Experimental iOS/iPadOS environment on Kubernetes using Docker-eyeOS, enabling real iOS (not simulator) for UI testing, automation, and Safari mobile testing.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `eyeos` |
| **Type** | Virtual Machine (Experimental) |
| **Default** | Disabled |
| **Config Key** | `raw_apps.eyeos` |
| **Deployment** | Raw Manifests (Kustomize) |
| **URL** | [eyeos.localhost](http://eyeos.localhost) (noVNC Web) |

## Official Documentation

- [Docker-eyeOS](https://github.com/sickcodes/Docker-eyeOS)
- [KubeVirt User Guide](https://kubevirt.io/user-guide/)

## Deployment Approaches

### KubeVirt VM (Recommended)

Uses a KubeVirt VirtualMachine CR with:
- q35 machine type with UEFI boot
- 4 CPU cores, 4Gi RAM
- System disk PVC (64Gi)

### Docker-eyeOS Container (Legacy)

Uses `sickcodes/docker-eyeos:latest` with:
- iPhone 14 Pro model (`iPhone15,2`), iOS 17
- Privileged StatefulSet with hostNetwork
- VNC on port 5900, noVNC web on port 6080
- SSH on port 2222, WebDAV on port 8080
- iOS debug on port 9221
- Jailbreak toggle and audio support

## Resource Requirements

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 4 | 8 |
| Memory | 4Gi | 8Gi |

## Exposed Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 5900 | VNC | Native VNC client access |
| 6080 | HTTP | noVNC web interface |
| 2222 | SSH | Shell access |
| 8080 | HTTP | WebDAV file transfer |
| 9221 | TCP | iOS debugging |

## Requirements

> **Warning**: Requires Linux host with KVM support. Does **NOT** work on Docker Desktop for Mac/Windows.

- Linux host with KVM (`/dev/kvm`)
- KubeVirt operator installed (for VM approach)
- Slow startup: probe allows 40 retries for iOS boot

## Enabling

```json
{
  "raw_apps": {
    "eyeos": true
  }
}
```

Requires KubeVirt to be enabled:
```json
{
  "raw_apps": {
    "kubevirt": true,
    "eyeos": true
  }
}
```

## Use Cases

- iOS Safari mobile testing
- iOS UI automation testing
- iOS app development/debugging
- Cross-platform responsive design testing
