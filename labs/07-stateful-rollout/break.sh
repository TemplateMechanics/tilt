#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
$K -n lab07 patch deploy mysql -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":null}}}' >/dev/null
$K -n lab07 rollout restart deploy/mysql >/dev/null
echo "mysql set to RollingUpdate and restarted. Watch: kubectl -n lab07 get pods -w"
echo "Expect a second mysql pod that never becomes Ready, and in its logs:"
echo "  [InnoDB] Unable to lock ./ibdata1 error: 11"
