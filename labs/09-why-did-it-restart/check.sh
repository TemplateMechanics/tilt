#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 09 — Why did it restart? (checked in the FIXED state)"
assert_ready lab09 starved
assert_ready lab09 impatient

# Assert the SHAPE of each fix, not just that things are green. Raising memory
# on the probe-killed pod would eventually look healthy too, for the wrong
# reason, and a grader that cannot tell those apart teaches nothing.
lim=$($K -n lab09 get deploy starved -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)
case "$lim" in
  64Mi|"") fail "starved still limited to '${lim:-unset}' - it needs more memory" ;;
  *) pass "starved memory limit raised to $lim" ;;
esac

if $K -n lab09 get deploy impatient -o jsonpath='{.spec.template.spec.containers[0].startupProbe}' 2>/dev/null | grep -q httpGet; then
    pass "impatient has a startupProbe holding liveness off during start-up"
else
    fail "impatient has no startupProbe - liveness still races its 60s start-up"
fi

# And the rollout must have FINISHED. This grader passed once on the old pod
# while the new one was still starting: readyReplicas was 1, but it was 1 of the
# previous ReplicaSet, still carrying the bug. "A pod is Ready" and "the change
# you made is live" are different facts, and a check that conflates them will
# happily bless a fix that has not taken effect yet.
for d in starved impatient; do
    gen=$($K -n lab09 get deploy $d -o jsonpath='{.metadata.generation}' 2>/dev/null)
    obs=$($K -n lab09 get deploy $d -o jsonpath='{.status.observedGeneration}' 2>/dev/null)
    upd=$($K -n lab09 get deploy $d -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)
    rdy=$($K -n lab09 get deploy $d -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    tot=$($K -n lab09 get pods -l app=$d --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "${gen:-0}" = "${obs:-x}" ] && [ "${upd:-0}" = "${rdy:-x}" ] && [ "${tot:-0}" = "1" ]; then
        pass "$d rollout complete: one pod, from the current ReplicaSet"
    else
        fail "$d rollout not finished (gen=$gen observed=$obs updated=$upd ready=$rdy pods=$tot)"
    fi
done
summary
