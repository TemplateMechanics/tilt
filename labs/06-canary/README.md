# Lab 06 — Canary release

**Profile:** gitops (needs Flagger) · **Time:** 30 min · **You will learn:**
what progressive delivery does with the Gateway and metrics you already have,
by watching it promote a good version and refuse a bad one.

## Setup

```
kubectl apply -f labs/06-canary/loadtester.yaml   # generates the traffic Flagger measures
kubectl apply -f labs/06-canary/canary.yaml
kubectl -n hello get canary -w                    # wait for Initialized
```

The load tester matters: Flagger judges a canary on request success rate, and
a canary nobody calls has no rate to judge. Without this pod the analysis
webhook fails and every release is rolled back — which looks like a bad
version and is actually missing tooling.

Flagger has now created `hello-primary` and re-pointed the HTTPRoute at it.
Your `hello` Deployment is the *candidate* from here on. Reload
<https://hello.localhost> — same app, now served by the primary.

## Ship a good version

```
kubectl -n hello set env deploy/hello PODINFO_UI_MESSAGE="canary v2"
kubectl -n hello get canary hello -w
```

Watch `WEIGHT` step 25 → 50 while the success rate holds, then `Promoting`,
then `Succeeded`. Reload the page: the new message, served by the primary.

## Ship a bad version

```
kubectl -n hello set image deploy/hello podinfo=ghcr.io/stefanprodan/podinfo:does-not-exist
kubectl -n hello get canary hello -w
```

The candidate pod never becomes Ready. After `progressDeadlineSeconds`
Flagger marks it `Failed` and the primary never changed. Reload the page:
still "canary v2". Nobody saw the broken version.

```
kubectl -n hello describe canary hello | tail -15    # the events tell the story
```

## Understand

Everything Flagger used already existed: the Gateway from lab 01, Prometheus
from the observability tier, the Istio data plane. Its job is only to move
traffic weights and read a metric. That is the whole idea — progressive
delivery is a policy on top of primitives you already run, not a new
platform.

## Check

```
./scripts/platform.sh lab 06
```

## Leaving the lab

Flagger now owns `hello`: your Deployment is scaled to zero and
`hello-primary` serves. Labs 01–05 assert on `hello` directly, so they fail
while the Canary exists.

Deleting the Canary is **not** enough, and this was found the hard way:

```
kubectl -n hello delete canary hello
```

leaves `hello` at 0/0, removes `hello-primary`, and leaves the HTTPRoute
pointing at `hello-primary` and `hello-canary` — backends that no longer
exist. `hello.localhost` returns **500**. Under the Gateway API provider,
Flagger does not put the route or the replica count back.

The real exit is the one every lab here comes back to — re-apply the
manifests you own:

```
kubectl -n hello delete canary hello
kubectl apply -k examples/hello-world       # hello -> 1/1, route -> hello
kubectl -n hello delete svc hello-primary hello-canary --ignore-not-found
```

The declarative state was right the whole time; the live state had drifted.
Progressive delivery was a layer on top of it, and a layer can be peeled off.
