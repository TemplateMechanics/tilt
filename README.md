# Project Tiltfile Overview

This document provides an overview of the Tiltfile used in this project for setting up the development environment using Tilt.

## .NET Service Configuration

### `dotnet_service` Function

- **Purpose**: Defines a Tilt configuration for building and running a .NET service.
- **Parameters**:
  - `service_name`: Name of the service.
  - `publish_folder`: Folder for the published output (default: "publish").
  - `host_port`: Port on the host machine (default: 80).
  - `container_port`: Port on the container (default: 80).

### Steps:
1. **Build Context**: Sets the context for the build, relative to the service name.
2. **Dotnet Publish**: Executes the `dotnet publish` command to compile the project.
3. **Docker Build**: Builds a Docker image for the service using the specified Dockerfile.
4. **Kubernetes Configuration**: Loads Kubernetes YAML for service deployment.
5. **Kubernetes Resource**: Sets up port forwarding and dependencies for the service.

## Example configurations
### Dockerfile for Dotnet:
```BASH
FROM mcr.microsoft.com/dotnet/aspnet:7.0
COPY . /app/out
WORKDIR /app/out
ENTRYPOINT ["dotnet", "REPLACE_WITH_YOUR.dll"]
```
### K8S YAML:
```YAML
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
## Kubernetes and Helm Configurations

### Namespaces
- Creates Kubernetes namespaces for `database`, `traefik`, and `cert-manager`.

### Database Deployment
- Deploys a Microsoft SQL Server using Helm chart configuration.

### Traefik Ingress Controller
- Deploys Traefik as an ingress controller using a remote Helm chart.

### Cert Manager (Commented Out)
- Code for deploying Cert Manager using a standard Helm chart (currently commented out).

## Notes
- Replace placeholders like `YOUR_SERVICE_NAME` and `YOUR_NAMESPACE` in the Kubernetes YAML configurations with actual values.
- Uncomment and configure the Cert Manager section if SSL/TLS certificates management is required.
- Ensure all paths (e.g., Helm chart paths) are correctly set relative to the Tiltfile's location.

## Example Files
- Example Dockerfile and Kubernetes YAML snippets are included as comments within the `dotnet_service` function.

## Extensions
- Uses Tilt extensions like `helm_remote` and `namespace` for additional functionalities.

---

For more detailed information on each configuration and how to customize it for your specific needs, refer to the respective official documentation for [.NET](https://docs.microsoft.com/en-us/dotnet/), [Docker](https://docs.docker.com/), [Kubernetes](https://kubernetes.io/), and [Helm](https://helm.sh/).
