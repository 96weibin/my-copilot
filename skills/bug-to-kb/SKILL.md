---
name: bug-to-kb
description: "Analyze a closed ALM defect from TFVC changeset diffs and persist fix patterns into KB. TRIGGER when: user says '帮我分析这个 bug', 'bug to kb', '整理这个 defect', 'defect 写入 kb', '分析这个修复', 'read this defect', or provides a defect ID followed by a KB intent. Requires Chrome with ALM tab open and logged in — ask user to authenticate first. DO NOT TRIGGER for general coding questions or active development sessions."
argument-hint: "Defect ID (optional), e.g. '1264939'. If omitted, reads the currently open defect in Chrome."
user-invocable: true
---

# Bug-to-KB Skill

Extract reusable fix patterns from closed ALM defects via TFVC changesets and write them to the appropriate KB.

中文说明：打开 Chrome 登录 ALM，导航到 defect，skill 读取 SCM changeset，diff 代码变更，提炼 fix pattern，写入 KB。

## Goal

Turn historically fixed bugs into reusable KB entries — patterns, pitfalls, and before/after examples — so future development avoids the same mistakes.

## Prerequisites

The user must:
1. Have Chrome open with `aspentech-alm.visualstudio.com` logged in
2. Navigate to the target defect (or the query list)
3. Confirm "ready" before the skill starts reading

---

## Decision Tree

```
User provides defect ID?
├── Yes → Confirm URL pattern, navigate if needed
└── No  → Use currently open page in Chrome
            ↓
Login wall detected?
├── Yes → Ask user to complete login + confirm
└── No  → Continue
            ↓
Defect page open?
├── No  → Ask user to navigate to the defect
└── Yes → Click Resolution tab
            ↓
SCM field found?
├── Empty → Report "No changeset recorded" and stop
└── Has value (e.g. "217415" or "C217415") → Extract changeset ID
            ↓
Run: tf changeset <id> /noprompt
            ↓
Filter changed files to analyzable types (.ts, .html, .less, .scss, .json)
            ↓
Run: tf diff for each file /version:C<prev>~C<id> /noprompt /format:unified
            ↓
Analyze diffs → classify patterns
            ↓
Route to KB → write entries → report
```

---

## Procedure

### Step 1 — Resolve Target Defect

1. If argument is provided (defect ID), note it.
2. Check Chrome pages with `list_pages`.
3. Look for a tab matching `aspentech-alm.visualstudio.com`.
4. If no ALM tab found → tell user to open ALM in Chrome and confirm when ready.
5. Select the ALM tab with `select_page`.

### Step 2 — Handle Authentication

Take a snapshot. Look for login indicators:
- `Sign in`, `Continue with SSO`, `Enter your email`, `Password`

If login wall detected:
1. Tell user to authenticate in the browser
2. Use `ask_user` to confirm: "ALM 登录完成后请确认，我将继续读取 defect"
3. Options: `已完成登录，继续` / `还没完成`
4. Only proceed after user confirms

### Step 3 — Navigate to Target Defect

If a defect ID was provided and the page is not already showing that defect:
1. Use the search box in the top-right of ALM (uid of search input)
2. Type the defect ID → press Enter or click the suggestion
3. Wait for the defect panel/page to load

If no defect ID, use the currently visible defect.

### Step 4 — Read SCM Changeset

1. Take a snapshot.
2. Find and click the **Resolution** tab (look for tab labeled "Resolution").
3. Take another snapshot after tab loads.
4. Find the "SCM (Source Code Management)" textbox.
5. Extract its value (e.g., `"217415"` or `"C217415"`).
6. Normalize: strip leading `C` if present → integer changeset ID.
7. Also read: **Fixed Build**, **Title**, **Description** fields for context.

If SCM field is empty or missing:
- Report: "该 defect 未记录 SCM changeset，无法分析代码变更。"
- Stop the skill.

### Step 5 — Get TFVC Changeset Metadata

Find the TFVC workspace root:
1. Check if `.github/tfvc-defaults.json` exists in the current project root.
2. If found, read `MainRoot` from it.
3. If not found, use default: `D:\Source\Releases\Main`.

Run:
```powershell
cd <MainRoot>; tf changeset <id> /noprompt
```

Output gives:
- Comment (bug description + fix intent)
- List of changed files (TFVC server paths like `$/UnifiedPIMS/...`)

### Step 6 — Filter and Diff Files

Filter changed files to analyzable types:
- `.ts`, `.html`, `.less`, `.scss` → UI patterns (analyze in depth)
- `.json` → i18n / config changes (analyze for resource patterns)
- `.cs`, `.csproj`, `.sln` → backend (note briefly, skip deep analysis)

