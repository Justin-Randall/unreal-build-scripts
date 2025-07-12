# -------------------------------------------------------------------
# Copyright 2025 Justin Randall
# MIT-Derived License with Attribution, see LICENSE file for full details.
# -------------------------------------------------------------------

# File: Scripts/Build/All.ps1
<#
.SYNOPSIS
  Orchestrate the local workflow:
    1) Build the Development Editor (failing on any warnings or errors)
    2) (later) Run tests & coverage
    3) (later) Build other configs and package game clients

  You may pass -UnrealEngineDir to override the UE_PATH environment
  variable. If neither is valid, the script will exit with an error.
#>

[CmdletBinding()]
param(
	[string]$UnrealEngineDir
)

# -------------------------------------------------------------------
# Resolve and validate Unreal Engine directory
# -------------------------------------------------------------------
if ($UnrealEngineDir) {
	$enginePath = $UnrealEngineDir
}
elseif ($env:UE_PATH) {
	$enginePath = $env:UE_PATH
}
else {
	Write-Error "Missing UnrealEngineDir: pass -UnrealEngineDir or set UE_PATH."
	exit 1
}

if (-not (Test-Path $enginePath)) {
	Write-Error "Engine directory not found: '$enginePath'"
	exit 1
}

# -------------------------------------------------------------------
# Export for downstream scripts
# -------------------------------------------------------------------
$env:UE_PATH = $enginePath
Write-Host "Using Unreal Engine at: $enginePath`n"

# -------------------------------------------------------------------
# Build the Development Editor (catching warnings/errors)
# -------------------------------------------------------------------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$buildScript = Join-Path $scriptDir 'EditorDevelopment.ps1'

Write-Host "=== Building Development Editor ==="

# -------------------------------------------------------------------
# Run the build, tee output to console AND capture for parsing
# -------------------------------------------------------------------
& $buildScript -UnrealEngineDir $enginePath

$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
	Write-Error "✘ $buildScript failed with exit code $exitCode"
	exit $exitCode
}

Write-Host "✔ Development Editor built successfully with no warnings or errors.`n"

# -------------------------------------------------------------------
# Invoke RunTests.ps1 for coverage
# -------------------------------------------------------------------
Write-Host "=== Running tests & coverage ==="
$testScript = Join-Path $scriptDir 'RunTests.ps1'
& $testScript -UnrealEngineDir $enginePath
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
	Write-Error "✘ RunTests.ps1 failed with exit code $exitCode"
	exit $exitCode
}

# -------------------------------------------------------------------
# Step 3 → Build Debug Editors
# -------------------------------------------------------------------
$buildScript = Join-Path $scriptDir 'EditorDebug.ps1'
Write-Host "=== Building Debug Editor ==="
& $buildScript -UnrealEngineDir $enginePath

$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
	Write-Error "✘ $buildScript failed with exit code $exitCode"
	exit $exitCode
}

Write-Host "✔ DebugEditor built successfully with no warnings or errors.`n"

# -------------------------------------------------------------------
# Build Debug game client
# -------------------------------------------------------------------
$buildScript = Join-Path $scriptDir 'GameDebug.ps1'

Write-Host "=== Building Debug Game ==="

# -------------------------------------------------------------------
# Run the build, tee output to console AND capture for parsing
# -------------------------------------------------------------------
& $buildScript -UnrealEngineDir $enginePath

$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
	Write-Error "✘ $buildScript failed with exit code $exitCode"
	exit $exitCode
}

Write-Host "✔ Debug Game built successfully with no warnings or errors.`n"

# -------------------------------------------------------------------
# Build Development game client
# -------------------------------------------------------------------
Write-Host "=== Building Development Game ==="
$buildScript = Join-Path $scriptDir 'GameDevelopment.ps1'

& $buildScript -UnrealEngineDir $enginePath

$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
	Write-Error "✘ $buildScript failed with exit code $exitCode"
	exit $exitCode
}

Write-Host "✔ Development Game built successfully with no warnings or errors.`n"


# -------------------------------------------------------------------
# Build Shipping game client
# -------------------------------------------------------------------
Write-Host "=== Building Shipping Game ==="
$buildScript = Join-Path $scriptDir 'GameShipping.ps1'
& $buildScript -UnrealEngineDir $enginePath

$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
	Write-Error "✘ $buildScript failed with exit code $exitCode"
	exit $exitCode
}

Write-Host "✔ Shipping Game built successfully with no warnings or errors.`n"

# -------------------------------------------------------------------
# Package Debug game client
# -------------------------------------------------------------------
Write-Host "=== Packaging Debug Game ==="
$packageScript = Join-Path $scriptDir 'PackageGame.ps1'
& $packageScript -UnrealEngineDir $enginePath -Configuration DebugGame

$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
	Write-Error "✘ $packageScript failed with exit code $exitCode"
	exit $exitCode
}
Write-Host "✔ Debug Game packaged successfully with no warnings or errors.`n"

# -------------------------------------------------------------------
# Package Development game client
# -------------------------------------------------------------------
Write-Host "=== Packaging Development Game ==="
& $packageScript -UnrealEngineDir $enginePath -Configuration Development
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
	Write-Error "✘ $packageScript failed with exit code $exitCode"
	exit $exitCode
}
Write-Host "✔ Development Game packaged successfully with no warnings or errors.`n"

# -------------------------------------------------------------------
# Package Shipping game client
# -------------------------------------------------------------------
Write-Host "=== Packaging Shipping Game ==="
& $packageScript -UnrealEngineDir $enginePath -Configuration Shipping
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
	Write-Error "✘ $packageScript failed with exit code $exitCode"
	exit $exitCode
}
Write-Host "✔ Shipping Game packaged successfully with no warnings or errors.`n"
Write-Host "All.ps1: completed successfully"
