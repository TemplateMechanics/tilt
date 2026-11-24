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
echo "the ReplicaSet backed off after its refused attempts, doubling the pause each"
echo "time, and it tries again when that pause ends, not when you fix the cause."
echo "Measured on this platform: from about one minute to over ten."
# 1100 s, not 600. The pause is counted from the last refusal, which is within
# seconds of the break, and doubles per refused attempt: measured at 77 s on
# one run and 636 s, after 17 attempts, on another. One more doubling passes 600 s, and the
# old limit then ran out with three pods, printed "3/6" and exited 0 as if it
# had worked. client-go's default ceiling for this pause is 1000 s (not measured
# here), so 1100 covers the worst case.
if ! wait_for 1100 "all 6 replicas to be ready (ReplicaSet backoff, be patient)" bash -c "[ \"\$($K -n lab10 get deploy quota-demo -o jsonpath='{.status.readyReplicas}')\" = 6 ]"; then
    $K -n lab10 get deploy quota-demo
    echo "still not at 6 ready after 1100 s. That is longer than the backoff can explain:" >&2
    echo "  kubectl -n lab10 get events --sort-by=.lastTimestamp | tail" >&2
    exit 1
fi
$K -n lab10 get deploy quota-demo
