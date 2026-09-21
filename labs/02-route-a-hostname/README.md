# Lab 02 — Route a second hostname

**Profile:** minimal · **Time:** 15 min · **You will learn:** why a route
without a matching certificate entry fails in a way that sends you to the
wrong place.

## Do

Add `hi.localhost` to `hostnames:` in `examples/hello-world/httproute.yaml`
and apply it:

```
kubectl apply -k examples/hello-world
```

Open <https://hi.localhost>. It fails. The browser says the certificate is
invalid.

## Understand

It is **not** a trust problem — the same CA signed this certificate and your
browser trusts it. It is a **hostname mismatch**: `hi.localhost` is not in
the certificate's SAN list. You might expect `*.localhost` to cover it. It
does not: every verifier rejects a wildcard directly beneath a single-label
parent.

```
./labs/04-break-tls/probe.sh hi.localhost
#   Verify return code: 62 (hostname mismatch)
```

Code 62. Remember it. A trust failure is 19, 20 or 21. They look identical in
a browser and mean opposite things.

This repo has a check for exactly this omission. Run it and read the message:

```
python scripts/ci/check-route-hostnames.py
```

## Fix

Add `hi.localhost` under `dnsNames:` in
`helm/istio/gateway/base/certificate.yaml`, apply the gateway overlay, and
wait ~30 s for cert-manager to reissue:

```
kubectl apply -k helm/istio/gateway/overlays/kind
kubectl -n istio-system get certificate wildcard-localhost -w
```

Reload. Run the CI check again — it passes now, and it will fail for the next
person who forgets.

## Check

```
./scripts/platform.sh lab 02
```

## Leaving the lab

This is the one lab where you edit files in the repo, so undoing it is a `git`
operation, not a `kubectl` one:

```
git checkout -- examples/hello-world/httproute.yaml helm/istio/gateway/base/certificate.yaml
```

Tilt watches both paths and re-applies within seconds; `hi.localhost` goes back
to a hostname mismatch (62), which is where lab 02 started. If Tilt is not
running, apply them yourself:

```
kubectl apply -k examples/hello-world
kubectl apply -k helm/istio/gateway/overlays/kind
```
