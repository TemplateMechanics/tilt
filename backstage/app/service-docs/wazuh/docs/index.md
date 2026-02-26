# Wazuh SIEM

Wazuh is an open source security information and event management (SIEM) platform for threat detection, integrity monitoring, incident response, and compliance.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `wazuh` |
| **Type** | SIEM Platform |
| **Default** | Disabled |
| **Config Key** | `raw_apps.wazuh` |
| **Deployment** | Raw Manifests (Kustomize) |
| **Dashboard** | [wazuh.localhost](https://wazuh.localhost) |

## Official Documentation

- [Wazuh Documentation](https://documentation.wazuh.com/current/)
- [Wazuh Docker Deployment](https://documentation.wazuh.com/current/deployment-options/docker/)
- [Wazuh API Reference](https://documentation.wazuh.com/current/user-manual/api/reference.html)
- [Wazuh Ruleset](https://documentation.wazuh.com/current/user-manual/ruleset/)

## Architecture

Wazuh is deployed as a three-component stack with a Filebeat DaemonSet for log collection:

```
┌─────────────────────────────────────┐
│          Wazuh Dashboard            │
│    (OpenSearch Dashboards :5601)    │
│    https://wazuh.localhost          │
└──────────────┬──────────────────────┘
               │ queries
┌──────────────▼──────────────────────┐
│          Wazuh Indexer              │
│       (OpenSearch :9200)            │
│    Security event storage           │
└──────────────▲──────────────────────┘
               │ ships events
┌──────────────┴──────────────────────┐
│          Wazuh Manager              │
│      (API :55000 / Syslog :514)     │
│    Event processing & analysis      │
└──────────────▲──────────────────────┘
               │ sends logs
┌──────────────┴──────────────────────┐
│       Filebeat DaemonSet            │
│   Collects K8s container logs       │
│   Dedicated inputs for:            │
│   • General containers             │
│   • Falco events → falco index     │
│   • Trivy reports → trivy index    │
└─────────────────────────────────────┘
```

## Components

| Component | Type | Description |
|-----------|------|-------------|
| **Indexer** | StatefulSet | OpenSearch-based event storage (single-node, security disabled for dev) |
| **Manager** | StatefulSet | Core SIEM engine — processes events, runs rules, manages agents |
| **Dashboard** | Deployment | Web UI built on OpenSearch Dashboards (port 5601) |
| **Filebeat** | DaemonSet | Collects all K8s container logs and ships to Indexer |

## Enabling

```json
{
  "raw_apps": {
    "wazuh": true
  }
}
```

## Log Collection

The Filebeat DaemonSet collects container logs from all nodes and routes them to separate indices:

| Source | Index Pattern | Description |
|--------|---------------|-------------|
| General containers | `filebeat-kubernetes-*` | All container logs (excluding Falco/Trivy) |
| Falco | `filebeat-falco-*` | Runtime security events with JSON parsing |
| Trivy | `filebeat-trivy-*` | Vulnerability scan results with JSON parsing |

## Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Dashboard | `admin` | `admin` |
| API | `wazuh-wui` | `MyS3cr3tP@ssw0rd` |

> **Note:** These are dev-only credentials. Replace with proper secrets management in production.

## Grafana Dashboard

A Grafana dashboard is available in the **Security** folder showing:

- Component health (Indexer, Manager, Dashboard pod status)
- Resource usage (CPU, memory, network, disk I/O)
- Loki log viewer for Wazuh pods

## Ports

| Port | Service | Protocol |
|------|---------|----------|
| 9200 | Indexer (OpenSearch API) | HTTP |
| 55000 | Manager (Wazuh API) | HTTPS |
| 1514 | Manager (Agent registration) | TCP |
| 514 | Manager (Syslog) | UDP |
| 5601 | Dashboard (Web UI) | HTTP |

## Related Services

| Service | Relationship |
|---------|-------------|
| **Falco** | Runtime security events collected by Wazuh Filebeat |
| **Trivy** | Vulnerability scan results collected by Wazuh Filebeat |
| **Prometheus/Grafana** | Monitoring dashboard for Wazuh components |
| **Loki** | Log aggregation (separate from Wazuh's own log pipeline) |

## Troubleshooting

```bash
# Check component status
kubectl get pods -n wazuh

# Check Indexer health
kubectl exec -n wazuh wazuh-indexer-0 -- curl -s http://localhost:9200/_cluster/health | jq

# Check Manager logs
kubectl logs -n wazuh -l app=wazuh-manager

# View Filebeat logs
kubectl logs -n wazuh -l app=wazuh-filebeat --tail=50

# Check indices in Indexer
kubectl exec -n wazuh wazuh-indexer-0 -- curl -s http://localhost:9200/_cat/indices?v
```
