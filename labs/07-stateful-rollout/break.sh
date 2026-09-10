#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
$K -n wordpress patch deploy mysql -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":null}}}' >/dev/null
$K -n wordpress rollout restart deploy/mysql >/dev/null
echo "mysql set to RollingUpdate and restarted. Watch: kubectl -n wordpress get pods -w"
echo "Expect a second mysql pod that never becomes Ready, and in its logs:"
echo "  [InnoDB] Unable to lock ./ibdata1 error: 11"
