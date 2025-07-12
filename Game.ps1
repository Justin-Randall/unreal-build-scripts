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

. (Join-Path $PSScriptRoot 'CommonBuildHelpers.ps1')

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$proj = Get-ProjectRoot -StartDir $scriptDir

Invoke-GameBuild -Configuration $Configuration -Platform $Platform -UnrealEngineDir $UnrealEngineDir -ProjectDir $proj.ProjectDir -ProjectName $proj.ProjectName -ProjectPath $proj.ProjectPath
