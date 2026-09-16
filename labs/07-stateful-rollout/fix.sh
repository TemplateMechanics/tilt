#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
# The repo manifest already says Recreate; re-applying it IS the fix. That is
# the point of the lab: the declarative state was right and the live state
# had drifted.
$K apply -k "$ROOT/helm/wordpress" >/dev/null
echo "re-applied helm/wordpress (strategy: Recreate); waiting for a single Ready mysql pod"
wait_for 180 single-mysql bash -c "[ \"\$($K -n wordpress get pods -l app=mysql --no-headers | wc -l)\" -eq 1 ] && $K -n wordpress get pods -l app=mysql --no-headers | grep -q '1/1 *Running'"
$K -n wordpress get pods -l app=mysql
