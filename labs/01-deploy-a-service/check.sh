#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 01 — Deploy a service"
assert_ready hello hello
assert_route_accepted hello hello
assert_http hello.localhost / 200
assert_body_contains hello.localhost /api/info '"version"'
assert_tls_ok hello.localhost
assert_browser hello
summary
