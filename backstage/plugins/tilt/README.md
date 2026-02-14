# Backstage Tilt Plugin

A custom Backstage plugin that integrates with Tilt's API to manage local development services.

## Features

- **Resource Dashboard**: View all Tilt resources and their status
- **Trigger Actions**: Trigger rebuilds, enable/disable resources
- **Log Viewer**: Stream logs from Tilt resources
- **Catalog Integration**: Link Backstage catalog components to Tilt resources via `tilt.dev/resource` annotation

## Configuration

Add to your `app-config.yaml`:

```yaml
tilt:
  baseUrl: http://host.docker.internal:10350
```

## Catalog Annotation

Link components to Tilt resources:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: harbor
  annotations:
    tilt.dev/resource: harbor-app
```

## API Endpoints Used

- `GET /api/view` - Get all resources
- `POST /api/trigger` - Trigger resource rebuild
- `GET /api/logs/{resource}` - Stream resource logs
- `PATCH /api/override` - Enable/disable resources

## Development

```bash
cd plugins/tilt
yarn install
yarn start
```
