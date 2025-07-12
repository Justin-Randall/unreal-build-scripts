# -------------------------------------------------------------------
# Copyright 2025 Justin Randall
# MIT-Derived License with Attribution, see LICENSE file for full details.
# -------------------------------------------------------------------

<#
.SYNOPSIS
  Cross-platform build of the game client target via dotnet + UnrealBuildTool.dll.
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[ValidateSet("DebugGame", "Development", "Shipping")]
	[string]$Configuration = "Development",

	[string]$Platform = "Win64", # adjust if you need Linux/Mac targets
	[string]$UnrealEngineDir
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


# fall back to UE_PATH environment variable if not provided
if ( -not $UnrealEngineDir ) {
	if ( $env:UE_PATH ) {
		$UnrealEngineDir = $env:UE_PATH
	}
	else {
		Throw "You must either pass -UnrealEngineDir or set the UE_PATH environment variable."
	}
}

# -------------------------------------------------------------------
# Resolve & validate
# -------------------------------------------------------------------
$ProjectPath = Join-Path $ProjectDir "$ProjectName.uproject"
if (-not (Test-Path $UnrealEngineDir)) {
	Write-Error "UE_PATH invalid: '$UnrealEngineDir'"
	exit 1
}
if (-not (Test-Path $ProjectPath)) {
	Write-Error "Project file not found at '$ProjectPath'"
	exit 1
}

# -------------------------------------------------------------------
# Locate UnrealBuildTool.dll
# -------------------------------------------------------------------
$ubtDll = Join-Path $UnrealEngineDir "Engine/Binaries/DotNET/UnrealBuildTool/UnrealBuildTool.dll"
if (-not (Test-Path $ubtDll)) {
	Write-Error "Cannot find UnrealBuildTool.dll at '$ubtDll'"
	exit 1
}

# -------------------------------------------------------------------
# Prepare log directory & file
# -------------------------------------------------------------------
$logDir = Join-Path $ProjectDir "Intermediate\BuildLogs\Game"
if (-not (Test-Path $logDir)) {
	New-Item -ItemType Directory -Path $logDir | Out-Null
}
$logFile = Join-Path $logDir "$ProjectName-$Configuration-$Platform.log"
if (Test-Path $logFile) {
	Remove-Item $logFile
}

# -------------------------------------------------------------------
# Build args
# -------------------------------------------------------------------
$ubtArgs = @(
	$ProjectName,
	$Platform,
	$Configuration,
	"-Project=$ProjectPath",
	"-WaitMutex",
	"-FromMsBuild"
)

Write-Host "→ Building game '$ProjectName' ($Platform / $Configuration) via dotnet UBT..."
Write-Host "  Logging output to: $logFile`n"

& dotnet "$ubtDll" $ubtArgs 2>&1 | Tee-Object -FilePath $logFile

$exitCode = $LASTEXITCODE

# -------------------------------------------------------------------
# Fail fast on non-zero exit
# -------------------------------------------------------------------
if ($exitCode -ne 0) {
	Write-Error "✘ Game build failed (exit code $exitCode)"
	Invoke-Clean
	exit 1
}

# -------------------------------------------------------------------
# Scan log for real warnings/errors
# -------------------------------------------------------------------
Write-Host "`n→ Scanning build log for warnings/errors…`n"
$logLines = Get-Content $logFile

$issues = $logLines | Where-Object {
	# Any ERROR:
	($_ -match '^\s*ERROR:') -or
	# WARNING except Unreal’s “Success - 0 error(s), 0 warning(s)”
	(
		$_ -match '^\s*WARNING:' -and
		$_ -notmatch 'Success\s*-\s*\d+\s*error\(s\),\s*\d+\s*warning\(s\)' -and
		$_ -notmatch 'Visual Studio.*not a preferred version'
	)
}

if ($issues.Count -gt 0) {
	Write-Error "✘ Detected $($issues.Count) warning(s)/error(s) in game build log. Failing."
	$issues | ForEach-Object { Write-Warning $_ }
	Invoke-Clean
	exit 1
}

Write-Host "`n✔ Successfully built game '$ProjectName' ($Platform / $Configuration) with no warnings or errors."