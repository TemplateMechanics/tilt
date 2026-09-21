#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
# Re-applying the manifest is the fix: the file was right, the live object drifted.
$K apply -f "$ROOT/labs/08-empty-dashboard/servicemonitor.yaml" >/dev/null
echo "re-applied the ServiceMonitor (port: http); waiting for Prometheus to scrape hello"
# Prometheus picks up ServiceMonitor changes on its own reload interval, so this
# can take a minute. Waiting on the SERIES, not on the object, because the object
# existing is exactly what fooled everyone in the first place.
wait_for 240 "hello metrics to appear in Prometheus" bash -c '
  curl -sS --max-time 15 --ssl-no-revoke --resolve prometheus.localhost:443:127.0.0.1 \
    "https://prometheus.localhost/api/v1/query?query=count(up%7Bjob%3D%22hello%22%7D)" \
    | grep -q "\"value\""'
echo "done - run ./scripts/platform.sh lab 08"
