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
$platformIsWindows = ($env:OS -like "*Windows*")
$platformIsMacOS = (Get-Command uname -ErrorAction SilentlyContinue) -and ((uname) -eq "Darwin")
$platformIsLinux = (Get-Command uname -ErrorAction SilentlyContinue) -and ((uname) -eq "Linux")
$skipTrust = [System.Environment]::GetEnvironmentVariable("SKIP_CERT_TRUST") -eq "true"
$forceRegenerate = [System.Environment]::GetEnvironmentVariable("FORCE_REGEN_CA") -eq "true"

# Check if Root CA already exists
$rootCAExists = (Test-Path "$rootCAPath/certs/ca.cert.pem") -and (Test-Path "$rootCAPath/private/ca.key.pem")
$intermediateCAExists = (Test-Path "$intermediateCAPath/certs/intermediate.cert.pem") -and (Test-Path "$intermediateCAPath/private/intermediate.key.pem")

# ---------------------------
# Elevate privileges if necessary
# ---------------------------
if (-not $skipTrust) {
    if ($platformIsWindows) {
        $adminCheck = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        $isAdmin = $adminCheck.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        
        if (-not $isAdmin) {
            Write-Host "Restarting script with Administrator privileges..."
            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            exit
        }
    } elseif (($platformIsMacOS -or $platformIsLinux)) {
        $currentUser = whoami
        if ($currentUser -ne "root") {
            Write-Host "Attempting to elevate privileges for certificate trust installation..."
            & sudo pwsh -File "$PSCommandPath"
            exit
        }
    }
}

# ---------------------------
# Check for OpenSSL installation
# ---------------------------
try {
    $opensslPath = (Get-Command openssl -ErrorAction Stop).Source
    Write-Host "Using OpenSSL at: $opensslPath"
} catch {
    Write-Error "OpenSSL is not installed or not in the PATH."
    exit
}

