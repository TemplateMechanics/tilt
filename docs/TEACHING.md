# Teaching from this platform

Everything here is written for the person running the session, not the learner.
The learner-facing material is `labs/`.

## The shape of the course

The labs are ordered so each one needs only what came before. All ten run on a
single kind cluster on a laptop.

| # | Lab | Profile | The idea it leaves behind |
|---|---|---|---|
| 01 | Deploy a service | minimal | which of the four objects is broken when a URL does not work |
| 02 | Route a hostname | minimal | a missing SAN is a *hostname mismatch* (62), not a trust problem |
| 03 | Join the mesh | observability | mesh membership is invisible from the app; the pod annotation is the proof |
| 04 | Break TLS | minimal | 62 vs 20: identical in a browser, opposite fixes |
| 05 | Scale it | observability | an HPA with no Metrics API is installed and inert |
| 06 | Canary | gitops | Flagger promotes a good version and refuses a bad one |
| 07 | Stateful rollout | minimal | RollingUpdate on one RWO volume can never finish |
| 08 | The dashboard that lies | observability | an empty graph is not a quiet system |
| 09 | Why did it restart? | minimal | two crashes, same exit code, opposite fixes |
| 10 | Why won't it schedule? | minimal | admission-time failures the object never mentions |

There is one idea underneath all of them, and it is worth saying out loud on day
one: **the dangerous failures are the quiet ones.** Every lab is a system that
looks healthy and is not. Labs 08, 09 and 10 exist because those exact failures
cost real days on this platform.

## Before a session

```bash
./scripts/platform.sh up          # minimal, ~10 min on a warm machine
./scripts/verify-labs.sh          # runs each automated lab broken AND fixed
```

Allow about twenty minutes for `verify-labs.sh` (measured: 18 and 22 minutes
on two runs); start it before you set up the room, not after.

`verify-labs.sh` is the one that matters. It applies each lab's fixture, grades
it, breaks it, checks the grader **fails**, fixes it and grades again. Labs 05
and 06 were both silently unpassable for weeks before this existed — a grader
that is never run is indistinguishable from one that passes.

It does not cover 02, 05 and 06: they need a certificate reissue, sustained load
and a Flagger canary respectively. Walk those by hand the day before.

Also worth doing once:

```bash
./scripts/student-check.sh         # includes both CRLs and host-native trust
./scripts/platform.sh check       # renders every service in a real browser
./scripts/check-mcp.sh            # if you plan to demo the three MCP servers
```

On a managed Mac, Chrome may require online revocation for a locally installed
root. A trusted root by itself is therefore not the readiness gate. Before the
session, require the complete chain to pass:

```bash
security verify-cert -R require https://hello.localhost/
curl -fsS http://crl.localhost/root.crl | openssl crl -inform DER -noout -nextupdate
curl -fsS http://crl.localhost/intermediate.crl | openssl crl -inform DER -noout -nextupdate
```

If that fails, make sure `local-ca-crls` is green in Tilt, then run
`./scripts/trust-ca.sh`. It installs the exact current root in the user's login
keychain and refuses to report success until required-revocation verification
passes. Do not teach learners to bypass the Chrome interstitial.

If you will show the AI Ops dashboard, give its trace tables something to show.
They list only slow (>250ms) and failed traces, and a quiet platform has
neither, so the tables are empty unless you make some:

```bash
for p in delay/1 delay/2 status/500 status/503; do curl -fsS https://hello.localhost/$p -o /dev/null || true; done
```

The dashboard intentionally uses manual refresh because its one-hour,
all-namespace view fans out into several Loki queries. Generate the signals,
then use Grafana's refresh control once rather than enabling auto-refresh.

hello is the only workload emitting spans. An empty table means nobody sent a
slow request in the time range, not that tracing is broken.

## AI-assisted observability showcase

The repository includes project-scoped Grafana, Playwright and Chrome DevTools
MCP servers. Use the [read-only showcase runbook](GRAFANA-MCP.md) rather than
improvising configuration during the session. Its Grafana surface is enforced
read-only, browser mutation tools are denied in the project settings, package
versions are pinned, and browser access is limited to the local demo routes.
The Playwright origin filter is a request guardrail, not a security boundary,
and upstream notes that it does not affect redirects. Service workers are
blocked, mutation tools stay denied, and demo prompts must remain on the local
GET-only routes.

Run the complete live gate from a normal Terminal before teaching:

```bash
./scripts/check-mcp.sh
```

On the managed instructor Mac, use Claude Code for this segment. `codex mcp
list` currently shows the required local servers disabled by enterprise policy;
a project config cannot override that. The runbook includes exact prompts that
correlate one request across the browser, Prometheus, Loki and Tempo.

## Profiles, and what to start

