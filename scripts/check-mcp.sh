#!/usr/bin/env bash
# Prove the MCP servers in .mcp.json actually work, before blaming the client.
#
# A server that fails here will fail in Claude Code too, and Claude Code reports
# it only as "Connection closed" - which says nothing about why. This runs the
# exact argv from .mcp.json, expands ${PWD} the way the client does, completes
# the JSON-RPC handshake and calls a real tool. Listing tools is not enough: the
# Grafana server lists its tools happily while unauthenticated and only fails
# when one is called.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || { echo "ERROR: cannot cd to $ROOT"; exit 1; }

if command -v python3 >/dev/null 2>&1; then
    PYTHON=python3
elif command -v python >/dev/null 2>&1; then
    PYTHON=python
else
    echo "  FAIL  Python 3 not on PATH" >&2
    exit 1
fi

"$PYTHON" scripts/validate/mcp-check.py "$@"

echo
echo "  Requested MCP checks passed. After a live check, if Claude Code still"
echo "  shows a server disconnected, restart it here and approve project MCPs."
