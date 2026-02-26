# KubeVirt

KubeVirt is a CNCF graduated project that extends Kubernetes with virtualization capabilities, enabling you to run Virtual Machines alongside containers using KVM/QEMU.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `kubevirt` |
| **Type** | VM Operator |
| **Default** | Disabled |
| **Config Key** | `raw_apps.kubevirt` |
| **Deployment** | Raw Manifests (Kustomize) |
| **Version** | v1.3.1 |

## Official Documentation

- [KubeVirt User Guide](https://kubevirt.io/user-guide/)
- [KubeVirt API Reference](https://kubevirt.io/api-reference/)
- [VirtualMachine CRD](https://kubevirt.io/user-guide/virtual_machines/virtual_machine_instances/)
- [GitHub Repository](https://github.com/kubevirt/kubevirt)

## Architecture

```
┌──────────────────────────────────────────┐
│           KubeVirt Operator              │
│  (virt-operator v1.3.1)                  │
└─────────────┬────────────────────────────┘
              │ manages
┌─────────────▼────────────────────────────┐
│           KubeVirt CR                    │
│  ┌──────────────┐  ┌─────────────────┐   │
│  │ virt-api      │  │ virt-controller │   │
│  │ (API Server)  │  │ (VM Lifecycle)  │   │
│  └──────────────┘  └─────────────────┘   │
│  ┌──────────────┐                        │
│  │ virt-handler  │ (per-node DaemonSet)  │
│  │ (KVM/QEMU)   │                       │
│  └──────────────┘                        │
└──────────────────────────────────────────┘
```

## Feature Gates

The following feature gates are enabled:

| Feature | Description |
|---------|-------------|
| **LiveMigration** | Live migrate VMs between nodes |
| **Snapshot** | VM snapshot and restore |
| **HotplugVolumes** | Hot-add volumes to running VMs |
| **ExpandDisks** | Online disk expansion |
| **Sidecar** | Sidecar container injection |
| **GPU** | GPU passthrough |
| **HostDevices** | Host device passthrough |

## Requirements

> **Warning**: KubeVirt requires a Linux host with KVM support (`/dev/kvm`). It does **NOT** work on Docker Desktop for Mac/Windows. Use emulation mode for testing only.

- Linux host with KVM enabled
- Nested virtualization support (if running in a VM)
- `useEmulation: true` is enabled for environments without hardware virtualization

## Enabling

```json
{
  "raw_apps": {
    "kubevirt": true
  }
}
```

## Related Services

- **macOS**: macOS VM running via KubeVirt
- **eyeOS**: iOS VM running via KubeVirt
