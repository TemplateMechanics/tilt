#!/usr/bin/env bash
# Restore both: the SAN in the certificate, and the root CA in the OS store.
# Every step is verified. An earlier version used a sed replacement with an
# embedded newline, which is not portable across sed builds; it failed with
# "unterminated `s' command", then printed "SAN restored" anyway and carried on
# with a certificate that still lacked the name. Reported success on failure is
# the exact bug these labs exist to teach people to notice.
. "$(dirname "$0")/../lib.sh"
cert="$ROOT/helm/istio/gateway/base/certificate.yaml"

python - "$cert" <<'PYEOF'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
if "    - hello.localhost\n" not in s:
    s = s.replace("    - harbor.localhost\n", "    - harbor.localhost\n    - hello.localhost\n", 1)
    io.open(p, "w", encoding="utf-8", newline="\n").write(s)
PYEOF
grep -q '^    - hello\.localhost$' "$cert" || { echo "ERROR: could not restore hello.localhost in $cert"; exit 1; }
echo "SAN present in $cert"

$K apply -k "$ROOT/helm/istio/gateway/overlays/${PLATFORM_OVERLAY:-kind}" >/dev/null
echo "waiting for cert-manager to reissue with hello.localhost..."
if wait_for 120 reissue bash -c "echo | openssl s_client -connect 127.0.0.1:${GATEWAY_PORT} -servername hello.localhost 2>/dev/null | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -q 'DNS:hello.localhost'"; then
    echo "served certificate lists hello.localhost again"
else
    echo "ERROR: certificate was not reissued with hello.localhost within 120s"; exit 1
fi

# Re-trust and prove online revocation through the same shared path Tilt uses.
CONTEXT="$CONTEXT" GATEWAY_PORT="$GATEWAY_PORT" "$ROOT/scripts/trust-ca.sh"
