#!/usr/bin/env bash
# Apply the local CA chain with a CRL URL that matches the host port mapping.
#
# The checked-in manifests use the normal port-80 URL. The alternate kind
# topology publishes HTTP on 8080, so its certificates must contain :8080.
# Rendering here keeps one PKI definition while ensuring the URL is embedded
# before cert-manager issues the intermediate and leaf certificates.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${CONTEXT:-kind-tiltdev}"
CRL_BASE_URL="${CRL_BASE_URL:-http://crl.localhost}"
K=(kubectl --context "$CONTEXT")

if [[ ! "$CRL_BASE_URL" =~ ^http://crl\.localhost(:[0-9]+)?$ ]]; then
    echo "ERROR: CRL_BASE_URL must be http://crl.localhost with an optional port" >&2
    exit 2
fi

render() {
    sed "s|http://crl.localhost|$CRL_BASE_URL|g" "$1"
}

if [ "${1:-}" = "--render" ]; then
    render "$ROOT/helm/cert-manager/pki/base/cluster-issuers.yaml"
    render "$ROOT/helm/cert-manager/pki/base/certificates.yaml"
    exit 0
fi

for command in kubectl openssl base64 sed awk grep; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "ERROR: required command is missing: $command" >&2
        exit 1
    }
done

work="$(mktemp -d "${TMPDIR:-/tmp}/tilt-local-pki.XXXXXX")"
cleanup() {
    chmod -R u+w "$work" 2>/dev/null || true
    /bin/rm -rf -- "$work"
}
trap cleanup EXIT
umask 077

secret_cert() {
    local namespace="$1" secret="$2" output="$3"
    "${K[@]}" -n "$namespace" get secret "$secret" \
        -o go-template='{{index .data "tls.crt"}}' 2>/dev/null \
        | base64 -d \
        | awk 'BEGIN { n=0 } /BEGIN CERTIFICATE/ { n++ } n==1 { print } /END CERTIFICATE/ && n==1 { exit }' \
        > "$output"
    [ -s "$output" ] && openssl x509 -in "$output" -noout >/dev/null 2>&1
}

spki_sha256() {
    openssl x509 -in "$1" -pubkey -noout \
        | openssl pkey -pubin -outform DER 2>/dev/null \
        | openssl dgst -sha256 | sed 's/.*= //'
}

old_root_spki=""
if secret_cert cert-manager local-root-ca "$work/root-before.crt"; then
    old_root_spki="$(spki_sha256 "$work/root-before.crt")"
fi

# Issuers go first so any reissued certificate receives the desired CRL
# distribution point. Changing CA usages below is a cert-manager-supported
# reissuance trigger and rotationPolicy: Never preserves the CA keys.
render "$ROOT/helm/cert-manager/pki/base/cluster-issuers.yaml" \
    | "${K[@]}" apply -f -
render "$ROOT/helm/cert-manager/pki/base/certificates.yaml" \
    | "${K[@]}" apply -f -

"${K[@]}" -n cert-manager wait --for=condition=Ready \
    certificate/local-root-ca --timeout=240s
"${K[@]}" wait --for=condition=Ready clusterissuer/local-root-ca --timeout=120s
"${K[@]}" -n cert-manager wait --for=condition=Ready \
    certificate/local-intermediate-ca --timeout=240s
"${K[@]}" wait --for=condition=Ready \
    clusterissuer/local-intermediate-ca --timeout=120s

deadline=$((SECONDS + 240))
while (( SECONDS < deadline )); do
    if secret_cert cert-manager local-root-ca "$work/root.crt" \
        && secret_cert cert-manager local-intermediate-ca "$work/intermediate.crt" \
        && openssl x509 -in "$work/root.crt" -noout -text | grep -q 'CRL Sign' \
        && openssl x509 -in "$work/intermediate.crt" -noout -text | grep -q 'CRL Sign' \
        && openssl x509 -in "$work/intermediate.crt" -noout -text | grep -Fq "$CRL_BASE_URL/root.crl"; then
        break
    fi
    sleep 2
done

if ! openssl x509 -in "$work/root.crt" -noout -text | grep -q 'CRL Sign'; then
    echo "ERROR: root CA was not reissued with cRLSign" >&2
    exit 1
fi
if ! openssl x509 -in "$work/intermediate.crt" -noout -text | grep -q 'CRL Sign'; then
    echo "ERROR: intermediate CA was not reissued with cRLSign" >&2
    exit 1
fi
if ! openssl x509 -in "$work/intermediate.crt" -noout -text \
    | grep -Fq "$CRL_BASE_URL/root.crl"; then
    echo "ERROR: intermediate certificate has the wrong root CRL URL" >&2
    exit 1
fi

new_root_spki="$(spki_sha256 "$work/root.crt")"
if [ -n "$old_root_spki" ] && [ "$old_root_spki" != "$new_root_spki" ]; then
    echo "ERROR: the root CA key changed while applying a metadata-only update" >&2
    echo "Refusing to report success; the new root must be reviewed and re-trusted." >&2
    exit 1
fi

openssl verify -CAfile "$work/root.crt" "$work/intermediate.crt" >/dev/null
echo "Local CA chain ready with CRL signing and $CRL_BASE_URL"
openssl x509 -in "$work/root.crt" -noout -fingerprint -sha256
