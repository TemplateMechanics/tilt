# Troubleshooting

## Crossplane Providers Not Healthy

```bash
# Check provider status
kubectl get providers.pkg.crossplane.io

# Check provider revisions
kubectl get providerrevision

# If CRD ownership conflicts, patch ownerReferences
kubectl get crd <crd-name> -o yaml
```

## Service Not Accessible

```bash
# Check HTTPRoute exists
kubectl get ingressroute -A

# Check Istio logs
kubectl logs -n istio-system -l gateway.networking.k8s.io/gateway-name=localhost-gateway

# Verify the service is running
kubectl get pods -n <service-namespace>
```

## Config Server Not Responding

```bash
# Check pod status
kubectl get pods -n tilt-system -l app=tilt-config-server

# Check pod logs
kubectl logs -n tilt-system -l app=tilt-config-server

# Verify ConfigMap exists
kubectl get configmap tilt-config -n tilt-system

# Health check via HTTPRoute
curl http://tilt-config.localhost/health

# Direct port-forward access
kubectl port-forward -n tilt-system svc/tilt-config-server 10351:10351
curl http://localhost:10351/health
```

## Backstage Not Loading Catalog

```bash
# Check Backstage pod logs
kubectl logs -n backstage -l app=backstage

# Verify catalog ConfigMap
kubectl get configmap backstage-catalog -n backstage -o yaml
```

## Flux CRDs Not Available

The Tiltfile auto-detects Flux API versions at runtime. If you see CRD errors:

```bash
# Check which API versions Flux registered
kubectl api-versions | grep -E 'source.toolkit|helm.toolkit'

# Check Flux controllers are running
kubectl get pods -n flux-system

# Restart the flux-install resource in Tilt
tilt trigger flux-install
```

## HelmRelease Stuck in "Not Ready"

```bash
# Check HelmRelease status
kubectl get helmrelease -A

# Describe for conditions
kubectl describe helmrelease <name> -n <namespace>

# Check Helm controller logs
kubectl logs -n flux-system -l app=helm-controller
```

## Certificate Issues

### Browser Shows "Not Secure"

1. Make sure `local-ca-crls` is green in Tilt.
2. Reconcile the exact current root with `./scripts/trust-ca.sh`.
3. Verify the complete macOS trust and revocation path with:

    ```bash
    security verify-cert -R require https://hello.localhost/
    ```

    On macOS the root belongs in the current user's login keychain, not the
    System keychain. `./scripts/trust-ca.sh --list` reports both current-user
    entries and any legacy System-keychain entries without deleting them.
4. Confirm both revocation lists are reachable:

    ```bash
    curl -fsS http://crl.localhost/root.crl | openssl crl -inform DER -noout -nextupdate
    curl -fsS http://crl.localhost/intermediate.crl | openssl crl -inform DER -noout -nextupdate
    ```

Do not bypass the certificate warning. Functional graders use the cluster CA
explicitly, so they can pass while host-native trust or managed-Chrome
revocation still fails.

## Windows Issues

### `'EXPECTED' is not recognized as an internal or external command`

Tilt is running commands through `cmd.exe` instead of bash. This means the `sh()` wrapper isn't being used. Ensure you're on the latest version of the Tiltfile.

### `execvpe(/bin/bash) failed: No such file or directory`

WSL's `/bin/bash` is being found on PATH instead of Git Bash. The Tiltfile handles this automatically by locating Git Bash via `git --exec-path`. Verify Git for Windows is installed:

```powershell
git --version
git --exec-path
```

The second command should return something like `C:/Program Files/Git/mingw64/libexec/git-core`.

### Flux CLI not found on Windows

The `flux-install` resource auto-installs the Flux CLI. On Windows, it prefers Chocolatey:

```powershell
# Install Chocolatey if not already available
Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Or install Flux manually
choco install flux -y
```

### Certificate trust fails

Run the shared trust operation from Git Bash and accept the Windows certificate
confirmation:

```bash
./scripts/trust-ca.sh
```

It installs `.local/dev-root-ca.crt` into the current user's Root store; an
Administrator prompt is not required.

See the [Windows Setup](windows.md) guide for full details.

## Tilt Dashboard

The Tilt web UI at [localhost:10350](http://localhost:10350) shows all resources, build history, and logs.

```bash
# Open dashboard
open http://localhost:10350

# Or check status from CLI
tilt get resources
```
