#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 07 — Stateful rollout (checked in the FIXED state)"
assert_strategy wordpress mysql Recreate
assert_pod_count wordpress app=mysql 1
assert_ready wordpress mysql
# WordPress 302s an uninstalled site to install.php; that redirect only happens
# once it has reached MySQL, so 302 is the proof the database is back.
assert_http wordpress.localhost / 302
summary
