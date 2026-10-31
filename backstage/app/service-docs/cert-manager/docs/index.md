# Cert Manager

cert-manager automates the management and issuance of TLS certificates in Kubernetes.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `cert-manager` |
| **Type** | Certificate Management |
| **Default** | Always on (core) |
| **Config Key** | none: it cannot be turned off |
| **Deployment** | Flux HelmRelease (`cert-manager` resource in `tilt/core.tilt`) |


## Official Documentation

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Certificate Resources](https://cert-manager.io/docs/usage/certificate/)
- [Issuer Configuration](https://cert-manager.io/docs/configuration/)
- [Troubleshooting Guide](https://cert-manager.io/docs/troubleshooting/)

## Purpose

cert-manager adds certificates and certificate issuers as resource types in Kubernetes, simplifying the process of obtaining, renewing, and using certificates. In the dev platform it *is* the PKI: it runs the local root and intermediate CAs (`helm/cert-manager/pki/`) and issues the Gateway's certificate, so every `*.localhost` route depends on it.

## Enabling

Nothing to enable. cert-manager is installed on every profile and has no entry in `tilt-config.json`. It used to be a toggleable `flux_apps` entry, and with `enabled: false` the auto-cleanup deleted it straight after the platform created it. The Gateway kept serving its already-issued certificate, so nothing looked wrong until that certificate needed renewing.

## Components

| Component | Description |
|-----------|-------------|
| **Controller** | Watches Certificate resources and issues certs |
| **Webhook** | Validates and mutates cert-manager resources |
| **CA Injector** | Injects CA bundles into webhook configurations |

## Usage

### Request a Certificate

Use the platform's `local-intermediate-ca` ClusterIssuer, the one the Gateway's certificate comes from. A new self-signed issuer would issue a certificate just as readily, but nothing trusts it, so clients fail verification.

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-cert
  namespace: default
spec:
  secretName: my-cert-tls
  issuerRef:
    name: local-intermediate-ca
    kind: ClusterIssuer
  commonName: my-service.localhost
  dnsNames:
    - my-service.localhost
```

## Troubleshooting

### Certificate not ready

```bash
kubectl describe certificate my-cert -n default
kubectl get certificaterequests -n default
kubectl logs -n cert-manager -l app=cert-manager
```
