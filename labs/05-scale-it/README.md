# Lab 05 — Scale it

**Profile:** observability (needs metrics-server) · **Time:** 15 min · **You
will learn:** what an HPA actually needs before it can do anything, and how
to tell "scaling" from "stuck".

## Do

```
kubectl apply -f labs/05-scale-it/hpa.yaml
kubectl -n hello get hpa hello
```

If the `TARGETS` column reads `<unknown>/50%`, stop. That is the HPA telling
you it has no metrics — and it will sit there forever without complaint.
Check the Metrics API exists:

```
kubectl top nodes
```

On this platform metrics-server is part of the observability profile. With
`--profile=minimal` the HPA is installed and inert. That is a real production
failure mode, not a lab contrivance.

Now load it:

```
./labs/05-scale-it/load.sh 90
kubectl -n hello get hpa,pods -w
```

Within a minute `REPLICAS` climbs. Reload <https://hello.localhost> a few
times: the hostname at the top rotates as requests spread across pods.

## Understand

`kubectl top pods -n hello` shows the numbers the HPA is reacting to. Note the
Deployment *requests* 10m CPU; utilisation is measured against the request,
not the limit, which is why such a small request trips a 50% target easily.
Once load stops, scale-down waits `stabilizationWindowSeconds` before
shrinking — that lag is deliberate, and it is why autoscaling never looks
instant.

## Check

Run while load is on, or within a minute of it:

```
./scripts/platform.sh lab 05
```
