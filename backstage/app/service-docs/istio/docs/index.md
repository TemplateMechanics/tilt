# Istio

Istio provides both the service mesh (ambient mode) and north-south ingress
(Gateway API) for the platform. It replaced Traefik; the Traefik configuration is
archived under `archive/traefik/`.

| | |
|---|---|
| **Namespace** | `istio-system` |
| **Version** | 1.28.3 |
| **Mode** | Ambient (ztunnel + istio-cni, no sidecars) |
| **Ingress** | Gateway API (`gatewayClassName: istio`) |
| **Config** | `helm/istio/` (base + overlays) |

## Components

| Component | Purpose |
|---|---|
| `istio-base` | CRDs and cluster roles |
| `istiod` | Control plane; also the Gateway API controller |
| `istio-cni` | Sets up pod networking for ambient capture |
| `ztunnel` | Per-node L4 proxy providing mTLS |
| `localhost-gateway` | The shared ingress Gateway in `istio-system` |

## How routing works

Each app owns an `HTTPRoute` next to its Deployment, attached to the shared
Gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp
  namespace: myapp
spec:
  hostnames: ["myapp.localhost"]
  parentRefs:
    - name: localhost-gateway
      namespace: istio-system
      kind: Gateway
      group: gateway.networking.k8s.io
  rules:
    - matches: [{path: {type: PathPrefix, value: /}}]
      backendRefs: [{name: myapp, port: 80}]
```

No `secretName` appears here. The Gateway holds the certificate, which is what
fixes the old Traefik behaviour where each app named a TLS Secret that only
existed in the `traefik` namespace and silently fell back to the default store.

Add `myapp.localhost` to `dnsNames` in
`helm/istio/gateway/base/certificate.yaml` — see the Certificates page for why
the wildcard alone is not sufficient.

## Platform overlays

| Overlay | Adds |
|---|---|
| `overlays/docker-desktop` | nothing; the LoadBalancer binds host 80/443 |
| `overlays/kind` | a NodePort Service (30080/30443) and `istio-ambient-node-prep` |

`istio-ambient-node-prep` makes `/run` rshared on each kind node. Without it
`istio-cni` cannot enter pod network namespaces and ambient capture silently
does nothing while every component still reports healthy.

## Troubleshooting

```bash
# Is the Gateway actually programmed? Accepted is not enough.
kubectl get gateway -n istio-system

# Is a route attached, and did its backend resolve?
kubectl get httproute -A
kubectl get httproute <name> -n <ns> -o jsonpath='{.status.parents[0].conditions}'

# Gateway logs
kubectl logs -n istio-system -l gateway.networking.k8s.io/gateway-name=localhost-gateway

# Is the namespace in the mesh?
kubectl get ns -L istio.io/dataplane-mode
```

**`Programmed=False` with traffic still flowing** means Istio's auto-provisioned
Service is a LoadBalancer with no address (the usual case on kind). The kind
overlay annotates the Gateway with `networking.istio.io/service-type: NodePort`
to avoid it; anything waiting on `condition=Programmed` blocks until timeout
without that annotation.

## Links

- [Istio ambient mode](https://istio.io/latest/docs/ambient/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
