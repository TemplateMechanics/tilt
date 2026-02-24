#!/usr/bin/env python3
"""
Tilt Config Server — K8s-native

A lightweight HTTP server that manages Tilt infrastructure configuration.
Uses zero external dependencies (stdlib only).

Storage backends (auto-detected):
  - Kubernetes mode: Reads/writes a ConfigMap via the K8s API.
    Detected when running in a pod (service account token present).
  - File mode: Reads/writes tilt-config.json on disk.
    Used when running locally on the host for development.

Deployed as a K8s Deployment in the tilt-system namespace. Backstage
reaches it via the Backstage proxy plugin (in-cluster routing). A sync
loop on the host watches the ConfigMap and writes changes back to
tilt-config.json, which triggers Tilt reload via watch_file().

Endpoints:
  GET    /config           - Returns the full config
  GET    /config/{group}   - Returns config for a specific group
  PUT    /config           - Replaces the full config
  PATCH  /config           - Merges partial config updates
  GET    /health           - Health check
  OPTIONS *                - CORS preflight
"""

import json
import os
import sys
import ssl
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime

PORT = int(os.environ.get('TILT_CONFIG_PORT', '10351'))

# K8s detection
SA_TOKEN_PATH = '/var/run/secrets/kubernetes.io/serviceaccount/token'
SA_CA_PATH = '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'
K8S_HOST = os.environ.get('KUBERNETES_SERVICE_HOST', '')
K8S_PORT = os.environ.get('KUBERNETES_SERVICE_PORT', '443')
CONFIG_NAMESPACE = os.environ.get('CONFIG_NAMESPACE', 'tilt-system')
CONFIG_CONFIGMAP = os.environ.get('CONFIG_CONFIGMAP', 'tilt-config')
CONFIG_KEY = os.environ.get('CONFIG_KEY', 'config.json')

# File mode path (when running outside K8s)
CONFIG_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), '..', 'tilt-config.json'
)


def is_k8s_mode():
    """Detect if running inside a Kubernetes pod."""
    return os.path.exists(SA_TOKEN_PATH) and K8S_HOST != ''


# =============================================================================
# K8s ConfigMap Backend
# =============================================================================

class K8sConfigBackend:
    """Reads/writes config from a K8s ConfigMap using the in-cluster API."""

    def __init__(self):
        self.api_url = f'https://{K8S_HOST}:{K8S_PORT}'
        self.cm_url = (
            f'{self.api_url}/api/v1/namespaces/{CONFIG_NAMESPACE}'
            f'/configmaps/{CONFIG_CONFIGMAP}'
        )
        print(f'[config-server] K8s mode: {CONFIG_NAMESPACE}/{CONFIG_CONFIGMAP} '
              f'key={CONFIG_KEY}')

    def _headers(self, content_type='application/json'):
        with open(SA_TOKEN_PATH) as f:
            token = f.read().strip()
        return {
            'Authorization': f'Bearer {token}',
            'Content-Type': content_type,
            'Accept': 'application/json',
        }

    def _ssl_ctx(self):
        return ssl.create_default_context(cafile=SA_CA_PATH)

    def read(self):
        try:
            req = urllib.request.Request(self.cm_url, headers=self._headers())
            resp = urllib.request.urlopen(req, context=self._ssl_ctx())
            cm = json.loads(resp.read())
            config_str = cm.get('data', {}).get(CONFIG_KEY, '{}')
            return json.loads(config_str)
        except urllib.error.HTTPError as e:
            print(f'[config-server] K8s API error: {e.code} {e.reason}',
                  file=sys.stderr)
            if e.code == 404:
                return {"crossplane_apps": {}, "flux_apps": {}, "raw_apps": {}}
            return None
        except Exception as e:
            print(f'[config-server] Error reading ConfigMap: {e}',
                  file=sys.stderr)
            return None

    def write(self, data):
        try:
            patch = json.dumps({
                'data': {CONFIG_KEY: json.dumps(data, indent=2) + '\n'}
            }).encode('utf-8')
            req = urllib.request.Request(
                self.cm_url,
                data=patch,
                headers=self._headers('application/strategic-merge-patch+json'),
                method='PATCH',
            )
            urllib.request.urlopen(req, context=self._ssl_ctx())
            print(f'[config-server] ConfigMap updated at '
                  f'{datetime.now().isoformat()}')
            return True
        except Exception as e:
            print(f'[config-server] Error writing ConfigMap: {e}',
                  file=sys.stderr)
            return False


