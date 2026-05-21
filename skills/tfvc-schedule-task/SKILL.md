---
name: tfvc-schedule-task
description: 'Create or update a Windows scheduled task for TFVC automation. Use when the user asks to schedule tf get, set up a daily build task, create a Windows Task Scheduler job, 自动执行拉最新代码, 明天几点帮我拉代码, 定时执行脚本, or schedule tfvc-get-latest-and-devtools.ps1. In this workflow, "拉代码" defaults to running the tfvc-schedule-task script tfvc-get-latest-and-devtools.ps1, which means get latest plus build, unless the user explicitly says only tf get.'
argument-hint: 'Describe the task name, when it should run, and whether it is only tf get or get latest plus build'
user-invocable: true
---

# TFVC Schedule Task

Use this skill when the user wants to create a shareable Windows scheduled task that runs TFVC sync and related automation on a schedule.

中文说明：当用户想要"每天某时自动拉最新代码"、"定时执行 tfvc-get-latest-and-devtools.ps1"、"创建 Windows 计划任务"时，使用这个 skill。默认执行脚本放在 `tfvc-schedule-task/scripts` 目录下，便于整体分享。

补充约定：在这个 skill 里，用户说"拉代码"默认不是只执行 `tf get`，而是默认执行 `./scripts/tfvc-get-latest-and-devtools.ps1`，也就是"拉代码 + build"。只有当用户明确说"只拉代码"、"只执行 tf get"、"不要 build"时，才按纯拉代码处理。

## Goal

Help the user create or update a Windows Task Scheduler task that runs a script such as `./scripts/tfvc-get-latest-and-devtools.ps1` on a chosen schedule.

中文说明：目标是让用户不手工点 Task Scheduler，也能通过明确步骤或脚本完成定时任务配置。

## When to Use

- The user asks to schedule `tf get` or TFVC sync.
- The user wants a reusable task like `dalyFirst`.
- The user wants to share this setup with teammates as a zip or a `.github` folder.
- The user asks for automatic daily, weekly, one-time, or logon-triggered execution.

## Required Inputs

Ask for these if the user did not provide them:

1. Task name
2. Target script path to run
3. Schedule type: `Daily`, `Weekly`, `Once`, or `OnLogon`
4. Start time for `Daily`, `Weekly`, or `Once`
5. Day of week for `Weekly`
6. Local `MainRoot` path when the shared default `<MainRoot>` does not exist

中文说明：如果脚本路径、任务名、时间或频率缺失，先问清楚再创建计划任务。

## Default Behavior

- If the script path is omitted, prefer `./scripts/tfvc-get-latest-and-devtools.ps1` in this skill folder.
- If the user says "明天几点帮我拉代码"、"定时帮我拉代码" or similar phrasing, default to `./scripts/tfvc-get-latest-and-devtools.ps1` in this skill folder, which means TFVC get latest plus build.
- Only treat "拉代码" as pure `tf get` when the user explicitly says `只拉代码`, `只执行 tf get`, `不要 build`, or equivalent wording.
- Prefer `<MainRoot>` from `.github/tfvc-defaults.json` as the default `MainRoot` on this machine. If that path does not exist on the target machine, ask the user for the local mapped root before creating the task.
- If the task name is omitted, suggest `TFVC-GetLatest-And-DevBuild`.
- If the schedule is omitted, ask instead of guessing.
- If the target machine may not have the same folder layout, ask the user to confirm the local path before creating the task.

## Procedure

1. Confirm the target script exists locally.
2. Interpret "拉代码" as "拉代码 + build" by default, unless the user explicitly asks for `tf get` only.
3. Resolve the local `MainRoot`, `DevTools`, and `TfsBuild` paths. Use this machine's known defaults first; if they do not exist, ask the user.
4. Ask for any missing scheduling inputs.
5. Build the scheduled task command using Windows `schtasks`.
6. Create or update the task.
7. Query the task to confirm `Next Run Time`, `Status`, and `Task To Run`.
8. Summarize the configuration for the user.

## Command Rules

- Prefer `schtasks /Create ... /F` to create or replace an existing task.
- Prefer `schtasks /Query /TN <name> /V /FO LIST` to verify the result.
- Use `powershell.exe -ExecutionPolicy Bypass -File <script>` as the task action for PowerShell scripts.
- In this workspace, when the user only says "拉代码", prefer the automation script `./scripts/tfvc-get-latest-and-devtools.ps1` in this skill rather than a raw `tf get` command.
- Pass the resolved `MainRoot` into the script as a parameter so the task remains portable across machines with different local mappings. Derive the `DevTools` and `TfsBuild` paths from that root.
- Do not assume the same folder structure exists on another machine; confirm or ask when paths are ambiguous.

## Shared Defaults

- Shared TFVC defaults file: `.github/tfvc-defaults.json`
- `<MainRoot>`, `<DevToolsScript>`, and `<TfsBuildScript>` resolve from that file.

## Shareable Assets

- Use the helper script [register-tfvc-scheduled-task.ps1](./scripts/register-tfvc-scheduled-task.ps1) when the user wants a reusable packaged setup.
- Use the execution script [tfvc-get-latest-and-devtools.ps1](./scripts/tfvc-get-latest-and-devtools.ps1) as the default scheduled task target for get latest plus build.
- This skill is shareable together with its helper script and the target automation script.

## Output Expectations

- State the final task name.
- State the script path used.
- State the resolved `MainRoot` path used for the scheduled task.
- State whether the task means `tf get only` or `get latest + build`.
- State the schedule type and start time.
- State whether the task was created or updated successfully.
- If information is missing, ask concise follow-up questions instead of guessing.
