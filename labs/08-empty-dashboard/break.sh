#!/usr/bin/env bash
# Point the ServiceMonitor at a port name that does not exist. Nothing errors.
. "$(dirname "$0")/../lib.sh"
$K -n monitoring patch servicemonitor hello --type=json \
  -p '[{"op":"replace","path":"/spec/endpoints/0/port","value":"metrics"}]' >/dev/null
echo "ServiceMonitor hello now asks for a port named 'metrics'."
echo "The hello Service publishes that port as 'http', so there is no such port."
echo
echo "Nothing will report an error. Look for yourself:"
echo "  kubectl -n monitoring get servicemonitor hello        # exists, looks fine"
echo "  kubectl -n hello get svc hello -o yaml | grep -A2 ports"
echo
echo "Then ask Prometheus what it is actually scraping (admin/admin):"
echo "  https://prometheus.localhost/targets"
echo "Give it ~60s: Prometheus reloads its config on a timer, not instantly."
