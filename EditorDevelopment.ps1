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

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
& "$scriptDir\Editor.ps1" -Configuration Development -UnrealEngineDir $UnrealEngineDir
return $LASTEXITCODE