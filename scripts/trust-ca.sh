#!/usr/bin/env bash
# Export this cluster's development root CA and install it in the host trust
# store. On macOS the user/login keychain is used deliberately: it needs no
# administrator trust-domain mutation and is the store Chrome consults for a
# user-installed local anchor.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
CONTEXT="${CONTEXT:-kind-tiltdev}"
# One trust file per cluster. A single shared dev-root-ca.crt meant trusting a
# second cluster replaced the first one's CA, and its HTTPS stopped verifying.
CLUSTER_NAME="${CONTEXT#kind-}"
GATEWAY_PORT="${GATEWAY_PORT:-443}"
host="${TRUST_CHECK_HOST:-hello.localhost}"
port_suffix=""
[ "$GATEWAY_PORT" = "443" ] || port_suffix=":$GATEWAY_PORT"
url="https://$host$port_suffix/"

IS_WSL=0
grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1

# Prove the host-native path, i.e. the store the browser uses. On managed
# macOS, requiring revocation also proves that both CRL distribution points
# are reachable; issuer trust alone is not enough for Chrome's local-anchor
# policy. Under WSL that is Windows: System32's curl.exe uses schannel and the
# Windows store (Git for Windows' curl.exe, often earlier on PATH, does not).
verify_native() {
    local code
    case "$(uname -s)" in
        Darwin)
            if security verify-cert -R require "$url" >/dev/null 2>&1; then
                echo "Verified macOS trust and online revocation: $url"
                return 0
            fi
            echo "ERROR: macOS rejected $url or could not obtain revocation status." >&2
            exit 2
            ;;
    esac
    if [ "$IS_WSL" = 1 ]; then
        code="$(/mnt/c/Windows/System32/curl.exe -sS -o NUL -w '%{http_code}' --max-time 15 \
            --ssl-revoke-best-effort --resolve "$host:$GATEWAY_PORT:127.0.0.1" "$url" 2>/dev/null || true)"
    else
        code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 \
            --resolve "$host:$GATEWAY_PORT:127.0.0.1" "$url" 2>/dev/null || true)"
    fi
    if [ -z "$code" ] || [ "$code" = "000" ]; then
        echo "ERROR: $url did not verify through the OS trust store." >&2
        exit 2
    fi
    echo "Verified OS trust: $url answered HTTP $code."
}

fp_of() {
    openssl x509 -in "$1" -noout -fingerprint -sha256 2>/dev/null \
        | sed 's/.*=//'
}

mac_login_keychain() {
    local keychain
    keychain="$(security default-keychain -d user 2>/dev/null | tr -d '"' | sed 's/^[[:space:]]*//')"
    if [ -n "$keychain" ]; then
        printf '%s\n' "$keychain"
    else
        printf '%s\n' "${HOME}/Library/Keychains/login.keychain-db"
    fi
}

if [ "${1:-}" = "--list" ]; then
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            powershell -NoProfile -Command "Get-ChildItem Cert:\\CurrentUser\\Root | Where-Object { \$_.Subject -match 'Development Root CA' } | Select-Object Thumbprint,Subject,NotAfter | Format-Table -AutoSize"
            echo "Remove one with: certutil -delstore -user Root <thumbprint>"
            ;;
        Darwin)
            keychain="$(mac_login_keychain)"
            echo "User keychain: $keychain"
            security find-certificate -a -c "Tilt Local Development Root CA" \
                -Z "$keychain" 2>/dev/null | grep -E "SHA-256|SHA-1|labl" || true
            legacy="$(security find-certificate -a -c "Tilt Local Development Root CA" \
                -Z /Library/Keychains/System.keychain 2>/dev/null \
                | grep -E "SHA-256|SHA-1|labl" || true)"
            if [ -n "$legacy" ]; then
                echo "Legacy System keychain entries (not modified automatically):"
                printf '%s\n' "$legacy"
            fi
            ;;
        Linux)
            ls -l /usr/local/share/ca-certificates/dev-root-ca*.crt 2>/dev/null || true
            if grep -qi microsoft /proc/version 2>/dev/null; then
                powershell.exe -NoProfile -Command "Get-ChildItem Cert:\\CurrentUser\\Root | Where-Object { \$_.Subject -match 'Development Root CA' } | Select-Object Thumbprint,Subject,NotAfter | Format-Table -AutoSize"
                echo "Remove one from Windows with: certutil.exe -delstore -user Root <thumbprint>"
            fi
            ;;
    esac
    exit 0
fi

for command in kubectl openssl base64 curl install sed tr awk; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "ERROR: required command is missing: $command" >&2
        exit 1
    }
done

CA_FILE="$(mktemp "${TMPDIR:-/tmp}/dev-root-ca.XXXXXX")"
trap '/bin/rm -f "$CA_FILE"' EXIT
kubectl --context "$CONTEXT" get secret local-root-ca -n cert-manager \
    -o go-template='{{index .data "tls.crt"}}' 2>/dev/null \
    | base64 -d > "$CA_FILE"
if [ ! -s "$CA_FILE" ] || ! openssl x509 -in "$CA_FILE" -noout >/dev/null 2>&1; then
    echo "ERROR: could not export a valid CA from cluster context $CONTEXT" >&2
    exit 1
fi

mkdir -p ./.local
install -m 0644 "$CA_FILE" ./.local/dev-root-ca.crt
FP="$(fp_of "$CA_FILE")"
FP_HEX="$(printf '%s' "$FP" | tr -d ':')"
CA_SKI="$(openssl x509 -in "$CA_FILE" -noout -ext subjectKeyIdentifier \
    | sed -n '2{s/[[:space:]:]//g;p;}')"
