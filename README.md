# Unreal Build Scripts

Build and test scripts suitable for game and plugin development that also generate coverage reports.

This is a collection of scripts I find myself re-using on projects. I have tried to make them project-agnostic so they can simply be used as a submodule in either a top-level game project, or as a plugin in `<Project>/Plugins`.

## Usage

Create an intermediate-level directory in your game or plugin project. For example `MyGameProject/Scripts`. Change to that directory and clone this project into it. The subdirectory name does not matter, so `unreal-build-scripts` should suffice. If you prefer other naming conventions that are more "Epic" in nature, then clone into "Build" so you end up with `MyGameProject/Scripts/Build`. The only requirement here is that these scripts are 2 subdirectories below your game project or plugin.

For a plugin, it may be `EmptyGameProject/Plugins/Scripts` as the intermediate, then clone this repository into that `Scripts` folder.

The parent directory does not even need to be named `Scripts`. Could be `Jabberwocky` for all they care. Just have `../..` lead to your plugin or project root.

## Opinionated Design

The scripts make some assumptions about project layout and naming, which are conventional across just about every Unreal Engine based project. For example, the tests assume that, if a plugin is being tested, then `<Project>/Plugins/<PluginName>` is the name of the plugin. It will search for `<PluginName>.fast` for fast tests using Unreal's test automation. It will also assume there is a `<PluginName>/Maps/TestMap` that should be loaded to setup test automation so the plugin (or project) can set some basic assumptions for testing (for example, an actor with a plugin's component attached is spawned).

The same is true for game projects. The project root should have `<ProjectName>.uproject`. If the scripts are not parented by a `Plugins` folder, they will assume they are for a top-level project.

Even if the scripts are in a plugin, they will still search for a top level `<ProjectName>.uproject` for building and testing. They do not yet "package" an unreal plugin fit for publishing.

## Code Coverage

On Windows, `RunTests.ps1` will check to see if [`OpenCppCoverage`](https://github.com/OpenCppCoverage/OpenCppCoverage) is installed. If so, it will generate Coburtera reports that can be used by CI systems to report code coverage, and even fail the build if a certain threshold is not met. It defaults to 100% coverage, and honestly, any new project should start there and strive to never drop below 100%.

## Building

There are scripts to build most targets. Editor, Game and Packaged builds. There is an `All.ps1` that will:

- Build a development editor
- Use the development editor to execute `RunTests.ps1`
- Build a debug editor
- Build a debug game
- Build a development game
- Build a shipping game
- Package debug, development and shipping games

This provides coverage for a number of configurations that may often be missed or languish as bugs pile up over time. They are in place to keep CI systems consistent. They should work anywhere, like Team City, Jenkins or proprietary CI systems. I test them with Github and Gitlab continuous integration.

## Using Powershell

I honestly prefer `bash` or even just `sh` if I can get away with it. Unreal Engine leverages a lot of `.Net` and every developer I know (code-wise) uses Windows for Unreal game dev. Powershell is now just as portable as POSIX shells, so I bit the bullet and opted for Powershell. It requires the latest Powershell (I use 7.5), so be sure to have that installed on systems running these scripts.

## Examples?

I have some templates I am working on to provide some examples that can help set a reasonable basis when starting new projects. When they are mature enough to share, I will create a repo and share them as well.
