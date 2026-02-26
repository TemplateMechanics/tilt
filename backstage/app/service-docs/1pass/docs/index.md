# 1Password Connect

1Password Connect provides a secure bridge between 1Password vaults and Kubernetes Secrets, enabling automated secrets management with the 1Password Kubernetes Operator.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `1password-system` |
| **Type** | Secrets Management |
| **Default** | Disabled |
| **Config Key** | `flux_apps.1pass` |
| **Deployment** | Flux HelmRelease |
| **Chart** | `connect` v2.0.5 from 1password.github.io |

## Official Documentation

- [1Password Connect](https://developer.1password.com/docs/connect/)
- [Kubernetes Operator](https://developer.1password.com/docs/connect/get-started/#step-3-deploy-1password-connect-to-kubernetes)
- [Helm Chart](https://github.com/1Password/connect-helm-charts)
- [OnePasswordItem CRD](https://developer.1password.com/docs/connect/kubernetes-operator/)

## Architecture

```
┌──────────────────────┐     ┌──────────────────────┐
│   1Password Vault    │     │   Kubernetes Cluster  │
│   (Cloud/Server)     │◄────│                       │
└──────────────────────┘     │  ┌──────────────────┐ │
                             │  │  Connect Server   │ │
                             │  │  (REST API)       │ │
                             │  └────────┬─────────┘ │
                             │           │           │
                             │  ┌────────▼─────────┐ │
                             │  │  K8s Operator     │ │
                             │  │  (CRD Watcher)    │ │
                             │  └────────┬─────────┘ │
                             │           │           │
                             │  ┌────────▼─────────┐ │
                             │  │ Kubernetes Secret │ │
                             │  │ (synced)          │ │
                             │  └──────────────────┘ │
                             └──────────────────────┘
```

## Features

- **Operator Pattern**: OnePasswordItem CRDs automatically synced to K8s Secrets
- **Vault Integration**: Pull secrets from any 1Password vault
- **Auto-Rotation**: Secrets refreshed on vault changes
- **Multiple Vaults**: Support for multiple vault sources

## Prerequisites

1. A 1Password account (Teams, Business, or Enterprise)
2. A Connect Server credentials file (`1password-credentials.json`)
3. An access token for the Connect API

## Configuration

The Helm release creates:
- Connect Server deployment
- Kubernetes Operator for watching OnePasswordItem CRDs
- Secrets for credentials and access tokens

## Enabling

```json
{
  "flux_apps": {
    "1pass": true
  }
}
```

> **Note**: You must provide valid 1Password credentials in `helm/1pass/secrets/` for the operator to function.
