# Archive

Superseded implementations, kept because customers still run them. Nothing here
is applied by the Tiltfile — these files are reference material, not live config.

| Folder | What it is | Replaced by |
|---|---|---|
| `traefik/` | Traefik ingress: chart values, Grafana dashboard, every `Ingress`/`IngressRoute` manifest, and the Tiltfile wiring | Istio ambient + Gateway API (`helm/istio/`) |
| `openssl-certs/` | Shell/PowerShell OpenSSL CA generation and OS trust installation | cert-manager (`helm/cert-manager/`) |

## traefik/

- `traefik-values.yaml` — the chart values (~1000 lines), including the
  `tlsStore.default.defaultCertificate` and the `security` CORS Middleware.
- `dashboards/traefik-dashboard.yaml` — Grafana dashboard ConfigMap.
- `ingress/<app>.yaml` — one per app, as they existed before migration.
  `_backstage-skeleton-ingress.yaml` is the scaffolder template's version.
- `tiltfile-traefik-and-openssl-certs.txt` — the Tiltfile block that installed
  Traefik via `helm_remote` and generated/installed certs.

### To run Traefik again

Restore `traefik-values.yaml` to `helm/traefik.yaml`, re-add the `helm_remote`
block from the Tiltfile snippet, and put the `ingress/` manifests back into each
app directory (referencing them from that app's `kustomization.yaml` instead of
`httproute.yaml`).

Traefik and cert-manager are **not** mutually exclusive — the cert-manager PKI in
`helm/cert-manager/` issues a Secret that Traefik's `tlsStore` can consume
directly. Preferred over the OpenSSL scripts even on Traefik, because it renews
unattended.

### Known issues in the archived Traefik setup

These are recorded so they are not reintroduced:

- **The per-app `tls.secretName` never resolved.** Apps referenced
  `wildcard-tls-dev` in their own namespace, but that Secret only ever existed in
  the `traefik` namespace. Traefik silently fell back to its default cert store,
  so it worked by accident. Under Gateway API the certificate lives on the
  Gateway and this class of bug is gone.
- **`www.jenkins.locahost`** — typo, missing an `l`, in the Jenkins route. Never
  resolved and was absent from the cert SANs.

## openssl-certs/

The scripts resolve paths relative to their own location, so they still run from
here: `bash archive/openssl-certs/generate-certs.sh`.

Generated CA material (`rootCA/`, `intermediateCA/`) stays gitignored and was
moved with the scripts, so an existing local CA keeps working.

### Why it was replaced

- **No renewal.** The Tiltfile regenerated only when the chain file was
  *missing*, never when expired. The server cert was 825 days; nothing warned
  before TLS simply broke.
- **Two implementations** (`.sh` + `.ps1`, ~250 lines each) to keep in step.
- **CA private keys were `chmod 644`** so `kubectl` could read them.
- **The TLS Secret was created imperatively** via `kubectl create secret tls`.

### If you already trusted the old root CA

It is still in your OS trust store; moving these files does not remove it. To
remove it:

```bash
# Windows
certutil -delstore -user Root "Root CA"
# macOS
sudo security delete-certificate -c "Root CA" /Library/Keychains/System.keychain
# Linux
sudo rm /usr/local/share/ca-certificates/dev-root-ca.crt && sudo update-ca-certificates
```

Leaving it trusted is harmless but means a private key on disk still chains to a
CA your browser accepts.
