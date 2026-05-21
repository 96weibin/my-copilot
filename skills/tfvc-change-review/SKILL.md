---
name: tfvc-change-review
description: 'Review TFS or TFVC changes using tf commands. Use when the user asks for code review and provides local paths, folders, pending-change hints such as add, edit, delete, tf diff, TFVC, or TFS, or references a specific changeset such as Changeset 240833, changeset id 240833, cs240833, or 查看 changeset. Focus the review on real TFVC change hunks plus minimal nearby local context, not the entire local file.'
argument-hint: 'Provide one or more TFVC local paths, folders, or a changeset ID to review'
user-invocable: true
---

# TFVC Change Review (Global)

Use this skill when the user wants a review of TFVC or TFS changes and provides file paths, folder paths, pending-change hints, or a specific changeset ID.

## Goal

Review only the actual pending changes, using TFVC diff output as the source of truth, and compare those changed hunks against the smallest amount of local code needed for context.

## Procedure

1. Normalize user input as local path, local folder, or changeset ID.
2. Resolve `<MainRoot>` from `.github/tfvc-defaults.json` if it exists. Otherwise use nearest mapped ancestor path.
3. For path-based review, enumerate pending files first, then run `tf diff` per file.
4. For changeset-based review, run `tf changeset <id> /noprompt` first, then diff each changed file with changeset-scoped version range.
5. Read only minimal local context around changed hunks when needed.
6. Ask once whether there is a related ADO work item ID/URL. If provided, fetch it and verify change intent against AC/repro.
7. Combine TFVC diff + ADO context + project KB (if available) and output findings.

## Command Rules

- Prefer `tf diff <path> /noprompt` for explicitly changed files.
- Prefer `tf status <path> /recursive /format:detailed` to enumerate folder pending changes.
- For changeset review, prefer `tf diff <path> /version:C<id>~C<id-1> /format:Unified /noprompt`.
- If direct `tf diff <absolute-path>` fails for a path under `<MainRoot>`, retry from `<MainRoot>`.
- Do not rely on `tf status /user:*` in local workspaces unless workspace is explicitly supplied.

## ADO + KB Context Rules

- Never hardcode project defaults. Prefer parsing project/org from user-provided ADO URL or ask user when ambiguous.
- If ADO item is provided, read title/type/state plus Description, Acceptance Criteria, Repro Steps.
- If project KB exists, consult `.github/kb/README.md` as index and relevant pages.
- If project KB does not exist, continue diff-only review and explicitly mention KB was not available.

## Review Scope

In scope:
- changed logic/template/style with behavior impact
- regressions introduced by changed hunks
- missing validation/guarding directly related to change

Out of scope:
- unrelated pre-existing issues outside changed hunks
- broad architecture comments not driven by the diff

## Output Expectations

- Findings first, ordered by severity.
- Include file path and changed location references.
- If no issues found, state that explicitly and mention testing gaps.
- If files from changeset cannot be mapped locally, list them clearly.
