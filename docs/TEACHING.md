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

`verify-labs.sh` is the one that matters. It applies each lab's fixture, grades
it, breaks it, checks the grader **fails**, fixes it and grades again. Labs 05
and 06 were both silently unpassable for weeks before this existed — a grader
that is never run is indistinguishable from one that passes.

It does not cover 02, 05 and 06: they need a certificate reissue, sustained load
and a Flagger canary respectively. Walk those by hand the day before.

Also worth doing once:

```bash
./scripts/platform.sh check       # renders every service in a real browser
./scripts/check-mcp.sh            # if you plan to demo the Grafana MCP
```

If you will show the AI Ops dashboard, give its trace tables something to show.
They list only slow (>250ms) and failed traces, and a quiet platform has
neither, so the tables are empty unless you make some:

```bash
for p in delay/1 delay/2 status/500 status/503; do curl -sk https://hello.localhost/$p -o /dev/null; done
```

hello is the only workload emitting spans. An empty table means nobody sent a
slow request in the time range, not that tracing is broken.

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

About a minute to an empty cluster, then the profile build. This is what makes
it safe to let people break things — say so early, because learners are far more
willing to experiment once they know the environment is disposable.

Lab fixtures live in their own namespaces (`lab07`, `lab09`, `lab10`) and can be
deleted individually without touching the platform.

## Things learners reliably get wrong

- **Testing immediately after a fix.** Prometheus reloads on a timer, kindnet
  applies NetworkPolicy in 30–60s, cert-manager reissues in ~30s, and a
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
Have people run `./scripts/platform.sh up` *before* they arrive; the first run
pulls a lot of images.

## If you extend it

Every grader in `labs/` has been run against a deliberately broken state before
being trusted, and each `check.sh` asserts several *different* facts rather than
one fact several ways. Keep that. A check that cannot fail reads as evidence and
is worse than no check at all.

When you add a lab, add it to `scripts/verify-labs.sh` too — otherwise it joins
the set that nobody runs.
