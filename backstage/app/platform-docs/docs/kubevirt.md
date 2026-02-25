# KubeVirt — Virtual Machines on Kubernetes

KubeVirt extends Kubernetes by adding support for running Virtual Machines alongside containers.

## What is KubeVirt?

- CNCF graduated project
- Runs VMs as Kubernetes-native resources
- Uses `VirtualMachine` and `VirtualMachineInstance` CRDs
- Leverages KVM for virtualization

## Prerequisites

### Linux Host Requirements

KubeVirt requires hardware virtualization:

```bash
# Check for KVM support
ls /dev/kvm

# Check CPU flags
grep -E 'vmx|svm' /proc/cpuinfo
```

### Platform Support

| Platform | Works |
|----------|-------|
| Linux bare metal (Intel VT-x / AMD-V) | ✅ |
| Linux VMs with nested virtualization | ✅ |
| Cloud VMs (GCP, Azure, some AWS) | ✅ |
| Kind/K3s on Linux with KVM | ✅ |
| Docker Desktop (Mac/Windows) | ❌ |
| Minikube on Mac/Windows | ❌ |

!!! warning
    KubeVirt **will not work on Docker Desktop for Mac** because there is no KVM support. Docker Desktop uses HyperKit/Apple Hypervisor which does not expose `/dev/kvm`.

## Architecture

```
┌─────────────────────────────────────────────┐
│                  Kubernetes                  │
├─────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────────┐ │
│  │  Pod    │  │  Pod    │  │ VirtualMachine│ │
│  │(container)│(container)│ │    (VM)      │ │
│  └─────────┘  └─────────┘  └─────────────┘ │
├─────────────────────────────────────────────┤
│              KubeVirt Operator               │
│  virt-api | virt-controller | virt-handler  │
├─────────────────────────────────────────────┤
│                   KVM/QEMU                   │
└─────────────────────────────────────────────┘
```

## Components

| Component | Description |
|-----------|-------------|
| **virt-operator** | Manages KubeVirt installation lifecycle |
| **virt-api** | Handles KubeVirt API extensions |
| **virt-controller** | Manages VM lifecycle and scheduling |
| **virt-handler** | DaemonSet on each node with KVM access |

## Usage

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: my-vm
spec:
  running: true
  template:
    spec:
      domain:
        devices:
          disks:
          - disk:
              bus: virtio
            name: containerdisk
        resources:
          requests:
            memory: 1Gi
      volumes:
      - containerDisk:
          image: quay.io/kubevirt/cirros-container-disk-demo
        name: containerdisk
```

## virtctl CLI

```bash
# macOS
brew install kubevirt/kubevirt/virtctl

# Linux
VERSION=$(kubectl get kubevirt.kubevirt.io/kubevirt -n kubevirt \
  -o=jsonpath="{.status.observedKubeVirtVersion}")
curl -L -o virtctl \
  https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-linux-amd64
chmod +x virtctl && sudo mv virtctl /usr/local/bin/
```

### Commands

```bash
virtctl start <vm>        # Start a VM
virtctl stop <vm>         # Stop a VM
virtctl restart <vm>      # Restart a VM
virtctl console <vm>      # Serial console
virtctl vnc <vm>          # VNC access
virtctl ssh <vm>          # SSH (if configured)
```

## Related

- See [macOS VMs](macos-vms.md) for running macOS on KubeVirt
- See [iOS / eyeOS](eyeos.md) for running iOS on KubeVirt

## Resources

- [KubeVirt.io](https://kubevirt.io/)
- [KubeVirt GitHub](https://github.com/kubevirt/kubevirt)
- [User Guide](https://kubevirt.io/user-guide/)
- [API Reference](https://kubevirt.io/api-reference/)