For each UI/JSON file, run:
```powershell
cd <MainRoot>; tf diff "<server_path>" /version:C<prev_id>~C<id> /noprompt /format:unified
```

Where `<prev_id> = <id> - 1`. (Standard TFVC convention for single-changeset diff.)

Collect all diffs.

### Step 7 — Analyze Fix Patterns

For each diff, identify:

| Signal | Pattern to Extract |
|---|---|
| Removed `start-limit`/`end-limit` bindings | Input component limit anti-pattern |
| Added `isDisabled` computed with per-reason logic | Validation in VM not template |
| `@computedFrom` added/updated | Computed dependency tracking |
| Added null/undefined guards | Defensive coding |
| Group row checks (`params.node.group`) | ag-Grid group row handling |
| `disabledReason` string pattern | UX: explain disabled state |
| i18n key additions in JSON | Resource message conventions |
| `valueFormatter` guard for group rows | ag-Grid export safety |

For each pattern found, compose a KB entry with:
- **Problem** (what the bug was)
- **Anti-pattern** (old code / approach)
- **Fix** (new code with diff excerpt)
- **Rule** (generalized lesson)
- **Bug Reference** (Defect ID, C<id>, date, committer)

### Step 8 — Route to KB

| Fix type | Target KB file |
|---|---|
| Aurelia binding, computed, lifecycle | `~/.copilot/kb/aurelia-form-patterns.md` |
| ag-Grid renderer, export, group rows | Project `.github/kb/pages/common-data-grid.md` OR `~/.copilot/kb/ag-grid-patterns.md` |
| TypeScript general patterns | `~/.copilot/kb/coding-patterns.md` |
| i18n resource conventions | Project `projects/<project>.md` |
| Project-specific logic | `.github/kb/projects/<project>.md` |
| Backend-only fix | Skip (note it was backend) |

Priority: prefer project KB (`.github/kb/`) when in a project and the page exists. Fallback to global `~/.copilot/kb/`.

### Step 9 — Write Entries (Append-only)

1. Read target KB file first — check for duplicate content.
2. If similar entry already exists → skip, note it.
3. Append new section under appropriate `##` heading.
4. If no appropriate heading exists → create one.
5. Include code examples from the actual diff (trimmed to relevant hunks).

### Step 10 — Report

```
✅ Bug-to-KB完成: Defect 1264939 / C217415

📝 写入：
- ~/.copilot/kb/aurelia-form-patterns.md → "Input validation: VM computed vs component limits"

⏭ 跳过：
- create-event-dialog.less → 仅样式微调，无规律性内容

ℹ️ 备注：
- Fixed Build: media 25 | 2024-01-03 | Committer: Zhao, Weibin
```

---

## Authentication Handling

Same pattern as `figma-design-inspector`:

1. Detect login wall in snapshot
2. Tell user to authenticate in browser
3. `ask_user` confirm prompt: "ALM 登录完成请确认"
4. Only continue after explicit confirmation

Never treat login screen content as defect data.

---

## Edge Cases

| Situation | Handling |
|---|---|
| SCM field empty | Report and stop — don't guess |
| Changeset has only backend files | Note it, skip writing, report |
| tf command not found / fails | Report TFVC error, ask user to check workspace |
| Defect has multiple changesets in SCM (e.g. "217415, 219270") | Process each one separately |
| Target KB file doesn't exist | Create it with `# Title` and `## Metadata` header |
| Pattern already in KB | Skip and note it was already documented |

---

## Companion Tools

| Tool | Purpose |
|---|---|
| `list_pages` / `select_page` | Find and select ALM tab in Chrome |
| `take_snapshot` | Read defect details, SCM field, tab content |
| `click` | Switch to Resolution tab |
| `type_text` / `fill` | Enter defect ID in search box |
| `start_process` | Run `tf changeset` and `tf diff` |
| `read_file` / `write_file` | Read + append KB files |
| `ask_user` | Confirm login, confirm defect target |

---

## Git Rules

**Write files + `git add` only. Do NOT commit or push.**

After staging, tell the user:
- Which files were staged
- Suggested commit message
- Ask them to run `git diff --staged` to review, then commit when ready

## Related Skills

- `session-kb-update` — end-of-session KB from plan/todos (no changeset analysis)
- `tfvc-change-review` — review pending/staged TFVC changes (not historical bugs)
- `figma-design-inspector` — same login-first Chrome pattern

---

## Global KB Files This Skill Writes To

| File | Content |
|---|---|
| `~/.copilot/kb/aurelia-form-patterns.md` | Binding, validation, computed patterns |
| `~/.copilot/kb/ag-grid-patterns.md` | Grid rendering, export, group row patterns |
| `~/.copilot/kb/coding-patterns.md` | General TS/JS patterns and gotchas |
