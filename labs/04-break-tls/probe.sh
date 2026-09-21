#!/usr/bin/env bash
# Show HOW TLS verification of <host> fails, by openssl verify return code.
#
#   probe.sh hello.localhost              verify against the platform root CA
#   probe.sh hello.localhost --untrusted  verify with NO trusted CAs at all
#
# The two failure modes look identical in a browser and mean opposite things:
#   62           hostname mismatch - chain is trusted, the name is not on the cert
#   18/19/20/21  trust failure     - chain does not reach a trusted root
#
# --untrusted simulates the second without touching your OS trust store, which
# matters on Windows where deleting from the user Root store needs a GUI
# confirmation and cannot be scripted. It uses -no-CAfile -no-CApath: an EMPTY
# -CAfile does not work - openssl errors out ("no certificate or crl found")
# before it ever verifies, and an earlier version of this probe printed nothing
# at all, silent on the exact case it exists to show.
. "$(dirname "$0")/../lib.sh"
host="${1:-hello.localhost}"
show() { grep -E "Verify return code|subject=|issuer=" | sed "s/^ *//"; }
if [ "${2:-}" = "--untrusted" ]; then
    echo "(no trusted CAs - what a machine that never trusted the platform CA sees)"
    echo | openssl s_client -connect "127.0.0.1:${GATEWAY_PORT}" -servername "$host" -verify_hostname "$host" -no-CAfile -no-CApath 2>&1 | show
else
    ca="$(mktemp -t lab-probe-ca-XXXXXX)"
    $K get secret local-root-ca -n cert-manager -o go-template="{{index .data \"tls.crt\"}}" 2>/dev/null | base64 -d > "$ca"
    echo | openssl s_client -connect "127.0.0.1:${GATEWAY_PORT}" -servername "$host" -verify_hostname "$host" -CAfile "$ca" 2>&1 | show
    rm -f "$ca"
fi
