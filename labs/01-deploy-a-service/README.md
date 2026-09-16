# Lab 01 — Deploy a service

**Profile:** minimal · **Time:** 10 min · **You will learn:** what the four
objects behind a URL are, and which one is doing which job.

## Do

```
./scripts/platform.sh hello
```

Open <https://hello.localhost>. Then read the four files in
[`examples/hello-world/`](../../examples/hello-world/) — all of them; each fits
on one screen.

## Understand

Trace the request. It arrives at the **Gateway** (istio-system), which owns
the certificate. The **HTTPRoute** says `hello.localhost` goes to Service
`hello` port 80. The **Service** selects pods by label and forwards to 9898.
The **Deployment** keeps one such pod running and marks it Ready only once
`/readyz` answers.

Now break the chain one link at a time and watch *where* it fails:

```
kubectl -n hello delete httproute hello           # 404 from the gateway: nothing matched
kubectl -n hello delete svc hello                 # 503: route matched, no backend
kubectl -n hello scale deploy/hello --replicas=0  # 503: backend has no endpoints
```

Each failure looks different, and that difference is how you debug routing
for the rest of your career. Put it back:

```
kubectl apply -k examples/hello-world
```

## Check

```
./scripts/platform.sh lab 01
```
