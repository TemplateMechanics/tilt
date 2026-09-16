#!/usr/bin/env bash
# Generate load from inside the cluster for N seconds (default 90).
. "$(dirname "$0")/../lib.sh"
secs="${1:-90}"
$K -n hello delete pod hello-load --ignore-not-found >/dev/null 2>&1
$K -n hello run hello-load --restart=Never --image=curlimages/curl:8.11.1 --command --   sh -c "end=\$((\$(date +%s)+$secs)); while [ \$(date +%s) -lt \$end ]; do for i in 1 2 3 4 5 6 7 8; do curl -s -o /dev/null http://hello.hello.svc/delay/0 & done; wait; done" >/dev/null
echo "load pod running for ${secs}s against hello.hello.svc - watch: kubectl -n hello get hpa,pods -w"
