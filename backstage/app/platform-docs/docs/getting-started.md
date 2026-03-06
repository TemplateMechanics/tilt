# Getting Started

## Prerequisites

| Tool | Version | Installation |
|------|---------|--------------|
| Docker Desktop | Latest | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Kubernetes | 1.25+ | Enable in Docker Desktop |
| Git | Latest | [git-scm.com](https://git-scm.com/) (**required on Windows** — provides Git Bash) |
| Tilt | 0.33+ | [docs.tilt.dev](https://docs.tilt.dev/install.html) |
| Helm | 3.12+ | [helm.sh](https://helm.sh/docs/intro/install/) |
| Flux CLI | 2.0+ | `brew install fluxcd/tap/flux` (macOS) / `choco install flux -y` (Windows) |
| kubectl | 1.25+ | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |

> **Windows users**: See the [Windows Setup](windows.md) guide for detailed instructions, including Chocolatey-based installation and WSL conflict resolution.

## Starting the Environment

```bash
# Clone the repository
git clone https://github.com/TemplateMechanics/tilt.git
cd tilt

# Start everything
tilt up
```

Tilt will:

1. Install Flux and wait for all controllers to be ready
2. Apply HelmRepositories for chart sources
3. Deploy Crossplane core and providers
4. Generate and trust TLS certificates for `*.localhost`
5. Deploy all enabled services based on `tilt-config.json`

## Accessing Services

All services are exposed via Traefik ingress at `https://<service>.localhost`:

| Service | URL |
|---------|-----|
| Backstage | [backstage.localhost](https://backstage.localhost) |
| Traefik Dashboard | [traefik.localhost/dashboard/](https://traefik.localhost/dashboard/) |
| Harbor | [harbor.localhost](https://harbor.localhost) |
| Jenkins | [jenkins.localhost](https://jenkins.localhost) |
| Prometheus | [prometheus.localhost](https://prometheus.localhost) |
| RabbitMQ | [rabbitmq.localhost](https://rabbitmq.localhost) |
| Airflow | [airflow.localhost](https://airflow.localhost) |
| Config API | [tilt-config.localhost](http://tilt-config.localhost/config) |

## Enabling / Disabling Services

Services can be toggled three ways:

### 1. Backstage Infrastructure Dashboard

Navigate to [backstage.localhost/infra](https://backstage.localhost/infra) and use the toggle switches.

### 2. Config API

```bash
# Enable Redis
curl -X PATCH http://tilt-config.localhost/config \
  -H 'Content-Type: application/json' \
  -d '{"raw_apps":{"redis":{"enabled":true}}}'
```

### 3. Edit tilt-config.json

Edit the file directly — Tilt watches it and auto-reloads:

```json
{
  "raw_apps": {
    "redis": { "enabled": true }
  }
}
```

## Tilt Dashboard

The Tilt web UI at [localhost:10350](http://localhost:10350) shows all resources, their status, build history, and logs.
