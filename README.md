# Project Tiltfile Overview

This document provides an overview of the Tiltfile used in this project for setting up the development environment using [Tilt](https://tilt.dev/).

## Prerequisites

Before you begin, ensure you have the following installed:

- **Tilt**: Follow the [installation guide](https://docs.tilt.dev/install.html) to install Tilt on your system.
- **Docker or Podman**: Required for building and running containerized services.
  - [Docker Installation Guide](https://docs.docker.com/get-docker/)
  - [Podman Installation Guide](https://podman.io/getting-started/installation)
- **Kubernetes Cluster**: A local cluster like [Minikube](https://minikube.sigs.k8s.io/docs/start/) or [Docker Desktop's Kubernetes](https://docs.docker.com/desktop/kubernetes/) is recommended for local development.
- **.NET SDK**: Necessary for building .NET services. Download it from the [.NET download page](https://dotnet.microsoft.com/download).
- **Helm**: Used for managing Kubernetes charts. Install it from the [Helm installation guide](https://helm.sh/docs/intro/install/).
- **Flux CLI**: Required for managing GitOps workflows. Install it from the [Flux installation guide](https://fluxcd.io/docs/installation/).
- **PowerShell Core**: For running cross-platform PowerShell scripts, including certificate generation.

## Loaded Extensions

The following Tilt extensions are loaded in the `Tiltfile`:

- **helm_remote**: For deploying remote Helm charts.
- **namespace**: To create Kubernetes namespaces.
- **cert_manager**: To deploy Cert Manager (currently utilized for certificate management).
- **git_resource**: To manage Git repositories as resources in Tilt.

## Helper Functions

### `get_os_type`
- **Purpose**: Detects the OS type (Windows, macOS, Linux) to handle OS-specific commands.

### `certificate_creation(service_name)`
- **Purpose**: Generates and installs SSL/TLS certificates using PowerShell scripts.
- **Steps**:
  1. Executes `generate-certs.ps1` to create certificates.
  2. Installs the generated certificates as Kubernetes secrets.

### `install_flux(service_name)`
- **Purpose**: Installs Flux using the `flux install` command.

### `k8s_namespace(namespace_name, allow_duplicates=False)`
- **Purpose**: Creates a Kubernetes namespace using a YAML snippet.
- **Parameters**:
  - `namespace_name`: Name of the namespace.
  - `allow_duplicates`: Allows reapplying the namespace without error.

### `k8s_helm(service_name, namespace)`
- **Purpose**: Deploys a Helm chart from the local `helm/` directory.
- **Parameters**:
  - `service_name`: Name of the service (also the Helm chart directory name).
  - `namespace`: Kubernetes namespace for deployment.

### `k8s_kustomize(path_to_dir, service_name, generate_link=False, flags=[])`
- **Purpose**: Deploys a Kustomize resource and optionally generates a local HTTPS link.
- **Parameters**:
  - `path_to_dir`: Path to the Kustomize directory.
  - `service_name`: Name of the service.
  - `generate_link`: If `True`, generates a local HTTPS link for the service.

### `remote_helm(service_name, repo_url, namespace, release_name, values)`
- **Purpose**: Deploys a Helm chart from a remote repository.
- **Parameters**:
  - `service_name`: Name of the service.
  - `repo_url`: URL of the Helm chart repository.
  - `namespace`: Kubernetes namespace for deployment.
  - `release_name`: Name of the Helm release.
  - `values`: Path to the Helm values file.

### `dotnet_service(service_name, publish_folder="publish", host_port=80, container_port=80)`
- **Purpose**: Builds and deploys a .NET service.
- **Steps**:
  1. Publishes the .NET project using `dotnet publish`.
  2. Builds a Docker image from the published output.
  3. Deploys the service to Kubernetes using a YAML manifest.
  4. Sets up port forwarding.

### `checkout_git_resource(name, repo_url, ref="master", subpath=None)`
- **Purpose**: Checks out a Git repository as a resource in Tilt.
- **Parameters**:
  - `name`: Resource name.
  - `repo_url`: Git repository URL.
  - `ref`: Branch or tag to checkout.
  - `subpath`: Subpath within the repository.

## Example Configurations

### Dockerfile for .NET:

```bash
FROM mcr.microsoft.com/dotnet/aspnet:7.0
COPY . /app/out
WORKDIR /app/out
ENTRYPOINT ["dotnet", "REPLACE_WITH_YOUR.dll"]
```

### Kubernetes YAML:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: YOUR_SERVICE_NAME
  namespace: YOUR_NAMESPACE
spec:
  selector:
    matchLabels:
      app: YOUR_SERVICE_NAME
  replicas: 1
  template:
    metadata:
      labels:
        app: YOUR_SERVICE_NAME
    spec:
      containers:
      - name: YOUR_SERVICE_NAME
        image: YOUR_SERVICE_NAME
        ports:
        - containerPort: 80
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: YOUR_SERVICE_NAME
  namespace: traefik
spec:
  entryPoints:
    - web
  routes:
  - match: Host(`YOUR_SERVICE_NAME.localhost`)
    kind: Rule
    services:
    - name: YOUR_SERVICE_NAME
      port: 80
```

## Example Usage

### Create Kubernetes Namespaces
```python
k8s_namespace("database")
k8s_namespace("flux")
k8s_namespace("traefik")
```

### Generate Certificates
```python
certificate_creation("dev")
```

### Install Flux
```python
install_flux("dev")
```

### Deploy a Local Helm Chart (e.g., MSSQL)
```python
k8s_helm(service_name="mssql", namespace="database")
```

### Deploy a Remote Helm Chart (e.g., Traefik)
```python
remote_helm(
    service_name="traefik",
    repo_url="https://helm.traefik.io/traefik",
    values="./helm/traefik.yaml",
    namespace="traefik",
    release_name="traefik"
)
```

### Deploy Kustomized Helm Resources
```python
k8s_kustomize("./helm/bitnami/", "bitnami", generate_link=False)
```

### Deploy a .NET Service
```python
dotnet_service("MyDotnetService", publish_folder="publish", host_port=8080, container_port=80)
```

## Dependencies

Ensure the following dependencies are met:

- **Tilt**: Version 0.23.2 or newer.
- **Docker**: Version 20.10.7 or newer.
- **Podman**: Version 3.0.0 or newer.
- **Kubernetes**: Version 1.21 or newer.
- **.NET SDK**: Version 5.0 or newer.
- **Helm**: Version 3.5.0 or newer.
- **Flux CLI**: Version 0.17.0 or newer.
- **PowerShell Core**: Latest version for cross-platform scripting.

## Common Issues

- **Port Conflicts**: If the default ports are in use, adjust the `host_port` in the `dotnet_service` function accordingly.
- **Dependency Errors**: Ensure all services are defined in the correct order, respecting their dependencies.
- **Certificate Generation Issues**: Ensure PowerShell Core is installed and accessible for running cross-platform scripts.

## Getting Help

For support, consider the following resources:

- **Tilt Documentation**: [https://docs.tilt.dev/](https://docs.tilt.dev/)
- **Kubernetes Slack**: Join the `#tilt` channel for real-time assistance.
- **GitHub Issues**: Report issues at [https://github.com/TemplateMechanics/tilt/issues](https://github.com/TemplateMechanics/tilt/issues)
