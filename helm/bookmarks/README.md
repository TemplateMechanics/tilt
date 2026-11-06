# Curious Pandas local bookmarks

The learner start page at **https://bookmarks.localhost** is in the **minimal**
profile. It is a static, unauthenticated list of resources, not a Kubernetes
control plane, service health monitor or credential store.

- Headlamp: `https://headlamp.localhost` (read-only learner token; see
  `helm/headlamp/README.md`)
- Tilt: `http://localhost:10350`
- Hello World: `https://hello.localhost`
- Grafana, Kiali, Prometheus: require `PROFILE=observability`.
- Interactive lessons: `https://learn.curiouspandas.dev`.
- Real troubleshooting labs: `https://github.com/TemplateMechanics/tilt/tree/main/labs`.

The HTML and styles are local, no fonts, scripts or media are fetched from
third-party domains. Clicking an external link is an intentional navigation.
The script rewrites local HTTPS links to preserve alternate gateway ports
(e.g. `:8443`). The Tilt UI link is tied to Tilt's default port (10350).

The page is served by unprivileged NGINX with no Kubernetes service-account
token, dropped capabilities, a read-only root filesystem and a memory-backed
temporary directory.

## Checks

```bash
kubectl kustomize helm/bookmarks
python scripts/ci/check-route-hostnames.py
./scripts/platform.sh up
kubectl -n bookmarks rollout status deploy/bookmarks --timeout=180s
kubectl -n bookmarks get httproute bookmarks -o yaml
```

Verify the HTTPRoute has both `Accepted=True` and `ResolvedRefs=True`, then
open `https://bookmarks.localhost` after the local CA trust step. With the
alternate kind port mapping open `https://bookmarks.localhost:8443` and verify
the Headlamp shortcut also points at `:8443`. Local-only hosts must not be
exposed through public tunnels.
