#!/usr/bin/env bash
# The fix is a capacity DECISION, not deleting the guardrail. Raising the quota
# says "six of these is acceptable here"; deleting it says "no limit, ever",
# which is how namespaces quietly eat a cluster.
. "$(dirname "$0")/../lib.sh"
$K -n lab10 patch resourcequota lab10-quota --type=merge \
  -p '{"spec":{"hard":{"pods":"8","requests.memory":"768Mi","limits.memory":"1536Mi"}}}' >/dev/null
echo "quota raised: pods 3 -> 8, requests.memory 384Mi -> 768Mi, limits.memory 768Mi -> 1536Mi"
echo
echo "Now wait. Raising the quota does not un-stick the Deployment straight away:"
echo "the ReplicaSet backs off exponentially after repeated FailedCreate, so it"
echo "retries on its own schedule, not yours. Several minutes of nothing happening"
echo "is normal here - measured at over three on this cluster."
wait_for 600 "all 6 replicas to be ready (ReplicaSet backoff, be patient)" bash -c "[ \"\$($K -n lab10 get deploy quota-demo -o jsonpath='{.status.readyReplicas}')\" = 6 ]"
$K -n lab10 get deploy quota-demo
