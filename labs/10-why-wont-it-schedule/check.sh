#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 10 — Why won't it schedule? (checked in the FIXED state)"

assert_replicas_at_least lab10 quota-demo 6

# The guardrail must still exist. Deleting the quota also turns the deployment
# green, and is the wrong answer - so a grader that only checks "6 pods" would
# pass the mistake this lab is warning about.
if $K -n lab10 get resourcequota lab10-quota >/dev/null 2>&1; then
    pass "ResourceQuota lab10-quota still in place"
else
    fail "ResourceQuota was deleted - raising a limit and removing it are different answers"
fi

# No lingering refusal. ReplicaFailure sticks around on the Deployment until the
# ReplicaSet can actually create pods again.
rf=$($K -n lab10 get deploy quota-demo -o jsonpath='{range .status.conditions[?(@.type=="ReplicaFailure")]}{.status}{end}' 2>/dev/null)
[ "${rf:-False}" = "True" ] && fail "Deployment still reports ReplicaFailure" \
                            || pass "Deployment has no ReplicaFailure condition"

# The LimitRange is still doing its invisible job: pods that declare no
# resources still come out with some.
req=$($K -n lab10 get pods -l app=quota-demo -o jsonpath='{.items[0].spec.containers[0].resources.requests.memory}' 2>/dev/null)
[ -n "$req" ] && pass "LimitRange still injects defaults (memory request $req, written by nobody)" \
              || fail "pods have no memory request - the LimitRange is not applying"
summary
