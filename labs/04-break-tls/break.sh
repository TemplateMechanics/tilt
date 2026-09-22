#!/usr/bin/env bash
# break.sh mismatch  -> remove hello.localhost from the certificate SANs
# break.sh trust     -> remove the platform root CA from the OS trust store
#                       (interactive on Windows; see below)
. "$(dirname "$0")/../lib.sh"
case "${1:-}" in
  mismatch)
    cert="$ROOT/helm/istio/gateway/base/certificate.yaml"
    sed -i '/^    - hello\.localhost$/d' "$cert"
    grep -q '^    - hello\.localhost$' "$cert" && { echo "ERROR: SAN still present in $cert"; exit 1; }
    $K apply -k "$ROOT/helm/istio/gateway/overlays/${PLATFORM_OVERLAY:-kind}" >/dev/null
    echo "removed hello.localhost from the cert; waiting for cert-manager to reissue..."
    if wait_for 120 reissue bash -c "echo | openssl s_client -connect 127.0.0.1:${GATEWAY_PORT} -servername hello.localhost 2>/dev/null | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -qv 'DNS:hello.localhost'"; then
        echo "served certificate no longer lists hello.localhost. Now: ./labs/04-break-tls/probe.sh hello.localhost"
    else
        echo "ERROR: certificate still lists hello.localhost after 120s"; exit 1
    fi
    ;;
  trust)
    root_ca=$($K get secret local-root-ca -n cert-manager -o go-template='{{index .data "tls.crt"}}' | base64 -d)
    fp=$(printf '%s\n' "$root_ca" | openssl x509 -noout -fingerprint -sha1 | sed 's/.*=//;s/://g')
    ski=$(printf '%s\n' "$root_ca" | openssl x509 -noout -ext subjectKeyIdentifier | sed -n '2{s/[[:space:]:]//g;p;}')
    [ -n "$fp" ] && [ -n "$ski" ] || { echo "ERROR: could not identify the current root CA"; exit 1; }
    case "$(uname -s)" in
      MINGW*|MSYS*|CYGWIN*)
        # Deliberately NOT automated. Windows shows a GUI confirmation dialog
        # for any deletion from the user Root store — `certutil -delstore` and
        # PowerShell's Remove-Item both trigger it — so a scripted delete hangs
        # forever waiting for a click. Found the hard way: a background run sat
        # on this for fifteen minutes.
        echo "On Windows this step is interactive. Run in a terminal and click Yes:"
        echo "  certutil -delstore -user Root $fp"
        echo "Or see the failure without touching your store at all:"
        echo "  ./labs/04-break-tls/probe.sh hello.localhost --untrusted"
        exit 2 ;;
      Darwin)
        keychain=$(security default-keychain -d user | tr -d '"' | sed 's/^[[:space:]]*//')
        [ -n "$keychain" ] || keychain="${HOME}/Library/Keychains/login.keychain-db"
        legacy_fp=$(security find-certificate -a -c "Tilt Local Development Root CA" \
          -Z /Library/Keychains/System.keychain 2>/dev/null \
          | awk -v ski="$ski" '
              /^SHA-1 hash:/ { sha1=$3 }
              index(toupper($0), "\"SKID\"<BLOB>=0X" toupper(ski)) { print sha1; exit }
            ')
        if [ -n "$legacy_fp" ]; then
          echo "ERROR: a same-key root is also trusted in the legacy System keychain."
          echo "Review and remove that exact certificate, then rerun this lab:"
          echo "  sudo security delete-certificate -Z $legacy_fp /Library/Keychains/System.keychain"
          exit 2
        fi
        security delete-certificate -Z "$fp" "$keychain" \
          && echo "removed root CA $fp from the macOS user keychain"
        ;;
      Linux)  sudo rm -f /usr/local/share/ca-certificates/dev-root-ca.crt && sudo update-ca-certificates >/dev/null && echo "removed root CA from Linux store" ;;
    esac
    ;;
  *) echo "usage: break.sh mismatch|trust"; exit 2 ;;
esac
