# -------------------------------------------------------------------
# Copyright 2025 Justin Randall
# MIT-Derived License with Attribution, see LICENSE file for full details.
# -------------------------------------------------------------------

# File: Scripts/Build/Clean.ps1
<#
.SYNOPSIS
  Remove all generated build artifacts so that the project is back
  to a pristine state (as if no builds have ever been run).

.DESCRIPTION
  This script will delete the common Unreal build output folders:
    - Intermediate/
    - Binaries/
    - Saved/
    - Packaged/    (if present)
    - Intermediate\BuildLogs/
    - Intermediate\CodeCoverage/

  All deletions are silent and non-destructive to your source files.
#>

[CmdletBinding()]
param(
	[string]$ProjectDir = (Resolve-Path "$PSScriptRoot\..\..")
)

# List of relative paths to remove
$pathsToClean = @(
	"Intermediate\Build",
	"Binaries",
	"Saved",
	"Packaged"
)

Write-Host "Cleaning project artifacts in `"$ProjectDir`"...`n"

foreach ($relPath in $pathsToClean) {
	$fullPath = Join-Path $ProjectDir $relPath
	if (Test-Path $fullPath) {
		Write-Host "  - Removing $relPath"
		Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
	}
}

Write-Host "`n✘ Clean complete. Project is now back to a pre-build state."
