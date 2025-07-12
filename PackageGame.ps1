# -------------------------------------------------------------------
# Copyright 2025 Justin Randall
# MIT-Derived License with Attribution, see LICENSE file for full details.
# -------------------------------------------------------------------

# File: Scripts/Build/PackageGame.ps1
<#
.SYNOPSIS
  Cook & package the game client, streaming UAT output live to the console,
  tee’ing it into a log file right next to the packaged output, then
  scanning that log for real warnings/errors (excluding Unreal’s
  “Success – 0 error(s), 0 warning(s)” summary).
#>

[CmdletBinding()]
param(
	[ValidateSet("DebugGame", "Development", "Shipping")]
	[string]$Configuration = "Shipping",

	[string]$Platform = "Win64",
	[string]$OutSubfolder = "Packaged",
	[switch]$SkipBuild, # If set, adds -NoBuild to UAT
	[string]$UnrealEngineDir = (Get-Item Env:UE_PATH).Value,
	[string]$ProjectDir = (Resolve-Path "$PSScriptRoot\..\.."),
	[string]$ProjectName = (Get-ChildItem $ProjectDir -Filter '*.uproject' |
		Select-Object -First 1).BaseName
)

Import-Module (Join-Path $PSScriptRoot 'BuildHelpers.psd1') -Force

# -------------------------------------------------------------------
# Discover project root and name
# -------------------------------------------------------------------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$proj = Get-ProjectRoot -StartDir $scriptDir

# now set the parameters you used to pass in:
$ProjectDir = $proj.ProjectDir
$ProjectName = $proj.ProjectName
$ProjectPath = $proj.ProjectPath

# -------------------------------------------------------------------
# Sanity-check paths
# -------------------------------------------------------------------
if (-not (Test-Path $UnrealEngineDir)) {
	Write-Error "UE_PATH invalid: '$UnrealEngineDir'"
	exit 1
}
if (-not (Test-Path $ProjectPath)) {
	Write-Error "Project file not found: '$ProjectPath'"
	exit 1
}

# -------------------------------------------------------------------
# Locate RunUAT.bat
# -------------------------------------------------------------------
$uat = Join-Path $UnrealEngineDir "Engine\Build\BatchFiles\RunUAT.bat"
if (-not (Test-Path $uat)) {
	Write-Error "RunUAT.bat not found at '$uat'"
	exit 1
}

# -------------------------------------------------------------------
# Prepare output dir & tee-log
# -------------------------------------------------------------------
$outDir = Join-Path $ProjectDir "$OutSubfolder\$Configuration"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$uatLogPath = Join-Path $outDir "BuildCookRun.log"
if (Test-Path $uatLogPath) { Remove-Item $uatLogPath | Out-Null }

# -------------------------------------------------------------------
# BuildCookRun arguments
# -------------------------------------------------------------------
$uatArgs = @(
	"BuildCookRun",
	"-project=`"$ProjectPath`"",
	"-noP4",
	"-compile",
	"-clientconfig=$Configuration",
	"-platform=$Platform",
	"-cook",
	"-allmaps",
	"-stage",
	"-pak",
	"-archive",
	"-archivedirectory=`"$outDir`""
)
if ($SkipBuild) {
	Write-Host "→ Skipping code compile (adding -NoBuild)"
	$uatArgs += "-NoBuild"
}

Write-Host "→ Running BuildCookRun for [$Configuration]; writing log to:`n   $uatLogPath`n"

# -------------------------------------------------------------------
# Stream UAT output to console AND tee into BuildCookRun.log
# -------------------------------------------------------------------
& $uat @uatArgs 2>&1 | Tee-Object -FilePath $uatLogPath
$exitCode = $LASTEXITCODE

# -------------------------------------------------------------------
# Fail fast on UAT exit code
# -------------------------------------------------------------------
if ($exitCode -ne 0) {
	Write-Error "✘ UAT exited with code $exitCode"
	# Invoke-Clean
	exit 1
}

# -------------------------------------------------------------------
# Parse the log for real issues
# -------------------------------------------------------------------
Write-Host "`n→ Parsing BuildCookRun.log for warnings/errors…`n"
$logLines = Get-Content $uatLogPath

$issues = $logLines | Where-Object {
	# Any ERROR:
	($_ -match '^\s*ERROR:') -or
	# Any WARNING except Unreal’s “Success – 0 error(s), 0 warning(s)”
	(
		$_ -match '^\s*WARNING:' -and
		$_ -notmatch 'Success\s*-\s*\d+\s*error\(s\),\s*\d+\s*warning\(s\)'
	)
}

if ($issues.Count -gt 0) {
	Write-Error "✘ Detected $($issues.Count) warning(s)/error(s) in BuildCookRun.log. Failing the build:"
	$issues | ForEach-Object { Write-Warning $_ }
	# Invoke-Clean
	exit 1
}

Write-Host "`n✔ Cooking & packaging ($Configuration) completed with no real warnings or errors."
