$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$outputDir = Join-Path $repoRoot "shorebird_keys"

$opensslPath = "C:\Program Files\Git\usr\bin\openssl.exe"
if (-not (Test-Path $opensslPath)) {
  Write-Error "OpenSSL not found at $opensslPath. Install Git for Windows or provide OpenSSL in PATH."
  exit 1
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

$privateKey = Join-Path $outputDir "shorebird_private.pem"
$publicKey = Join-Path $outputDir "shorebird_public.pem"

Write-Host "Generating RSA private key..."
& $opensslPath genrsa -out $privateKey 2048

Write-Host "Generating RSA public key..."
& $opensslPath rsa -in $privateKey -outform PEM -pubout -out $publicKey

$publicBase64 = Join-Path $outputDir "shorebird_public_key_base64.txt"
$privateBase64 = Join-Path $outputDir "shorebird_private_key_base64.txt"

Write-Host "Encoding public key to base64..."
certutil -encode $publicKey $publicBase64 | Out-Null

Write-Host "Encoding private key to base64..."
certutil -encode $privateKey $privateBase64 | Out-Null

Write-Host ""
Write-Host "Done. Files written to $outputDir"
Write-Host "Use these GitHub secrets:"
Write-Host "  SHOREBIRD_PATCH_PUBLIC_KEY_BASE64  -> shorebird_public_key_base64.txt"
Write-Host "  SHOREBIRD_PATCH_PRIVATE_KEY_BASE64 -> shorebird_private_key_base64.txt"
