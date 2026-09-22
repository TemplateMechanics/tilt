# Read-only AI observability demo

The repository supplies three project-scoped MCP servers in [`.mcp.json`](../.mcp.json):

| Server | What to demonstrate | Safety boundary |
|---|---|---|
| `grafana` | Discover datasources, run PromQL, query Loki and Tempo, inspect dashboards | Server-enforced `--disable-write` plus a narrow tool-category list |
| `playwright` | Render `hello.localhost` or Kiali through the accessibility tree | Isolated profile, blocked service workers, local-origin request filter, and Claude deny rules for page input/evaluation/upload tools |
| `chrome-devtools` | Inspect console, requests, timings and a local performance trace | Isolated profile, local URL allowlist, JS evaluation off, sensitive headers redacted, telemetry and CrUX off, and Claude deny rules for input/upload/screenshot/audit tools |

The Grafana server is read-only at its own process boundary. The browser servers
are general automation products, so [`.claude/settings.json`](../.claude/settings.json)
denies page-input, upload, evaluation and unnecessary browser-state tools. The
origin filter narrows accidental requests but upstream explicitly does not call
the Playwright filter a security boundary. Navigation and diagnostic tools
remain enabled, so prompts must still stay on the documented local GET-only
workflow. Do not weaken those rules for the training demo.

## Why Claude Code is the demo client on this machine

Claude Code reads the checked-in `.mcp.json` and asks the user to approve
project servers on first use. Start it from the repository root so `${PWD}`
expands to this checkout.

Codex also supports MCP servers, but the managed policy on the instructor Mac
currently reports the local Grafana, Chrome DevTools and local-origin
Playwright servers as `disabled: requirements`. A project `.codex/config.toml`
cannot relax an enterprise policy. Confirm with `codex mcp list`; if that state
changes, a Codex-specific project configuration can be added later. Do not
replace this reproducible Claude configuration with a user-global exception.

Only this optional showcase needs Node.js and Claude Code. Install Node.js
`^20.19`, `^22.12`, or `>=23` (the Chrome DevTools MCP engine requirement) and
the current Claude Code CLI before the session. `npx` must be on `PATH`; it is
included with npm. The cluster and labs themselves do not require Node.js or
Claude Code.

## Pinned components

- Grafana MCP `1.5.1`, pinned to its multi-architecture image digest.
- Playwright MCP `0.0.80`. Upstream `0.0.82` is newer, but this machine enforces
  `NPM_CONFIG_MIN_RELEASE_AGE=14`; `0.0.80` is the newest admitted release for
  the training date. Do not bypass the package-age gate.
- Chrome DevTools MCP `1.9.0`.

Both npm servers use `.local/npm-cache`. The default npm cache on this Mac has
root-owned entries and is not a reliable training dependency.

## Grafana authentication

The local chart publishes the documented development credential `admin/admin`.
The MCP uses it because Grafana persistence is off: a service-account token is
deleted whenever the Grafana pod is recreated. This is acceptable only for
this disposable loopback-only platform.

The credential alone is privileged, so the server also applies two independent
tool-surface controls:

```text
--disable-write
--enabled-tools search,datasource,prometheus,loki,dashboard,navigation,tempo
```

That removes create, update, delete, arbitrary API and raw-SQL tools before the
client sees them. The live verifier fails if one of the known write tools is
ever exposed.

## Before the session

Bring up at least the observability profile and validate the current CA:

```bash
PROFILE=observability ./scripts/platform.sh up
./scripts/trust-ca.sh
security verify-cert -R require https://hello.localhost/
```

Then run the server verifier from a normal Terminal, not from a sandboxed
coding-agent shell:

```bash
./scripts/check-mcp.sh
```

It validates the safety pins, completes each MCP handshake, confirms that no
Grafana write tools are exposed, calls live Grafana, and opens
`https://hello.localhost` with both browser servers. To isolate a failure:

```bash
./scripts/check-mcp.sh --server grafana
./scripts/check-mcp.sh --server playwright
./scripts/check-mcp.sh --server chrome-devtools
```

Now start `claude` in the repository, approve the three project servers, and
use `/mcp` to confirm all three are connected. Claude reads `.mcp.json` only at
startup, so restart it after changing the file.

## Ten-minute showcase

### 1. Grafana MCP: establish the evidence

Ask:

> Use only the Grafana MCP. List the datasources, run `sum(up)` in Prometheus,
> then list Loki namespace values and show the latest five log lines for
> `{namespace="hello"}`. Do not call any write tool.

This demonstrates discovery before query and gives a current metric plus the
matching workload logs. A follow-up can search Tempo for recent `hello` traces.

### 2. Playwright MCP: check what a user gets

Ask:

> Use only Playwright. Open `https://hello.localhost`, report the page heading
> and serving pod, then report console errors and failed requests. Do not click,
> type, upload, evaluate JavaScript, or bypass certificate errors.

The page should render without an interstitial. That proves the real browser
accepts the current local CA; it is stronger evidence than `curl -k`.

### 3. Chrome DevTools MCP: inspect the browser side

Ask:

> Use only Chrome DevTools. Open `https://hello.localhost`, list network
> requests and console messages, inspect the document request status and
> timing, and take a local performance trace. Do not interact with the page.

CrUX is disabled deliberately: a `.localhost` URL must not be sent to an
external field-data service, and public field data would not exist for it
anyway.

### 4. Correlate the three views

Generate safe, visible signals:

```bash
for path in delay/1 delay/2 status/500 status/503; do
  curl -fsS "https://hello.localhost/$path" -o /dev/null || true
done
```

Then ask Grafana MCP for the recent `hello` errors and request-rate change, and
ask Chrome DevTools for the status/timing of a fresh `delay/1` request. The
teaching point is that browser symptoms, metrics, logs and traces are different
views of one request—not independent guesses.

## Expected startup warning

`hello` starts before the optional observability tier. During a fresh build it
can log `traces export ... produced zero addresses` until the Tempo Service
exists. On the validated cluster those messages stopped when Tempo became
Ready; DNS resolves, `/ready` succeeds and accepted spans increase. Treat older
lines in a one-hour Loki window as startup history, not a current outage.

## How the Grafana container reaches the cluster

The Gateway redirects HTTP to HTTPS, so `dev-ca-trust` exports the exact cluster
root to `.local/dev-root-ca.crt`. The container mounts that file and passes it
to `mcp-grafana` with `--tls-ca-file`; TLS verification stays enabled.

Docker Desktop's host networking reaches the kind ports, and the explicit host
entry maps `grafana.localhost` to that loopback path. The image's baked-in
entrypoint starts SSE, so `.mcp.json` must override it with
`--entrypoint /app/mcp-grafana` before selecting stdio. The static CI check
guards all of these otherwise easy-to-remove details.

## Alternate ports

The checked-in MCP config targets the default 443/80 topology used for the
training machine. If the cluster uses `kind/cluster-alt-ports.yaml`, make a
local, uncommitted copy of the MCP config and change the Grafana URL to
`https://grafana.localhost:8443`; the browser allowlists already include 8443
and the CRL's 8080 listener.
