# Lab 07 — Why did my database rollout hang?

**Profile:** minimal, plus the wordpress app · **Time:** 20 min · **You will
learn:** the one Deployment field that decides whether a stateful workload can
ever be updated.

This lab reproduces a real incident on this platform: 733 restarts, two days,
zero alerts.

## Setup

```
kubectl apply -k helm/wordpress
kubectl -n wordpress get pods -w        # wait for mysql and wordpress Running
```

## Break it

```
./labs/07-stateful-rollout/break.sh
kubectl -n wordpress get pods -w
```

You set `strategy: RollingUpdate` and restarted the mysql Deployment. Watch a
second mysql pod appear — and never become Ready. The first one keeps
running. WordPress keeps working. `readyReplicas` is 1. Everything is green.

```
kubectl -n wordpress logs -l app=mysql --tail=5 | grep -i lock
#   [ERROR] [InnoDB] Unable to lock ./ibdata1 error: 11
```

## Understand

RollingUpdate starts the new pod *before* stopping the old one. Both mount the
same ReadWriteOnce volume. The old pod holds InnoDB's file lock; the new pod
can never take it. Nothing is wrong enough to alert on, and nothing is right
enough to finish. It stays that way until someone looks.

`strategy: Recreate` stops the old pod first. For a single replica on one
volume it is the only correct choice — and the default is the wrong one.
(A StatefulSet is the fuller answer for databases; Recreate is the smallest
correct change.)

## Fix

```
./labs/07-stateful-rollout/fix.sh
```

Watch the stuck pod take the lock and become the only mysql pod. Note what
the fix *is*: re-applying the manifest. The declarative state was right the
whole time; the live state had drifted.

## Check

```
./scripts/platform.sh lab 07
```
