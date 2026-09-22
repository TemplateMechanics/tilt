#!/usr/bin/env bash
# Generate empty, issuer-signed CRLs for the local development PKI and publish
# them through the Gateway's plaintext listener. CA private keys exist only in
# a mode-0700 temporary directory and are removed on exit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${CONTEXT:-kind-tiltdev}"
GATEWAY_PORT="${GATEWAY_PORT:-443}"
CRL_BASE_URL="${CRL_BASE_URL:-http://crl.localhost}"
K=(kubectl --context "$CONTEXT")

if [[ ! "$CRL_BASE_URL" =~ ^http://crl\.localhost(:[0-9]+)?$ ]]; then
    echo "ERROR: CRL_BASE_URL must be http://crl.localhost with an optional port" >&2
    exit 2
fi
for command in kubectl openssl curl base64 cmp awk sed grep tr; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "ERROR: required command is missing: $command" >&2
        exit 1
    }
done

work="$(mktemp -d "${TMPDIR:-/tmp}/tilt-local-crl.XXXXXX")"
cleanup() {
    chmod -R u+w "$work" 2>/dev/null || true
    /bin/rm -rf -- "$work"
}
trap cleanup EXIT
umask 077

secret_part() {
    local namespace="$1" secret="$2" part="$3" output="$4"
    "${K[@]}" -n "$namespace" get secret "$secret" \
        -o "go-template={{index .data \"$part\"}}" 2>/dev/null \
        | base64 -d > "$output"
    [ -s "$output" ]
}

# Git Bash's openssl is a native Windows build. MSYS rewrites arguments that
# look like POSIX paths, so -config lands correctly, but paths written INSIDE
# the config file are passed through untouched and openssl looks for a literal
# C:	mp\... . Measured before this: "Could not open file or uri for loading CA
# private key from /tmp/tilt-local-crl.XXXX/root.key" - and it was invisible,
# because the openssl call discarded its own stderr.
native_path() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) cygpath -m "$1" ;;
        *)                    printf '%s
' "$1" ;;
    esac
}

first_certificate() {
    awk 'BEGIN { n=0 } /BEGIN CERTIFICATE/ { n++ } n==1 { print } /END CERTIFICATE/ && n==1 { exit }' \
        "$1" > "$2"
    [ -s "$2" ] && openssl x509 -in "$2" -noout >/dev/null 2>&1
}

generate_crl() {
    local name="$1" ca_cert="$2" ca_key="$3" output_der="$4"
    local db="$work/$name-db" number
    mkdir -p "$db/newcerts"
    : > "$db/index.txt"
    number="$(printf '%X' "$(date +%s)")"
    printf '%s\n' "$number" > "$db/crlnumber"
    printf '%s\n' '1000' > "$db/serial"

    local db_n ca_cert_n ca_key_n
    db_n="$(native_path "$db")"
    ca_cert_n="$(native_path "$ca_cert")"
    ca_key_n="$(native_path "$ca_key")"

    cat > "$db/openssl.cnf" <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
database = $db_n/index.txt
new_certs_dir = $db_n/newcerts
certificate = $ca_cert_n
private_key = $ca_key_n
serial = $db_n/serial
crlnumber = $db_n/crlnumber
default_md = sha256
default_crl_days = 30
crl_extensions = crl_ext
policy = policy_any
unique_subject = no

[ policy_any ]
commonName = optional

[ crl_ext ]
authorityKeyIdentifier = keyid:always
EOF

    # Keep openssl's message. With it discarded, a failure here aborted the
    # script under `set -e` with no output at all: Tilt showed "exit status 1"
    # and nothing else.
    local gencrl_err
    if ! gencrl_err="$(openssl ca -batch -config "$db/openssl.cnf" -gencrl \
        -out "$db/$name.crl.pem" 2>&1 >/dev/null)"; then
        echo "ERROR: openssl could not generate the $name CRL:" >&2
        printf '%s\n' "$gencrl_err" >&2
        return 1
    fi
    openssl crl -in "$db/$name.crl.pem" -outform DER -out "$output_der"
    openssl crl -inform DER -in "$output_der" -verify \
        -CAfile "$ca_cert" -noout >/dev/null
}

secret_part cert-manager local-root-ca tls.crt "$work/root-chain.crt"
secret_part cert-manager local-root-ca tls.key "$work/root.key"
secret_part cert-manager local-intermediate-ca tls.crt "$work/intermediate-chain.crt"
secret_part cert-manager local-intermediate-ca tls.key "$work/intermediate.key"
first_certificate "$work/root-chain.crt" "$work/root.crt"
first_certificate "$work/intermediate-chain.crt" "$work/intermediate.crt"

# Wait, do not fail. Tilt orders this after cert-manager-pki on a fresh `up`,
# but when an existing session reloads a changed Tiltfile this resource is new,
# its dependency has already built once, and it starts first. Measured on the
# upgrade path: this ran at 16:27:39 and the root was reissued at 16:27:54 - it
# failed on a cluster seconds away from being correct, and nothing re-ran it.
ca_deadline=$((SECONDS + 300))
while (( SECONDS < ca_deadline )); do
    secret_part cert-manager local-root-ca tls.crt "$work/root-chain.crt" \
        && secret_part cert-manager local-intermediate-ca tls.crt "$work/intermediate-chain.crt" \
        && first_certificate "$work/root-chain.crt" "$work/root.crt" \
        && first_certificate "$work/intermediate-chain.crt" "$work/intermediate.crt" \
        && openssl x509 -in "$work/root.crt" -noout -text | grep -q 'CRL Sign' \
        && openssl x509 -in "$work/intermediate.crt" -noout -text | grep -q 'CRL Sign' \
        && break
    sleep 5
