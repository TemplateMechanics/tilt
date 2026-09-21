#!/usr/bin/env bash
# Trust this cluster's development root CA, on its own.
#
# Tilt's dev-ca-trust resource does this during a build, but on Windows the
# operating system raises a confirmation dialog that nobody may be sitting in
# front of, and that step gives up after two minutes rather than blocking the
# platform. This is how you do it afterwards, without a rebuild.
#
# Until it is done, every curl and browser check against the platform fails
# (lab 01: 3 of 6 checks, including ERR_CERT_AUTHORITY_INVALID in Chrome).
# The labs' TLS-code assertions verify against the CA read from the cluster,
# so they pass either way - a green "TLS verifies" line says nothing about
# your trust store.
#
# Each cluster mints its own CA, so a `reset` means a new certificate and one
# more entry in your trust store. `--list` shows what has accumulated.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
CONTEXT="${CONTEXT:-kind-tiltdev}"

fp_of() { openssl x509 -in "$1" -noout -fingerprint -sha256 2>/dev/null | sed 's/.*=//'; }

if [ "${1:-}" = "--list" ]; then
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            powershell -NoProfile -Command "Get-ChildItem Cert:\\CurrentUser\\Root | Where-Object { \$_.Subject -match 'Development Root CA' } | Select-Object Thumbprint,Subject,NotAfter | Format-Table -AutoSize"
            echo "Remove one with:  certutil -delstore -user Root <thumbprint>"
            ;;
        Darwin) security find-certificate -a -c "Development Root CA" -Z /Library/Keychains/System.keychain 2>/dev/null | grep -E "SHA-256|labl" ;;
        *)      ls -l /usr/local/share/ca-certificates/ 2>/dev/null ;;
    esac
    exit 0
fi

# Export from the cluster rather than trusting the file in .local/: that file is
# a copy, and a copy can disagree with what the gateway is actually serving.
CA_FILE="$(mktemp -t dev-root-ca-XXXXXX).crt"
kubectl --context "$CONTEXT" get secret local-root-ca -n cert-manager \
    -o go-template='{{index .data "tls.crt"}}' 2>/dev/null | base64 -d > "$CA_FILE"
if [ ! -s "$CA_FILE" ]; then
    echo "ERROR: could not read the CA from the cluster (context $CONTEXT)."
    echo "Is the cluster up, and has cert-manager-pki finished?"
    exit 1
fi
FP=$(fp_of "$CA_FILE")
echo "CA fingerprint (SHA-256): $FP"
# Windows identifies certificates by SHA-1 thumbprint, and --list prints those.
# Comparing the SHA-256 above against a thumbprint says "not trusted" about a
# CA that is trusted - it cost an hour here. Print both.
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*)
    echo "Windows thumbprint (SHA-1): $(openssl x509 -in "$CA_FILE" -noout -fingerprint -sha1 | sed 's/.*=//' | tr -d ':')" ;;
esac

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        echo "Windows will ask you to confirm. Click Yes."
        if certutil -addstore -user -f Root "$(cygpath -w "$CA_FILE")" >/dev/null; then
            echo "Trusted in the Windows user Root store."
        else
            echo "ERROR: not trusted. If no dialog appeared, run this from an admin PowerShell:"
            echo "  certutil -addstore Root $(cygpath -w "$CA_FILE")"
            exit 1
        fi
        ;;
    Darwin)
        bash ./archive/openssl-certs/sudo-helper.sh \
            "security add-trusted-cert -d -r trustRoot -p ssl -k /Library/Keychains/System.keychain $CA_FILE" \
            && echo "Trusted in the macOS System keychain." \
            || { echo "ERROR: not trusted (sudo declined or security failed)."; exit 1; }
        ;;
    Linux)
        bash ./archive/openssl-certs/sudo-helper.sh \
            "cp $CA_FILE /usr/local/share/ca-certificates/dev-root-ca.crt && update-ca-certificates" \
            && echo "Trusted in the Linux certificate store." \
            || { echo "ERROR: not trusted (sudo declined or update-ca-certificates failed)."; exit 1; }
        ;;
    *)  echo "Unsupported OS. Trust this file by hand: $CA_FILE"; exit 1 ;;
esac

# Prove it, rather than trusting the exit code of the thing that just ran.
# A curl WITHOUT -k is the only evidence that the trust store took effect.
# --ssl-no-revoke matters on Windows: curl there is a Schannel build, and
# Schannel tries a revocation check that a local CA with no CRL endpoint
# cannot satisfy. Without the flag this returns 000 / exit 35 on a correctly
# trusted CA, which reads exactly like a trust failure and is not one.
# TRUST_CHECK_HOST exists so the failure branch can be tested: a host the
# certificate does not name fails TLS the same way an untrusted CA does.
host="${TRUST_CHECK_HOST:-hello.localhost}"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 --ssl-no-revoke \
        --resolve "$host:443:127.0.0.1" "https://$host/" 2>/dev/null)
# Any HTTP status proves the chain verified: without -k, a TLS failure aborts
# before HTTP and curl reports 000. So 503 means "trusted, app down" - which
# an earlier version of this script called a trust failure and exited 2 on.
case "${code:-000}" in
    200) echo "Verified: https://$host returns 200 without -k." ;;
    000) # Non-zero, not a warning: `./scripts/trust-ca.sh && next-step` must
         # not carry on as if TLS verified when the evidence says it does not.
         echo "ERROR: https://$host does not verify over TLS (no response, code 000)."
         echo "The certificate is installed but not trusted for this host, or nothing is listening."
         exit 2 ;;
    *)   echo "Verified TLS: https://$host answered over a trusted connection (HTTP $code)."
         echo "The CA is trusted. HTTP $code is the app, not the certificate - check: kubectl -n hello get pods" ;;
esac
