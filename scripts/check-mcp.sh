#!/usr/bin/env bash
# Prove the MCP servers in .mcp.json actually work, before blaming the client.
#
# A server that fails here will fail in Claude Code too, and Claude Code reports
# it only as "Connection closed" - which says nothing about why. This runs the
# exact argv from .mcp.json, expands ${PWD} the way the client does, completes
# the JSON-RPC handshake and calls a real tool. Listing tools is not enough: the
# Grafana server lists its tools happily while unauthenticated and only fails
# when one is called.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || { echo "ERROR: cannot cd to $ROOT"; exit 1; }

fail=0
ok()  { printf '  \033[32mok\033[0m    %s\n' "$*"; }
bad() { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$*"; }

command -v docker >/dev/null 2>&1 || { bad "docker not on PATH"; exit 1; }
docker info >/dev/null 2>&1 && ok "docker daemon responding" || bad "docker daemon not responding"

# dev-ca-trust writes this on every `up`. Without it the container cannot verify
# the platform's TLS and the server exits before answering anything.
# Stop here if the CA is missing, and do NOT fall through to the docker run: a
# bind mount whose source does not exist makes Docker CREATE A DIRECTORY at that
# path. The next CA export then fails with "Is a directory", which is a far more
# confusing problem than the missing file it replaced. Learned by causing it.
if [ -d .local/dev-root-ca.crt ]; then
    bad ".local/dev-root-ca.crt is a DIRECTORY - docker created it as a mount point"
    echo "        fix: rm -rf .local/dev-root-ca.crt && ./scripts/platform.sh up"
    exit 1
elif [ -s .local/dev-root-ca.crt ]; then
    ok "platform CA exported to .local/dev-root-ca.crt"
else
    bad "missing .local/dev-root-ca.crt - run ./scripts/platform.sh up (dev-ca-trust writes it)"
    echo "        not starting the server: the bind mount would create a directory there"
    exit 1
fi

cmd=$(python - <<'PY'
import io, json, os
cfg = json.load(io.open('.mcp.json', encoding='utf-8'))
g = cfg['mcpServers']['grafana']
pwd = os.environ.get('PWD') or os.getcwd()
args = [a.replace('${PWD}', pwd) for a in g['args']]
print(g['command'] + ' ' + ' '.join("'" + a + "'" for a in args))
PY
) || { bad "could not read .mcp.json"; exit 1; }

out=$(printf '%s\n%s\n%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"check","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_datasources","arguments":{}}}' \
  | MSYS_NO_PATHCONV=1 timeout 90 bash -c "$cmd" 2>/dev/null)

echo "$out" | grep -q '"tools"\|"serverInfo"' && ok "MCP handshake completed" || bad "no response to initialize"

# The tool call is the real test - it is the first thing that needs credentials.
if echo "$out" | python -c "
import sys, json
for l in sys.stdin:
    l = l.strip()
    if not l.startswith('{'): continue
    try: m = json.loads(l)
    except Exception: continue
    if m.get('id') == 2:
        r = m.get('result', {})
        txt = ''.join(c.get('text','') for c in r.get('content', []))
        sys.exit(0 if (not r.get('isError')) and 'datasources' in txt else 1)
sys.exit(1)
"; then ok "list_datasources returned live Grafana data"
else bad "list_datasources failed - usually a 401; check GRAFANA_USERNAME/PASSWORD in .mcp.json"; fi

echo
[ "$fail" -eq 0 ] && echo "  MCP is ready. If Claude Code still shows it disconnected, restart Claude Code" \
                  && echo "  in this directory - .mcp.json is read only at startup." \
                  || echo "  $fail check(s) failed"
[ "$fail" -eq 0 ]
