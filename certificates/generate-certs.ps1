# PowerShell Script to Create a Certificate Chain and Server Certificate for localhost
# This version installs certs at the "user level" on macOS if not running as root.
# On Linux, it still does system-wide trust if root; skip if not.
# On Windows, does a system-wide trust (requires admin).

# ---------------------------
# Variables for easy configuration
# ---------------------------
$rootCAPath         = Join-Path $PSScriptRoot "rootCA"
$intermediateCAPath = Join-Path $PSScriptRoot "intermediateCA"
$rootConfig         = Join-Path $PSScriptRoot "openssl_root.cnf"
$intermediateConfig = Join-Path $PSScriptRoot "openssl_intermediate.cnf"
$serverConfig       = Join-Path $PSScriptRoot "openssl_server.cnf"

# Change to the script's own directory to avoid System32 confusion
Set-Location -Path $PSScriptRoot

# Detect if we're on Windows
$platformIsWindows = ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)

if ($platformIsWindows) {
    # -- Windows: check for admin privileges and re-run if needed --
    $windowsIdentity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = New-Object Security.Principal.WindowsPrincipal($windowsIdentity)
    $isAdmin          = $windowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "Not running as Administrator. Relaunching with elevated privileges..."
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}
else {
    # -- macOS / Linux
    $isRoot = ($env:USER -eq "root")

    if (-not $isRoot) {
        Write-Warning "Not running as root. We'll generate certs and do user-level trust on macOS, or skip system trust on Linux."
        Write-Warning "If you need system-wide trust on Linux or macOS, re-run this script with sudo."
    }
}

# ---------------------------
# Check for OpenSSL installation
# ---------------------------
try {
    $opensslPath = (Get-Command openssl).Source
    Write-Host "Using OpenSSL at: $opensslPath"
} catch {
    Write-Error "OpenSSL is not installed or not in the PATH."
    exit
}

# ---------------------------
# Create directories
# ---------------------------
function CreateDirectories($path) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $folders = 'certs', 'crl', 'newcerts', 'private', 'csr'
    foreach ($folder in $folders) {
        $dirPath = Join-Path $path $folder
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        # On non-Windows, apply restrictive permissions to 'private'
        if ($folder -eq 'private' -and -not $platformIsWindows) {
            chmod 700 $dirPath
        }
    }
    # Initialize index.txt and serial
    Set-Content -Path (Join-Path $path "index.txt") -Value $null
    Set-Content -Path (Join-Path $path "serial") -Value "1000"
}

CreateDirectories $rootCAPath
CreateDirectories $intermediateCAPath

# ---------------------------
# Generate Root CA
# ---------------------------
Write-Host "`n--- Generating Root CA ---"
openssl genrsa -out "$rootCAPath/private/ca.key.pem" 4096
openssl req -config $rootConfig `
    -key "$rootCAPath/private/ca.key.pem" `
    -new -x509 -days 7300 -sha256 -extensions v3_ca `
    -out "$rootCAPath/certs/ca.cert.pem" `
    -subj "/C=US/ST=State/L=City/O=Company/OU=Department/CN=Root CA"
Write-Host "Root CA Certificate generated."

# ---------------------------
# Generate Intermediate CA
# ---------------------------
Write-Host "`n--- Generating Intermediate CA ---"
openssl genrsa -out "$intermediateCAPath/private/intermediate.key.pem" 4096
openssl req -config $intermediateConfig `
    -key "$intermediateCAPath/private/intermediate.key.pem" `
    -new -sha256 `
    -out "$intermediateCAPath/csr/intermediate.csr.pem" `
    -subj "/C=US/ST=State/L=City/O=Company/OU=Department/CN=Intermediate CA"

if (Test-Path "$intermediateCAPath/csr/intermediate.csr.pem") {
    echo "y" | openssl ca -config $rootConfig -extensions v3_intermediate_ca `
        -days 3650 -notext -md sha256 `
        -in "$intermediateCAPath/csr/intermediate.csr.pem" `
        -out "$intermediateCAPath/certs/intermediate.cert.pem" `
        -batch
    Write-Host "Intermediate CA Certificate generated."
} else {
    Write-Warning "Intermediate CSR generation failed. Skipping Intermediate CA creation."
}

