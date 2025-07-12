# -------------------------------------------------------------------
# Copyright 2025 Justin Randall
# MIT-Derived License with Attribution, see LICENSE file for full details.
# -------------------------------------------------------------------

<#
.SYNOPSIS
  Wrapper to build the Editor in Development configuration.
#>
param(
	[string]$UnrealEngineDir
)

if ( -not $UnrealEngineDir ) {
	if ( $env:UE_PATH ) {
		$UnrealEngineDir = $env:UE_PATH
	}
	else {
		Throw "You must either pass -UnrealEngineDir or set the UE_PATH environment variable."
	}
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
& "$scriptDir\Editor.ps1" -Configuration Development -UnrealEngineDir $UnrealEngineDir
return $LASTEXITCODE
