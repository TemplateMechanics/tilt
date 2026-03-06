# macOS on Kubernetes - EXPERIMENTAL

⚠️ **WARNING: This is experimental and has significant limitations!**

## Two Approaches

This setup supports two different approaches to running macOS:

### 1. KubeVirt (Recommended)
Uses KubeVirt to run a proper macOS VM in Kubernetes.

**Files:**
- `virtualmachine.yaml` - KubeVirt VirtualMachine resource
- `pvc-kubevirt.yaml` - Persistent storage for VM disks

**Pros:**
- Proper VM with hardware virtualization
- Better macOS compatibility
- Full KVM acceleration
- Can run Xcode, full development environment

**Cons:**
- Requires KubeVirt installation
- Requires Linux host with KVM
- More setup complexity

### 2. Docker-OSX (Legacy/Alternative)
Uses sickcodes/docker-osx container directly.

**Files:**
- `statefulset.yaml` - StatefulSet running Docker-OSX container
- `pvc.yaml` - Storage for container approach

**Pros:**
- Simpler setup
- Single container deployment

**Cons:**
- Requires privileged containers
- Requires hostNetwork
- Still needs KVM support

## Prerequisites

### Hardware Requirements
1. **KVM Support Required**
   - Linux host with KVM enabled
   - Check: `ls /dev/kvm` should exist
   - Enable: `sudo modprobe kvm_intel` (or `kvm_amd`)

2. **Resources**
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
- Apple's EULA requires macOS on Apple hardware
- Use only for educational/testing purposes
- Consider legal implications for your use case

## Installation

### With KubeVirt (Recommended)

1. First, install KubeVirt:
   ```bash
   # Enable kubevirt in your Tiltfile CONFIG
   # Deploy: tilt up kubevirt
   ```

2. Prepare a macOS disk image:
   ```bash
   # Option A: Use OSX-KVM to create an image
   # https://github.com/kholia/OSX-KVM
   
   # Option B: Convert existing macOS installation
   # qemu-img convert -O qcow2 input.vmdk macos.qcow2
   ```

3. Upload the disk image to the PVC (requires virtctl):
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

### With Docker-OSX (Legacy)

1. Edit `kustomization.yaml` to use the statefulset approach
2. Ensure your node has KVM support
3. Deploy: `tilt up macos`

## Access

### VNC Access
- **URL**: https://macos.localhost (via ingress)
- **Direct**: `virtctl vnc macos-vm -n macos`
- **Port**: 5900

### SSH Access (after setup)
```bash
# Via virtctl
virtctl ssh user@macos-vm -n macos

# Direct (if exposed)
ssh user@macos.localhost -p 10022
```

### Console Access
```bash
virtctl console macos-vm -n macos
```

## Configuration

### KubeVirt VM Settings

Edit `virtualmachine.yaml` to customize:

- **CPU**: Adjust `spec.template.spec.domain.cpu.cores`
- **Memory**: Adjust `spec.template.spec.domain.memory.guest`
- **Disk Size**: Adjust PVC sizes in `pvc-kubevirt.yaml`

### macOS Version

You'll need to prepare a disk image for your desired macOS version:
- Ventura (13.x) - Recommended
- Monterey (12.x)
- Big Sur (11.x)
- Catalina (10.15.x)

## Troubleshooting

### VM Won't Start

1. Check KubeVirt is installed:
   ```bash
   kubectl get kubevirt -n kubevirt
   ```

2. Check virt-handler has KVM access:
   ```bash
   kubectl logs -n kubevirt -l kubevirt.io=virt-handler
   ```

3. Check VMI status:
   ```bash
   kubectl get vmi -n macos
   kubectl describe vmi macos-vm -n macos
   ```

### No KVM Support

If you see "KVM not available" errors, KubeVirt is running in emulation mode:
- VMs will be very slow
- Check `useEmulation: true` in KubeVirt CR
- For production, ensure KVM is available

### Disk Image Issues

```bash
# Check disk image format
qemu-img info /path/to/macos.qcow2

# Convert if needed
qemu-img convert -O raw input.qcow2 output.raw
```

## Resources

- [KubeVirt Documentation](https://kubevirt.io/user-guide/)
- [OSX-KVM](https://github.com/kholia/OSX-KVM)
- [Docker-OSX](https://github.com/sickcodes/docker-osx)
- [virtctl Reference](https://kubevirt.io/user-guide/operations/virtctl_client_tool/)

## First Boot

⏰ **First boot takes 30-60 minutes** - macOS needs to install and configure

Monitor with: `kubectl logs -f statefulset/macos -n macos`

## iOS Development

For iOS development, you'll need:
1. Wait for macOS to fully boot
2. Access via VNC
3. Install Xcode from App Store (requires Apple ID)
4. Configure simulators

## Troubleshooting

**Pod won't start:**
- Check KVM: `kubectl exec -it macos-0 -n macos -- ls -la /dev/kvm`
- Check privileged: `kubectl describe pod macos-0 -n macos`

**Performance issues:**
- Increase CPU/RAM resources
- Use dedicated node with better CPU
- Nested virtualization is slow by nature

**Display issues:**
- Try different VNC client
- Adjust WIDTH/HEIGHT env vars
- Use noVNC web interface instead

## Alternative Images

sickcodes provides several variants:

- `sickcodes/docker-osx:auto` - Auto-detect and install latest
- `sickcodes/docker-osx:naked` - Barebones, bring your own .img
- `sickcodes/docker-osx:big-sur` - macOS 11
- `sickcodes/docker-osx:monterey` - macOS 12
- `sickcodes/docker-osx:ventura` - macOS 13

## Better Alternatives for CI/CD

For production iOS/macOS builds, consider:

1. **GitHub Actions** - macOS runners in cloud
2. **CircleCI** - Hosted macOS builds
3. **Mac mini cluster** - Real hardware with Jenkins/GitLab
4. **Tart/Anka** - Proper macOS virtualization on Mac hardware

## Resources

- Docker-OSX GitHub: https://github.com/sickcodes/Docker-OSX
- KVM Setup: https://help.ubuntu.com/community/KVM/Installation
