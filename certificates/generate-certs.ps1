# PowerShell Script to Create a Certificate Chain and Server Certificate for localhost
# Supports Windows, macOS, and Linux

# Ensure the script is run as Administrator on Windows
$platformIsWindows = ($env:OS -like "*Windows*")

function Ensure-Admin {
    if ($platformIsWindows) {
        $adminCheck = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        $isAdmin = $adminCheck.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        
        if (-not $isAdmin) {
            Write-Host "Restarting script with Administrator privileges..."
            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            exit
        }
    }
}

Ensure-Admin

# Variables for easy configuration
$rootCAPath         = "$PSScriptRoot\rootCA"
$intermediateCAPath = "$PSScriptRoot\intermediateCA"
$rootConfig         = "$PSScriptRoot\openssl_root.cnf"
$intermediateConfig = "$PSScriptRoot\openssl_intermediate.cnf"
$serverConfig       = "$PSScriptRoot\openssl_server.cnf"

# Change to the script's own directory to avoid System32 confusion
Set-Location -Path $PSScriptRoot

# Detect OS
$platformIsMacOS = $false
if ($env:OSTYPE -and $env:OSTYPE -like "*darwin*") {
    $platformIsMacOS = $true
} elseif ((Get-Command uname -ErrorAction SilentlyContinue) -and ((uname) -eq "Darwin")) {
    $platformIsMacOS = $true
}

$skipTrust = [System.Environment]::GetEnvironmentVariable("SKIP_CERT_TRUST") -eq "true"

# Check for OpenSSL installation
try {
    $opensslPath = (Get-Command openssl -ErrorAction Stop).Source
    Write-Host "Using OpenSSL at: $opensslPath"
} catch {
    Write-Error "OpenSSL is not installed or not in the PATH."
    exit 1
}

# Validate Configuration Files
$requiredConfigs = @($rootConfig, $intermediateConfig, $serverConfig)
foreach ($config in $requiredConfigs) {
    if (!(Test-Path $config)) {
        Write-Error "Missing OpenSSL config file: $config"
        exit 1
    }
}

# Create necessary directories
function CreateDirectories($path) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $folders = 'certs', 'crl', 'newcerts', 'private', 'csr'
    foreach ($folder in $folders) {
        $dirPath = Join-Path $path $folder
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
    }
    Set-Content -Path (Join-Path $path "index.txt") -Value $null
    Set-Content -Path (Join-Path $path "serial") -Value "1000"
}

CreateDirectories $rootCAPath
CreateDirectories $intermediateCAPath

# Cleanup old certificates if they exist
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

# Generate Root CA
Write-Host "`nGenerating Root CA..."
openssl genrsa -out "$rootCAPath/private/ca.key.pem" 4096
if (!(Test-Path "$rootCAPath/private/ca.key.pem")) { Write-Error "Failed to generate Root CA key"; exit }

openssl req -config $rootConfig -key "$rootCAPath/private/ca.key.pem" -new -x509 -days 7300 -sha256 -extensions v3_ca -out "$rootCAPath/certs/ca.cert.pem" -subj "/C=US/ST=State/L=City/O=Company/OU=Department/CN=Root CA"
if (!(Test-Path "$rootCAPath/certs/ca.cert.pem")) { Write-Error "Failed to generate Root CA certificate"; exit }

# Generate Intermediate CA
Write-Host "`nGenerating Intermediate CA..."
openssl genrsa -out "$intermediateCAPath/private/intermediate.key.pem" 4096
openssl req -config $intermediateConfig -key "$intermediateCAPath/private/intermediate.key.pem" -new -sha256 -out "$intermediateCAPath/csr/intermediate.csr.pem" -subj "/C=US/ST=State/L=City/O=Company/OU=Department/CN=Intermediate CA"
openssl ca -config $rootConfig -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -in "$intermediateCAPath/csr/intermediate.csr.pem" -out "$intermediateCAPath/certs/intermediate.cert.pem" -batch

# Generate localhost certificate
Write-Host "`nGenerating localhost certificate..."
openssl genrsa -out "$intermediateCAPath/private/localhost.key.pem" 4096
openssl req -new -key "$intermediateCAPath/private/localhost.key.pem" -out "$intermediateCAPath/csr/localhost.csr.pem" -config $serverConfig -extensions req_ext
openssl ca -config $serverConfig -extensions req_ext -days 825 -notext -md sha256 -in "$intermediateCAPath/csr/localhost.csr.pem" -out "$intermediateCAPath/certs/localhost.cert.pem" -batch

# Bundle the certificate chain for localhost
Get-Content "$intermediateCAPath/certs/localhost.cert.pem", "$intermediateCAPath/certs/intermediate.cert.pem" |
    Set-Content "$intermediateCAPath/certs/localhost-chain.cert.pem"

# System-wide certificate trust setup
if (-not $skipTrust) {
    if ($platformIsWindows) {
        Write-Host "`nInstalling Root CA on Windows..."
        try {
            Import-Certificate -FilePath "$rootCAPath/certs/ca.cert.pem" -CertStoreLocation "Cert:\LocalMachine\Root"
        } catch {
            Write-Host "Failed to install in LocalMachine Root. Trying CurrentUser Root..."
            Import-Certificate -FilePath "$rootCAPath/certs/ca.cert.pem" -CertStoreLocation "Cert:\CurrentUser\Root"
        }
    } elseif ($platformIsMacOS) {
        Write-Host "`nInstalling Root CA system-wide on macOS..."
        sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$rootCAPath/certs/ca.cert.pem"
    } else {
        Write-Host "`nInstalling Root CA system-wide on Linux..."
        sudo cp "$rootCAPath/certs/ca.cert.pem" /usr/local/share/ca-certificates/
        sudo update-ca-certificates
    }
}

Write-Host "`nCertificate generation completed successfully."
