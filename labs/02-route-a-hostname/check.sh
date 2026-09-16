#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 02 — Route a second hostname"
if $K -n hello get httproute hello -o jsonpath='{.spec.hostnames[*]}' 2>/dev/null | grep -qw hi.localhost; then
    pass "HTTPRoute hello lists hi.localhost"; else fail "HTTPRoute hello does not list hi.localhost"; fi
assert_san_present hi.localhost
assert_tls_ok hi.localhost
assert_http hi.localhost / 200
( cd "$ROOT" && python scripts/ci/check-route-hostnames.py >/dev/null 2>&1 ) && pass "check-route-hostnames.py passes" || fail "check-route-hostnames.py fails"
summary
