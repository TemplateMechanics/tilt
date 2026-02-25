# Keycloak

Keycloak is an open-source identity and access management solution providing SSO, OAuth 2.0, and OIDC.

## Overview

| Property | Value |
|----------|-------|
| **Namespace** | `keycloak` |
| **Type** | Identity & Access Management |
| **Default** | Disabled |
| **Config Key** | `raw_apps.keycloak` |
| **Console** | [keycloak.localhost](https://keycloak.localhost) |
| **Deployment** | Kustomize (raw manifests) |


## Official Documentation

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Admin REST API](https://www.keycloak.org/docs-api/latest/rest-api/index.html)
- [Server Administration Guide](https://www.keycloak.org/docs/latest/server_admin/)
- [Securing Applications](https://www.keycloak.org/docs/latest/securing_apps/)

## Architecture

```
┌─────────────────────────────────┐
│        Keycloak System          │
│                                 │
│  ┌───────────────────────────┐ │
│  │        Keycloak           │ │
│  │     :8080 (HTTP)          │ │
│  │   Admin Console + OIDC    │ │
│  └────────────┬──────────────┘ │
│               │                 │
│  ┌────────────▼──────────────┐ │
│  │      PostgreSQL           │ │
│  │   (realm/user data)       │ │
│  └───────────────────────────┘ │
└─────────────────────────────────┘
```

## Enabling

```json
{
  "raw_apps": {
    "keycloak": true
  }
}
```

## Accessing

- **Admin Console**: [https://keycloak.localhost](https://keycloak.localhost)
- **Default credentials**: `admin` / `admin`
- **OIDC Discovery**: `https://keycloak.localhost/realms/<realm>/.well-known/openid-configuration`

## Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Keycloak Admin | `admin` | `admin` |
| PostgreSQL | `keycloak` | `keycloak` |

## Common Operations

### Create a Realm

1. Login to Admin Console
2. Click dropdown next to "master" realm
3. Click "Create Realm"
4. Enter realm name and save

### Create a Client (for your app)

```bash
# Using the Admin REST API
curl -X POST "https://keycloak.localhost/admin/realms/master/clients" \
  -H "Authorization: Bearer $(curl -s -X POST 'https://keycloak.localhost/realms/master/protocol/openid-connect/token' \
    -d 'grant_type=password&client_id=admin-cli&username=admin&password=admin' | jq -r .access_token)" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "my-app",
    "redirectUris": ["http://localhost:3000/*"],
    "publicClient": true
  }'
```

### Get an Access Token

```bash
curl -X POST "https://keycloak.localhost/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin"
```

## Provided APIs

| API | Type | Description |
|-----|------|-------------|
| `keycloak-api` | REST/OIDC | Admin API, token endpoints, OIDC discovery |

## Dependencies

- `resource:keycloak-postgresql` — User and realm data storage

## Troubleshooting

```bash
# Check pods
kubectl get pods -n keycloak

# Keycloak logs
kubectl logs -n keycloak -l app=keycloak --tail=50

# Database connectivity
kubectl exec -n keycloak deploy/keycloak -- /opt/keycloak/bin/kc.sh show-config

# Test OIDC endpoint
curl https://keycloak.localhost/realms/master/.well-known/openid-configuration | jq .
```
