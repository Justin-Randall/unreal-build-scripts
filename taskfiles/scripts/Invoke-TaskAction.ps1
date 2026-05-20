param(
  [Parameter(Mandatory = $true)] [ValidateSet('doctor','clean','build-editor','build-game','test','coverage','coverage-gate','package')]
  [string]$Action,
  [string]$Config = 'Development',
  [string]$Platform = 'Win64',
  [string]$AdditionalArgs = '',
  [string]$CoverageThreshold = '100',
  [string]$OutSubfolder = 'Packaged'
)

$ErrorActionPreference = 'Stop'
$ctxPath = Join-Path $PSScriptRoot '..\.task-context.env'
if (-not (Test-Path -LiteralPath $ctxPath)) { throw 'Context file missing. Run resolve first.' }
Get-Content -LiteralPath $ctxPath | ForEach-Object {
  $parts = $_ -split '=', 2
  if ($parts.Length -eq 2) { [Environment]::SetEnvironmentVariable($parts[0], $parts[1], 'Process') }
}

function Invoke-Process {
  param(
    [Parameter(Mandatory = $true)] [string]$FilePath,
    [Parameter(Mandatory = $true)] [string]$Arguments
  )
  $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
  return $process.ExitCode
}

function Show-TestLogSummary {
  $automatedTestsLogPath = Join-Path $env:PROJECT_DIR 'Saved\Logs\AutomatedTests.log'
  if (-not (Test-Path -LiteralPath $automatedTestsLogPath)) { return }
  ""
  "=== Errors, Warnings and LogAutomation Output from $automatedTestsLogPath ==="
  Get-Content -LiteralPath $automatedTestsLogPath | Select-String -Pattern 'Warning|Error|LogAutomationC' | ForEach-Object { $_.Line }
  "=== End of Errors, Warnings and LogAutomation Output ==="
  ""
}

