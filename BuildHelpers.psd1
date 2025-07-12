# -------------------------------------------------------------------
# Copyright 2025 Justin Randall
# MIT-Derived License with Attribution, see LICENSE file for full details.
# -------------------------------------------------------------------

@{
	# Script module or binary module file name
	RootModule        = 'BuildHelpers.psm1'

	# Version for this module
	ModuleVersion     = '1.0.0'

	# Author info
	Author            = 'Justin Randall'
	CompanyName       = 'Playscale'

	# Functions to export
	FunctionsToExport = @(
		'Invoke-Clean', 
		'Get-ProjectRoot',
		'Invoke-EditorBuild'
	)

	# PowerShell version requirement
	PowerShellVersion = '7.0'
}
