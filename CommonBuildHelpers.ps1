# -------------------------------------------------------------------
# Copyright 2025 Justin Randall
# MIT-Derived License with Attribution, see LICENSE file for full details.
# -------------------------------------------------------------------

# File: Scripts/Build/CommonBuildHelpers.ps1
<#
.SYNOPSIS
  Shared build helper functions for Unreal projects.

.DESCRIPTION
  This script contains common functions used by Editor.ps1, Game.ps1, etc.
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

<#
.SYNOPSIS
  Builds the Unreal Editor for the specified configuration.

.PARAMETER Configuration
  The build configuration (e.g., "Development", "DebugGame").

.PARAMETER UnrealEngineDir
  The absolute path to the Unreal Engine installation directory.

.PARAMETER ProjectDir
  The absolute path to the project's root directory.

.PARAMETER ProjectName
  The name of the Unreal Engine project.

.PARAMETER ProjectPath
  The absolute path to the .uproject file.
#>
<#
.SYNOPSIS
  Resolves the Unreal Engine directory from parameter or environment variable.

.PARAMETER UnrealEngineDir
  The absolute path to the Unreal Engine installation directory.

.OUTPUTS
  String - The resolved Unreal Engine directory.
#>
function Resolve-UnrealEngineDir {
  [CmdletBinding()]
  param(
    [string]$UnrealEngineDir
  )

  if (-not $UnrealEngineDir) {
    if ($env:UE_PATH) {
      $UnrealEngineDir = $env:UE_PATH
    }
    else {
      Throw "You must either pass -UnrealEngineDir or set the UE_PATH environment variable."
    }
  }

  if (-not (Test-Path $UnrealEngineDir)) {
    Write-Error "Unreal Engine directory not found at '$UnrealEngineDir'"
    exit 1
  }
  return $UnrealEngineDir
}

<#
.SYNOPSIS
  Invokes UnrealBuildTool to build a target and handles logging and error checking.

.PARAMETER TargetName
  The name of the target to build (e.g., "MyProjectEditor", "MyProject").

.PARAMETER Platform
  The target platform (e.g., "Win64").

.PARAMETER Configuration
  The build configuration (e.g., "Development", "DebugGame", "Shipping").

.PARAMETER UnrealEngineDir
  The absolute path to the Unreal Engine installation directory.

.PARAMETER ProjectPath
  The absolute path to the .uproject file.

.PARAMETER ProjectDir
  The absolute path to the project's root directory.

.PARAMETER LogSubDir
  Subdirectory within Intermediate\BuildLogs to store the log file (e.g., "Editor", "Game").
#>
function Invoke-UnrealBuildTool {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$TargetName,
    [Parameter(Mandatory)]
    [string]$Platform,
    [Parameter(Mandatory)]
    [string]$Configuration,
    [Parameter(Mandatory)]
    [string]$UnrealEngineDir,
    [Parameter(Mandatory)]
    [string]$ProjectPath,
    [Parameter(Mandatory)]
    [string]$ProjectDir,
    [Parameter(Mandatory)]
    [string]$LogSubDir
  )

  # Locate UnrealBuildTool.dll
  $ubtDll = Join-Path $UnrealEngineDir "Engine/Binaries/DotNET/UnrealBuildTool/UnrealBuildTool.dll"
  if (-not (Test-Path $ubtDll)) {
    Write-Error "Cannot find UnrealBuildTool.dll at '$ubtDll'"
    Invoke-Clean
    exit 1
  }

  # Prepare log directory & file
  $logDir = Join-Path $ProjectDir "Intermediate\BuildLogs\$LogSubDir"
  if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
  }
  $logFile = Join-Path $logDir "$TargetName-$Configuration-$Platform.log"
  if (Test-Path $logFile) {
    Remove-Item $logFile | Out-Null
  }

  # Build arguments
  $ubtArgs = @(
    $TargetName,
    $Platform,
    $Configuration,
    "-Project=$ProjectPath",
    "-WaitMutex",
    "-FromMsBuild"
  )

  Write-Host "Building '$TargetName' ($Platform / $Configuration) via dotnet UBT..."
  Write-Host "  Logging output to: $logFile`n"

  & dotnet "$ubtDll" $ubtArgs 2>&1 | Tee-Object -FilePath $logFile

  $exitCode = $LASTEXITCODE

  if ($exitCode -ne 0) {
    Write-Error "✘ Build failed (exit code $exitCode)"
    Invoke-Clean
    exit 1
  }

  Write-Host "`nScanning log for warnings/errors...`n"
  $logLines = Get-Content $logFile
  $issues = $logLines | Where-Object {
    ($_ -match '^\s*ERROR:') -or
    (
      $_ -match '^\s*WARNING:' -and
      $_ -notmatch 'Success\s*-\s*\d+\s*error\(s\),\s*\d+\s*warning\(s\)' -and
      $_ -notmatch 'Visual Studio.*not a preferred version'
    )
  }

  if ($issues.Count -gt 0) {
    Write-Error "✘ Detected $($issues.Count) warning(s)/error(s) in build log. Failing."
    $issues | ForEach-Object { Write-Warning $_ }
    Invoke-Clean
    exit 1
  }

  Write-Host "Build succeeded: $TargetName ($Configuration) with no warnings or errors."
}

