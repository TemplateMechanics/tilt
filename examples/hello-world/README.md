# Hello, world

The smallest complete thing on this platform: one app, reachable over HTTPS,
inside the service mesh. Four files, all of which you can read in one sitting.

```
./scripts/platform.sh hello        # or: make hello
```

Then open <https://hello.localhost:8443>.

## What you just deployed

| File | What it is | The one thing to notice |
|---|---|---|
| `namespace.yaml` | a namespace | the `istio.io/dataplane-mode: ambient` label is what puts it in the mesh |
| `deployment.yaml` | one pod running [podinfo](https://github.com/stefanprodan/podinfo) | the probes — without `readinessProbe` traffic arrives before the app is ready |
| `service.yaml` | a stable name and port for the pod | it selects by label, not by pod name |
| `httproute.yaml` | attaches the service to the shared Gateway | **no TLS secret anywhere** — the Gateway holds the certificate |

## Things to try

Each of these teaches something by breaking it. `./scripts/platform.sh reset`
puts everything back if you go too far.

**Scale it.**
```
kubectl -n hello scale deploy/hello --replicas=3
kubectl -n hello get pods -w
```
Reload the page a few times — the hostname at the top changes as requests land
on different pods. Then `kubectl top pods -n hello` to see what they cost.

**Take it out of the mesh.** Remove the `istio.io/dataplane-mode` label from
`namespace.yaml`, re-apply, and restart the pod:
```
kubectl -n hello rollout restart deploy/hello
```
The page still works. Open <https://kiali.localhost:8443> — the data plane
count dropped by one. That is the whole difference between "in the mesh" and
"not": invisible from the app, visible only from Kiali. Put the label back.

**Route a second hostname.** Add `hi.localhost` to `hostnames:` in
`httproute.yaml` and apply it. Open <https://hi.localhost:8443>.

It fails — and *how* it fails is the lesson. The browser says the certificate is
wrong. It is not a trust problem; it is a **hostname mismatch**, because
`hi.localhost` is not in the certificate's SAN list. `*.localhost` does not cover
it (a wildcard directly under a single-label parent is rejected by every
verifier). Run the check that exists for exactly this:
```
python scripts/ci/check-route-hostnames.py
```
Add `hi.localhost` to `dnsNames` in `helm/istio/gateway/base/certificate.yaml`,
apply it, wait ~30s for cert-manager to reissue, and reload.

**Watch the logs.** Open <https://grafana.localhost:8443> (admin/admin), the
*AI Ops → Log Review* dashboard, and set the namespace filter to `hello`. Every
request you made is there.

**Break the probe.** Change `readinessProbe.httpGet.path` to `/nope` and apply.
The new pod never becomes Ready, the old one keeps serving, and the rollout
sits at 1/2. `kubectl -n hello describe pod` tells you why. This is the
platform refusing to send traffic to something that has not proven it works.

## What is deliberately not here

- **No Ingress.** This platform uses Gateway API. An `Ingress` object would be
  accepted by the API server and reconciled by nothing.
- **No TLS secret in the namespace.** Under the previous ingress controller each
  app named a secret that only existed in another namespace, and routing worked
  by accidental fallback. The Gateway owns the cert; apps attach routes.
- **No Helm, no Crossplane, no scaffolder.** Those are how the platform
  deploys *itself*. This is how you deploy *a thing*. Learn this first.
