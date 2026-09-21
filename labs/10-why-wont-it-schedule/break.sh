#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
# Breaking this takes three steps, and the reason is worth knowing.
#
# A ResourceQuota lowered below current usage does NOT evict anything - it only
# refuses NEW pods. So dropping the quota back to 3 while six pods are running
# changes nothing at all: the six stay, everything reads green, and the lab
# silently teaches nothing. scripts/verify-labs.sh caught exactly that twice
# while this script was being written ("STILL grades green after break.sh").
#
# So: scale down to release the usage, then lower the quota, then scale back up
# into it.
$K -n lab10 scale deploy quota-demo --replicas=1 >/dev/null
wait_for 120 "pods to drain so the quota usage drops" bash -c   "[ \"\$($K -n lab10 get pods -l app=quota-demo --no-headers | wc -l | tr -d ' ')\" = 1 ]"

$K -n lab10 patch resourcequota lab10-quota --type=merge   -p '{"spec":{"hard":{"pods":"3","requests.memory":"384Mi","limits.memory":"768Mi"}}}' >/dev/null

$K -n lab10 scale deploy quota-demo --replicas=6 >/dev/null
echo "quota-demo scaled to 6. The quota allows 3 pods."
echo
echo "Watch what each command tells you:"
echo "  kubectl -n lab10 get deploy quota-demo     # says 3/6 and nothing about why"
echo "  kubectl -n lab10 get pods                  # three pods, no failing pod to inspect"
echo "  kubectl -n lab10 get events --field-selector reason=FailedCreate"
echo "  kubectl -n lab10 describe resourcequota lab10-quota"