done
openssl x509 -in "$work/root.crt" -noout -text | grep -q 'CRL Sign' || {
    echo "ERROR: root CA still lacks cRLSign after 300s; check cert-manager-pki" >&2
    exit 1
}
openssl x509 -in "$work/intermediate.crt" -noout -text | grep -q 'CRL Sign' || {
    echo "ERROR: intermediate CA still lacks cRLSign after 300s; check cert-manager-pki" >&2
    exit 1
}
# Re-read the keys after the wait so they match the certificates checked above.
secret_part cert-manager local-root-ca tls.key "$work/root.key"
secret_part cert-manager local-intermediate-ca tls.key "$work/intermediate.key"
openssl x509 -in "$work/intermediate.crt" -noout -text \
    | grep -Fq "$CRL_BASE_URL/root.crl" || {
    echo "ERROR: intermediate certificate has the wrong root CRL URL" >&2
    exit 1
}
# Certificate Ready can remain true while cert-manager replaces an existing,
# still-valid Secret. Poll the actual leaf bytes so an in-place upgrade cannot
# race ahead and generate CRLs for the pre-revocation leaf.
leaf_ready=""
deadline=$((SECONDS + 240))
while (( SECONDS < deadline )); do
    if secret_part istio-system wildcard-localhost-tls tls.crt \
        "$work/wildcard-chain.crt" \
        && first_certificate "$work/wildcard-chain.crt" "$work/wildcard.crt" \
        && openssl x509 -in "$work/wildcard.crt" -noout -text \
            | grep -Fq "$CRL_BASE_URL/intermediate.crl"; then
        leaf_ready=1
        break
    fi
    sleep 2
done
if [ -z "$leaf_ready" ]; then
    echo "ERROR: wildcard certificate was not reissued with $CRL_BASE_URL/intermediate.crl" >&2
    exit 1
fi

generate_crl root "$work/root.crt" "$work/root.key" "$work/root.crl"
generate_crl intermediate "$work/intermediate.crt" "$work/intermediate.key" \
    "$work/intermediate.crl"

"${K[@]}" -n istio-system create configmap local-ca-crls \
    --from-file=root.crl="$work/root.crl" \
    --from-file=intermediate.crl="$work/intermediate.crl" \
    --dry-run=client -o yaml | "${K[@]}" apply -f - >/dev/null
"${K[@]}" apply -k "$ROOT/helm/cert-manager/crl" >/dev/null
"${K[@]}" -n istio-system rollout restart deployment/local-ca-crl-server >/dev/null
"${K[@]}" -n istio-system rollout status deployment/local-ca-crl-server \
    --timeout=180s

deadline=$((SECONDS + 120))
accepted=""; resolved=""
while (( SECONDS < deadline )); do
    accepted="$("${K[@]}" -n istio-system get httproute local-ca-crls \
        -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null || true)"
    resolved="$("${K[@]}" -n istio-system get httproute local-ca-crls \
        -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null || true)"
    [ "$accepted" = True ] && [ "$resolved" = True ] && break
    sleep 2
done
if [ "$accepted" != True ] || [ "$resolved" != True ]; then
    echo "ERROR: CRL HTTPRoute is not accepted with resolved references" >&2
    "${K[@]}" -n istio-system describe httproute local-ca-crls >&2
    exit 1
fi

for name in root intermediate; do
    curl -fsSI --max-time 10 "$CRL_BASE_URL/$name.crl" \
        | tr -d '\r' | grep -qi '^content-type: application/pkix-crl' || {
        echo "ERROR: $CRL_BASE_URL/$name.crl has the wrong content type" >&2
        exit 1
    }
    curl -fsS --max-time 10 "$CRL_BASE_URL/$name.crl" \
        -o "$work/fetched-$name.crl"
    cmp "$work/$name.crl" "$work/fetched-$name.crl"
done

openssl crl -inform DER -in "$work/root.crl" -outform PEM \
    -out "$work/root.crl.pem"
openssl crl -inform DER -in "$work/intermediate.crl" -outform PEM \
    -out "$work/intermediate.crl.pem"
cat "$work/root.crl.pem" "$work/intermediate.crl.pem" > "$work/all.crl.pem"
openssl verify -CAfile "$work/root.crt" -untrusted "$work/intermediate.crt" \
    -CRLfile "$work/all.crl.pem" -crl_check_all "$work/wildcard.crt" >/dev/null

expected_serial="$(openssl x509 -in "$work/wildcard.crt" -noout -serial | sed 's/^serial=//')"
served_serial=""
served_ready=""
deadline=$((SECONDS + 120))
while (( SECONDS < deadline )); do
    served_serial="$(printf '\n' \
        | openssl s_client -connect "127.0.0.1:$GATEWAY_PORT" \
            -servername hello.localhost 2>/dev/null \
        | openssl x509 -noout -serial 2>/dev/null \
        | sed 's/^serial=//' || true)"
    if [ "$served_serial" = "$expected_serial" ]; then
        served_ready=1
        break
    fi
    sleep 2
done
if [ -z "$served_ready" ]; then
    echo "ERROR: the Gateway is not serving the current wildcard certificate" >&2
    echo "Expected serial $expected_serial, served ${served_serial:-none}" >&2
    exit 1
fi

echo "Local CA revocation endpoints are ready:"
echo "  $CRL_BASE_URL/root.crl"
echo "  $CRL_BASE_URL/intermediate.crl"
openssl crl -inform DER -in "$work/root.crl" -noout -nextupdate
