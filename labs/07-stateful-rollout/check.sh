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
# `mysqladmin ping` exits 0 with a wrong password and even when the server
# refuses the host, so it proves only that a process is listening. A SELECT
# proves the database is usable, which is the thing the lab claims to restore.
if $K -n lab07 exec deploy/mysql -- sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" 2>/dev/null' 2>/dev/null | grep -q '^1$'; then
    pass "mysqld answers a SELECT as root"
else
    fail "mysqld did not answer a SELECT (a listening server passes ping; this needs a usable one)"
fi
summary