[ -n "$CA_SKI" ] || {
    echo "ERROR: exported root CA has no subject key identifier" >&2
    exit 1
}
echo "Root CA written to .local/dev-root-ca.crt"
echo "CA fingerprint (SHA-256): $FP"

if [ "${TRUST_CA:-1}" = "0" ]; then
    echo "TRUST_CA=0 - exported the CA, but did not modify the OS trust store."
    exit 0
fi

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        echo "Windows may ask you to confirm installing the development root CA."
        if timeout 120 certutil -addstore -user -f Root \
            "$(cygpath -w "$CA_FILE" 2>/dev/null || echo "$CA_FILE")" >/dev/null; then
            echo "Root CA trusted in the Windows user Root store."
        else
            echo "ERROR: the root CA was not trusted (prompt unanswered or certutil failed)." >&2
            exit 1
        fi
        ;;
    Darwin)
        keychain="$(mac_login_keychain)"
        present="$(security find-certificate -a -c "Tilt Local Development Root CA" \
            -Z "$keychain" 2>/dev/null | grep -F "SHA-256 hash: $FP_HEX" || true)"
        if [ -z "$present" ] \
            || ! security verify-cert -c "$CA_FILE" -p ssl >/dev/null 2>&1; then
            echo "Installing the current root in the macOS user keychain: $keychain"
            security add-trusted-cert -r trustRoot -p ssl -k "$keychain" "$CA_FILE"
        else
            echo "Current root is already trusted for SSL in the macOS user keychain."
        fi
        legacy_fp="$(security find-certificate -a -c "Tilt Local Development Root CA" \
            -Z /Library/Keychains/System.keychain 2>/dev/null \
            | awk -v ski="$CA_SKI" '
                /^SHA-1 hash:/ { sha1=$3 }
                index(toupper($0), "\"SKID\"<BLOB>=0X" toupper(ski)) { print sha1; exit }
            ')"
        if [ -n "$legacy_fp" ]; then
            echo "WARNING: a same-key root also remains in the legacy System keychain." >&2
            echo "Review and remove it manually if no other cluster uses it:" >&2
            echo "  sudo security delete-certificate -Z $legacy_fp /Library/Keychains/System.keychain" >&2
        fi
        ;;
    Linux)
        # Under WSL the browser is a Windows program reading the Windows store,
        # so the Linux store - which needs sudo, and so failed under Tilt with
        # no terminal - left every browser warning anyway. The Windows *user*
        # Root store needs no administrator; Windows asks for confirmation.
        # Nothing in WSL needs the Linux store: the lab graders pass the CA
        # with --cacert. TRUST_LINUX=1 adds it as well, with sudo.
        if [ "$IS_WSL" = 1 ]; then
            win_thumb="$(openssl x509 -in "$CA_FILE" -noout -fingerprint -sha1 | sed 's/.*=//;s/://g')"
            if powershell.exe -NoProfile -Command "if (Test-Path Cert:\\CurrentUser\\Root\\$win_thumb) { exit 0 } else { exit 1 }" >/dev/null 2>&1; then
                echo "Current root is already trusted by Windows (user Root store, $win_thumb)."
            else
                win_ca="$(wslpath -w "$ROOT/.local/dev-root-ca.crt")"
                echo "Windows will ask you to confirm installing the development root CA."
                if timeout 120 certutil.exe -addstore -user -f Root "$win_ca" >/dev/null; then
                    echo "Root CA trusted in the Windows user Root store ($win_thumb)."
                else
                    echo "ERROR: Windows did not trust the root CA (prompt declined or unanswered)." >&2
                    exit 1
                fi
            fi
            [ "${TRUST_LINUX:-0}" = 1 ] || { verify_native; exit 0; }
        fi
        target="/usr/local/share/ca-certificates/dev-root-ca-${CLUSTER_NAME}.crt"
        existing=""
        [ -f "$target" ] && existing="$(fp_of "$target")"
        native_code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 \
            --resolve "$host:$GATEWAY_PORT:127.0.0.1" "$url" 2>/dev/null || true)"
        if [ "$existing" = "$FP" ] \
            && [ -n "$native_code" ] && [ "$native_code" != "000" ]; then
            echo "Current root is already trusted by Linux."
        elif [ ! -t 0 ] && ! sudo -n true 2>/dev/null \
            && ! command -v pkexec >/dev/null 2>&1 && ! command -v zenity >/dev/null 2>&1; then
            # Under Tilt there is no terminal to type a password into, and sudo
            # failing mid-script read as a broken platform. Say what to run.
            echo "ERROR: trusting the CA in Linux needs your password, and there is no terminal here." >&2
            echo "  Run once in a terminal, then re-trigger this resource:" >&2
            echo "    cd '$ROOT' && CONTEXT='$CONTEXT' GATEWAY_PORT='$GATEWAY_PORT' KUBECONFIG='${KUBECONFIG:-}' ./scripts/trust-ca.sh" >&2
            exit 1
        else
            bash ./archive/openssl-certs/sudo-helper.sh \
                "cp '$CA_FILE' '$target' && update-ca-certificates"
            echo "Root CA trusted in the Linux certificate store."
        fi
        ;;
    *)
        echo "ERROR: unsupported OS; trust this file manually: .local/dev-root-ca.crt" >&2
        exit 1
        ;;
esac

verify_native
