#!/usr/bin/env bash
# Generate a certificate chain and server certificate for localhost
# Supports macOS and Linux
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ROOT_CA_PATH="./rootCA"
INTERMEDIATE_CA_PATH="./intermediateCA"
ROOT_CONFIG="./openssl_root.cnf"
INTERMEDIATE_CONFIG="./openssl_intermediate.cnf"
SERVER_CONFIG="./openssl_server.cnf"

SKIP_TRUST="${SKIP_CERT_TRUST:-false}"
FORCE_REGEN="${FORCE_REGEN_CA:-false}"

# ---------------------------
# Check prerequisites
# ---------------------------
if ! command -v openssl &>/dev/null; then
    echo "ERROR: OpenSSL is not installed or not in PATH." >&2
    exit 1
fi
echo "Using OpenSSL at: $(command -v openssl)"

for cfg in "$ROOT_CONFIG" "$INTERMEDIATE_CONFIG" "$SERVER_CONFIG"; do
    if [[ ! -f "$cfg" ]]; then
        echo "ERROR: Missing OpenSSL config file: $cfg" >&2
        exit 1
    fi
done

# ---------------------------
# Create directory structure
# ---------------------------
create_directories() {
    local path="$1"
    mkdir -p "$path"/{certs,crl,csr,newcerts,private}
    chmod 700 "$path/private"
    [[ -f "$path/index.txt" ]] || touch "$path/index.txt"
    [[ -f "$path/serial" ]] || echo "1000" > "$path/serial"
}

create_directories "$ROOT_CA_PATH"
create_directories "$INTERMEDIATE_CA_PATH"

# ---------------------------
# Check existing certs
# ---------------------------
root_exists=false
intermediate_exists=false

if [[ -f "$ROOT_CA_PATH/certs/ca.cert.pem" && -f "$ROOT_CA_PATH/private/ca.key.pem" ]]; then
    root_exists=true
fi
if [[ -f "$INTERMEDIATE_CA_PATH/certs/intermediate.cert.pem" && -f "$INTERMEDIATE_CA_PATH/private/intermediate.key.pem" ]]; then
    intermediate_exists=true
fi

# ---------------------------
# Cleanup helpers
# ---------------------------
cleanup_cert() {
    local path="$1" key="$2" cert="$3"
    rm -f "$path/private/$key" "$path/certs/$cert"
}

if [[ "$root_exists" == "false" || "$FORCE_REGEN" == "true" ]]; then
    echo "Root CA will be regenerated (exists: $root_exists, force: $FORCE_REGEN)"
    cleanup_cert "$ROOT_CA_PATH" "ca.key.pem" "ca.cert.pem"
    cleanup_cert "$INTERMEDIATE_CA_PATH" "intermediate.key.pem" "intermediate.cert.pem"
else
    echo "Preserving existing Root CA and Intermediate CA"
fi

# Always cleanup server cert
cleanup_cert "$INTERMEDIATE_CA_PATH" "localhost.key.pem" "localhost.cert.pem"
rm -f "$INTERMEDIATE_CA_PATH/certs/localhost-chain.cert.pem"

# ---------------------------
# Generate Root CA
# ---------------------------
if [[ "$root_exists" == "false" || "$FORCE_REGEN" == "true" ]]; then
    echo ""
    echo "--- Generating Root CA ---"
    openssl genrsa -out "$ROOT_CA_PATH/private/ca.key.pem" 4096
    openssl req -config "$ROOT_CONFIG" \
        -key "$ROOT_CA_PATH/private/ca.key.pem" \
        -new -x509 -days 7300 -sha256 \
        -extensions v3_ca \
        -out "$ROOT_CA_PATH/certs/ca.cert.pem" \
        -subj "/C=US/ST=State/L=City/O=Company/OU=Department/CN=Root CA"
else
    echo ""
    echo "--- Skipping Root CA generation (already exists) ---"
fi

# ---------------------------
# Generate Intermediate CA
# ---------------------------
if [[ "$intermediate_exists" == "false" || "$FORCE_REGEN" == "true" ]]; then
    echo ""
    echo "--- Generating Intermediate CA ---"
    openssl genrsa -out "$INTERMEDIATE_CA_PATH/private/intermediate.key.pem" 4096
    openssl req -config "$INTERMEDIATE_CONFIG" \
        -key "$INTERMEDIATE_CA_PATH/private/intermediate.key.pem" \
        -new -sha256 \
        -out "$INTERMEDIATE_CA_PATH/csr/intermediate.csr.pem" \
        -subj "/C=US/ST=State/L=City/O=Company/OU=Department/CN=Intermediate CA"

    echo "y" | openssl ca -config "$ROOT_CONFIG" \
        -extensions v3_intermediate_ca \
        -days 3650 -notext -md sha256 \
        -in "$INTERMEDIATE_CA_PATH/csr/intermediate.csr.pem" \
        -out "$INTERMEDIATE_CA_PATH/certs/intermediate.cert.pem" \
        -batch
else
    echo ""
    echo "--- Skipping Intermediate CA generation (already exists) ---"
fi

# ---------------------------
# Generate localhost certificate
# ---------------------------
echo ""
echo "--- Generating localhost certificate ---"