# ---------------------------
# Generate localhost cert
# ---------------------------
Write-Host "`n--- Generating localhost certificate ---"
openssl genrsa -out "$intermediateCAPath/private/localhost.key.pem" 4096
openssl req -new `
    -key "$intermediateCAPath/private/localhost.key.pem" `
    -out "$intermediateCAPath/csr/localhost.csr.pem" `
    -config $serverConfig -extensions req_ext

if (Test-Path "$intermediateCAPath/csr/localhost.csr.pem") {
    echo "y" | openssl ca -config $serverConfig -extensions req_ext `
        -days 825 -notext -md sha256 `
        -in "$intermediateCAPath/csr/localhost.csr.pem" `
        -out "$intermediateCAPath/certs/localhost.cert.pem" `
        -batch
    Write-Host "Localhost Server Certificate generated."
} else {
    Write-Warning "Localhost CSR generation failed."
}

# ---------------------------
# Display the new certificates
# ---------------------------
Write-Host "`nRoot CA Certificate Info:"
openssl x509 -noout -text -in "$rootCAPath/certs/ca.cert.pem"

Write-Host "`nIntermediate CA Certificate Info:"
openssl x509 -noout -text -in "$intermediateCAPath/certs/intermediate.cert.pem" 2>$null

Write-Host "`nLocalhost Server Certificate Info:"
openssl x509 -noout -text -in "$intermediateCAPath/certs/localhost.cert.pem" 2>$null

# ---------------------------
# System trust steps
# ---------------------------
if ($platformIsWindows) {
    # ---- Windows system-wide trust (requires admin) ----
    Write-Host "`n--- Installing Root CA on Windows ---"
    Import-Certificate -FilePath "$intermediateCAPath/certs/intermediate.cert.pem" -CertStoreLocation "Cert:\LocalMachine\Root"
    Write-Host "Root CA certificate is now trusted in Windows."
}
else {
    # macOS or Linux
    $isRoot = ($env:USER -eq "root")

    # Use a variable name that does NOT conflict with built-in $IsMacOS
    $myIsMacOS = $false
    if ($env:OSTYPE -and $env:OSTYPE -like "*darwin*") {
        $myIsMacOS = $true
    }
    elseif ((Get-Command uname -ErrorAction SilentlyContinue) -and ((uname) -eq "Darwin")) {
        $myIsMacOS = $true
    }

    if ($myIsMacOS) {
        # ---------------
        # macOS logic
        # ---------------
        if ($isRoot) {
            # System-wide trust
            Write-Host "`n--- Installing Root CA system-wide on macOS (root) ---"
            security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$rootCAPath/certs/ca.cert.pem"
            Write-Host "Root CA certificate is now trusted system-wide on macOS."
        }
        else {
            # User-level trust in login keychain
            Write-Host "`n--- Installing Root CA into your user login keychain (macOS) ---"
            # This may prompt for your account password
            security add-trusted-cert -k ~/Library/Keychains/login.keychain "$rootCAPath/certs/ca.cert.pem"
            Write-Host "Root CA certificate is now trusted in your user account on macOS."
        }
    }
    else {
        # ---------------
        # Linux logic
        # ---------------
        if ($isRoot) {
            # System-wide trust
            Write-Host "`n--- Installing Root CA system-wide on Linux (root) ---"
            cp "$rootCAPath/certs/ca.cert.pem" /usr/local/share/ca-certificates/
            update-ca-certificates
            Write-Host "Root CA certificate is now trusted system-wide on Linux."
        }
        else {
            # Not root on Linux => skip
            Write-Host "`nSkipping system trust on Linux, because you're not root."
            Write-Host "If you need system-wide trust, rerun this script with sudo, or install $rootCAPath/certs/ca.cert.pem manually."
        }
    }
}

Write-Host "`nCertificate generation completed."
Write-Host "Press any key to exit..."
$null = Read-Host
