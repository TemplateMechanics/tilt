#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
# The lab manifest already says Recreate; re-applying it IS the fix. That is the
# point of the lab: the declarative state was right and the live state drifted.
$K apply -f "$ROOT/labs/07-stateful-rollout/mysql.yaml" >/dev/null
echo "re-applied the lab manifest (strategy: Recreate); waiting for a single Ready mysql pod"
wait_for 180 "one ready mysql pod" bash -c "[ \"\$($K -n lab07 get pods -l app=mysql --no-headers | wc -l)\" -eq 1 ] && $K -n lab07 get pods -l app=mysql --no-headers | grep -q '1/1 *Running'"
$K -n lab07 get pods -l app=mysql
