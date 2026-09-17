# Labs

Every script here is bash. On macOS and Linux that is your shell already; on
Windows run them from Git Bash, not PowerShell.

Numbered exercises, each with a README that explains one thing and a
`check.sh` that proves you did it. Run a grader with
`./scripts/platform.sh lab NN`.

`./scripts/platform.sh test` runs the graders that hold in the platform's
steady state — 01, 03, and 07 once its fixture is applied. The others stage
something first (a second route, a broken cert, an HPA under load, a Canary)
and are run by hand after their README; 06 in particular hands `hello` to
Flagger and must be exited before 01 and 03 pass again.

| Lab | Profile | The thing you leave knowing |
|---|---|---|
| [01 Deploy a service](01-deploy-a-service/) | minimal | which of the four objects is failing when a URL does not work |
| [02 Route a hostname](02-route-a-hostname/) | minimal | a missing SAN is a *hostname mismatch* (62), not a trust problem |
| [03 Join the mesh](03-join-the-mesh/) | observability | mesh membership is invisible from the app; the pod annotation is the proof |
| [04 Break TLS](04-break-tls/) | minimal | 62 vs 20: same browser error, opposite fixes |
| [05 Scale it](05-scale-it/) | observability | an HPA with no Metrics API is installed and inert |
| [06 Canary](06-canary/) | gitops | Flagger promotes a good version and rolls back a bad one, on the Gateway you built |
| [07 Stateful rollout](07-stateful-rollout/) | minimal | RollingUpdate on one PVC can never finish; Recreate can |
| [08 The dashboard that lies](08-empty-dashboard/) | observability | an empty graph is not a quiet system; a ServiceMonitor can be accepted and scrape nothing |
| [09 Why did it restart?](09-why-did-it-restart/) | minimal | two crashes with the same exit code and opposite fixes |
| [10 Why won't it schedule?](10-why-wont-it-schedule/) | minimal | admission-time failures: the object you are looking at never mentions them |

## Every grader has been made to fail

A check that cannot fail is worse than none — it reads as evidence. Each
`check.sh` was run once against a deliberately broken state before it was
trusted, and the break/fix scripts in labs 04 and 07 are the fixtures for
that. If you add a lab, do the same and say so in its README.

## Reset

`./scripts/platform.sh reset` destroys the cluster and rebuilds it empty in
about a minute. That is what makes it safe to break things.
