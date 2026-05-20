# Unreal Build Scripts

Project-agnostic Unreal build automation for game and plugin workflows, with support for both PowerShell scripts and Taskfile.dev tasks.

The repository is designed to be dropped into other repos (usually as a submodule) and discover the current Unreal project dynamically.

## What this provides

- Build editor and game targets across common configurations
- Run Unreal automation tests through `UnrealEditor-Cmd.exe`
- Generate and gate C++ coverage with `OpenCppCoverage` (Windows)
- Package game builds via `RunUAT BuildCookRun`
- Compose CI-friendly workflows with either scripts or Task

## Two interfaces

You can use either interface:

1. PowerShell scripts under `./` (for example `All.ps1`, `RunTests.ps1`)
2. Taskfiles under `taskfiles/` (recommended for CI composition)

Both paths are intended to have equivalent behavior.

## Taskfile usage

Entry Taskfile:

- `taskfiles/Taskfile.yml`

Common commands:

- `task -t taskfiles/Taskfile.yml clean`
- `task -t taskfiles/Taskfile.yml doctor`
- `task -t taskfiles/Taskfile.yml build:all`
- `task -t taskfiles/Taskfile.yml test`
- `task -t taskfiles/Taskfile.yml coverage`
- `task -t taskfiles/Taskfile.yml coverage:gate COVERAGE_THRESHOLD=100`
- `task -t taskfiles/Taskfile.yml package:all`
- `task -t taskfiles/Taskfile.yml ci`
- `task -t taskfiles/Taskfile.yml ci:full`

If your host project provides a thin root wrapper Taskfile, you can call namespaced tasks from the project root (for example `task unreal:coverage`).

## Project-agnostic behavior

The automation discovers context at runtime:

- Finds the nearest `.uproject` by walking up parent directories
- Resolves default test prefix:
  - plugin context: `<PluginName>.Fast`
  - project context: `<ProjectName>.Fast`
- Supports plugin-in-project scenarios by building/testing against the discovered top-level `.uproject`

## Environment resolution

Unreal engine path precedence:

1. `UE_DIR` override
2. Existing process `UE_PATH`
3. Cascading `.env` files discovered upward from invocation directory

Expected variable:

- `UE_PATH=...` (or `UE_DIR=...` override)

The task system writes a generated runtime context file named `.task-context.env`. This file should be gitignored.

## Coverage behavior

Coverage uses [`OpenCppCoverage`](https://github.com/OpenCppCoverage/OpenCppCoverage) and writes artifacts to:

- `Intermediate/CodeCoverage/coverage.xml`
- `Intermediate/CodeCoverage/` (HTML report)

`coverage` runs tests and prints a summary including duration and threshold result.

`coverage:gate` enforces threshold and fails when below `COVERAGE_THRESHOLD` (default `100`).

## Script behavior parity notes

The Task implementation mirrors the script model:

- Uses explicit process execution for Unreal and coverage tools
- Produces equivalent command-line arguments for test/coverage runs
- Preserves package log scanning and failure-on-real-warning/error behavior

## CI guidance

For fast CI:

- `ci` => build matrix + coverage gate

For full CI:

- `ci:full` => `ci` + packaging matrix

## Placement and portability

You can place this repository in any intermediate folder, as long as parent traversal from the invocation location can reach your project root (`.uproject`). Folder naming is flexible.

Typical examples:

- `<Project>/Scripts/unreal-build-scripts`
- `<Project>/Plugins/<Plugin>/Scripts/unreal-build-scripts`

## Requirements

- PowerShell 7+
- Unreal Engine installed and path configured (`UE_PATH` or `UE_DIR`)
- `task` CLI (for Taskfile flows)
- `OpenCppCoverage` (required for coverage tasks)

## Install Task

Install Task from the official guide:

- https://taskfile.dev/installation/

Quick Windows options:

- `winget install Task.Task`
- `choco install go-task`
- `scoop install task`

Verify installation:

- `task --version`
