# Lab 09 — Why did it restart?

**Profile:** minimal · **Time:** 20 min · **You will learn:** to tell apart two
crashes that look identical and have opposite fixes.

Two Deployments. Both restart forever. `kubectl get pods` says the same thing
about each, and **both exit with code 137** — so the first thing most people
reach for does not separate them at all.

Both are real failures from this platform. Keycloak was OOMKilled at a 2Gi limit,
eight restarts deep. Wazuh's API never finished starting before its liveness
probe fired, and it surfaced as a filebeat stack dump that pointed at entirely
the wrong component.

## Setup

```
kubectl apply -f labs/09-why-did-it-restart/workloads.yaml
kubectl -n lab09 get pods -w
```

Wait a couple of minutes for both to fail a few times.

## Look

```
kubectl -n lab09 get pods
```

Two pods, restart counts climbing. Now try the usual next step:

```
kubectl -n lab09 get pods -o jsonpath='{range .items[*]}{.metadata.labels.app}{"  exit="}{.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}{end}'
```

Both say `137`. That is 128 + SIGKILL: the kernel or kubelet killed the process.
It tells you *that* something killed it, not *what* or *why*.

## The two fields that actually tell you

**One:** the termination reason.

```
kubectl -n lab09 get pods -o jsonpath='{range .items[*]}{.metadata.labels.app}{"  "}{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}{end}'
#   starved     OOMKilled
#   impatient   Error
```

**Two:** the events.

```
kubectl -n lab09 describe pod -l app=impatient | tail -6
#   Warning  Unhealthy  Liveness probe failed: Get "http://…:8080/": connection refused
#   Normal   Killing    Container app failed liveness probe, will be restarted
```

`starved` has no such event. `impatient` has no OOMKilled.

## Understand

- **starved** allocates ~200Mi against a 64Mi limit. The kernel's OOM killer
  ends it. More memory is the only fix; no probe change would help.
- **impatient** takes 60 seconds to start and has a liveness probe that gives it
  15. The probe kills a perfectly healthy process before it can finish. More
  memory would change nothing.

Same symptom, same exit code, opposite causes, opposite fixes. Reading the
symptom alone will send you to the wrong one about half the time.

The right fix for a slow start is a **startupProbe**, not a longer liveness
delay: it holds liveness off until the container is actually up, then hands over
with a tight interval. A long `initialDelaySeconds` on liveness buys start-up
time at the cost of being slow to notice a real hang later.

## Fix

```
./labs/09-why-did-it-restart/fix.sh
```

Two different patches, one per pod.

## Check

```
./scripts/platform.sh lab 09
```

The grader asserts the *shape* of each fix, not just that things went green —
raising memory on the probe-killed pod would eventually look healthy too, for
entirely the wrong reason. It also requires the rollout to have **finished**:
while writing this lab the grader passed once on the old pod, which was Ready
and still carrying the bug. "A pod is Ready" and "your change is live" are
different facts.

## Re-break it

```
./labs/09-why-did-it-restart/break.sh
```

Not `kubectl apply -f workloads.yaml`, and the reason is worth knowing:
`fix.sh` uses `kubectl patch`, which changes the live object without updating
the `last-applied-configuration` annotation that `apply` reconciles against. So
`apply` never learns the startupProbe was added and leaves it there — you get a
half-broken lab and a confusing result. This bit me while writing the lab.

## Clean up

```
kubectl delete -f labs/09-why-did-it-restart/workloads.yaml
```
