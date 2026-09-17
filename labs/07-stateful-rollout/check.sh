#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 07 — Stateful rollout (checked in the FIXED state)"
assert_strategy lab07 mysql Recreate
assert_pod_count lab07 app=mysql 1
assert_ready lab07 mysql
# Ask the database, not Kubernetes. A Ready pod only means a probe passed; this
# proves mysqld is actually serving, which is what the rollout was blocking.
# The old version asserted an HTTP 302 from WordPress, which needed a whole blog
# deployed just to say "the database answered".
if $K -n lab07 exec deploy/mysql -- sh -c 'mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" 2>/dev/null' 2>/dev/null | grep -q 'mysqld is alive'; then
    pass "mysqld answers mysqladmin ping"
else
    fail "mysqld did not answer mysqladmin ping"
fi
summary