<#
.SYNOPSIS
  Builds the Unreal Editor for the specified configuration.

.PARAMETER Configuration
  The build configuration (e.g., "Development", "DebugGame").

.PARAMETER UnrealEngineDir
  The absolute path to the Unreal Engine installation directory.

.PARAMETER ProjectDir
  The absolute path to the project's root directory.

.PARAMETER ProjectName
  The name of the Unreal Engine project.

.PARAMETER ProjectPath
  The absolute path to the .uproject file.
#>
function Invoke-EditorBuild {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateSet("Development", "DebugGame")]
    [string]$Configuration,
    [string]$UnrealEngineDir,
    [string]$ProjectDir,
    [string]$ProjectName,
    [string]$ProjectPath
  )

  $ResolvedUnrealEngineDir = Resolve-UnrealEngineDir -UnrealEngineDir $UnrealEngineDir
  $EditorTarget = "${ProjectName}Editor"

  Invoke-UnrealBuildTool `
    -TargetName $EditorTarget `
    -Platform "Win64" `
    -Configuration $Configuration `
    -UnrealEngineDir $ResolvedUnrealEngineDir `
    -ProjectPath $ProjectPath `
    -ProjectDir $ProjectDir `
    -LogSubDir "Editor"
}

<#
.SYNOPSIS
  Builds the Unreal Game client for the specified configuration and platform.

.PARAMETER Configuration
  The build configuration (e.g., "DebugGame", "Development", "Shipping").

.PARAMETER Platform
  The target platform (e.g., "Win64").

.PARAMETER UnrealEngineDir
  The absolute path to the Unreal Engine installation directory.

.PARAMETER ProjectDir
  The absolute path to the project's root directory.

.PARAMETER ProjectName
  The name of the Unreal Engine project.

.PARAMETER ProjectPath
  The absolute path to the .uproject file.
#>
function Invoke-GameBuild {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateSet("DebugGame", "Development", "Shipping")]
    [string]$Configuration,
    [string]$Platform = "Win64",
    [string]$UnrealEngineDir,
    [string]$ProjectDir,
    [string]$ProjectName,
    [string]$ProjectPath
  )

  $ResolvedUnrealEngineDir = Resolve-UnrealEngineDir -UnrealEngineDir $UnrealEngineDir

  Invoke-UnrealBuildTool `
    -TargetName $ProjectName `
    -Platform $Platform `
    -Configuration $Configuration `
    -UnrealEngineDir $ResolvedUnrealEngineDir `
    -ProjectPath $ProjectPath `
    -ProjectDir $ProjectDir `
    -LogSubDir "Game"
}
