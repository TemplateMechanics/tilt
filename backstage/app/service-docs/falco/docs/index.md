# Falco

Falco is a cloud-native runtime security tool that detects anomalous activity in containers, hosts, Kubernetes, and cloud environments.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `falco` |
| **Type** | Runtime Security |
| **Default** | Disabled |
| **Config Key** | `flux_apps.falco` |
| **Deployment** | Flux HelmRelease |
| **Chart** | `falcosecurity/falco` v7.0.1 |

## Official Documentation

- [Falco Documentation](https://falco.org/docs/)
- [Falco Rules Reference](https://falco.org/docs/reference/rules/)
- [Falcosidekick Documentation](https://github.com/falcosecurity/falcosidekick)
- [Falco Helm Chart](https://github.com/falcosecurity/charts)

## Purpose

Falco monitors system calls at the kernel level to detect:

- Unexpected process execution in containers
- Privilege escalation attempts
- Unauthorized file access (e.g., reading `/etc/shadow`)
- Suspicious network activity
- Container escape attempts
- Kubernetes API abuse

## Architecture

```
┌─────────────────────────────────┐
│     Falco DaemonSet             │
│  (runs on every node)           │
│  Monitors syscalls via eBPF     │
└──────────┬──────────────────────┘
           │ events
┌──────────▼──────────────────────┐
│     Falcosidekick               │
│  Event forwarder & enricher     │
│  Exposes Prometheus metrics     │
│  (:2801 API / :8082 metrics)    │
└──────────┬──────────────────────┘
           │
    ┌──────┴──────┐
    ▼             ▼
Prometheus    Wazuh Filebeat
(metrics)     (log collection)
```

## Enabling

```json
{
  "flux_apps": {
    "falco": true
  }
}
```

## Falcosidekick

Falcosidekick is enabled as a sidecar that:

- Receives events from Falco
- Exposes Prometheus metrics on port 8082
- Provides a REST API on port 2801

### Prometheus Metrics

| Metric | Description |
|--------|-------------|
| `falcosidekick_inputs_total` | Total events received by priority |
| `falcosidekick_outputs_total` | Events forwarded to each output |

## Grafana Dashboard

A Grafana dashboard is available in the **Security** folder showing:

- Total events and breakdown by priority (Emergency/Critical/Warning/Notice)
- Event trends over time by priority and rule
- Falcosidekick output destination stats
- Loki log viewer for Falco pods

## ServiceMonitor

Two ServiceMonitors scrape metrics from:

- **falco-exporter** — kernel-level event metrics
- **falcosidekick** — event forwarding and output metrics

## Integration with Wazuh

Falco container logs are collected by the Wazuh Filebeat DaemonSet with:

- Dedicated input with JSON parsing
- `security.source: falco` field for identification
- Separate index: `filebeat-falco-*`

## Default Rules

Falco ships with rules for detecting:

| Category | Examples |
|----------|----------|
| **Container** | Shell spawned, sensitive mount, privilege escalation |
| **File** | `/etc/shadow` read, binary directory write |
| **Network** | Unexpected outbound, DNS tunneling |
| **Kubernetes** | Anonymous API access, pod exec, configmap access |
| **Process** | Crypto mining, reverse shell, suspicious binary |

## Troubleshooting

```bash
# Check Falco pods
kubectl get pods -n falco

# View Falco alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50

# Check Falcosidekick
kubectl logs -n falco -l app.kubernetes.io/name=falcosidekick --tail=20

# View HelmRelease status
kubectl get helmrelease -n falco

# Trigger a test alert (exec into any pod)
kubectl exec -it -n default <pod> -- cat /etc/shadow
```
