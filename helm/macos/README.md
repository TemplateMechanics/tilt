# Docker-OSX on Kubernetes - EXPERIMENTAL

⚠️ **WARNING: This is experimental and has significant limitations!**

## Prerequisites

1. **KVM Support Required**
   - Linux host with KVM enabled
   - Check: `ls /dev/kvm` should exist
   - Enable: `sudo modprobe kvm_intel` (or `kvm_amd`)

2. **Privileged Containers**
   - Security risk - only use in isolated/dev environments
   - Requires cluster admin permissions

3. **Resources**
   - Minimum: 4 CPU cores, 8GB RAM
   - Recommended: 8 CPU cores, 16GB RAM
   - Storage: 100GB+ for macOS installation

4. **Legal Compliance**
   - Apple's EULA requires macOS on Apple hardware
   - Use only for educational/testing purposes
   - Consider legal implications for your use case

## Configuration

Edit `statefulset.yaml` to customize:

- **macOS Version**: Change `image: sickcodes/docker-osx:ventura`
  - Options: `ventura`, `monterey`, `big-sur`, `catalina`, `auto`
  
- **Resources**: Adjust CPU/RAM in resources section
  
- **Credentials**: Change default password (alpine)

- **Node Selection**: Uncomment `nodeSelector` to pin to specific node with KVM

## Deployment

1. Ensure KVM is available on target node
2. Uncomment in Tiltfile: `k8s_kustomize("./helm/macos/", "macos", generate_link=True)`
3. Run: `tilt up`

## Access

- **Web VNC**: http://macos.localhost (port 5800)
- **VNC Client**: Connect to `macos.localhost:5900`
- **SSH**: `ssh user@macos.localhost -p 10022` (password: alpine)

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
