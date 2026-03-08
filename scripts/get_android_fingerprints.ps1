param(
  [string]$KeystorePath = "",
  [string]$Alias = "",
  [string]$StorePassword = "",
  [string]$KeyPassword = ""
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$keyPropertiesPath = Join-Path $projectRoot "android\key.properties"

if (Test-Path $keyPropertiesPath) {
  $properties = @{}
  Get-Content $keyPropertiesPath | ForEach-Object {
    if ($_ -match "^\s*([^#=]+?)\s*=\s*(.*)\s*$") {
      $properties[$matches[1].Trim()] = $matches[2].Trim()
    }
  }

  if ([string]::IsNullOrWhiteSpace($KeystorePath) -and $properties.ContainsKey("storeFile")) {
    $KeystorePath = $properties["storeFile"]
  }
  if ([string]::IsNullOrWhiteSpace($Alias) -and $properties.ContainsKey("keyAlias")) {
    $Alias = $properties["keyAlias"]
  }
  if ([string]::IsNullOrWhiteSpace($StorePassword) -and $properties.ContainsKey("storePassword")) {
    $StorePassword = $properties["storePassword"]
  }
  if ([string]::IsNullOrWhiteSpace($KeyPassword) -and $properties.ContainsKey("keyPassword")) {
    $KeyPassword = $properties["keyPassword"]
  }
}

if ([string]::IsNullOrWhiteSpace($KeystorePath)) {
  $KeystorePath = ".\keystore\owllet-release.jks"
}

$resolvedKeystorePath = Join-Path $projectRoot $KeystorePath

if (-not (Test-Path $resolvedKeystorePath)) {
  Write-Error "Keystore not found at $resolvedKeystorePath"
}

if ([string]::IsNullOrWhiteSpace($Alias)) {
  Write-Error "Missing key alias. Provide -Alias or set keyAlias in android/key.properties."
}

if ([string]::IsNullOrWhiteSpace($StorePassword)) {
  Write-Error "Missing store password. Provide -StorePassword or set storePassword in android/key.properties."
}

if (-not (Get-Command keytool -ErrorAction SilentlyContinue)) {
  Write-Error "keytool was not found. Install a JDK and ensure keytool is on PATH."
}

$arguments = @(
  "-list",
  "-v",
  "-keystore", $resolvedKeystorePath,
  "-alias", $Alias,
  "-storepass", $StorePassword
)

if (-not [string]::IsNullOrWhiteSpace($KeyPassword)) {
  $arguments += @("-keypass", $KeyPassword)
}

& keytool @arguments
