---
name: tfvc-get-latest
description: 'Get latest code from a TFVC or TFS workspace using tf get. Use when the user asks to pull latest code, update code, sync workspace, get newest code, 拉最新代码, 拉取最新代码, 更新代码, tf get, or refresh from main branch. Prefer the shared TFVC default MainRoot from .github/tfvc-defaults.json when it exists locally; otherwise ask the user to choose or provide the mapped TFVC path.'
argument-hint: 'Provide an optional local TFVC path; if omitted, prefer the shared TFVC default MainRoot from .github/tfvc-defaults.json when available'
user-invocable: true
---

# TFVC Get Latest

Use this skill when the user wants to update a TFVC workspace to the latest server version.

中文说明：当用户说"拉最新代码"、"拉取今天最新的代码"、"更新代码"、"同步代码"或者明确提到 `tf get` 时，优先使用这个 skill。

## Goal

Run `tf get` against the correct TFVC workspace path, preferring `<MainRoot>` from `.github/tfvc-defaults.json` when it exists locally and otherwise asking the user to choose or provide the mapped path.

中文说明：目标是把本地 TFVC 工作区更新到服务器最新版本，而不是做 Git pull，也不是扫描整个仓库状态。

## Default Behavior

- If the user provides a local file or folder path, run `tf get` on that path.
- If the user does not provide a path and `<MainRoot>` exists locally, use it.
- If the user does not provide a path and `<MainRoot>` does not exist locally, ask the user to choose or provide the mapped TFVC local path.
- If the user says "latest code" without naming a branch, assume they mean the local workspace mapping for the main branch.
- In this repository, prefer `<MainRoot>` for "get latest" requests, but do not assume that path exists on another machine.

中文说明：TFVC 的"branch"通常体现在本地映射路径上。用户不指定分支时，不需要先做 Git 风格的 branch 切换；如果本机存在共享默认值 `<MainRoot>`，优先在这个映射到 main 的本地路径上执行 `tf get`，否则先问用户或让用户选择路径。

## Shared Defaults

- Shared TFVC defaults file: `.github/tfvc-defaults.json`
- `<MainRoot>` resolves from that file.

## Procedure

1. Start from the exact local path provided by the user.
2. If no path is provided, check whether `<MainRoot>` exists locally.
3. If that path exists, use it; otherwise ask the user to choose or provide the mapped TFVC path.
4. Confirm the path is inside a TFVC workspace when needed.
5. Run `tf get <path> /recursive /noprompt` for folders, or `tf get <file> /noprompt` for a single file.
6. Summarize what was updated, skipped, or blocked.
7. If the command indicates the path is not mapped, report that clearly and ask for the correct TFVC local path.

## Command Rules

- Prefer `tf get <path> /recursive /noprompt` for workspace or folder-level sync.
- Prefer `tf get <file> /noprompt` for a single file.
- If the user says "today's latest code" or "latest main branch code" without a path, prefer `<MainRoot>` only when that path exists locally.
- If the default path is unavailable, ask the user to choose a path, ideally from known workspace roots or another mapped TFVC folder.
- Do not assume Git branches or run Git commands for TFVC sync requests.
- If a different sandbox or mapped path is explicitly provided, use that path instead of the current workspace root.

## Output Expectations

- State the local path used for `tf get`.
- State whether the command completed successfully.
- Summarize key result lines instead of dumping raw terminal output unless the user asks for it.
- If no files changed, say that the workspace was already up to date.

## Notes

- "Main branch" in TFVC usually means the local workspace is already mapped to the server path for main.
- On another machine, the same TFVC mapping may live under a different drive or folder.
- If the local path is unknown, prefer asking for the mapped local path or presenting likely choices instead of guessing a server path.
