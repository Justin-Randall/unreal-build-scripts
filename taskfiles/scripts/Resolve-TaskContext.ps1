$ErrorActionPreference = 'Stop'

$startDir = if ($env:USER_WORKING_DIR) { $env:USER_WORKING_DIR } elseif ($env:INIT_CWD) { $env:INIT_CWD } else { (Get-Location).Path }
$startDir = (Resolve-Path -LiteralPath $startDir).Path

$dirs = New-Object System.Collections.Generic.List[string]
$current = $startDir
while ($true) {
  $dirs.Add($current)
  $parent = Split-Path -Path $current -Parent
  if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
  $current = $parent
}

$envMap = @{}
foreach ($dir in $dirs) {
  $envFile = Join-Path $dir '.env'
  if (-not (Test-Path -LiteralPath $envFile)) { continue }
  foreach ($rawLine in Get-Content -LiteralPath $envFile) {
    $line = $rawLine.Trim()
    if (-not $line -or $line.StartsWith('#')) { continue }
    $eq = $line.IndexOf('=')
    if ($eq -le 0) { continue }
    $key = $line.Substring(0, $eq).Trim()
    $value = $line.Substring($eq + 1).Trim()
    if ($value.Length -ge 2) {
      if (($value.StartsWith("'") -and $value.EndsWith("'")) -or ($value.StartsWith('"') -and $value.EndsWith('"'))) {
        $value = $value.Substring(1, $value.Length - 2)
      }
    }
    $envMap[$key] = $value
  }
}

$uproject = $null
foreach ($dir in $dirs) {
  $candidate = Get-ChildItem -LiteralPath $dir -Filter '*.uproject' -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $uproject = $candidate; break }
}
if (-not $uproject) { throw "Cannot find a .uproject from '$startDir' up to filesystem root." }

$projectPath = $uproject.FullName
$projectDir = $uproject.DirectoryName
$projectName = $uproject.BaseName
$automationRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$testMapRoot = $projectName
$pluginMatch = [regex]::Match($startDir, '[\\/]Plugins[\\/]([^\\/]+)')
if ($pluginMatch.Success) { $testPrefix = "$($pluginMatch.Groups[1].Value).Fast"; $testMapRoot = $pluginMatch.Groups[1].Value } else { $testPrefix = "$projectName.Fast" }
$integrationPrefix = $testPrefix -replace '\.Fast$', '.Integration'

if ($env:UE_DIR) { $uePath = $env:UE_DIR; $ueSource = 'UE_DIR task/env override' }
elseif ($env:UE_PATH) { $uePath = $env:UE_PATH; $ueSource = 'process UE_PATH' }
elseif ($envMap.ContainsKey('UE_PATH') -and $envMap['UE_PATH']) { $uePath = $envMap['UE_PATH']; $ueSource = 'cascading .env UE_PATH' }
else { throw 'UE path unresolved. Set UE_DIR, or UE_PATH in environment, or UE_PATH in a .env file.' }
if (-not (Test-Path -LiteralPath $uePath)) { throw "Unreal Engine path does not exist: $uePath" }

$ctxPath = Join-Path $PSScriptRoot '..\.task-context.env'
@{
  START_DIR = $startDir
  PROJECT_PATH = $projectPath
  PROJECT_DIR = $projectDir
  PROJECT_NAME = $projectName
  AUTOMATION_ROOT = $automationRoot
  TEST_PREFIX = $testPrefix
  TEST_PREFIX_FAST = $testPrefix
  TEST_PREFIX_INTEGRATION = $integrationPrefix
  TEST_MAP_ROOT = $testMapRoot
  UE_PATH_RESOLVED = $uePath
  UE_PATH_SOURCE = $ueSource
  UBT_DLL = (Join-Path $uePath 'Engine\Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.dll')
  EDITOR_CMD = (Join-Path $uePath 'Engine\Binaries\Win64\UnrealEditor-Cmd.exe')
  UAT_BAT = (Join-Path $uePath 'Engine\Build\BatchFiles\RunUAT.bat')
}.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value } | Set-Content -LiteralPath $ctxPath -Encoding ascii
