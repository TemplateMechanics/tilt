#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 05 — Scale it"
assert_metrics_api
$K -n hello get hpa hello >/dev/null 2>&1 && pass "HPA hello exists" || fail "HPA hello not found (kubectl apply -f labs/05-scale-it/hpa.yaml)"
t=$($K -n hello get hpa hello -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null)
[ -n "$t" ] && pass "HPA has a current CPU reading (${t}%)" || fail "HPA target is <unknown>: it has no metrics and will never scale"
assert_replicas_at_least hello hello 2
summary
