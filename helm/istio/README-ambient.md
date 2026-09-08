# Ambient mesh enrolment

Istio ambient captures traffic per namespace. A namespace joins the mesh only
when it carries:

```yaml
metadata:
  labels:
    istio.io/dataplane-mode: ambient
```

## Why this file exists

Installing ambient does not put anything in the mesh. Until these labels were
added the platform had ztunnel Running on every node, istio-cni healthy, mount
propagation correctly set to `shared` — and **zero** workloads captured. Nothing
reported a fault; the only visible symptom was Kiali's overview reading
`Data planes (0)` next to a healthy `Control planes (1)`.

Kiali is what surfaced it, which is most of the argument for having Kiali.

## Enrolled

Application workloads: airflow, azurite, backstage, eyeos, gcp-emulators,
harbor, jenkins, jupyterhub, keycloak, langfuse, localstack, macos, mailhog,
mongodb, postgresql, qdrant, rabbitmq, redis, wazuh, wordpress — plus every
namespace the Crossplane DevApplication composition creates.

## Deliberately not enrolled

Absence here is a decision, not an oversight:

| Namespace | Why not |
|---|---|
| `istio-system`, `kube-system` | the mesh cannot capture its own control plane |
| `cert-manager`, `flux-system` | admission webhooks and Flux source fetches run outside the data path; capturing them risks deadlocking reconciliation |
| `crossplane-system` | providers talk to the API server directly |
| `monitoring`, `logging`, `tracing` | scrapers need direct pod access, and capture changes source IPs, breaking target discovery |
| `kyverno`, `falco`, `keda`, `velero`, `trivy`, `1pass`, `policy-reporter` | cluster agents with host access |
| `dapr`, `knative`, `kubevirt` | ship their own sidecars or CNI and conflict |

## Checking it worked

```bash
# Which namespaces are actually in the mesh
kubectl get ns -L istio.io/dataplane-mode

# ztunnel should list workloads, not be empty
kubectl exec -n istio-system ds/ztunnel -- ztunnel-cli workload list 2>/dev/null

# Kiali: Data planes should be non-zero
# https://kiali.localhost/
```

A pod must be **restarted** after its namespace is labelled. Existing pods are
not captured retroactively, so a namespace can show the label while its
long-running pods remain outside the mesh.
