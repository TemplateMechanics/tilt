# Cert Manager

cert-manager automates the management and issuance of TLS certificates in Kubernetes.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `cert-manager` |
| **Type** | Certificate Management |
| **Default** | Disabled |
| **Config Key** | `flux_apps.cert-manager` |
| **Deployment** | Flux HelmRelease |


## Official Documentation

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Certificate Resources](https://cert-manager.io/docs/usage/certificate/)
- [Issuer Configuration](https://cert-manager.io/docs/configuration/)
- [Troubleshooting Guide](https://cert-manager.io/docs/troubleshooting/)

## Purpose

cert-manager adds certificates and certificate issuers as resource types in Kubernetes, simplifying the process of obtaining, renewing, and using certificates. In the dev platform, it can be used alongside or instead of the manual certificate generation.

## Enabling

```json
// tilt-config.json
{
  "flux_apps": {
    "cert-manager": true
  }
}
```

Or via the config server API:

```bash
curl -X PATCH https://localhost:10351/config \
  -H "Content-Type: application/json" \
  -d '{"flux_apps": {"cert-manager": true}}'
```

## Components

| Component | Description |
|-----------|-------------|
| **Controller** | Watches Certificate resources and issues certs |
| **Webhook** | Validates and mutates cert-manager resources |
| **CA Injector** | Injects CA bundles into webhook configurations |

## Usage

### Create a self-signed Issuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
```

### Request a Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-cert
  namespace: default
spec:
  secretName: my-cert-tls
  issuerRef:
    name: selfsigned-issuer
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
