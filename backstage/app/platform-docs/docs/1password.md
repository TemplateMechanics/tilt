# 1Password Integration

## Overview

The 1Password Connect operator can be used to inject secrets from 1Password vaults into Kubernetes pods.

## Mounting Secrets

Add the following to a service deployment to pull secrets from 1Password:

```yaml
volumeMounts:
  enabled: true
  items:
    - name: rh-data
      mountPath: "/app/rh-data"
      readOnly: true

volumes:
  enabled: true
  items:
    - name: rh-data
      secret:
        secretName: rh-data-secret
```

## How It Works

1. The 1Password Connect operator watches for `OnePasswordItem` resources
2. It syncs the referenced secret from your 1Password vault into a Kubernetes Secret
3. Your pod mounts the Secret as a volume or environment variable

## Configuration

The 1Password Connect Helm chart is deployed via Flux under `flux_apps` group:

```json
{
  "flux_apps": {
    "1pass": { "enabled": false, "description": "1Password Connect", "category": "Security" }
  }
}
```

Enable it via the config API or Backstage dashboard.

## Resources

- [1Password Connect](https://developer.1password.com/docs/connect/)
- [1Password Kubernetes Operator](https://github.com/1Password/onepassword-operator)
