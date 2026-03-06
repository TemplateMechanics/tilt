# TLS Certificates

## Overview

The development environment uses a self-signed CA chain to provide TLS for all `*.localhost` services. Certificates are generated locally and trusted in the system certificate store.

## Certificate Chain

```
Root CA
  └── Intermediate CA
        └── Wildcard Certificate (*.localhost)
```

## Generation

Certificates are generated automatically by Tilt via the `dev-certificate-generate` resource:

```bash
# Or manually:
cd certificates
bash generate-certs.sh
```

The script:

1. Creates root and intermediate CA directories with proper permissions
2. Generates a root CA key and self-signed certificate
3. Generates an intermediate CA signed by the root
4. Creates a wildcard certificate for `*.localhost` signed by the intermediate CA

## Trust Installation

The `dev-certificate-trust` Tilt resource automatically installs the root CA into the system trust store:

### macOS

Uses `osascript` to prompt for administrator privileges, then runs:

```bash
security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  certificates/rootCA/certs/ca.cert.pem
```

### Linux

Copies the root CA to the system certificates directory and updates the trust store:

```bash
sudo cp certificates/rootCA/certs/ca.cert.pem /usr/local/share/ca-certificates/dev-root-ca.crt
sudo update-ca-certificates
```

### Windows

Uses `certutil` to add the certificate to the trusted root store:

```cmd
certutil -addstore -f "Root" certificates\rootCA\certs\ca.cert.pem
```

## File Locations

| File | Description |
|------|-------------|
| `certificates/rootCA/certs/ca.cert.pem` | Root CA certificate |
| `certificates/rootCA/private/ca.key.pem` | Root CA private key |
| `certificates/intermediateCA/certs/intermediate.cert.pem` | Intermediate CA certificate |
| `certificates/intermediateCA/certs/ca-chain.cert.pem` | Full certificate chain |
| `certificates/intermediateCA/certs/localhost.cert.pem` | Wildcard server certificate |
| `certificates/intermediateCA/private/localhost.key.pem` | Wildcard server private key |

## Kubernetes Secret

The `dev-certificate-install` resource creates a TLS secret from the generated certificates:

```bash
kubectl create secret tls wildcard-tls-dev \
  --cert=certificates/intermediateCA/certs/localhost.cert.pem \
  --key=certificates/intermediateCA/private/localhost.key.pem \
  --namespace=traefik \
  --dry-run=client -o yaml | kubectl apply -f -
```

This secret is used by Traefik for HTTPS termination on all `*.localhost` ingress routes.

## Troubleshooting

### Browser still shows "Not Secure"

- Ensure the root CA is trusted (check Keychain Access on macOS)
- Restart the browser after trusting the certificate
- Clear browser TLS cache

### Permission denied during generation

The script handles root-owned directories from previous runs by prompting for admin privileges via a GUI dialog. If issues persist:

```bash
# macOS
sudo rm -rf certificates/rootCA certificates/intermediateCA
bash certificates/generate-certs.sh
```

### Certificate expired

Regenerate by deleting old certs and re-running:

```bash
rm -rf certificates/rootCA/certs certificates/intermediateCA/certs
tilt trigger dev-certificate-generate
```
