---
name: ado-bug-to-kb
description: "Analyze one or more ADO or ALM defects from TFVC changesets, extract reusable fix patterns from diffs, and write them into KB. TRIGGER when: user says '帮我分析这个 bug', '整理这些 defect', 'defect 写入 kb', '分析这些修复', 'read these defects', or pastes one or several ADO/ALM defect URLs or IDs with KB intent. ALM path requires Chrome logged in. DO NOT TRIGGER for broad keyword history scans such as '查 order 相关 defect' or '看 scope 下的 changeset' (use tfvc-defect-scan)."
argument-hint: "One or more defect refs separated by spaces, commas, or newlines. Supports ADO URL, ALM URL, or bare numeric ID."
user-invocable: true
---

# ADO Bug to KB Skill

Deep-dive one or more defects, follow their SCM changesets into TFVC diffs, extract reusable lessons, and persist them into KB.

中文：支持一次输入多个 defect（ADO URL / ALM URL / 纯数字 ID）。skill 会读取 defect 的 SCM changeset，分析 TFVC diff，提炼可复用规则，最后写入 KB。

## Goal

Turn historically fixed defects into reusable KB entries:
1. Find the exact changeset(s) behind each defect
2. Read the meaningful code diffs
3. Generalize them into patterns, pitfalls, and review rules
4. Append the good parts to the right KB pages

This is the **top-down** workflow: defect first, code second, KB last.

## Inputs

Accept any mix of:
- ADO work item URLs (`dev.azure.com/aspentechnology/.../_workitems/edit/<id>`)
- ALM defect URLs (`aspentech-alm.visualstudio.com/...`)
- Bare numeric IDs

Batch input is allowed. Split on spaces, commas, or newlines. De-duplicate exact duplicates.

---

## Decision Tree

```
Parse input into target list
        |
        v
For each target: classify system
  ├── ADO URL or bare ID (ADO batch)
  │     └── ado-wit_get_work_item → read title, repro, SCM hints
  └── ALM URL or bare ID (ALM batch)
        └── Chrome DevTools → navigate defect page → Resolution tab → read SCM
              |
              v
         Login wall? → ask user to confirm login
              |
              v
        Read SCM value → extract all changeset IDs
              |
              v
     tf changeset <id> /noprompt → get files + comment
              |
              v
     Filter to analyzable files (.ts .html .less .scss .json)
              |
              v
     tf diff per file /version:C<prev>~C<id> /format:unified
              |
              v
     Analyze diffs → extract patterns → write KB → report
```

---

## Procedure

### Step 1 — Normalize target batch

1. Parse all incoming refs.
2. De-duplicate.
3. Classify each:
   - `ADO URL` → extract numeric ID
   - `ALM URL` → keep URL for Chrome navigation
   - `Bare ID` → ask once whether this batch is ADO or old ALM
4. Build two queues: **ADO targets** and **ALM targets**.
5. If no input was given, use the currently open ALM page in Chrome.

### Step 2 — Resolve defect metadata and SCM

**ADO path:**
- Use `ado-wit_get_work_item`
- Read: title, description, `Microsoft.VSTS.TCM.ReproSteps`, any SCM/changeset hint in text

**ALM path:**
- Use Chrome DevTools, `list_pages` to find ALM tab
- If no ALM tab → tell user to open `aspentech-alm.visualstudio.com` and confirm
- Detect login wall → ask user to complete login + confirm
- Navigate to the defect
- Click `Resolution` tab
- Read: SCM, Fixed Build, Title, Description

If SCM is empty or missing → note defect as skipped, continue with rest.

### Step 3 — Expand SCM into changeset IDs

SCM may contain:
- `217415`
- `C217415`
- `217415, 219270`

Normalize:
1. Split on comma, semicolon, whitespace, or newline
2. Strip leading `C`
3. Keep valid integers only

Run per unique changeset:

```cmd
cd <MainRoot> && tf changeset <id> /noprompt
```

Find MainRoot by:
1. `tf workfold` → find mapping for `$/UnifiedPIMS/Releases/Main`
2. Fall back to `C:\source\Main`

### Step 4 — Filter and diff files

Analyze deeply: `.ts`, `.tsx`, `.js`, `.html`, `.less`, `.scss`, `.json`
Note briefly: `.cs`, `.csproj`, `.sln`
Skip: binary files, pure cosmetic style-only changes

```cmd
cd <MainRoot> && tf diff "<server_path>" /version:C<prev_id>~C<id> /noprompt /format:unified
```

`<prev_id> = <id> - 1`

### Step 5 — Extract reusable patterns

For each meaningful diff, compose an entry:

| Field | Content |
|---|---|
| **Problem** | What the bug was |
| **Anti-pattern** | The old approach that caused it |
| **Fix** | The corrected code (trimmed diff excerpt) |
| **Rule** | Generalized, reusable lesson |
| **References** | Defect ID, C\<changeset\>, date, author |

Good pattern signals:
- Missing null/undefined guards
- `@computedFrom` missing or incorrect
- ag-Grid group row not handled
- Permission logic in wrong layer (template vs view model)
- Dialog missing field constraints
- Backend guard preventing silent bad state
- i18n key inconsistency

### Step 6 — Route to KB

| Fix type | Target KB file |
|---|---|
| Aurelia binding, computed, lifecycle | `~/.copilot/kb/aurelia-form-patterns.md` |
| ag-Grid renderer, export, group rows | `~/.copilot/kb/ag-grid-patterns.md` |
| TypeScript general patterns | `~/.copilot/kb/coding-patterns.md` |
| Project-specific logic | `.github/kb/projects/<project>.md` |
| Backend-only fix | Skip (mention it was backend) |

Prefer project KB (`.github/kb/`) if the file exists. Fall back to global `~/.copilot/kb/`.

Before writing:
1. Read target file
2. Check for near-duplicate entries
3. Append under the right `##` heading; create heading if missing
4. Include trimmed diff excerpts as code blocks

### Step 7 — Report

```
✅ ado-bug-to-kb 完成: 3 defects / 4 changesets

📝 写入:
- ~/.copilot/kb/ag-grid-patterns.md  → "Group row guard for order grids"
- ~/.copilot/kb/coding-patterns.md   → "Normalize SCM value before TFVC call"

⏭ 跳过:
- Defect 105046  → 未记录 SCM changeset
- order-property.less  → 纯样式微调

ℹ 备注:
- 涵盖: ADO 105028、105019；ALM 1264939
- Changesets: C241638, C217415, C219270
```

---

## Authentication Handling (ALM only)

1. Detect login wall in snapshot (`Sign in`, `Enter your email`, `Password`)
2. Tell user to authenticate
3. `ask_user`: "ALM 登录完成后请确认"
4. Only continue after explicit confirmation

Never treat login page content as defect data.

---

## Edge Cases

| Situation | Handling |
|---|---|
| Mixed ADO + ALM input | Split into two queues, process both |
| Bare IDs only | Ask once which system they belong to |
| Multiple SCM changesets in one defect | Process all of them |
| SCM missing | Skip that defect, continue batch |
| Only backend files changed | Note briefly; only write KB if a reusable backend rule exists |
| Pattern already in KB | Skip and note it as duplicate |

---

## Related Skills

- `tfvc-defect-scan` — bottom-up scan from scope/history to defects; feeds candidates to this skill
- `session-kb-update` — end-of-session KB consolidation
- `figma-design-inspector` — same login-first browser workflow pattern

---

## Git Rules

Write files and `git add` only. Do not commit or push.

After staging, tell the user which files were staged and suggest a commit message.
