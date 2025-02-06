# PowerShell Script to Create a Certificate Chain and Server Certificate for localhost
# Supports Windows, macOS, and Linux

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

# Detect OS
$platformIsWindows = ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)
$platformIsMacOS = ($env:OSTYPE -and $env:OSTYPE -like "*darwin*") -or ((Get-Command uname -ErrorAction SilentlyContinue) -and ((uname) -eq "Darwin"))
$skipTrust = [System.Environment]::GetEnvironmentVariable("SKIP_CERT_TRUST") -eq "true"

# Elevate privileges on macOS if necessary
if ($platformIsMacOS -and -not $skipTrust -and $env:USER -ne "root") {
    Write-Host "Attempting to elevate privileges..."
    & sudo pwsh -File "$PSCommandPath"
    exit
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
# Validate Configuration Files
# ---------------------------
if (!(Test-Path $rootConfig)) {
    Write-Error "Missing OpenSSL config file: $rootConfig"
    exit 1
}
if (!(Test-Path $intermediateConfig)) {
    Write-Error "Missing OpenSSL config file: $intermediateConfig"
    exit 1
}
if (!(Test-Path $serverConfig)) {
    Write-Error "Missing OpenSSL config file: $serverConfig"
    exit 1
}

# ---------------------------
# Create necessary directories
# ---------------------------
function CreateDirectories($path) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $folders = 'certs', 'crl', 'newcerts', 'private', 'csr'
    foreach ($folder in $folders) {
        $dirPath = Join-Path $path $folder
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        if ($folder -eq 'private' -and -not $platformIsWindows) {
            chmod 700 $dirPath
        }
    }
    Set-Content -Path (Join-Path $path "index.txt") -Value $null
    Set-Content -Path (Join-Path $path "serial") -Value "1000"
}

CreateDirectories $rootCAPath
CreateDirectories $intermediateCAPath

# ---------------------------
# Cleanup old certificates if they exist
# ---------------------------
function CleanupCertificates($path, $keyFile, $certFile) {
    if (Test-Path "$path/private/$keyFile") {
        Remove-Item -Force "$path/private/$keyFile"
    }
    if (Test-Path "$path/certs/$certFile") {
        Remove-Item -Force "$path/certs/$certFile"
    }
}

CleanupCertificates $rootCAPath "ca.key.pem" "ca.cert.pem"
CleanupCertificates $intermediateCAPath "intermediate.key.pem" "intermediate.cert.pem"

# ---------------------------
# Generate Root CA
# ---------------------------
Write-Host "`n--- Generating Root CA ---"
openssl genrsa -out "$rootCAPath/private/ca.key.pem" 4096
openssl req -config $rootConfig -key "$rootCAPath/private/ca.key.pem" -new -x509 -days 7300 -sha256 -extensions v3_ca -out "$rootCAPath/certs/ca.cert.pem" -subj "/C=US/ST=State/L=City/O=Company/OU=Department/CN=Root CA"

# ---------------------------
# Generate Intermediate CA
# ---------------------------
Write-Host "`n--- Generating Intermediate CA ---"
openssl genrsa -out "$intermediateCAPath/private/intermediate.key.pem" 4096
openssl req -config $intermediateConfig -key "$intermediateCAPath/private/intermediate.key.pem" -new -sha256 -out "$intermediateCAPath/csr/intermediate.csr.pem" -subj "/C=US/ST=State/L=City/O=Company/OU=Department/CN=Intermediate CA"

echo "y" | openssl ca -config $rootConfig -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -in "$intermediateCAPath/csr/intermediate.csr.pem" -out "$intermediateCAPath/certs/intermediate.cert.pem" -batch

# ---------------------------
# Generate localhost cert
# ---------------------------
Write-Host "`n--- Generating localhost certificate ---"
openssl genrsa -out "$intermediateCAPath/private/localhost.key.pem" 4096
openssl req -new -key "$intermediateCAPath/private/localhost.key.pem" -out "$intermediateCAPath/csr/localhost.csr.pem" -config $serverConfig -extensions req_ext

echo "y" | openssl ca -config $serverConfig -extensions req_ext -days 825 -notext -md sha256 -in "$intermediateCAPath/csr/localhost.csr.pem" -out "$intermediateCAPath/certs/localhost.cert.pem" -batch

# Adjust permissions on the localhost key so that kubectl can read it
if (-not $platformIsWindows) {
    chmod 644 "$intermediateCAPath/private/localhost.key.pem"
}

# ---------------------------
# Bundle the certificate chain for localhost
# ---------------------------
# Combine the server certificate and the intermediate certificate into one file.
Get-Content "$intermediateCAPath/certs/localhost.cert.pem", "$intermediateCAPath/certs/intermediate.cert.pem" |
    Set-Content "$intermediateCAPath/certs/localhost-chain.cert.pem"

# ---------------------------
# System-wide certificate trust setup
# ---------------------------
if (-not $skipTrust) {
    if ($platformIsWindows) {
        Write-Host "`n--- Installing Root CA on Windows ---"
        Import-Certificate -FilePath "$rootCAPath/certs/ca.cert.pem" -CertStoreLocation "Cert:\\LocalMachine\\Root"
    } elseif ($platformIsMacOS) {
        Write-Host "`n--- Installing Root CA system-wide on macOS ---"
        security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$rootCAPath/certs/ca.cert.pem"
    } else {
        Write-Host "`n--- Installing Root CA system-wide on Linux ---"
        cp "$rootCAPath/certs/ca.cert.pem" /usr/local/share/ca-certificates/
        update-ca-certificates
    }
} else {
    Write-Host "Skipping certificate trust installation due to SKIP_CERT_TRUST=true."
}

Write-Host "`nCertificate generation completed."
