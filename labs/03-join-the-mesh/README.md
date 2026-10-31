# Lab 03 — Join the mesh (and leave it)

**Profile:** observability (for Kiali) · **Time:** 15 min · **You will
learn:** that "in the mesh" is invisible from the app and visible only from
the mesh — and what actually flips it.

## Do

Open <https://kiali.localhost> → Overview. Note **Data planes (N)**.

Remove the `istio.io/dataplane-mode: ambient` label from
`examples/hello-world/namespace.yaml`, apply, and restart the pod:

```
kubectl apply -k examples/hello-world
kubectl -n hello rollout restart deploy/hello
```

The app still works. Reload Kiali: **Data planes (N-1)**.

## Understand

Ambient mesh membership is a namespace (or pod) label. Unlike sidecar mode,
joining or leaving needs no restart: Istio's docs say ambient mode can be
enabled or disabled "completely transparently as far as the application pods
are concerned", and istio-cni moves running pods in and out. The restarts in
this lab are harmless, not required. Without the label the pod gets no mTLS
and no L4 telemetry, and nothing anywhere reports that. When this platform was
first built, **zero** namespaces carried the label: ztunnel ran on every node,
every check was green, and not one workload was in the mesh. Kiali was the only thing that showed it.

The proof is on the pod itself:

```
kubectl -n hello get pod -l app.kubernetes.io/name=hello   -o jsonpath='{.items[0].metadata.annotations.ambient\.istio\.io/redirection}'
#   enabled   -> captured by ztunnel
#   (empty)   -> not in the mesh
```

## Fix

```
kubectl label ns hello istio.io/dataplane-mode=ambient --overwrite
kubectl -n hello get pod -l app.kubernetes.io/name=hello   -o jsonpath='{.items[0].metadata.annotations.ambient\.istio\.io/redirection}'
```

The annotation must say `enabled`, and it should without a restart: istio-cni
captures the pod that is already running. If it stays empty, that is the
finding - on kind, istio-cni needs `/run` to be rshared on the node, which the
`istio-ambient-node-prep` DaemonSet (helm/istio/overlays/kind) sets. A restart
(`kubectl -n hello rollout restart deploy/hello`) is harmless if you want a
fresh pod anyway.

## Check

```
./scripts/platform.sh lab 03
```
