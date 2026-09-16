#!/usr/bin/env bash
# Provision the Grafana service account the MCP server authenticates with, and
# write it where docker can read it without anything being set in your shell.
#
# Grafana shows a service-account token exactly once, at creation. So this is
# idempotent on the TOKEN, not on the account: if the env file already holds a
# token that still authenticates, it does nothing. If it does not, it makes a
# new one. Re-running must never leave you with an account whose token nobody
# has, which is what happens if you only check whether the account exists.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || { echo "ERROR: cannot cd to $ROOT"; exit 1; }

GRAFANA="${GRAFANA_URL:-https://grafana.localhost}"
GATEWAY_PORT="${GATEWAY_PORT:-443}"
ADMIN="${GRAFANA_ADMIN:-admin:admin}"
ENVFILE=".local/grafana-mcp.env"
CA=".local/dev-root-ca.crt"

host="${GRAFANA#https://}"; host="${host#http://}"; host="${host%%/*}"
g() { curl -sS --max-time 20 --ssl-no-revoke --resolve "${host}:${GATEWAY_PORT}:127.0.0.1" \
        ${CA:+--cacert "$CA"} -u "$ADMIN" "$@"; }

mkdir -p .local
[ -s "$CA" ] || { echo "no $CA yet - dev-ca-trust writes it; skipping"; exit 0; }

if [ -s "$ENVFILE" ]; then
    tok=$(sed -n 's/^GRAFANA_SERVICE_ACCOUNT_TOKEN=//p' "$ENVFILE")
    if [ -n "$tok" ]; then
        code=$(curl -sS -o /dev/null --max-time 20 --ssl-no-revoke \
                 --resolve "${host}:${GATEWAY_PORT}:127.0.0.1" --cacert "$CA" \
                 -H "Authorization: Bearer $tok" -w '%{http_code}' "${GRAFANA}/api/org")
        if [ "$code" = "200" ]; then echo "existing MCP token still valid"; exit 0; fi
        echo "existing token no longer authenticates (HTTP $code) - issuing a new one"
    fi
fi

id=$(g "${GRAFANA}/api/serviceaccounts/search?query=mcp" 2>/dev/null \
     | python -c "import json,sys;d=json.load(sys.stdin);a=[x for x in d.get('serviceAccounts',[]) if x['name']=='mcp'];print(a[0]['id'] if a else '')" 2>/dev/null)

if [ -z "$id" ]; then
    id=$(g -X POST -H 'Content-Type: application/json' \
           -d '{"name":"mcp","role":"Admin","isDisabled":false}' \
           "${GRAFANA}/api/serviceaccounts" \
         | python -c "import json,sys;print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
    [ -n "$id" ] || { echo "ERROR: could not create the service account"; exit 1; }
    echo "created Grafana service account 'mcp' (id $id)"
fi

tok=$(g -X POST -H 'Content-Type: application/json' \
        -d "{\"name\":\"mcp-$(date +%s)\"}" \
        "${GRAFANA}/api/serviceaccounts/${id}/tokens" \
      | python -c "import json,sys;print(json.load(sys.stdin).get('key',''))" 2>/dev/null)
[ -n "$tok" ] || { echo "ERROR: Grafana returned no token"; exit 1; }

printf 'GRAFANA_SERVICE_ACCOUNT_TOKEN=%s\n' "$tok" > "$ENVFILE"

# Prove it before claiming success: a token that is written but not accepted is
# the failure this whole script exists to avoid.
code=$(curl -sS -o /dev/null --max-time 20 --ssl-no-revoke \
         --resolve "${host}:${GATEWAY_PORT}:127.0.0.1" --cacert "$CA" \
         -H "Authorization: Bearer $tok" -w '%{http_code}' "${GRAFANA}/api/org")
[ "$code" = "200" ] || { echo "ERROR: new token rejected by Grafana (HTTP $code)"; exit 1; }
echo "MCP token written to $ENVFILE and verified against ${GRAFANA}/api/org"
