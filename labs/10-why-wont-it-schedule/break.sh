#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
$K -n lab10 scale deploy quota-demo --replicas=6 >/dev/null
echo "quota-demo scaled to 6. The quota allows 3 pods."
echo
echo "Watch what each command tells you:"
echo "  kubectl -n lab10 get deploy quota-demo     # says 3/6 and nothing about why"
echo "  kubectl -n lab10 get pods                  # three pods, no failing pod to inspect"
echo "  kubectl -n lab10 get events --field-selector reason=FailedCreate"
echo "  kubectl -n lab10 describe resourcequota lab10-quota"
