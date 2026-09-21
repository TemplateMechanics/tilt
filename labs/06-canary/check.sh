#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 06 — Canary"
$K -n hello get canary hello >/dev/null 2>&1 && pass "Canary hello exists" || fail "Canary hello not found (kubectl apply -f labs/06-canary/canary.yaml)"
ph=$($K -n hello get canary hello -o jsonpath='{.status.phase}' 2>/dev/null)
case "$ph" in Initialized|Succeeded|Progressing|Promoting) pass "Canary phase is $ph" ;; *) fail "Canary phase is '${ph:-none}'" ;; esac
assert_ready hello hello-primary
# Both of these went missing without a sound, and a missing one shows up only
# as a healthy release being rolled back. Check them by name.
[ "$($K get ns hello -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}' 2>/dev/null)" = "waypoint" ]     && pass "namespace hello routes through the waypoint"     || fail "namespace hello has no istio.io/use-waypoint label - no L7 metrics, every canary rolls back (kubectl label ns hello istio.io/use-waypoint=waypoint)"
$K -n hello get metrictemplate ambient-success-rate >/dev/null 2>&1     && pass "MetricTemplate ambient-success-rate exists"     || fail "MetricTemplate ambient-success-rate missing (kubectl apply -f labs/06-canary/metric-template.yaml)"
if $K -n hello get httproute hello -o jsonpath='{.spec.rules[*].backendRefs[*].name}' 2>/dev/null | grep -q hello-primary; then
    pass "HTTPRoute now fronts hello-primary"; else fail "HTTPRoute does not reference hello-primary"; fi
assert_http hello.localhost / 200
summary