# =============================================================================
# File Backend (local development / fallback)
# =============================================================================

class FileConfigBackend:
    """Reads/writes config from a local JSON file."""

    def __init__(self, path):
        self.path = os.path.abspath(path)
        print(f'[config-server] File mode: {self.path}')

    def read(self):
        try:
            with open(self.path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            return {"crossplane_apps": {}, "flux_apps": {}, "raw_apps": {}}
        except json.JSONDecodeError as e:
            print(f'[config-server] JSON parse error: {e}', file=sys.stderr)
            return None

    def write(self, data):
        with open(self.path, 'w') as f:
            json.dump(data, f, indent=2)
            f.write('\n')
        print(f'[config-server] File updated at {datetime.now().isoformat()}')
        return True


# =============================================================================
# HTTP Handler
# =============================================================================

# Set by main() before server starts
backend = None


def deep_merge(base, override):
    """Recursively merge override into base."""
    result = base.copy()
    for key, value in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


class ConfigHandler(BaseHTTPRequestHandler):
    """HTTP request handler for config management."""

    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, PUT, PATCH, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Accept')
        self.send_header('Access-Control-Max-Age', '86400')

    def _json(self, status, data):
        body = json.dumps(data, indent=2).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    def _error(self, status, msg):
        self._json(status, {"error": msg})

    def _body(self):
        length = int(self.headers.get('Content-Length', 0))
        if length == 0:
            return None
        raw = self.rfile.read(length)
        try:
            return json.loads(raw)
        except json.JSONDecodeError as e:
            self._error(400, f'Invalid JSON: {e}')
            return None

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        path = self.path.rstrip('/')

        if path == '/health':
            mode = 'kubernetes' if is_k8s_mode() else 'file'
            self._json(200, {"status": "ok", "mode": mode})
            return

        if path == '/config':
            config = backend.read()
            if config is None:
                self._error(500, 'Failed to read config')
                return
            self._json(200, config)
            return

        parts = path.split('/')
        if len(parts) == 3 and parts[1] == 'config':
            config = backend.read()
            if config is None:
                self._error(500, 'Failed to read config')
                return
            group = parts[2]
            if group not in config:
                self._error(404, f"Group '{group}' not found")
                return
            self._json(200, config[group])
            return

        self._error(404, 'Not found')

    def do_PUT(self):
        if self.path.rstrip('/') != '/config':
            self._error(404, 'Not found')
            return
        data = self._body()
        if data is None:
            return
        valid = {'crossplane_apps', 'flux_apps', 'raw_apps'}
        if not isinstance(data, dict) or not valid.issubset(data.keys()):
            self._error(400, f'Config must contain keys: {valid}')
            return
        if not backend.write(data):
            self._error(500, 'Failed to write config')
            return
        self._json(200, {"status": "updated"})

    def do_PATCH(self):
        if self.path.rstrip('/') != '/config':
            self._error(404, 'Not found')
            return
        patch = self._body()
        if patch is None:
            return
        config = backend.read()
        if config is None:
            self._error(500, 'Failed to read config')
            return
        updated = deep_merge(config, patch)
        if not backend.write(updated):
            self._error(500, 'Failed to write config')
            return
        self._json(200, {"status": "updated"})

    def log_message(self, fmt, *args):
        print(f'[config-server] {self.address_string()} - {fmt % args}')


def main():
    global backend

    if is_k8s_mode():
        backend = K8sConfigBackend()
    else:
        backend = FileConfigBackend(CONFIG_FILE)

    server = HTTPServer(('0.0.0.0', PORT), ConfigHandler)
    print(f'[config-server] Listening on :{PORT}')
    print(f'  GET  /config   — Read config')
    print(f'  PATCH /config  — Update config')
    print(f'  GET  /health   — Health check')

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n[config-server] Shutting down...')
        server.shutdown()


if __name__ == '__main__':
    main()
