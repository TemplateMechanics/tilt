#!/usr/bin/env bash
# Generate load from inside the cluster for N seconds (default 90).
. "$(dirname "$0")/../lib.sh"
secs="${1:-90}"
$K -n hello delete pod hello-load --ignore-not-found >/dev/null 2>&1
# 40 independent loops, not batches of 8 behind `wait`. The batched version
# could not move the needle: it spent most of its time waiting for the slowest
# curl in each batch of 8, sustained maybe 1m of CPU against a 10m request, and
# the HPA sat at 10%/50% forever - the lab could not be completed as written.
# Measured with this version: 162m, which is 1620% of the request, and the HPA
# scales to 4. If you change the endpoint, re-measure; a cheap endpoint served
# slowly is indistinguishable from load that never arrived.
$K -n hello run hello-load --restart=Never --image=curlimages/curl:8.11.1 --command --   sh -c "end=\$((\$(date +%s)+$secs)); i=0; while [ \$i -lt 40 ]; do ( while [ \$(date +%s) -lt \$end ]; do curl -s -o /dev/null http://hello.hello.svc/delay/0; done ) & i=\$((i+1)); done; wait" >/dev/null
echo "load pod running for ${secs}s against hello.hello.svc - watch: kubectl -n hello get hpa,pods -w"
