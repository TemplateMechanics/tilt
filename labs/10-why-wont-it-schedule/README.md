# Lab 10 — Why won't it schedule?

**Profile:** minimal · **Time:** 25 min · **You will learn:** to read a failure
that happens at admission, where the object you are staring at never mentions it.

You ask for six replicas. The Deployment says six. Three pods exist. Nothing is
crashing, nothing is Pending, and there is no failing pod to describe.

## Setup

```
kubectl apply -f labs/10-why-wont-it-schedule/governance.yaml
kubectl -n lab10 get pods
```

## First, something already happened without telling you

The Deployment declares no CPU or memory at all. Look at the pod:

```
kubectl -n lab10 get pods -l app=quota-demo \
  -o jsonpath='{.items[0].spec.containers[0].resources}{"\n"}'
#   {"limits":{"cpu":"200m","memory":"128Mi"},"requests":{"cpu":"25m","memory":"64Mi"}}
```

Nobody wrote those. A **LimitRange** mutated the pod at admission. The object
stored in the cluster is not the object you submitted, and nothing announced it.

That matters more than it looks: a ResourceQuota on `requests.memory` cannot
count a pod that requests nothing, so without the LimitRange the pod would be
refused outright rather than defaulted.

## Break it

```
./labs/10-why-wont-it-schedule/break.sh
```

Six replicas against a quota of three pods. Now go looking:

```
kubectl -n lab10 get deploy quota-demo    # 3/6, and not a word about why
kubectl -n lab10 get pods                 # three healthy pods; nothing to debug
```

There is no failing pod because **the pods were never created**. The rejection
happened at the API server, before anything was scheduled.

## Where the message actually is

Two places, and neither is `kubectl get`:

```
kubectl -n lab10 get events --field-selector reason=FailedCreate
#   Error creating: pods "quota-demo-..." is forbidden: exceeded quota:
#   lab10-quota, requested: pods=1, used: pods=3, limited: pods=3
```

```
kubectl -n lab10 get deploy quota-demo -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
#   ReplicaFailure=True FailedCreate
```

The Deployment does know. It records it in a **condition** that `kubectl get`
never prints. This is the habit worth building: when a Deployment will not reach
its replica count and no pod looks wrong, read its conditions and the
ReplicaSet's events.

And read the quota itself, which shows exactly which limit bound first:

```
kubectl -n lab10 describe resourcequota lab10-quota
#   pods             3      3      <-- this one
#   requests.memory  192Mi  384Mi  <-- plenty of headroom
```

Memory was never the constraint. The pod count was.

## Fix

```
./labs/10-why-wont-it-schedule/fix.sh
```

The fix raises the quota. It does **not** delete it — those are different
answers, and deleting the guardrail is how a namespace quietly eats a cluster.
The grader checks the quota still exists for exactly that reason.

**Then wait.** Raising the quota does not un-stick the Deployment immediately:
the ReplicaSet backs off exponentially after repeated `FailedCreate` and retries
on its own schedule. Measured on this cluster it took over three minutes of
nothing happening. That interval is not a second bug, and it is worth feeling
once — it is why "I fixed it and nothing changed" is so often premature.

## Check

```
./scripts/platform.sh lab 10
```

## Clean up

```
kubectl delete -f labs/10-why-wont-it-schedule/governance.yaml
```

## Worth knowing next

`PodDisruptionBudget` is the same idea aimed at voluntary disruption: it makes
`kubectl drain` refuse. A PDB with `minAvailable` equal to `replicas` deadlocks
a drain permanently — the same shape of bug as lab 07's rollout that can never
finish. It is not a lab here only because draining a node on a two-node teaching
cluster evicts the platform along with it.
