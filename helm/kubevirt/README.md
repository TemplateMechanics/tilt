# KubeVirt - Virtual Machines on Kubernetes

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

### macOS/Docker Desktop Limitations

⚠️ **KubeVirt will NOT work on Docker Desktop for Mac** because:
1. No KVM support (Docker Desktop uses HyperKit/Apple Hypervisor)
2. No nested virtualization
3. /dev/kvm not available

### Where KubeVirt Works

- ✅ Linux bare metal with Intel VT-x or AMD-V
- ✅ Linux VMs with nested virtualization enabled
- ✅ Cloud VMs with nested virtualization (GCP, Azure, some AWS)
- ✅ Kind/K3s on Linux with KVM
- ❌ Docker Desktop (Mac/Windows)
- ❌ Minikube on Mac/Windows (unless Linux VM with nested virt)

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

1. **virt-operator** - Manages KubeVirt installation lifecycle
2. **virt-api** - Handles KubeVirt API extensions
3. **virt-controller** - Manages VM lifecycle and scheduling
4. **virt-handler** - DaemonSet running on each node with KVM

## Installation

This kustomization installs:
1. KubeVirt operator (manages the installation)
2. KubeVirt CR (triggers operator to install components)

## Usage

Once installed, you can create VMs like this:

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

Install the virtctl CLI for VM management:

```bash
# macOS
brew install kubevirt/kubevirt/virtctl

# Linux
VERSION=$(kubectl get kubevirt.kubevirt.io/kubevirt -n kubevirt -o=jsonpath="{.status.observedKubeVirtVersion}")
curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-linux-amd64
chmod +x virtctl && sudo mv virtctl /usr/local/bin/
```

Commands:
```bash
virtctl start <vm>        # Start a VM
virtctl stop <vm>         # Stop a VM
virtctl restart <vm>      # Restart a VM
virtctl console <vm>      # Serial console
virtctl vnc <vm>          # VNC access
virtctl ssh <vm>          # SSH (if configured)
```

## macOS/iOS VMs

For macOS/iOS VMs, you need:
1. Legal compliance (Apple hardware for macOS)
2. OSX-KVM or Docker-OSX disk images
3. Proper passthrough configuration

See `helm/macos/` and `helm/eyeos/` for Kubernetes VM definitions.

## Resources

- [KubeVirt.io](https://kubevirt.io/)
- [KubeVirt GitHub](https://github.com/kubevirt/kubevirt)
- [User Guide](https://kubevirt.io/user-guide/)
- [API Reference](https://kubevirt.io/api-reference/)
