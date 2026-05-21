---
name: tfvc-devtools
description: 'Run the shared TFVC DevTools workflow for this workspace. Use when the user asks to build code, build 一下代码, 全局 build, 编译一下, 跑一下 Dev build, 跑一下 DevTools, or run the shared DevTools workflow without asking for scheduling. In this workspace, the default immediate action uses the shared TFVC defaults from .github/tfvc-defaults.json.'
argument-hint: 'Provide an optional local TFVC root path or a DevTools option name; if omitted, use the shared TFVC defaults from .github/tfvc-defaults.json and default to Dev'
user-invocable: true
---

# TFVC DevTools

Use this skill when the user wants to run the shared DevTools workflow now, not create a scheduled task.

中文说明：当用户说"build 一下代码"、"build 代码"、"全局 build"、"编译一下"、"跑一下 Dev build"或者"跑一下 DevTools"时，使用这个 skill。这里默认执行的是共享默认值 `<DevToolsScript> Dev`，但这个 workflow 的语义是 DevTools，而不是狭义上的单纯 build。

## Goal

Run the workspace DevTools entry point immediately, preferring `<DevToolsScript> Dev` resolved from `.github/tfvc-defaults.json` on this machine.

中文说明：目标是直接执行当前机器上的 TFVC DevTools 入口，而不是创建 Windows 计划任务。默认动作是 DevTools 的 `Dev` 选项，也就是菜单中的第 1 项。

## Default Behavior

- If the user does not provide a path, prefer `<MainRoot>` when it exists locally.
- In this workspace, `build 代码` defaults to running `<DevToolsScript> Dev`.
- Treat this as the shared DevTools workflow, not a generic npm or dotnet build.
- If `<MainRoot>` does not exist locally, ask the user to provide the mapped TFVC root.
- Do not route immediate DevTools requests to `tfvc-schedule-task` unless the user explicitly asks for scheduling.
- Do not assume the user also wants `tf get` unless they explicitly ask to sync or pull latest first.

## Supported DevTools Context

`<DevToolsScript>` exposes multiple options. For immediate build-like requests, default to option `1` / `Dev`, which the script maps to `<TfsBuildScript> Dev`.

## Shared Defaults

- Shared TFVC defaults file: `.github/tfvc-defaults.json`
- `<MainRoot>`, `<DevToolsScript>`, and `<TfsBuildScript>` resolve from that file.

Relevant options from the shared DevTools menu include:
- `Dev`: full incremental build plus webpack
- `DevRestore`: restore packages only
- `DevNet`: dotnet build only
- `DevNetNoRestore`: dotnet build without restore
- `DevWeb`: webpack build only
- `DevWebSeq`: sequential webpack build
- `WebOnly`: production webpack build
- `LocalStage`: local staging workflow

## Procedure

1. Start from the exact local path provided by the user, if any.
2. If no path is provided, check whether `<MainRoot>` exists locally.
3. Resolve the DevTools script path as `<MainRoot>\Psc\_DevTools.ps1`.
4. Confirm the script exists locally.
5. If the user did not specify a DevTools option, run `powershell.exe -ExecutionPolicy Bypass -File <DevToolsScript> Dev`.
6. If the user did specify a supported DevTools option, pass that option through to `_DevTools.ps1`.
7. Summarize whether the workflow completed successfully and quote the key result lines.
8. If the script path or root path is missing, ask for the mapped TFVC root instead of guessing.

## Command Rules

- Prefer `powershell.exe -ExecutionPolicy Bypass -File <DevToolsScript> Dev` on this machine when the default path exists.
- If the user supplies a different local TFVC root, derive the script path as `<MainRoot>\Psc\_DevTools.ps1`.
- Do not create a scheduled task for one-off DevTools requests.
- Do not run Git build commands for this workflow.
- If the user explicitly asks for `get latest + build`, first use the TFVC sync workflow and then run this DevTools workflow.
- If the user asks for a specific DevTools mode such as `DevWeb` or `DevRestore`, pass that exact option to `_DevTools.ps1`.

## Output Expectations

- State the local TFVC root used.
- State the DevTools script path used.
- State the DevTools option used, defaulting to `Dev` when omitted.
- State whether the command completed successfully.
- Summarize key result lines instead of dumping raw terminal output unless the user asks for it.

## Notes

- This skill is for immediate execution only.
- Scheduled automation remains the responsibility of `tfvc-schedule-task`.
- In this workspace, the scheduled-task skill may call related build scripts, but the immediate user intent `build 代码` should resolve here as the DevTools workflow.