switch ($Action) {
  'doctor' {
    if (-not (Test-Path -LiteralPath $env:UBT_DLL)) { throw "UnrealBuildTool.dll missing at $($env:UBT_DLL)" }
    if (-not (Test-Path -LiteralPath $env:EDITOR_CMD)) { throw "UnrealEditor-Cmd.exe missing at $($env:EDITOR_CMD)" }
    if (-not (Test-Path -LiteralPath $env:UAT_BAT)) { throw "RunUAT.bat missing at $($env:UAT_BAT)" }
    "Start dir: $($env:START_DIR)"; "Project:   $($env:PROJECT_PATH)"; "UE path:   $($env:UE_PATH_RESOLVED) ($($env:UE_PATH_SOURCE))"; "Prefix:    $($env:TEST_PREFIX)"
  }
  'clean' {
    @('Intermediate\\Build','Binaries','Saved','Packaged') | ForEach-Object {
      $path = Join-Path $env:PROJECT_DIR $_
      if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force; "Removed: $path" } else { "Skipped (not found): $path" }
    }
  }
  'build-editor' {
    & dotnet $env:UBT_DLL "$($env:PROJECT_NAME)Editor" $Platform $Config "-Project=$($env:PROJECT_PATH)" -NoHotReloadFromIDE
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  'build-game' {
    & dotnet $env:UBT_DLL "$($env:PROJECT_NAME)" $Platform $Config "-Project=$($env:PROJECT_PATH)" -NoHotReloadFromIDE
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  'test' {
    $execCmd = "Automation RunTests FTest_+$($env:TEST_PREFIX); Quit"
    $args = @($env:PROJECT_PATH, "/$($env:TEST_MAP_ROOT)/Maps/TestMap", '-nullrhi', "-ExecCmds=`"$execCmd`"", '-NoSplash', '-Unattended', '-NoCompile', '-NoLogTimes', '-Log=AutomatedTests.log', $AdditionalArgs) -join ' '
    "[info] Running tests without coverage"
    "[debug] $($env:EDITOR_CMD) $args"
    $exitCode = Invoke-Process -FilePath $env:EDITOR_CMD -Arguments $args
    "[info] Unreal Automation Tests finished with exit code: $exitCode"
    if ($exitCode -ne 0) { exit $exitCode }
  }
  'coverage' {
    $coverageCmd = Get-Command 'OpenCppCoverage.exe' -ErrorAction SilentlyContinue
    if (-not $coverageCmd) { throw 'OpenCppCoverage.exe is required for coverage tasks but was not found in PATH.' }
    $outDir = Join-Path $env:PROJECT_DIR 'Intermediate\CodeCoverage'
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    Remove-Item -LiteralPath (Join-Path $outDir '*') -Recurse -Force -ErrorAction SilentlyContinue
    $cobertura = Join-Path $outDir 'coverage.xml'
    $execCmd = "Automation RunTests FTest_+$($env:TEST_PREFIX); Quit"
    $testArgs = @($env:PROJECT_PATH, "/$($env:TEST_MAP_ROOT)/Maps/TestMap", '-nullrhi', "-ExecCmds=`"$execCmd`"", '-NoSplash', '-Unattended', '-NoCompile', '-NoLogTimes', '-Log=AutomatedTests.log', $AdditionalArgs) -join ' '
    $occArgs = @(
      "--export_type=cobertura:$cobertura",
      "--export_type=html:$outDir",
      '--sources', (Join-Path $env:AUTOMATION_ROOT 'Source'),
      '--modules', (Join-Path $env:AUTOMATION_ROOT 'Binaries'),
      '--excluded_line_regex', '.*LCOV_EXCL_LINE.*',
      '--excluded_sources', 'UnrealEngine',
      '--excluded_sources', 'Intermediate',
      '--excluded_sources', (Join-Path $env:AUTOMATION_ROOT 'Plugins'),
      '--excluded_sources', '_E2E_',
      '--excluded_sources', 'TestHelpers',
      '--', $env:EDITOR_CMD, $testArgs
    ) -join ' '
    "[debug] $($env:EDITOR_CMD) $testArgs"
    "[info] Running $($coverageCmd.Path) $occArgs"
    $testExecutionTime = Measure-Command {
      $exitCode = Invoke-Process -FilePath $coverageCmd.Path -Arguments $occArgs
    }
    "[info] OpenCppCoverage finished with exit code: $exitCode"
    if ($exitCode -ne 0) {
      Show-TestLogSummary
      exit $exitCode
    }

    ""
    "[info] The test run took $($testExecutionTime.TotalSeconds) seconds (including engine initialization and setup)."
    ""
    "[info] All tests passed."

    if (-not (Test-Path -LiteralPath $cobertura)) {
      '[info] No coverage file found!'
      exit 0
    }

    [xml]$coverageXml = Get-Content -LiteralPath $cobertura
    $lineRate = $coverageXml.coverage.'line-rate'
    $coverage = [math]::Round([double]$lineRate * 100, 2)
    $threshold = [double]$CoverageThreshold

    if ($coverage -lt $threshold) {
      Show-TestLogSummary
      "[error] Coverage ($coverage%) is below the threshold ($threshold%)."

      $uncoveredByFile = @{}
      foreach ($package in $coverageXml.coverage.packages.package) {
        foreach ($class in $package.classes.class) {
          $filename = $class.filename
          foreach ($line in $class.lines.line) {
            if ([int]$line.hits -eq 0) {
              if (-not $uncoveredByFile.ContainsKey($filename)) { $uncoveredByFile[$filename] = @() }
              $uncoveredByFile[$filename] += [int]$line.number
            }
          }
        }
      }

      if ($uncoveredByFile.Count -gt 0) {
        '[error] Uncovered lines with source context:'
        foreach ($file in $uncoveredByFile.Keys) {
          $resolvedFile = $null
          if (Test-Path -LiteralPath $file) {
            $resolvedFile = (Resolve-Path -LiteralPath $file).Path
          }
          elseif ($file -match '\\Plugins\\') {
            $idx = $file.IndexOf('\Plugins\')
            if ($idx -ge 0) {
              $attempt = Join-Path $env:PROJECT_DIR $file.Substring($idx)
              if (Test-Path -LiteralPath $attempt) { $resolvedFile = (Resolve-Path -LiteralPath $attempt).Path }
            }
          }
          if (-not $resolvedFile) {
            $attempt = Join-Path $env:PROJECT_DIR $file
            if (Test-Path -LiteralPath $attempt) { $resolvedFile = (Resolve-Path -LiteralPath $attempt).Path }
          }

          $fileContent = @()
          if ($resolvedFile) { $fileContent = Get-Content -LiteralPath $resolvedFile }

          foreach ($lineNumber in ($uncoveredByFile[$file] | Sort-Object -Unique)) {
            $lineText = '(source code not available)'
            if ($fileContent.Count -ge $lineNumber) { $lineText = $fileContent[$lineNumber - 1].TrimEnd() }
            "File: $file : Line $lineNumber"
            "    `"$lineText`""
          }
        }
      }
      exit 1
    }

    "[info] Coverage ($coverage%) meets the threshold ($threshold%)."
  }
  'coverage-gate' {
    $cobertura = Join-Path $env:PROJECT_DIR 'Intermediate\CodeCoverage\coverage.xml'
    if (-not (Test-Path -LiteralPath $cobertura)) { throw "Coverage file not found: $cobertura" }
    [xml]$xml = Get-Content -LiteralPath $cobertura
    $coverage = [math]::Round(([double]$xml.coverage.'line-rate') * 100, 2)
    $threshold = [double]$CoverageThreshold
    "Coverage: $coverage% (threshold: $threshold%)"
    if ($coverage -lt $threshold) { throw "Coverage ($coverage%) is below threshold ($threshold%)." }
  }
  'package' {
    $outDir = Join-Path $env:PROJECT_DIR "$OutSubfolder\$Config"
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    $uatLogPath = Join-Path $outDir 'BuildCookRun.log'
    if (Test-Path -LiteralPath $uatLogPath) { Remove-Item -LiteralPath $uatLogPath -Force }
    & $env:UAT_BAT BuildCookRun "-project=$($env:PROJECT_PATH)" -noP4 -compile "-clientconfig=$Config" "-platform=$Platform" -cook -allmaps -stage -pak -archive "-archivedirectory=$outDir" 2>&1 | Tee-Object -FilePath $uatLogPath
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (-not (Test-Path -LiteralPath $uatLogPath)) { throw "Expected package log not found: $uatLogPath" }
    $issues = Get-Content -LiteralPath $uatLogPath | Where-Object {
      ($_ -match '^\s*ERROR:') -or
      (($_ -match '^\s*WARNING:') -and ($_ -notmatch 'Success\s*-\s*\d+\s*error\(s\),\s*\d+\s*warning\(s\)'))
    }
    if ($issues -and $issues.Count -gt 0) {
      $issues | ForEach-Object { "[package-issue] $_" }
      throw "Packaging produced warning/error log entries in $uatLogPath"
    }
  }
}
