#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 04 — Break TLS (checked in the FIXED state)"
assert_san_present hello.localhost
assert_tls_ok hello.localhost
assert_os_trust hello.localhost
summary
