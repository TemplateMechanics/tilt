# Headlamp: the learner's cluster view

Headlamp is the visual Kubernetes explorer at **https://headlamp.localhost**,
installed by `tilt/core.tilt` in **every profile**, including `minimal`, with
the [Flux plugin](https://github.com/headlamp-k8s/plugins/tree/main/flux)
preinstalled.

## No login, and what that costs

There is no token prompt. Every visitor acts as Headlamp's own service account
(`config.unsafeUseServiceAccountToken` in `helm-release.yaml`). That is only
acceptable because the gateway answers on this machine alone: on Windows the
WSL relay listens on `127.0.0.1:443`, and the machine's LAN and tailnet
addresses refuse the connection. **Do not use this configuration on a shared
or reachable cluster.**

Because anyone who reaches the page gets the same identity, that identity is
capped (`learner-rbac.yaml`) rather than the chart's default cluster-admin:

| You can | You cannot, and why |
|---|---|
| See every namespaced object except Secrets, plus nodes, CRDs, RBAC, Gateway API, Istio, ServiceMonitors | Read Secrets |
| Read pod logs | Exec, attach or open a shell — that is a path to the node |
| Delete a pod and watch it come back | Edit or "Restart" a Deployment — both patch the pod template, which could make it privileged |
| Scale Deployments and StatefulSets | Create pods |
| Browse Flux sources, Kustomizations and HelmReleases | Reconcile or suspend from the Flux plugin — patching a HelmRelease runs its chart as cluster-admin. Use `flux reconcile` in a terminal |

A refused button is Kubernetes saying no, not a broken install. To check the
cap from a terminal:

```bash
SA=system:serviceaccount:headlamp:headlamp
kubectl auth can-i list pods -A --as=$SA                    # yes
kubectl auth can-i delete pods -n hello --as=$SA            # yes
kubectl auth can-i get secrets -A --as=$SA                  # no
kubectl auth can-i create pods/exec -n hello --as=$SA       # no
kubectl auth can-i patch deployments -n hello --as=$SA      # no
kubectl auth can-i patch helmreleases -n headlamp --as=$SA  # no
```

## The Flux plugin

An init container downloads the plugin release by a pinned URL and refuses it
unless the SHA-256 matches, so an upgrade is a reviewed commit, never a
surprise at pod start. A mismatch leaves the pod in `Init:Error`; it does not
start Headlamp without the plugin. To upgrade, change the version and the hash
together:

```bash
curl -sL -o flux.tgz https://github.com/headlamp-k8s/plugins/releases/download/flux-<version>/headlamp-k8s-flux-<version>.tar.gz
sha256sum flux.tgz
```

The pod needs to reach github.com when it starts.

## Checking the installation

```bash
kubectl -n headlamp wait --for=condition=Ready helmrelease/headlamp --timeout=600s
kubectl -n headlamp rollout status deployment/headlamp --timeout=180s
kubectl -n headlamp logs deploy/headlamp -c flux-plugin   # the checksum line says OK
```

With a non-default gateway port the URL carries it, e.g.
`https://headlamp.localhost:8443`.
