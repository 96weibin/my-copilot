---
name: tfvc-defect-scan
description: "Scan recent TFVC history in a scope folder by keyword, extract defect IDs from changeset comments, cross-reference them in ADO, and summarize findings with recommendations for deeper follow-up. TRIGGER when: user says '查一下 XXX 相关的 defect', '看 XXX 的 changeset', 'scan defects for XXX', '帮我盘点 XXX 修复', '帮我看 scope 下的 bug', or asks to correlate TFVC history with ADO bugs in a folder/module. DO NOT TRIGGER for single-defect deep analysis or KB writing (use ado-bug-to-kb for those)."
argument-hint: "Keyword plus optional scope folder, e.g. 'order in Psc/Aum' or 'movement'."
user-invocable: true
---

# TFVC Defect Scan Skill

Scan TFVC history bottom-up: start with a folder + keyword, find recent changesets, look up linked ADO defects, then deliver a summary table, observations, and recommended defects to deep-dive.

中文：从 TFVC scope 和关键词出发扫描近期 history，提取 comment 中的 defect 编号，联动 ADO 查询状态，最后输出结果表、观察点和推荐深入列表。

## Goal

Give a fast defect landscape for a module:
1. Which recent changesets match the topic
2. Which ADO bugs are behind them (state, owner, priority)
3. Which changesets are missing bug IDs (policy violations)
4. Which defects are worth handing off to `ado-bug-to-kb`

This is the **bottom-up** workflow: TFVC history first, ADO defects second, recommendations last.

## Default output

This skill is **read-only**. It does **not** write to KB.

Every run ends with four sections:
1. **Summary table** — grouped by changeset, one row per bug
2. **No-ID changesets** — commits describing fixes with no parseable bug ID
3. **Observations** — 3–5 concise bullets
4. **Recommended next defects** — best candidates for `ado-bug-to-kb`

---

## Inputs

| Input | Default |
|---|---|
| **Keyword** | required — e.g. `order`, `movement`, `auth` |
| **Scope folder** | inferred from cwd, or specified (e.g. `Psc/Aum`) |
| **History depth** | asked at runtime (choices: 50 / 100 / 200 / custom number or date) |

If scope is omitted, infer from current working directory mapped against `tf workfold`.

---

## Procedure

### Step 1 — Resolve workspace and scope

1. Run `tf workfold`
2. Find the local path that maps to `$/UnifiedPIMS/Releases/Main` (usually `C:\source\Main`)
3. Combine with scope folder (e.g. `C:\source\Main\Psc\Aum`)
4. Confirm the folder exists before proceeding

### Step 2 — Confirm scan depth with user

Before running history, **always ask the user** how far back to scan:

```
ask_user:
  question: "要扫描最近多少条 changeset？"
  choices:
    - "最近 50 条（最快，约 1 周）"
    - "最近 100 条（默认，约 1–2 周）"
    - "最近 200 条（约 1 个月）"
  allow_freeform: true   # user can type a custom number or a date like "4月以来"
```

If the user provides a **date range** (e.g. "4月以来", "since April"):
- Use `/stopafter:500` as a safe upper bound
- After fetching, filter rows by date client-side

If the user provides a **bare number** (e.g. "300"):
- Use `/stopafter:300`

If the user says "all" or similar:
- Warn: "历史记录可能很长，建议先用 200 确认规模再决定。"
- Ask for confirmation before proceeding

### Step 3 — Pull recent history

Run inside the scope folder:

```cmd
cd <ScopeFolder> && tf history . /recursive /noprompt /format:brief /stopafter:<depth>
```

`/format:brief` is essential — never use `detailed` at scan time.

### Step 4 — Filter candidate changesets

Keep rows whose `Comment` column contains the keyword (case-insensitive).

Drop:
- Author is `atbuild.psb`
- Comment is only a version bump
- Comment is only `***NO_CI***`
- Rollback or merge rows (unless the keyword still appears in a relevant way)

### Step 5 — Expand full changeset metadata

