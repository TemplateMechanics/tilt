# Grafana MCP server

Lets an agent query Grafana, Loki, Prometheus and Tempo directly as tools instead
of shelling out to `curl` with `--resolve`, a CA file and credentials on every
call. Verified against the `kind-tiltdev` cluster: 65 tools exposed, including
7 Loki tools (`query_loki_logs`, `list_loki_label_values`, `query_loki_stats`, …)
and 6 dashboard tools.

Config lives in [`.mcp.json`](../.mcp.json) at the repo root.

## Setup

The token is **not** committed. Create a Grafana service account token and export
it before starting Claude Code:

```bash
# 1. Create a Viewer service account + token (one time, per cluster)
GRAFANA=https://grafana.localhost   # add :8443 on the alternate-ports config
SAID=$(curl -sk -u admin:admin -X POST -H 'Content-Type: application/json' \
  -d '{"name":"claude-mcp","role":"Viewer","isDisabled":false}' \
  "$GRAFANA/api/serviceaccounts" | jq -r .id)

curl -sk -u admin:admin -X POST -H 'Content-Type: application/json' \
  -d '{"name":"claude-mcp-token"}' \
  "$GRAFANA/api/serviceaccounts/$SAID/tokens" | jq -r .key

# 2. Export it (add to your shell profile to persist)
export GRAFANA_SERVICE_ACCOUNT_TOKEN='<the key from step 1>'
```

Use **Viewer**, not Admin. The server exposes `update_dashboard`,
`create_datasource` and `delete_*` tools; a Viewer token makes those fail loudly
rather than letting an agent mutate the platform by accident.

## Why the config looks the way it does

Three things in `.mcp.json` are non-obvious and will break if "simplified":

**`--entrypoint /app/mcp-grafana`** — the image's baked-in entrypoint is
`--transport sse --address 0.0.0.0:8000`. Appending `--transport stdio` as an
argument does not override it; the server comes up on SSE and the MCP client
sees nothing on stdin/stdout. The entrypoint must be replaced.

**`--add-host=grafana.localhost:host-gateway`** — the container has to reach
Grafana through the Istio gateway published on the host. Note this only works
because the image is glibc-based: an alpine/musl container ignores the
`/etc/hosts` entry for `*.localhost` and resolves it to its own loopback, giving
`Failed to connect ... after 0 ms`. If the base image ever changes to alpine,
switch to `host.docker.internal` and add that hostname to the Gateway listener.

**`GRAFANA_SERVICE_ACCOUNT_TOKEN`, not `GRAFANA_API_KEY`** — the latter still
works but logs a deprecation warning on every start.

## Note for Git Bash on Windows

Running the `docker run` command by hand from Git Bash needs
`MSYS_NO_PATHCONV=1`, or MSYS rewrites `/app/mcp-grafana` into
`C:/Program Files/Git/app/mcp-grafana` and the container exits 127. Claude Code
invokes `docker` directly rather than through a shell, so `.mcp.json` is
unaffected.

## Port note

`GRAFANA_URL` uses `http://grafana.localhost` — plain HTTP on the kind host-port
mapping (append `:8080` if you run the alternate-ports kind config). HTTPS would need the local root CA mounted into the container.
Traffic stays on the loopback interface of the developer's own machine, and the
token is a Viewer credential on a local dev cluster. This is also the Docker Desktop address.
