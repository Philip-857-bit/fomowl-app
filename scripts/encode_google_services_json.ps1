param(
  [string]$JsonPath = ".\android\app\google-services.json",
  [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot $JsonPath

if (-not (Test-Path $sourcePath)) {
  Write-Error "google-services.json not found at $sourcePath"
}

$bytes = [System.IO.File]::ReadAllBytes($sourcePath)
$base64 = [System.Convert]::ToBase64String($bytes)

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  Write-Output $base64
  Write-Host ""
  Write-Host "Copy the output above into the GitHub secret GOOGLE_SERVICES_JSON_BASE64."
} else {
  $targetPath = Join-Path $projectRoot $OutputPath
  $targetDir = Split-Path -Parent $targetPath

  if (-not [string]::IsNullOrWhiteSpace($targetDir) -and -not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir | Out-Null
  }

  Set-Content -Path $targetPath -Value $base64 -NoNewline
  Write-Host "Wrote base64 JSON to $targetPath"
  Write-Host "Use that file content for the GitHub secret GOOGLE_SERVICES_JSON_BASE64."
}