Brief-format comments are truncated. Fetch full metadata for each candidate in a single batched call:

```cmd
cmd /c "tf changeset 241638 /noprompt & tf changeset 241424 /noprompt & ..."
```

Collect for each:
- Full comment
- Author
- Date
- Changed files (all Items lines)
- Linked Work Items (if any)

### Step 6 — Extract ADO bug IDs

Scan full comment text with patterns (case-insensitive):

| Pattern | Example |
|---|---|
| `Bug <id>:` | `Bug 105028: AUM - Orders...` |
| `fix bug <id>,<id>` | `fix bug 103066, 103082, 103110` |
| `Bug <id> -` | `AUM Bug 101958 - Add Order...` |
| `User Story <id>:` | `User Story 104128: UI: Add...` |
| `TASK<id>` | `TASK102310- Dev: Add Columns` |

Regex: `\b(?:bug|user\s+story|task|defect)\s*#?\s*(\d{4,7})\b`

Then do a comma-list pass: after a matched prefix, grab all subsequent comma-separated integers.

Bucket results:
- **with-ID**: changeset → list of bug IDs
- **no-ID**: changesets whose comments sound like bug fixes but contain no parseable ID

### Step 7 — Query ADO in one batch call

```
ado-wit_get_work_items_batch_by_ids(
  ids = <all de-duplicated bug IDs>,
  fields = [
    System.Id, System.Title, System.State,
    System.WorkItemType, System.AssignedTo,
    Microsoft.VSTS.Common.Priority, System.Tags
  ]
)
```

### Step 8 — Compose response

#### Section 1: Summary table

Group by changeset. Use status icons:
- 🟢 Active
- 🟡 Resolved
- ✅ Closed
- 🔴 New

| Changeset | Bug ID | Title | State | Assigned | Priority |
|---|---|---|---|---|---|

#### Section 2: No-ID changesets

List each violation with:
- Changeset number
- Author
- Date
- Short comment (verbatim)
- Key files touched

#### Section 3: Observations

Write 3–5 bullets. Look for:
- Active bugs whose code is already in (state sync gap)
- One person owning the bulk of fixes in this module
- Files that appear across many changesets (hotspot)
- Policy violations (no ADO ID in commit)
- Groups of bugs that look like the same underlying pattern

#### Section 4: Recommended next defects

Pick 2–5 defects that are best suited for `ado-bug-to-kb` deep-dive.

A good candidate has one or more of:
- Multiple files touched (especially shared services or grids)
- Permission / validation / state-machine logic changed
- Several bugs fixed in one changeset (suggests non-trivial pattern)
- Bug title suggests a reusable rule (not just cosmetic fix)
- Already Closed (diff is stable, safe to analyze)

Format:

```
🎯 Recommended for ado-bug-to-kb

1. Bug 102257 — "Movement disappears after state change"
   Why: touches both UI (5 files) and GraphQL CRUDMovements.cs;
        likely contains a reusable order/movement sync pattern.

2. Bug 103437 — "Viewer should not add/remove movements"
   Why: permission enforcement in Detail Panel;
        could generalize into a viewer-role guard pattern.
```

---

## What this skill should NOT do

- Run `tf diff` — that is `ado-bug-to-kb`'s job
- Write KB entries
- Fully analyze code patterns inside files

---

## Edge Cases

| Situation | Handling |
|---|---|
| No changesets match keyword | Report empty; suggest broader keyword or larger depth |
| All matches are build noise | Report "no human commits found" |
| Extracted ID returns 404 in ADO | Note as possible comment typo |
| One changeset references 5+ bugs | Show all rows; likely a good recommendation candidate |
| TFVC workspace not mapped | Tell user to run `tf workfold` and check mappings |

---

## Related Skills

- `ado-bug-to-kb` — deep-dive selected defects, run diffs, write KB
- `tfvc-change-review` — review pending/working-copy TFVC changes, not history

---

## Git Rules

Read-only by default. If the user asks to export results, write to the session workspace only (`~/.copilot/session-state/<id>/files/`). Stage only after review.
