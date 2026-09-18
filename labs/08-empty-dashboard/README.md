# Lab 08 — The dashboard that lies

**Profile:** observability · **Time:** 20 min · **You will learn:** why an empty
graph is not the same as a quiet system, and where to look instead.

Every other lab breaks the thing you are watching. This one breaks the watching.

This is not a hypothetical. Three separate dashboards in this repo were empty
for exactly this reason, on healthy components: the Argo CD monitor asked for a
port named `metrics` while every argocd service publishes `http-metrics`; the
Loki monitor selected `app: loki` after the chart moved to
`app.kubernetes.io/name`; cert-manager had no monitor at all. In each case
Kubernetes was content, Prometheus reported nothing wrong, and eighteen panels
read as a calm, healthy system.

## Setup

```
kubectl apply -f labs/08-empty-dashboard/servicemonitor.yaml
./scripts/platform.sh lab 08          # should pass 4/4
```

The hello app already serves Prometheus metrics; this just tells Prometheus to
collect them.

## Break it

```
./labs/08-empty-dashboard/break.sh
```

That points the ServiceMonitor at a port named `metrics`. The hello Service
publishes its port as `http`, so no such port exists.

Now look at everything you would normally check:

```
kubectl -n monitoring get servicemonitor hello     # exists, Age climbing, no events
kubectl -n hello get pods                          # Running, Ready
kubectl -n hello logs -l app.kubernetes.io/name=hello --tail=5
```

All fine. Nothing anywhere says a word about the problem.

## Understand

A ServiceMonitor names a port **by name**, and it selects **Services** by their
labels — not pods, and not by the port number. Get either wrong and the
Prometheus Operator does exactly what you asked: it finds no matching port,
generates no scrape target, and does not consider that an error. There is
nothing to alert on, because from the cluster's point of view nothing failed.

The only place the truth appears is Prometheus itself:

```
https://prometheus.localhost/targets       (admin / admin)
```

Search for `hello`. Before the break there is a target. After it, there is not.
That page — not the dashboard — is the first thing to open when a graph is
empty.

Two more things worth knowing:

- **Stale data hides it for ~5 minutes.** Prometheus keeps serving the last
  sample after scraping stops, so `count({job="hello"})` still returns data long
  after the target is gone. This lab's grader checks how long ago the last
  scrape happened, not merely whether series exist. Freshness and existence are
  different questions.
- **Prometheus reloads on a timer.** Changes take up to a minute to appear.
  Testing immediately and concluding "my fix did nothing" is its own trap.

## Fix

```
./labs/08-empty-dashboard/fix.sh
```

Re-applies the manifest. The file was right the whole time; the live object had
drifted — same shape as lab 07.

## Check

```
./scripts/platform.sh lab 08
```

The grader asserts four separate facts, and they are deliberately not the same
fact: the object exists, the port it names actually exists on the Service,
Prometheus has a healthy target, and the data is fresh. The first can pass while
the other three fail. That gap is the whole lesson.

## Clean up

```
kubectl delete -f labs/08-empty-dashboard/servicemonitor.yaml
```
