# -------------------------------------------------------------------
# Copyright 2025 Justin Randall
# MIT-Derived License with Attribution, see LICENSE file for full details.
# -------------------------------------------------------------------

<#
.SYNOPSIS
  Build the "<ProjectName>Editor" target for Win64 in the given UBT configuration.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("Development", "DebugGame")]
    [string]$Configuration = "Development",
    [string]$UnrealEngineDir
)

Import-Module (Join-Path $PSScriptRoot 'BuildHelpers.psd1') -Force

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$proj = Get-ProjectRoot -StartDir $scriptDir

Invoke-EditorBuild -Configuration $Configuration -UnrealEngineDir $UnrealEngineDir -ProjectDir $proj.ProjectDir -ProjectName $proj.ProjectName -ProjectPath $proj.ProjectPath
