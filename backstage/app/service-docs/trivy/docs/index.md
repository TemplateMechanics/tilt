# Trivy Operator

Trivy Operator is a Kubernetes-native security scanner that continuously monitors your cluster for vulnerabilities, misconfigurations, and compliance issues.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `trivy-system` |
| **Type** | Vulnerability Scanner |
| **Default** | Disabled |
| **Config Key** | `flux_apps.trivy` |
| **Deployment** | Flux HelmRelease |
| **Chart** | `aquasecurity/trivy-operator` v0.28.1 |

## Official Documentation

- [Trivy Operator Documentation](https://aquasecurity.github.io/trivy-operator/)
- [Trivy Scanner](https://aquasecurity.github.io/trivy/)
- [Trivy Operator Helm Chart](https://github.com/aquasecurity/trivy-operator/tree/main/deploy/helm)
- [Custom Resource Definitions](https://aquasecurity.github.io/trivy-operator/latest/docs/crds/)

## Purpose

Trivy Operator automatically scans your Kubernetes workloads and produces security reports as Custom Resources:

| Report Type | CRD | Description |
|-------------|-----|-------------|
| **Vulnerability** | `VulnerabilityReport` | CVEs in container images |
| **Config Audit** | `ConfigAuditReport` | Kubernetes misconfigurations |
| **RBAC Assessment** | `RbacAssessmentReport` | Overly permissive RBAC roles |
| **Exposed Secrets** | `ExposedSecretReport` | Secrets in container images |
| **Infra Assessment** | `InfraAssessmentReport` | Node and cluster security |

## Enabling

```json
{
  "flux_apps": {
    "trivy": true
  }
}
```

## How It Works

```
┌─────────────────────────────────────┐
│       Trivy Operator Controller     │
│      (trivy-system namespace)       │
│                                     │
│  Watches for new/updated workloads  │
│  Creates scan Jobs automatically    │
└──────────┬──────────────────────────┘
           │ creates
┌──────────▼──────────────────────────┐
│         Scan Jobs                   │
│  (run in trivy-system namespace)    │
│  Pull images, scan for CVEs,       │
│  check configs, audit RBAC         │
└──────────┬──────────────────────────┘
           │ produces
┌──────────▼──────────────────────────┐
│     Security Reports (CRDs)         │
│  Stored in workload's namespace     │
│  VulnerabilityReport, etc.          │
└─────────────────────────────────────┘
```

## Scanning Modes

The operator runs in **standalone mode** (default), meaning scan jobs pull vulnerability databases directly from the internet. No separate Trivy server is required.

## Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| `scanJobsConcurrentLimit` | 3 | Max parallel scan jobs |
| `batchDeleteLimit` | 10 | Reports deleted per batch |
| `vulnerabilityScannerEnabled` | true | CVE scanning |
| `configAuditScannerEnabled` | true | K8s config checks |
| `rbacAssessmentScannerEnabled` | true | RBAC auditing |
| `exposedSecretScannerEnabled` | true | Secret detection |
| `infraAssessmentScannerEnabled` | true | Infrastructure checks |

## Grafana Dashboard

A Grafana dashboard is available in the **Security** folder showing:

- Vulnerability counts by severity (Critical/High/Medium/Low)
- Vulnerabilities by namespace (bar gauge)
- Severity distribution (pie chart)
- Top vulnerable images (table)
- Config audit and RBAC assessment findings

## ServiceMonitor

A ServiceMonitor scrapes Trivy Operator metrics on port 8080, exposing:

| Metric | Description |
|--------|-------------|
| `trivy_image_vulnerabilities` | Vulnerabilities per image by severity |
| `trivy_resource_configaudits` | Config audit findings per resource |
| `trivy_resource_rbacassessments` | RBAC assessment findings |
| `trivy_image_exposedsecrets` | Exposed secrets per image |

## Integration with Wazuh

Trivy Operator logs are collected by the Wazuh Filebeat DaemonSet with:

- Dedicated input with JSON parsing
- `security.source: trivy` field for identification
- Separate index: `filebeat-trivy-*`

## Querying Reports

```bash
# List vulnerability reports
kubectl get vulnerabilityreports -A

# View a specific report
kubectl get vulnerabilityreport -n <namespace> <name> -o yaml

# Count critical vulnerabilities across all namespaces
kubectl get vulnerabilityreports -A -o json | \
  jq '[.items[].report.summary.criticalCount] | add'

# List config audit reports
kubectl get configauditreports -A

# Check RBAC assessments
kubectl get rbacassessments -A
```

## Troubleshooting

```bash
# Check operator status
kubectl get pods -n trivy-system

# View operator logs
kubectl logs -n trivy-system -l app.kubernetes.io/name=trivy-operator --tail=50

# Check HelmRelease status
kubectl get helmrelease -n trivy-system

# View active scan jobs
kubectl get jobs -n trivy-system

# Check for failed scans
kubectl get jobs -n trivy-system --field-selector status.successful=0
```
