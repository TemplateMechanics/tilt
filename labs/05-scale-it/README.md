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

**Who owns `replicas`?** The Deployment manifest says `replicas: 1`. The
HPA says whatever the load needs. While the load is running and you are at 4,
re-apply the manifest:

```
kubectl apply -k examples/hello-world
kubectl -n hello get deploy hello -w
```

Three of the four pods are terminated at once. The HPA puts the count back
within a second and the new pods are ready in about 13 s. Here, that is a
blip. In production, it is what a GitOps sync does to an autoscaled service
at peak traffic. The fix is to stop declaring `replicas` in the manifest
once an HPA owns it. This repo keeps it only because lab 01 relies on
re-applying to undo `scale --replicas=0`.

## Check

Run it **while the load is still on**. About a minute after the load stops,
the HPA scales back to one replica, which is correct behaviour, and the
grader then fails. It tells you which case you are in.

```
./scripts/platform.sh lab 05
```

## Leaving the lab

```
kubectl delete -f labs/05-scale-it/hpa.yaml
kubectl -n hello delete pod hello-load --ignore-not-found
```

Leave the HPA behind and it follows you. In lab 06 Flagger copies the
candidate's replica count into `hello-primary` at promotion, and the HPA had
scaled the candidate. The primary came out at 4 replicas instead of 1, with
no HPA of its own to bring it back down.
