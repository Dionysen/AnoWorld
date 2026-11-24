#!/usr/bin/env pwsh
# Build arm64-v8a release APK and install it onto an adb device.
#
# Usage:
#   tool/build_and_install_android.ps1 <device-id>
#   tool/build_and_install_android.ps1 -List
#   tool/build_and_install_android.ps1 -UninstallFirst <device-id>
#
# Example:
#   .\tool\build_and_install_android.ps1 R5CW929XXFH
#   .\tool\build_and_install_android.ps1 -UninstallFirst R5CW929XXFH
#
# PowerShell port of build_and_install_android.sh; same build and install steps.

[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$Device,
  [switch]$List,
  [switch]$UninstallFirst,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'
# Native tools report failure through $LASTEXITCODE; do not turn their stderr
# (adb banner, gradle warnings) into terminating errors.
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
  $PSNativeCommandUseErrorActionPreference = $false
}

$ScriptName = Split-Path -Leaf $PSCommandPath
$Root = Split-Path -Parent $PSScriptRoot
$Apk = Join-Path $Root 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
$PackageId = 'com.anoworld.anoworld'

function Write-Usage {
  @"
Usage:
  $ScriptName <device-id>
  $ScriptName -List
  $ScriptName -UninstallFirst <device-id>

Builds:
  flutter build apk --split-per-abi --target-platform android-arm64

Then installs:
  adb -s <device-id> install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk

Options:
  -List             List adb devices and exit
  -UninstallFirst   Uninstall the existing app before install (clears data;
                    use when signatures do not match)
  -Help             Show this help
"@
}

function Fail([string]$Message) {
  [Console]::Error.WriteLine($Message)
  exit 1
}

function Get-AdbDevices {
  # "serial<TAB>state" lines only; the daemon banner goes to stderr.
  $lines = & adb devices 2>$null
  $devices = @()
  foreach ($line in $lines) {
    if ($line -match '^\s*(\S+)\s+(\S+)\s*$' -and $Matches[1] -ne 'List') {
      $devices += [pscustomobject]@{ Serial = $Matches[1]; State = $Matches[2] }
    }
  }
  return $devices
}

function Show-AdbDevices {
  & adb devices -l
}

function Format-FileSize([string]$Path) {
  $mb = (Get-Item -LiteralPath $Path).Length / 1MB
  return '{0:N1} MB' -f $mb
}

if ($Help) {
  Write-Usage
  exit 0
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Fail 'flutter not found in PATH'
}
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
  Fail 'adb not found in PATH'
}

if ($List) {
  Show-AdbDevices
  exit 0
}

if (-not $Device) {
  [Console]::Error.WriteLine('Missing device id.')
  [Console]::Error.WriteLine('')
  [Console]::Error.WriteLine((Write-Usage))
  [Console]::Error.WriteLine('')
  [Console]::Error.WriteLine('Connected devices:')
  Show-AdbDevices | ForEach-Object { [Console]::Error.WriteLine($_) }
  exit 2
}

$online = @(Get-AdbDevices | Where-Object { $_.State -eq 'device' } | ForEach-Object { $_.Serial })
if ($online -notcontains $Device) {
  [Console]::Error.WriteLine("Device not connected (or not in 'device' state): $Device")
  [Console]::Error.WriteLine('')
  Show-AdbDevices | ForEach-Object { [Console]::Error.WriteLine($_) }
  exit 1
}

Push-Location $Root
try {
  Write-Host '==> Building arm64-v8a release APK'
  & flutter build apk --split-per-abi --target-platform android-arm64
  if ($LASTEXITCODE -ne 0) { Fail "flutter build apk failed (exit $LASTEXITCODE)." }
} finally {
  Pop-Location
}

if (-not (Test-Path -LiteralPath $Apk)) {
  Fail "APK not found after build: $Apk"
}

Write-Host "==> Installing to $Device"
Write-Host "    $Apk ($(Format-FileSize $Apk))"

if ($UninstallFirst) {
  Write-Host "==> Uninstalling $PackageId (data will be cleared)"
  & adb -s $Device uninstall $PackageId | Out-Null
}

$installOut = & adb -s $Device install -r $Apk 2>&1
$installStatus = $LASTEXITCODE
$installText = ($installOut | ForEach-Object { "$_" }) -join "`n"
Write-Host $installText

if ($installStatus -ne 0) {
  if ($installText -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') {
    [Console]::Error.WriteLine('')
    [Console]::Error.WriteLine('Signature mismatch with the installed app.')
    [Console]::Error.WriteLine('Re-run with -UninstallFirst to replace it (clears app data):')
    [Console]::Error.WriteLine("  $ScriptName -UninstallFirst `"$Device`"")
  }
  exit $installStatus
}

Write-Host '==> Done'
