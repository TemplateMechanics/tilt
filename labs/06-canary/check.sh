#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 06 — Canary"
$K -n hello get canary hello >/dev/null 2>&1 && pass "Canary hello exists" || fail "Canary hello not found (kubectl apply -f labs/06-canary/canary.yaml)"
ph=$($K -n hello get canary hello -o jsonpath='{.status.phase}' 2>/dev/null)
case "$ph" in Initialized|Succeeded|Progressing|Promoting) pass "Canary phase is $ph" ;; *) fail "Canary phase is '${ph:-none}'" ;; esac
assert_ready hello hello-primary
if $K -n hello get httproute hello -o jsonpath='{.spec.rules[*].backendRefs[*].name}' 2>/dev/null | grep -q hello-primary; then
    pass "HTTPRoute now fronts hello-primary"; else fail "HTTPRoute does not reference hello-primary"; fi
assert_http hello.localhost / 200
summary
