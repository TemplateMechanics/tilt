# Production Notes

!!! danger "Local Development Only"
    This repository is designed for **local development only**. The following items must be addressed before adapting any manifests for production use.

## KubeVirt Operator RBAC

`helm/kubevirt/operator.yaml` uses wildcard `*` permissions for convenience. In production, use the [official KubeVirt operator manifest](https://github.com/kubevirt/kubevirt/releases) which defines granular per-resource RBAC, or install via OLM.

## Backstage Guest Auth

`helm/backstage/configmap.yaml` uses `dangerouslyAllowOutsideDevelopment` for guest access. Replace with a proper auth provider (GitHub, OIDC, etc.) in production.

## Hardcoded Credentials

All services use plaintext dev passwords for convenience. In production, replace with securely generated secrets managed via a secrets manager (e.g., HashiCorp Vault, AWS Secrets Manager, 1Password Operator).

| Service | File | Credential |
|---------|------|------------|
| Backstage | `helm/backstage/secrets.yaml` | Postgres password, GitHub token |
| Backstage PostgreSQL | `helm/backstage/postgresql.yaml` | `bstage-dev-password` |
| Keycloak | `helm/keycloak/deployment.yaml`, `postgresql.yaml` | `kc-dev-password` |
| MSSQL | `helm/mssql/values.yaml` | `P@ssw0rd` |
| Jenkins | `helm/jenkins/helm-release.yaml` | `P@ssw0rd` |
| Harbor | `helm/harbor/helm-release.yaml` | `P@ssw0rd` |
| MongoDB | `helm/mongodb/manifests/secret.yaml` | `mongo-dev-password` |
| RabbitMQ | `helm/rabbitmq/manifests/secret.yaml` | `rmq-dev-password` |
| Redis | `helm/redis/manifests/secret.yaml` | `redis-dev-password` |

## TLS Certificates

Local self-signed CA. Replace with real certificates or cert-manager with a trusted issuer in production.

## Resource Limits

Development manifests generally do not set CPU/memory limits. Production deployments should include resource requests and limits for all containers.

## Persistence

Some services use `emptyDir` or ephemeral storage. Ensure all stateful services have proper PersistentVolumeClaims backed by a reliable storage class.

## Network Policies

No network policies are defined. Production clusters should restrict pod-to-pod communication with appropriate NetworkPolicy resources.