# ---------------------------
# Validate Configuration Files
# ---------------------------
$requiredConfigs = @($rootConfig, $intermediateConfig, $serverConfig)
foreach ($config in $requiredConfigs) {
    if (!(Test-Path $config)) {
        Write-Error "Missing OpenSSL config file: $config"
        exit 1
    }
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

# Only cleanup Root CA if it doesn't exist or force regenerate is set
if (-not $rootCAExists -or $forceRegenerate) {
    Write-Host "Root CA will be regenerated (exists: $rootCAExists, force: $forceRegenerate)"
    CleanupCertificates $rootCAPath "ca.key.pem" "ca.cert.pem"
    CleanupCertificates $intermediateCAPath "intermediate.key.pem" "intermediate.cert.pem"
} else {
    Write-Host "Preserving existing Root CA and Intermediate CA"
}

# Always cleanup server cert (it will be regenerated with current SANs)
CleanupCertificates $intermediateCAPath "localhost.key.pem" "localhost.cert.pem"
if (Test-Path "$intermediateCAPath/certs/localhost-chain.cert.pem") {
    Remove-Item -Force "$intermediateCAPath/certs/localhost-chain.cert.pem"
}

# ---------------------------
# Generate Root CA (only if not exists or force regenerate)
# ---------------------------
if (-not $rootCAExists -or $forceRegenerate) {
    Write-Host "`n--- Generating Root CA ---"
    openssl genrsa -out "$rootCAPath/private/ca.key.pem" 4096
    openssl req -config $rootConfig -key "$rootCAPath/private/ca.key.pem" -new -x509 -days 7300 -sha256 -extensions v3_ca -out "$rootCAPath/certs/ca.cert.pem" -subj "/C=US/ST=State/L=City/O=Company/OU=Department/CN=Root CA"
} else {
    Write-Host "`n--- Skipping Root CA generation (already exists) ---"
}

# ---------------------------
# Generate Intermediate CA (only if not exists or force regenerate)
# ---------------------------
if (-not $intermediateCAExists -or $forceRegenerate) {
    Write-Host "`n--- Generating Intermediate CA ---"
    openssl genrsa -out "$intermediateCAPath/private/intermediate.key.pem" 4096
    openssl req -config $intermediateConfig -key "$intermediateCAPath/private/intermediate.key.pem" -new -sha256 -out "$intermediateCAPath/csr/intermediate.csr.pem" -subj "/C=US/ST=State/L=City/O=Company/OU=Department/CN=Intermediate CA"

    echo "y" | openssl ca -config $rootConfig -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -in "$intermediateCAPath/csr/intermediate.csr.pem" -out "$intermediateCAPath/certs/intermediate.cert.pem" -batch
} else {
    Write-Host "`n--- Skipping Intermediate CA generation (already exists) ---"
}

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
Get-Content "$intermediateCAPath/certs/localhost.cert.pem", "$intermediateCAPath/certs/intermediate.cert.pem" |
    Set-Content "$intermediateCAPath/certs/localhost-chain.cert.pem"

# ---------------------------
# System-wide certificate trust setup
# ---------------------------
if (-not $skipTrust) {
    Write-Host "`n--- Checking Root CA trust status ---"
    
    if ($platformIsWindows) {
        # Check if cert is already trusted
        $certThumbprint = (Get-PfxCertificate "$rootCAPath/certs/ca.cert.pem").Thumbprint
        $existingCert = Get-ChildItem -Path "Cert:\LocalMachine\Root" | Where-Object { $_.Thumbprint -eq $certThumbprint }
        
        if ($existingCert) {
            Write-Host "Root CA is already trusted in Windows Trusted Root store"
        } else {
            Write-Host "Installing Root CA in Windows Trusted Root store..."
            Import-Certificate -FilePath "$rootCAPath/certs/ca.cert.pem" -CertStoreLocation "Cert:\\LocalMachine\\Root"
            Write-Host "Root CA installed in Windows Trusted Root store"
        }
    } elseif ($platformIsMacOS) {
        # Get the fingerprint of the current Root CA
        $currentFingerprint = (openssl x509 -in "$rootCAPath/certs/ca.cert.pem" -noout -fingerprint -sha1 2>$null) -replace ".*=", "" -replace ":", ""
        
        # Check if this exact cert is already trusted
        $verifyResult = & security verify-cert -c "$rootCAPath/certs/ca.cert.pem" 2>&1
        $isAlreadyTrusted = $LASTEXITCODE -eq 0
        
        if ($isAlreadyTrusted) {
            Write-Host "Root CA is already trusted in macOS System keychain (fingerprint: $currentFingerprint)"
        } else {
            Write-Host "Root CA not trusted or not found. Installing..."
            
            # Remove any existing Root CA certificates with DIFFERENT fingerprints to avoid duplicates
            Write-Host "Checking for old Root CA certificates..."
            $existingCerts = & security find-certificate -c "Root CA" -a -Z /Library/Keychains/System.keychain 2>&1
            if ($existingCerts -match "SHA-1 hash:") {
                $hashes = $existingCerts | Select-String "SHA-1 hash:" | ForEach-Object { ($_ -split ": ")[1].Trim() }
                foreach ($hash in $hashes) {
                    if ($hash -and $hash -ne $currentFingerprint) {
                        Write-Host "Removing old Root CA certificate: $hash"
                        & security delete-certificate -Z $hash /Library/Keychains/System.keychain 2>&1 | Out-Null
                    }
                }
            }
            
            # Add and trust the certificate for SSL - must run as root
            # -d: use admin trust domain (system-wide)
            # -r trustRoot: mark as trusted root CA  
            # -p ssl: explicitly trust for SSL/TLS (required for browsers like Edge/Chrome)
            # -k: target the System keychain
            & security add-trusted-cert -d -r trustRoot -p ssl -k /Library/Keychains/System.keychain "$rootCAPath/certs/ca.cert.pem"
            Write-Host "Root CA installed and trusted for SSL in macOS System keychain"
        }
    } elseif ($platformIsLinux) {
        # Check if cert is already installed
        $targetPath = "/usr/local/share/ca-certificates/dev-root-ca.crt"
        if (Test-Path $targetPath) {
            $existingHash = (openssl x509 -in $targetPath -noout -fingerprint -sha1 2>$null) -replace ".*=", ""
            $currentHash = (openssl x509 -in "$rootCAPath/certs/ca.cert.pem" -noout -fingerprint -sha1 2>$null) -replace ".*=", ""
            
            if ($existingHash -eq $currentHash) {
                Write-Host "Root CA is already installed in Linux trusted certificates"
            } else {
                Write-Host "Updating Root CA in Linux trusted certificates..."
                cp "$rootCAPath/certs/ca.cert.pem" $targetPath
                update-ca-certificates
                Write-Host "Root CA updated in Linux trusted certificates"
            }
        } else {
            Write-Host "Installing Root CA in Linux trusted certificates..."
            cp "$rootCAPath/certs/ca.cert.pem" $targetPath
            update-ca-certificates
            Write-Host "Root CA installed in Linux trusted certificates"
        }
    }
} else {
    Write-Host "`nSkipping certificate trust installation due to SKIP_CERT_TRUST=true"
}

Write-Host "`nCertificate generation completed"
