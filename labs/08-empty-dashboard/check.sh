#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
echo "Lab 08 — The dashboard that lies (checked in the FIXED state)"

# 1. The object exists. This alone proves nothing, which is the lesson.
if $K -n monitoring get servicemonitor hello >/dev/null 2>&1; then
    pass "ServiceMonitor hello exists"
else
    fail "ServiceMonitor hello not found (kubectl apply -f labs/08-empty-dashboard/servicemonitor.yaml)"
fi

# 2. The port it names actually exists on the Service. This is the bug.
want=$($K -n monitoring get servicemonitor hello -o jsonpath='{.spec.endpoints[0].port}' 2>/dev/null)
have=$($K -n hello get svc hello -o jsonpath='{range .spec.ports[*]}{.name} {end}' 2>/dev/null)
case " $have " in
  *" $want "*) pass "ServiceMonitor names port '$want', which the Service publishes" ;;
  *) fail "ServiceMonitor names port '$want'; the Service publishes: ${have:-none}" ;;
esac

# 3. Prometheus has a target for it, and that target is up. An object with no
#    target is the silent state this lab exists to make visible.
n=$(curl -sS --max-time 20 --ssl-no-revoke --resolve prometheus.localhost:443:127.0.0.1 \
      'https://prometheus.localhost/api/v1/targets?state=active' 2>/dev/null \
    | python -c "import json,sys
try: ts=json.load(sys.stdin)['data']['activeTargets']
except Exception: ts=[]
print(sum(1 for t in ts if t['labels'].get('job')=='hello' and t.get('health')=='up'))" 2>/dev/null)
[ "${n:-0}" -ge 1 ] && pass "Prometheus has $n healthy target(s) for job=hello" \
                    || fail "Prometheus has no healthy target for job=hello"

# 4. And the data is FRESH. Asking "are there series?" is not enough: when the
#    scrape stops, Prometheus keeps serving the last sample for ~5 minutes, so a
#    broken monitor still looks healthy for the length of a coffee break. This
#    measures how long ago the last successful scrape was.
age=$(curl -sS --max-time 20 --ssl-no-revoke --resolve prometheus.localhost:443:127.0.0.1       'https://prometheus.localhost/api/v1/query?query=time()%20-%20max(timestamp(up%7Bjob%3D%22hello%22%7D))' 2>/dev/null     | python -c "import json,sys
try:
    r=json.load(sys.stdin)['data']['result']; print(int(float(r[0]['value'][1])) if r else 999)
except Exception: print(999)" 2>/dev/null)
if [ "${age:-999}" -lt 120 ]; then
    pass "last successful scrape of job=hello was ${age}s ago"
else
    fail "no fresh data for job=hello (last scrape ${age}s ago; stale series can linger ~5m)"
fi
summary
