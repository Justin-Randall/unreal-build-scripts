# -------------------------------------------------------------------
# Copyright 2025 Justin Randall
# MIT-Derived License with Attribution, see LICENSE file for full details.
# -------------------------------------------------------------------

# File: Scripts/Build/BuildHelpers.psm1
<#
.SYNOPSIS
  Shared build helper functions for Unreal projects.

.DESCRIPTION
  This module exports common functions used by Editor.ps1, Game.ps1, PackageGame.ps1, etc.
  - Invoke-Clean: runs Clean.ps1 to wipe build artifacts.
#>

function Invoke-Clean {
	<#
    .SYNOPSIS
      Perform a full project clean by invoking Clean.ps1.

    .PARAMETER ProjectDir
      Path to the project root. Defaults to two levels up from this module file.
    #>
	[CmdletBinding()]
	param(
		[string]$ProjectDir = (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent)
	)

	Write-Host "→ Performing full clean of '$ProjectDir'..."
	$cleanScript = Join-Path $PSScriptRoot 'Clean.ps1'
	if (Test-Path $cleanScript) {
		& pwsh $cleanScript -ProjectDir $ProjectDir
	}
	else {
		Write-Warning "Clean.ps1 not found at '$cleanScript'. Skipping clean."
	}
}

function Get-ProjectRoot {
	<#
    .SYNOPSIS
      Find the nearest parent folder containing a .uproject.

    .PARAMETER StartDir
      Directory to begin the search from. Defaults to the folder where this module lives.
    .OUTPUTS
      PSCustomObject with ProjectDir, ProjectName, ProjectPath.
    #>
	[CmdletBinding()]
	param(
		[string]$StartDir = (Split-Path -Parent $MyInvocation.MyCommand.Definition)
	)

	# resolve to an absolute path
	$current = (Resolve-Path $StartDir).ProviderPath

	while ($true) {
		# look for any .uproject here
		$uproject = Get-ChildItem -Path $current -Filter '*.uproject' -File -ErrorAction SilentlyContinue |
		Select-Object -First 1
		if ($uproject) {
			return [PSCustomObject]@{
				ProjectDir  = $current
				ProjectName = $uproject.BaseName
				ProjectPath = $uproject.FullName
			}
		}
		# move up
		$parent = Split-Path $current -Parent
		if (-not $parent -or $parent -eq $current) {
			Throw "Cannot find any .uproject in parent hierarchy of '$StartDir'"
		}
		$current = $parent
	}
}

Export-ModuleMember -Function Invoke-Clean, Get-ProjectRoot
