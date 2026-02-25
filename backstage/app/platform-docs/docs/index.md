# Dev Platform

A comprehensive Kubernetes development environment using [Tilt](https://tilt.dev/), demonstrating three deployment patterns with 25+ services. Includes a [Backstage](https://backstage.io/) developer portal with a custom plugin that serves as a GUI control plane for toggling infrastructure on and off.

## Highlights

- **Three deployment patterns** — Crossplane XRDs, Flux HelmReleases, and raw Kubernetes manifests
- **Backstage developer portal** — Service catalog, infrastructure dashboard, and scaffolder templates
- **25+ services** — Databases, message brokers, CI/CD, AI/ML, cloud emulators, observability, and more
- **Config-driven** — Toggle services on/off via UI, API, or file edit with automatic Tilt reload
- **TLS everywhere** — Self-signed CA with wildcard `*.localhost` certificates

## Quick Start

```bash
# Prerequisites: Docker Desktop (with Kubernetes), Tilt, Helm, Flux CLI

# Start the environment
tilt up

# Access services at https://<service>.localhost
# Access the Tilt dashboard at http://localhost:10350
# Access the config API at http://tilt-config.localhost/config
```

## Project Structure

```
.
├── Tiltfile                    # Main orchestration file
├── tilt-config.json            # Service config (seed file, synced to ConfigMap)
├── scripts/
│   └── config-server.py        # REST API server (deployed as K8s pod)
├── apps/                       # Crossplane DevApplication claims
├── backstage/
│   ├── catalog/                # Backstage catalog entities
│   ├── plugins/tilt/           # Custom Backstage Tilt plugin
│   └── templates/              # Scaffolder templates
├── helm/
│   ├── repositories/           # Flux HelmRepositories
│   ├── crossplane/             # Crossplane core + providers + compositions
│   ├── backstage/              # Backstage K8s manifests
│   └── <service>/              # Service-specific manifests
├── certificates/               # TLS certificate generation
└── docs/                       # Additional documentation
```
