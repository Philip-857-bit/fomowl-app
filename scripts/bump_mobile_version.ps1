param(
  [ValidateSet("patch", "minor", "major")]
  [string]$Bump = "patch"
)

$ErrorActionPreference = "Stop"

$pubspecPath = Join-Path $PSScriptRoot "..\pubspec.yaml"
$pubspecPath = [System.IO.Path]::GetFullPath($pubspecPath)

if (!(Test-Path $pubspecPath)) {
  throw "pubspec.yaml not found at $pubspecPath"
}

$content = Get-Content $pubspecPath -Raw
$match = [regex]::Match($content, "(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$")
if (!$match.Success) {
  throw "Could not parse version from pubspec.yaml"
}

$major = [int]$match.Groups[1].Value
$minor = [int]$match.Groups[2].Value
$patch = [int]$match.Groups[3].Value
$build = [int]$match.Groups[4].Value

switch ($Bump) {
  "major" {
    $major += 1
    $minor = 0
    $patch = 0
  }
  "minor" {
    $minor += 1
    $patch = 0
  }
  default {
    $patch += 1
  }
}

$build += 1
$newVersion = "$major.$minor.$patch+$build"
$updated = [regex]::Replace(
  $content,
  "(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$",
  "version: $newVersion",
  1
)

Set-Content -Path $pubspecPath -Value $updated -NoNewline
Write-Host "Updated mobile version to $newVersion"
