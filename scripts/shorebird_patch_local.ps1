$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

$shorebird = Get-Command shorebird -ErrorAction SilentlyContinue
if (-not $shorebird) {
  Write-Error "shorebird CLI not found in PATH."
  exit 1
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
  Write-Error "python not found in PATH."
  exit 1
}

$manifestPath = Join-Path $repoRoot "shorebird_release_manifest.json"
if (-not (Test-Path $manifestPath)) {
  Write-Error "Missing shorebird_release_manifest.json. Download the release manifest artifact and place it at $manifestPath."
  exit 1
}

$flutterVersion = $env:FLUTTER_VERSION
if ([string]::IsNullOrWhiteSpace($flutterVersion)) {
  Write-Error "FLUTTER_VERSION is not set. Set it to the release-line Flutter version."
  exit 1
}

Write-Host "Running patch guard..."
& $python.Source (Join-Path $repoRoot "scripts\shorebird_patch_guard.py") `
  --repo-root $repoRoot `
  --manifest $manifestPath `
  --flutter-version $flutterVersion

if ($LASTEXITCODE -ne 0) {
  Write-Error "Patch guard failed. Use a store release instead."
  exit 1
}

$platform = $env:SHOREBIRD_PLATFORM
if ([string]::IsNullOrWhiteSpace($platform)) {
  Write-Error "SHOREBIRD_PLATFORM is not set. Use 'android' or 'ios'."
  exit 1
}

$releaseVersion = $env:SHOREBIRD_RELEASE_VERSION
if ([string]::IsNullOrWhiteSpace($releaseVersion)) {
  Write-Error "SHOREBIRD_RELEASE_VERSION is not set, for example 1.2.8+13."
  exit 1
}

$publicKeyPath = $env:SHOREBIRD_PATCH_PUBLIC_KEY_PATH
$privateKeyPath = $env:SHOREBIRD_PATCH_PRIVATE_KEY_PATH
if ([string]::IsNullOrWhiteSpace($publicKeyPath) -or [string]::IsNullOrWhiteSpace($privateKeyPath)) {
  Write-Error "SHOREBIRD_PATCH_PUBLIC_KEY_PATH and SHOREBIRD_PATCH_PRIVATE_KEY_PATH must be set."
  exit 1
}

Write-Host "Creating Shorebird patch..."
& $shorebird.Source patch $platform `
  --release-version $releaseVersion `
  --public-key-path $publicKeyPath `
  --private-key-path $privateKeyPath

exit $LASTEXITCODE
