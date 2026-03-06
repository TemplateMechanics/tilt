# WordPress

WordPress is deployed as a demo CMS application with a MySQL 8.0 backend, providing a realistic web application for testing and development.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `wordpress` |
| **Type** | CMS / Demo App |
| **Default** | Disabled |
| **Config Key** | `raw_apps.wordpress` |
| **Deployment** | Raw Manifests (Kustomize) |
| **URL** | [wordpress.localhost](https://wordpress.localhost) |

## Official Documentation

- [WordPress Documentation](https://wordpress.org/documentation/)
- [WordPress Docker Image](https://hub.docker.com/_/wordpress)
- [MySQL Docker Image](https://hub.docker.com/_/mysql)

## Architecture

```
┌───────────────────────────┐
│       Traefik Ingress     │
│  wordpress.localhost:443  │
└─────────────┬─────────────┘
              │
┌─────────────▼─────────────┐
│   WordPress Deployment    │
│   (wordpress:6.4-apache)  │
│   Port: 80                │
│   Resources: 500m/512Mi   │
└─────────────┬─────────────┘
              │
┌─────────────▼─────────────┐
│   MySQL Deployment        │
│   (mysql:8.0)             │
│   Port: 3306              │
│   Resources: 500m/512Mi   │
└─────────────┬─────────────┘
              │
┌─────────────▼─────────────┐
│   Persistent Volumes      │
│   wordpress-data (5Gi)    │
│   mysql-data (5Gi)        │
└───────────────────────────┘
```

## Features

- **Full CMS**: Complete WordPress installation with themes and plugins
- **Persistent Storage**: Both WordPress and MySQL data survive restarts
- **Health Checks**: Liveness and readiness probes configured
- **Resource Limits**: CPU and memory limits prevent resource starvation

## Access

After enabling, visit [https://wordpress.localhost](https://wordpress.localhost) to complete the WordPress setup wizard.

Default MySQL credentials are configured in the deployment manifests.

## Enabling

```json
{
  "raw_apps": {
    "wordpress": true
  }
}
```
