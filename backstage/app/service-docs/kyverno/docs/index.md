# Kyverno

Kyverno is a Kubernetes-native policy engine that validates, mutates, and generates configurations.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `kyverno` |
| **Type** | Policy Engine |
| **Default** | Disabled |
| **Config Key** | `flux_apps.kyverno` |
| **Deployment** | Flux HelmRelease |


## Official Documentation

- [Kyverno Documentation](https://kyverno.io/docs/)
- [Policy Reference](https://kyverno.io/policies/)
- [Writing Policies](https://kyverno.io/docs/writing-policies/)
- [Kyverno CLI](https://kyverno.io/docs/kyverno-cli/)

## Purpose

Kyverno enforces best practices and security policies across your Kubernetes cluster without requiring a separate policy language. Policies are written as Kubernetes resources.

## Enabling

```json
{
  "flux_apps": {
    "kyverno": true
  }
}
```

## Policy Types

| Type | Description |
|------|-------------|
| **Validate** | Reject non-compliant resources |
| **Mutate** | Automatically modify resources |
| **Generate** | Create companion resources |
| **Verify Images** | Validate container image signatures |

## Example Policies

### Require Labels

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-team-label
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "The label 'team' is required."
        pattern:
          metadata:
            labels:
              team: "?*"
```

### Add Default Resource Limits

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-resources
spec:
  rules:
    - name: add-defaults
      match:
        resources:
          kinds:
            - Pod
      mutate:
        patchStrategicMerge:
          spec:
            containers:
              - (name): "*"
                resources:
                  limits:
                    memory: "256Mi"
                    cpu: "500m"
```

## Related Services

| Service | Purpose |
|---------|---------|
| **Policy Reporter** | UI and metrics for Kyverno policy results |
| **Kyverno Policies** | Pre-built policy library |

## Troubleshooting

```bash
# View policy status
kubectl get clusterpolicy
kubectl get policyreport -A

# Check policy violations
kubectl describe clusterpolicy <name>
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno
```
