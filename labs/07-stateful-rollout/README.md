# Lab 07 — Why did my database rollout hang?

**Profile:** minimal · **Time:** 20 min · **You will learn:** the one Deployment
field that decides whether a stateful workload can ever be updated.

This lab reproduces a real incident on this platform: 733 restarts, two days,
zero alerts.

## Setup

```
kubectl apply -f labs/07-stateful-rollout/mysql.yaml
kubectl -n lab07 get pods -w            # wait for mysql to be Running and Ready
```

One namespace, one volume, one MySQL. Nothing needs enabling in
`tilt-config.json` — the lab owns its fixture.

## Break it

```
./labs/07-stateful-rollout/break.sh
kubectl -n lab07 get pods -w
```

You set `strategy: RollingUpdate` and restarted the Deployment. Watch a second
mysql pod appear — and never become Ready. The first one keeps running and keeps
serving. `readyReplicas` is 1. Everything is green.

```
kubectl -n lab07 logs -l app=mysql --tail=5 | grep -i lock
#   [ERROR] [InnoDB] Unable to lock ./ibdata1 error: 11
```

## Understand

RollingUpdate starts the new pod *before* stopping the old one. Both mount the
same ReadWriteOnce volume. The old pod holds InnoDB's file lock; the new pod can
never take it. Nothing is wrong enough to alert on, and nothing is right enough
to finish. It stays that way until someone looks.

`strategy: Recreate` stops the old pod first. For a single replica on one volume
it is the only correct choice — and the default is the wrong one. (A StatefulSet
is the fuller answer for databases; Recreate is the smallest correct change.)

Notice what the failure looked like from outside: a healthy service, a green
dashboard, and a rollout that had silently stopped meaning anything.

## Fix

```
./labs/07-stateful-rollout/fix.sh
```

Watch the stuck pod take the lock and become the only mysql pod. Note what the
fix *is*: re-applying the manifest. The declarative state was right the whole
time; the live state had drifted.

## Check

```
./scripts/platform.sh lab 07
```

The grader asks the database directly — `mysqladmin ping` — rather than asking
Kubernetes whether a pod is Ready. A Ready pod only means a probe passed.

## Clean up

```
kubectl delete -f labs/07-stateful-rollout/mysql.yaml
```
