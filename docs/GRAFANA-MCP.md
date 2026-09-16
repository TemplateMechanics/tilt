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

`GRAFANA_URL` uses `https://grafana.localhost` — the gateway redirects plaintext, so the MCP verifies TLS against the platform CA (see below)
mapping (append `:8080` if you run the alternate-ports kind config). HTTPS would need the local root CA mounted into the container.
Traffic stays on the loopback interface of the developer's own machine, and the
token is a Viewer credential on a local dev cluster. This is also the Docker Desktop address.

## Networking, and why it is `--network host`

The container previously used `--add-host=grafana.localhost:host-gateway` over
plain HTTP. Both halves of that stopped being true:

- The platform now redirects port 80 to 443, so the MCP must speak HTTPS and
  must therefore trust the platform CA. `dev-ca-trust` writes it to
  `.local/dev-root-ca.crt` on every `up`, and the container mounts that file
  and is pointed at it with `--tls-ca-file`. A `mktemp` path would work once
  and then silently break, which is why the export has a stable home.
- `host-gateway` resolves to an IPv6 address on this machine that cannot reach
  the kind port mappings. Measured: every request from the container failed to
  connect, on port 80 as well as 443, while the identical URL worked from the
  host. `--network host` puts the container on the Docker VM's network, where
  kind publishes 80 and 443, and `--add-host=grafana.localhost:127.0.0.1` gives
  it the name. Verified end to end: the MCP starts, resolves, completes the TLS
  handshake against the platform CA, and reaches the Grafana API.

## The other two servers

`playwright` and `chrome-devtools` are there to QA deployed services: render a
page in a real browser, read the console and the failed requests, and look at
what a user would see. `scripts/validate/browser-check.mjs` already does this
non-interactively for every service in `services.json`; the MCP servers are for
poking at one service by hand when a check fails and you want to know why.

Neither needs configuration. Both are fetched by `npx` on first use.
