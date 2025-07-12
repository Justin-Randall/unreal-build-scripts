# -------------------------------------------------------------------
# Copyright 2025 Justin Randall
# MIT-Derived License with Attribution, see LICENSE file for full details.
# -------------------------------------------------------------------

<#
.SYNOPSIS
  Build the game client in Shipping (Release) configuration.
#>

param(
    [string]$UnrealEngineDir
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
& "$scriptDir\Game.ps1" -Configuration Shipping -UnrealEngineDir $UnrealEngineDir
return $LASTEXITCODE