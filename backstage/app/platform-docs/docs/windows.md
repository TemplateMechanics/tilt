# Windows Setup

## Overview

The Tilt development environment fully supports Windows. The Tiltfile includes cross-platform compatibility that automatically detects Windows and routes all shell commands through **Git for Windows' bash**, bypassing the limitations of `cmd.exe` and avoiding conflicts with WSL's `/bin/bash`.

## Prerequisites

| Tool | Version | Installation |
|------|---------|--------------|
| Docker Desktop | Latest | [docs.docker.com](https://docs.docker.com/desktop/install/windows-install/) |
| Kubernetes | 1.25+ | Enable in Docker Desktop → Settings → Kubernetes |
| Git for Windows | Latest | [git-scm.com](https://git-scm.com/download/win) (includes Git Bash) |
| Tilt | 0.33+ | [docs.tilt.dev](https://docs.tilt.dev/install.html) |
| Helm | 3.12+ | `choco install kubernetes-helm` |
| kubectl | 1.25+ | `choco install kubernetes-cli` |
| Flux CLI | 2.0+ | Auto-installed by Tilt (via Chocolatey or curl) |

!!! important "Git for Windows is required"
    Git for Windows provides `bash.exe` which the Tiltfile uses to run all shell commands. Without it, Tilt will fail to execute resources. Make sure Git is on your PATH — run `git --version` to confirm.

### Optional: Chocolatey Package Manager

[Chocolatey](https://chocolatey.org/install) simplifies installing all prerequisites:

```powershell
# Install Chocolatey (run in elevated PowerShell)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install all prerequisites
choco install git docker-desktop kubernetes-helm kubernetes-cli tilt -y
```

If Chocolatey is available, the Tiltfile will also use it to auto-install the Flux CLI when missing.

## How Windows Support Works

### Cross-Platform Shell Wrapper

Tilt on Windows runs `local_resource` commands through `cmd.exe` by default, which cannot handle bash syntax (`$(…)`, pipes, for-loops, etc.). The Tiltfile includes a `sh()` helper that forces all commands through Git Bash:

1. **Detection** — At startup, Tilt runs `echo %OS%` via raw `local()` (which uses `cmd.exe` on Windows). If the output contains `Windows`, it sets `_IS_WINDOWS = True`.
2. **Git Bash discovery** — Runs `git --exec-path` to find the Git install directory (e.g., `C:/Program Files/Git/mingw64/libexec/git-core`), then derives the bash path (`C:/Program Files/Git/bin/bash.exe`).
3. **Command wrapping** — Every `cmd=` and `serve_cmd=` call is wrapped with `sh(script)`, which returns `[bash_path, '-c', script]` — executing through Git Bash instead of `cmd.exe`.

You'll see this message in the Tilt log on startup:

```
Windows detected — using Git Bash: C:/Program Files/Git/bin/bash.exe
```

### Flux CLI Auto-Install

The `flux-install` resource detects if the Flux CLI is missing and auto-installs it. On Windows, the install cascade is:

1. **Chocolatey** (`choco install flux -y`) — preferred on Windows
2. **Homebrew** (`brew install fluxcd/tap/flux`) — if available
3. **curl** (FluxCD install script) — universal fallback

### TLS Certificate Trust

The `dev-certificate-trust` resource uses `certutil` on Windows to install the root CA:

```cmd
certutil -addstore -f "Root" certificates\rootCA\certs\ca.cert.pem
```

## WSL Conflict

!!! warning "WSL can break the Tiltfile"
    If WSL (Windows Subsystem for Linux) is installed, `bash` on your PATH may resolve to WSL's `/bin/bash` instead of Git Bash. WSL's bash can fail with `execvpe(/bin/bash) failed: No such file or directory` if no default distribution is configured.

The Tiltfile handles this automatically by **never** using the bare `bash` command. Instead, it finds Git Bash's full path via `git --exec-path` and uses that explicitly.

If you still encounter issues:

1. Verify Git is installed and on PATH: `git --version`
2. Check what `git --exec-path` returns — it should point to your Git for Windows install
3. Ensure Docker Desktop Kubernetes is enabled and `kubectl cluster-info` works

## File Path Considerations

- Use forward slashes (`/`) or escaped backslashes (`\\`) in paths
- The Tiltfile normalizes all Git-reported paths to forward slashes internally
- `kubectl`, `helm`, and `flux` all support forward slashes on Windows

## Known Limitations

| Area | Limitation | Workaround |
|------|-----------|-------------|
| KubeVirt | Requires Linux with KVM — not available on Windows | Use emulation mode for testing only |
| macOS VMs | KubeVirt-based, Linux-only | Not available on Windows |
| eyeOS | KubeVirt-based, Linux-only | Not available on Windows |
| PowerShell scripts | Certificate generation uses `generate-certs.ps1` | Works natively on Windows (PowerShell is the default) |
| Symlinks | Some Git operations may require elevated privileges | Run Git Bash as Administrator if symlink errors occur |

## Quick Verification

After installing prerequisites, verify your setup:

```powershell
# Check all tools are available
git --version
docker version
kubectl cluster-info
helm version
tilt version

# Start the environment
cd tilt
tilt up
```

If everything is configured correctly, Tilt will:

1. Detect Windows and locate Git Bash
2. Install Flux CLI (via Chocolatey if available)
3. Deploy all enabled services
4. Generate and trust TLS certificates

All services will be accessible at `https://<service>.localhost`.