# Ensure existing CA keys are readable (they may have restrictive perms from a previous run)
# Fix directory permissions first, then file permissions
chmod 755 "$ROOT_CA_PATH/private" "$INTERMEDIATE_CA_PATH/private" 2>/dev/null || true
chmod 644 "$ROOT_CA_PATH/private/"*.pem 2>/dev/null || true
chmod 644 "$INTERMEDIATE_CA_PATH/private/"*.pem 2>/dev/null || true
# Verify the intermediate key is actually readable
if [[ -f "$INTERMEDIATE_CA_PATH/private/intermediate.key.pem" ]] && ! head -1 "$INTERMEDIATE_CA_PATH/private/intermediate.key.pem" &>/dev/null; then
    echo "WARNING: Cannot read intermediate key — regenerating CA chain..."
    FORCE_REGEN="true"
    cleanup_cert "$ROOT_CA_PATH" "ca.key.pem" "ca.cert.pem"
    cleanup_cert "$INTERMEDIATE_CA_PATH" "intermediate.key.pem" "intermediate.cert.pem"
    # Re-run the CA generation steps
    echo "--- Regenerating Root CA ---"
    openssl genrsa -out "$ROOT_CA_PATH/private/ca.key.pem" 4096
    openssl req -config "$ROOT_CONFIG" \
        -key "$ROOT_CA_PATH/private/ca.key.pem" \
        -new -x509 -days 7300 -sha256 \
        -extensions v3_ca \
        -out "$ROOT_CA_PATH/certs/ca.cert.pem" \
        -subj "/C=US/ST=State/L=City/O=Company/OU=Department/CN=Root CA"

    echo "--- Regenerating Intermediate CA ---"
    openssl genrsa -out "$INTERMEDIATE_CA_PATH/private/intermediate.key.pem" 4096
    openssl req -config "$INTERMEDIATE_CONFIG" \
        -key "$INTERMEDIATE_CA_PATH/private/intermediate.key.pem" \
        -new -sha256 \
        -out "$INTERMEDIATE_CA_PATH/csr/intermediate.csr.pem" \
        -subj "/C=US/ST=State/L=City/O=Company/OU=Department/CN=Intermediate CA"
    echo "y" | openssl ca -config "$ROOT_CONFIG" \
        -extensions v3_intermediate_ca \
        -days 3650 -notext -md sha256 \
        -in "$INTERMEDIATE_CA_PATH/csr/intermediate.csr.pem" \
        -out "$INTERMEDIATE_CA_PATH/certs/intermediate.cert.pem" \
        -batch
fi

openssl genrsa -out "$INTERMEDIATE_CA_PATH/private/localhost.key.pem" 4096
openssl req -new \
    -key "$INTERMEDIATE_CA_PATH/private/localhost.key.pem" \
    -out "$INTERMEDIATE_CA_PATH/csr/localhost.csr.pem" \
    -config "$SERVER_CONFIG" \
    -extensions req_ext

echo "y" | openssl ca -config "$SERVER_CONFIG" \
    -extensions req_ext \
    -days 825 -notext -md sha256 \
    -in "$INTERMEDIATE_CA_PATH/csr/localhost.csr.pem" \
    -out "$INTERMEDIATE_CA_PATH/certs/localhost.cert.pem" \
    -batch

# Make key readable for kubectl
chmod 644 "$INTERMEDIATE_CA_PATH/private/localhost.key.pem"

# ---------------------------
# Bundle the certificate chain
# ---------------------------
cat "$INTERMEDIATE_CA_PATH/certs/localhost.cert.pem" \
    "$INTERMEDIATE_CA_PATH/certs/intermediate.cert.pem" \
    > "$INTERMEDIATE_CA_PATH/certs/localhost-chain.cert.pem"

# ---------------------------
# Trust Root CA in system keychain
# ---------------------------
if [[ "$SKIP_TRUST" != "true" ]]; then
    echo ""
    echo "--- Checking Root CA trust status ---"

    OS_TYPE="$(uname -s)"
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        # macOS: trust in System keychain
        if security verify-cert -c "$ROOT_CA_PATH/certs/ca.cert.pem" &>/dev/null; then
            echo "Root CA is already trusted in macOS System keychain"
        else
            echo "Installing Root CA in macOS System keychain (requires sudo)..."
            sudo security add-trusted-cert -d -r trustRoot -p ssl \
                -k /Library/Keychains/System.keychain \
                "$ROOT_CA_PATH/certs/ca.cert.pem"
            echo "Root CA installed and trusted for SSL"
        fi
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        TARGET="/usr/local/share/ca-certificates/dev-root-ca.crt"
        if [[ -f "$TARGET" ]]; then
            existing_hash=$(openssl x509 -in "$TARGET" -noout -fingerprint -sha1 2>/dev/null | sed 's/.*=//')
            current_hash=$(openssl x509 -in "$ROOT_CA_PATH/certs/ca.cert.pem" -noout -fingerprint -sha1 2>/dev/null | sed 's/.*=//')
            if [[ "$existing_hash" == "$current_hash" ]]; then
                echo "Root CA is already installed in Linux trusted certificates"
            else
                echo "Updating Root CA in Linux trusted certificates..."
                sudo cp "$ROOT_CA_PATH/certs/ca.cert.pem" "$TARGET"
                sudo update-ca-certificates
            fi
        else
            echo "Installing Root CA in Linux trusted certificates..."
            sudo cp "$ROOT_CA_PATH/certs/ca.cert.pem" "$TARGET"
            sudo update-ca-certificates
        fi
    else
        echo "Unsupported OS for automatic trust: $OS_TYPE"
        echo "Manually trust: $ROOT_CA_PATH/certs/ca.cert.pem"
    fi
else
    echo ""
    echo "Skipping certificate trust installation (SKIP_CERT_TRUST=true)"
fi

echo ""
echo "Certificate generation completed!"
echo "  Chain:   $INTERMEDIATE_CA_PATH/certs/localhost-chain.cert.pem"
echo "  Key:     $INTERMEDIATE_CA_PATH/private/localhost.key.pem"
echo "  Root CA: $ROOT_CA_PATH/certs/ca.cert.pem"
