param(
  [string]$KeystorePath = ".\keystore\owllet-release.jks",
  [string]$Alias = "owllet",
  [string]$StorePassword = "change_me",
  [string]$KeyPassword = "change_me",
  [string]$Dname = "CN=Owllet, OU=Mobile, O=FOMOwl, L=Berlin, S=Berlin, C=DE",
  [int]$ValidityDays = 365000
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$targetPath = Join-Path $projectRoot $KeystorePath
$targetDir = Split-Path -Parent $targetPath

if (-not (Get-Command keytool -ErrorAction SilentlyContinue)) {
  Write-Error "keytool was not found. Install a JDK and ensure keytool is on PATH."
}

if (-not (Test-Path $targetDir)) {
  New-Item -ItemType Directory -Path $targetDir | Out-Null
}

if (Test-Path $targetPath) {
  Write-Error "Keystore already exists at $targetPath"
}

& keytool -genkeypair `
  -v `
  -keystore $targetPath `
  -alias $Alias `
  -keyalg RSA `
  -keysize 4096 `
  -validity $ValidityDays `
  -storepass $StorePassword `
  -keypass $KeyPassword `
  -dname $Dname

Write-Host "Created Android release keystore at $targetPath"
Write-Host "Copy android/key.properties.example to android/key.properties and set:"
Write-Host "storeFile=$KeystorePath"
Write-Host "storePassword=<your password>"
Write-Host "keyAlias=$Alias"
Write-Host "keyPassword=<your password>"
