#!/usr/bin/env bash
# Put both bugs back.
#
# Note why this is a script and not "re-apply the manifest". fix.sh uses
# `kubectl patch`, which changes the live object without touching the
# last-applied-configuration annotation. `kubectl apply` reconciles against that
# annotation, so it does not know the startupProbe was ever added and leaves it
# in place - the lab looks re-broken while one bug is still fixed. Patching back
# is explicit and cannot half-work.
. "$(dirname "$0")/../lib.sh"

$K -n lab09 patch deploy starved --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"64Mi"}]' >/dev/null
echo "starved:   memory limit back to 64Mi (it needs ~200Mi)"

if $K -n lab09 get deploy impatient -o jsonpath='{.spec.template.spec.containers[0].startupProbe}' 2>/dev/null | grep -q httpGet; then
    $K -n lab09 patch deploy impatient --type=json \
      -p '[{"op":"remove","path":"/spec/template/spec/containers/0/startupProbe"}]' >/dev/null
fi
echo "impatient: startupProbe removed (liveness races its 60s start-up again)"
echo
echo "Give them two minutes, then: kubectl -n lab09 get pods"
