# macOS on Kubernetes — EXPERIMENTAL

!!! warning
    This is experimental and has significant limitations. Requires Linux host with KVM.

## Two Approaches

### 1. KubeVirt (Recommended)

Uses KubeVirt to run a proper macOS VM in Kubernetes.

| Pros | Cons |
|------|------|
| Proper VM with hardware virtualization | Requires KubeVirt installation |
| Better macOS compatibility | Requires Linux host with KVM |
| Full KVM acceleration | More setup complexity |
| Can run Xcode, full dev environment | |

### 2. Docker-OSX (Legacy)

Uses `sickcodes/docker-osx` container directly.

| Pros | Cons |
|------|------|
| Simpler setup | Requires privileged containers |
| Single container deployment | Requires hostNetwork |
| | Still needs KVM support |

## Prerequisites

### Hardware

- Linux host with KVM enabled (`ls /dev/kvm`)
- Minimum: 4 CPU cores, 8GB RAM
- Recommended: 8 CPU cores, 16GB RAM
- Storage: 100GB+ for macOS installation

### Platform Support

| Platform | KubeVirt | Docker-OSX |
|----------|----------|------------|
| Linux bare metal | ✅ | ✅ |
| Linux VM (nested virt) | ✅ | ✅ |
| Docker Desktop (Mac) | ❌ | ❌ |
| Docker Desktop (Win) | ❌ | ❌ |
| Minikube (Linux) | ✅ | ✅ |
| Kind (Linux) | ✅ | ⚠️ |

### Legal Compliance

Apple's EULA requires macOS to run on Apple hardware. Use only for educational/testing purposes.

## Installation (KubeVirt)

1. Install KubeVirt (see [KubeVirt guide](kubevirt.md))
2. Prepare a macOS disk image:
    ```bash
    # Option A: Use OSX-KVM
    # https://github.com/kholia/OSX-KVM

    # Option B: Convert existing macOS installation
    qemu-img convert -O qcow2 input.vmdk macos.qcow2
    ```
3. Upload the disk image:
    ```bash
    virtctl image-upload pvc macos-system-disk \
      --namespace macos \
      --image-path=/path/to/macos.qcow2 \
      --insecure
    ```
4. Deploy the VM:
    ```bash
    kubectl apply -f helm/macos/virtualmachine.yaml
    ```

## Access

### VNC

- **Ingress**: `https://macos.localhost`
- **Direct**: `virtctl vnc macos-vm -n macos`

### SSH

```bash
virtctl ssh user@macos-vm -n macos
# or
ssh user@macos.localhost -p 10022
```

### Console

```bash
virtctl console macos-vm -n macos
```

## Configuration

Edit `virtualmachine.yaml` to customize:

- **CPU**: `spec.template.spec.domain.cpu.cores`
- **Memory**: `spec.template.spec.domain.memory.guest`
- **Disk Size**: Adjust PVC sizes in `pvc-kubevirt.yaml`

### macOS Versions

Supported via disk images: Ventura (13.x), Monterey (12.x), Big Sur (11.x), Catalina (10.15.x)

## Troubleshooting

### VM Won't Start

```bash
kubectl get kubevirt -n kubevirt
kubectl logs -n kubevirt -l kubevirt.io=virt-handler
kubectl get vmi -n macos
kubectl describe vmi macos-vm -n macos
```

### No KVM Support

If KubeVirt falls to emulation mode, VMs will be very slow. Verify `/dev/kvm` is available on the host.

### Disk Image Issues

```bash
qemu-img info /path/to/macos.qcow2
qemu-img convert -O raw input.qcow2 output.raw
```

## First Boot

First boot takes **30–60 minutes** as macOS installs and configures.

## Alternatives for CI/CD

For production macOS builds, consider GitHub Actions, CircleCI, Mac mini clusters, or Tart/Anka.

## Resources

- [OSX-KVM](https://github.com/kholia/OSX-KVM)
- [Docker-OSX](https://github.com/sickcodes/docker-osx)
- [virtctl Reference](https://kubevirt.io/user-guide/operations/virtctl_client_tool/)
