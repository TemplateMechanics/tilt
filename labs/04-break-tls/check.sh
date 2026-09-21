#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 04 — Break TLS (checked in the FIXED state)"
assert_san_present hello.localhost
assert_tls_ok hello.localhost
# The OS store must trust the chain: a plain curl with no --cacert must succeed.
code=$(curl -sS --max-time 15 --ssl-no-revoke --resolve "hello.localhost:${GATEWAY_PORT}:127.0.0.1" -o /dev/null -w '%{http_code}' "$(url hello.localhost /)" 2>/dev/null); code="${code:-000}"
[ "$code" = "200" ] && pass "OS trust store accepts the chain (no --cacert) -> 200" || fail "OS trust store rejects the chain (curl without --cacert -> $code)"
summary
