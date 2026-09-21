#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 05 — Scale it"
assert_metrics_api
$K -n hello get hpa hello >/dev/null 2>&1 && pass "HPA hello exists" || fail "HPA hello not found (kubectl apply -f labs/05-scale-it/hpa.yaml)"
t=$($K -n hello get hpa hello -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null)
[ -n "$t" ] && pass "HPA has a current CPU reading (${t}%)" || fail "HPA target is <unknown>: it has no metrics and will never scale"
assert_replicas_at_least hello hello 2
# One "ready replicas 1 < 2" covers three situations, and only one of them is
# a broken HPA. The HPA scales back about a minute after load stops (30s
# stabilisation plus the metrics lag), so a student who reads the load output
# first and grades second was told they had failed a lab they had completed.
# Measured: green up to 55s after the load ended, red from 70s.
r=$($K -n hello get deploy hello -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "${r:-0}" -lt 2 ]; then
    case "$($K -n hello get pod hello-load -o jsonpath='{.status.phase}' 2>/dev/null)" in
        Running)   note "Load is running but has not scaled yet. Allow 30-60s for metrics to catch up;"                    && note "if it stays at 1 after that, it is a real failure - look at the CPU reading above." ;;
        Succeeded) note "The load has finished and the HPA has scaled back down, as it should."                    && note "Re-run ./labs/05-scale-it/load.sh 90 and grade WHILE it runs." ;;
        *)         note "No load has been run. Start ./labs/05-scale-it/load.sh 90, then grade while it runs." ;;
    esac
fi
summary