`up` defaults to `minimal`: Flux, Gateway API, Istio ambient, cert-manager, the
gateway and hello-world. That is the ten-minute path and enough for labs 01, 02,
04, 07, 09 and 10.

```bash
PROFILE=observability ./scripts/platform.sh up   # adds Prometheus/Grafana/Loki/Tempo/Kiali — labs 03, 05, 08
PROFILE=gitops        ./scripts/platform.sh up   # adds Crossplane, Flagger, ESO, CNPG — lab 06
PROFILE=full          ./scripts/platform.sh up   # adds the toggleable app catalogue
```

Only Headlamp is enabled in `tilt-config.json` by default. Everything else is
off deliberately: `full` with the whole catalogue on is roughly 100 pods, which
is a demo of the catalogue, not a teaching environment. Turn on what you intend
to show.

## Resetting between cohorts

```bash
./scripts/platform.sh reset       # destroys the cluster and rebuilds it empty
```

Measured on this machine: 4m55s to an empty cluster, then 8m29s more before
hello.localhost answered. The heavier profiles keep building for a while after
that. Budget accordingly — a reset is not a coffee break, and almost all of it
is image pulls, so a slow connection makes it worse.

That it is disposable at all is what makes it safe to let people break things —
say so early, because learners are far more willing to experiment once they
know the environment can be thrown away.

Lab fixtures live in their own namespaces (`lab07`, `lab09`, `lab10`) and can be
deleted individually without touching the platform.

## When a learner is stuck, and the clock is running

`./scripts/platform.sh reset` is the guaranteed fix, and it costs a full
rebuild, so it is the wrong answer during a session. Each lab can be put back
on its own:

| Lab | Put it back with |
|---|---|
| 01 | `kubectl apply -k examples/hello-world` |
| 02 | `git checkout -- examples/hello-world/httproute.yaml helm/istio/gateway/base/certificate.yaml` (Tilt re-applies) |
| 03 | `kubectl label ns hello istio.io/dataplane-mode=ambient --overwrite && kubectl -n hello rollout restart deploy/hello` |
| 04 | `./labs/04-break-tls/fix.sh` |
| 05 | `kubectl delete -f labs/05-scale-it/hpa.yaml && kubectl apply -k examples/hello-world` (deleting the HPA alone leaves 4 replicas) |
| 06 | the "Leaving the lab" block in its README - deleting the Canary alone leaves `hello.localhost` returning 500 |
| 07-10 | `./labs/NN-*/fix.sh` |

Lab 06 is the one to watch. It hands `hello` to Flagger, and labs 01-05 fail
until it is exited properly. If someone runs it early, that is what has
happened to their cluster.

## Things learners reliably get wrong

- **Testing immediately after a fix.** Prometheus reloads on a timer, kindnet
  applies NetworkPolicy in 30–60s, cert-manager reissues in 5–15s (measured
  twice here: 5s and 13s; the labs say "wait ~30s" to be safe), and a
  ReplicaSet that has been failing backs off for minutes. "I fixed it and
  nothing happened" is usually impatience. Lab 10 makes them feel it.
- **Reading `kubectl get` and stopping.** Quota rejections live in events and in
  a Deployment *condition*; `get` prints neither.
- **Trusting a green dashboard.** See lab 08. Also worth demoing live: the Istio
  panels list every service the gateway has ever proxied since it started, so a
  deleted app still appears in the legend with a rate of zero. A remembered
  counter looks exactly like a live one.
- **Assuming the exit code identifies the cause.** Lab 09: both crashes are 137.

## Running it on someone else's laptop

`platform.sh` is bash. On Windows that means Git Bash, not PowerShell — see the
README prerequisites. Docker Desktop is the tested default; Podman works and
needs a WSL kernel carrying `nft_fib_inet` (see `docs/CONTAINER-RUNTIMES.md`).
On Windows, the first `up` on a new cluster raises a dialog asking to trust
the cluster's root CA. Unanswered, it used to stall the whole build
indefinitely (a `tilt ci` run gave up at its 30-minute timeout with 23
resources queued behind it); now it fails that one step after two minutes, the
build carries on, and `./scripts/trust-ca.sh` finishes the job. Tell people to
expect it.

Send people [STUDENT-SETUP.md](STUDENT-SETUP.md) a few days ahead. It walks
them through installing the tools, building the cluster at home, and running
`./scripts/student-check.sh`, which verifies the platform actually answers a
request rather than merely having installed. Ask for that script's output from
anyone you have not taught before; it turns "it didn't work" on the morning
into a fixable email the week before.

## If you extend it

Every grader in `labs/` has been run against a deliberately broken state before
being trusted, and each `check.sh` asserts several *different* facts rather than
one fact several ways. Keep that. A check that cannot fail reads as evidence and
is worse than no check at all.

When you add a lab, add it to `scripts/verify-labs.sh` too — otherwise it joins
the set that nobody runs.
