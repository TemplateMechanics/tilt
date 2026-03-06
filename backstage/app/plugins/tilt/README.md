# Backstage Tilt Plugin

A custom Backstage plugin that integrates with Tilt's API to manage local development services, providing a full GUI control plane for your infrastructure.

## Features

- **Infrastructure Dashboard**: Toggle services on/off from Backstage — changes persist to `tilt-config.json` and trigger automatic Tilt reload
- **Resource Dashboard**: View all Tilt resources and their status in a table
- **Trigger Actions**: Trigger rebuilds, enable/disable resources at runtime
- **Log Viewer**: Stream logs from Tilt resources
- **Catalog Integration**: Link Backstage catalog components to Tilt resources via `tilt.dev/resource` annotation
- **Category Grouping**: Services organized by category (Databases, AI/ML, Security, etc.) with toggle switches
- **Status Merging**: Combines config state (enabled/disabled) with live Tilt runtime status

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Backstage (in K8s)                        │
│  ┌──────────────────┐  ┌────────────────────────────────┐   │
│  │   TiltPage        │  │  InfrastructureDashboard       │   │
│  │  (resource table) │  │  (service toggles per category)│   │
│  └────────┬─────────┘  └─────────────┬──────────────────┘   │
│           │                          │                       │
│  ┌────────┴──────────────────────────┴──────────────────┐   │
│  │              TiltClient (API layer)                   │   │
│  └────────┬──────────────────────────┬──────────────────┘   │
└───────────┼──────────────────────────┼──────────────────────┘
            │                          │
   ┌────────▼────────┐     ┌──────────▼──────────┐
   │  Tilt API        │     │  Config Server       │
   │  :10350          │     │  :10351              │
   │  (runtime ctrl)  │     │  (tilt-config.json)  │
   └─────────────────┘     └─────────────────────┘
                                      │
                              ┌───────▼───────┐
                              │ tilt-config.json│
                              │ (watch_file)    │
                              └───────┬───────┘
                                      │
                              ┌───────▼───────┐
                              │   Tiltfile     │
                              │  (auto-reload) │
                              └───────────────┘
```

## Configuration

Add to your `app-config.yaml`:

```yaml
tilt:
  baseUrl: http://host.docker.internal:10350
  configServerUrl: http://host.docker.internal:10351
```

## Pages

### Infrastructure Dashboard (`/infra`)
Full control plane for toggling services. Services grouped by category with:
- Toggle switches (persisted to tilt-config.json)
- Runtime status indicators
- Trigger rebuild buttons
- Quick links to service UIs

### Tilt Resources (`/tilt`)
Table view of all Tilt resources with status, labels, and actions.

## Catalog Annotation

Link components to Tilt resources:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: harbor
  annotations:
    tilt.dev/resource: harbor-app
    dev.tilt/config-key: crossplane_apps.harbor
```

## API Endpoints Used

### Tilt API (port 10350)
- `GET /api/view` - Get all resources
- `POST /api/trigger` - Trigger resource rebuild
- `GET /api/logs/{resource}` - Stream resource logs
- `PATCH /api/override` - Enable/disable resources at runtime

### Config Server API (port 10351)
- `GET /config` - Get full infrastructure config
- `GET /config/{group}` - Get config for a group (crossplane_apps, flux_apps, raw_apps)
- `PUT /config` - Replace full config
- `PATCH /config` - Merge partial config updates (e.g., toggle one service)

## Development

```bash
cd plugins/tilt
yarn install
yarn start
```
