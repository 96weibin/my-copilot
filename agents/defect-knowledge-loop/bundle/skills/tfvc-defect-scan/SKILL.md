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

This skill is read-only with respect to product code and KB content.

This skill **does update shared analysis context** in a lightweight repo state file so later `ado-bug-to-kb` runs know which defects were already scanned or recommended.

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
| **Start changeset** | optional — blank means start from latest |
| **History depth** | asked at runtime (choices: 50 / 100 / 200 / custom number or date) |

If scope is omitted, infer from the current working directory and resolve the owning TFVC workspace with `tf workfold <localFolder>`.

## Shared Context

Use one shared repo state file for both `tfvc-defect-scan` and `ado-bug-to-kb`:

- Path: `.copilot/defect-analysis-index.json`
- Purpose:
  - remember which defects were already seen in scans
  - remember which defects were already recommended for deep dive
  - remember which defects were already analyzed into KB
  - remember the last scan anchor per scope

Suggested shape:

```json
{
  "schemaVersion": 2,
  "lastUpdated": "",
  "generatedBy": [],
  "scopes": {},
  "defects": {}
}
```

Rules:
- Read this file near the start of every run if it exists.
- Create it if missing.
- Treat it as shared state, not as user-facing KB.
- Keep updates minimal and append-only in spirit: prefer filling missing fields or refreshing timestamps over rewriting history.
- Use stable enums for `analysisStatus`: `new`, `recommended`, `analyzed`.
- Store shareable KB references only. Do not write user-machine absolute paths into the registry.
- Prefer repo-relative project-KB paths such as `Aura/.github/kb/defects/frontend-fix-patterns.md` or `Aura/.github/kb/defects/backend-fix-patterns.md`.
- Track KB intent separately from KB promotion status.
- When a project already has a KB root, treat scan recommendations as inputs into that project KB structure rather than as standalone defect notes.

---

## Procedure

### Step 0 — Read shared context

1. Try to read `.copilot/defect-analysis-index.json` from repo root.
2. If missing, create an empty registry with `schemaVersion`, `lastUpdated`, `generatedBy`, `scopes`, and `defects`.
3. If present but older than the current schema, migrate in place before continuing.
4. Resolve the current logical scope key, for example `Psc/Aura`.
5. If a scope entry already exists, use it to understand:
   - the previous scan anchor
   - defects already recommended
   - defects already analyzed by `ado-bug-to-kb`
6. Do not suppress results solely because a defect was seen before, but mark it as already analyzed when relevant.

### Step 1 — Resolve workspace and scope

1. Start from the current local folder or the user-provided scope folder.
2. If the current folder is already inside the intended module, run `tf workfold <localFolder>` first.
  - Prefer this over plain `tf workfold` because a user may have multiple TFVC workspaces.
  - Example: `tf workfold D:\Source\Releases\Main\Psc\Aura`
3. If `tf workfold <localFolder>` resolves a workspace and server path, use that workspace's local path directly.
  - Example: `$/UnifiedPIMS/Releases/Main/Psc/Aura -> D:\Source\Releases\Main\Psc\Aura`
4. Only if the local folder is not mapped, run plain `tf workfold` and inspect candidate mappings for `$/UnifiedPIMS/Releases/Main`.
5. If a mapped local root is found, combine it with the scope folder and confirm it exists.
6. If no local mapping can be resolved, fall back to TFVC server path mode in Step 4.

Important:
- VS Code workspace folders and TFVC workspaces are different concepts.
- The correct mapping is stored in the TFVC workspace, not in the VS Code `.code-workspace` file.
- A machine may have multiple TFVC workspaces, so do not assume the first `tf workfold` result is the right one.

### Step 2 — Confirm start changeset with user

Before running history, **always ask the user** where to start scanning:

```
ask_user:
  question: "从哪个 changeset 开始往前扫描？留空表示从最新一条开始。"
  allow_freeform: true   # user can type a changeset id like "241717"
```

Rules:
- If the user leaves it blank, scan from the latest changeset.
- If the user provides a changeset id, treat it as the inclusive starting point.
- Validate that the value is numeric before using it.
- If the provided changeset does not exist in the target scope, warn the user and offer to continue from the nearest available newer row or restart from latest.

Why:
- Large modules may have years of history.
- KB work is usually done from near to far, so the scan needs a stable starting anchor instead of always starting at "now".

### Step 3 — Confirm scan depth with user

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

### Step 4 — Pull recent history

Preferred local mode: run inside the resolved scope folder:

```cmd
cd <ScopeFolder> && tf history . /recursive /noprompt /format:brief /stopafter:<depth>
```

If local mapping is unavailable, use server path mode instead:

```cmd
tf history $/UnifiedPIMS/Releases/Main/Psc/<Scope> /recursive /noprompt /format:brief /stopafter:<depth> /collection:http://hqtfs03:8080/tfs/defaultcollection
```

When local mode works, prefer it because later file-level follow-up is easier. When it does not, server path mode is an acceptable fallback for read-only scanning.

If the user specified a start changeset, use it as the anchor and scan older history from there.

Recommended flow:
- First fetch enough rows to include the requested start changeset.
- Trim all rows newer than the start changeset.
- Then take the next `<depth>` rows from that point going backward in time.

Practical guidance:
- For a numeric start changeset, use `/stopafter:<safeUpperBound>` first, such as 500 or 1000 if needed.
- After fetching, filter client-side so the first kept row is the requested changeset id.
- If the requested changeset is not found in the fetched window, tell the user and offer a larger window.

`/format:brief` is essential — never use `detailed` at scan time.

### Step 5 — Filter candidate changesets

Keep rows whose `Comment` column contains the keyword (case-insensitive).

Drop:
- Author is `atbuild.psb`
- Comment is only a version bump
- Comment is only `***NO_CI***`
- Rollback or merge rows (unless the keyword still appears in a relevant way)

### Step 6 — Expand full changeset metadata

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

Also classify likely routing for later KB handoff:
- If the meaningful changed files are mainly under `Aura/AspenUnified.AuraServices/UI` or `Aum/AspenUnified.AumServices/UI`, treat the candidate as likely `frontend`.
- If the meaningful changed files are mainly under non-`UI` service, domain, import, reconciliation, report, or model code, treat the candidate as likely `backend`.
- For Aura, both routing outcomes still belong to the Aura project KB root under `Aura/.github/kb/`.
- For Aura, remember that `Aura/AspenUnified.AuraServices/UI/.github/kb/` is historical only; scan handoff should point to the project KB under `Aura/.github/kb/`.

### Step 7 — Extract ADO bug IDs

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

### Step 8 — Query ADO in one batch call

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

### Step 9 — Compose response

#### Section 1: Summary table

Group by changeset. Use status icons:
- 🟢 Active
- 🟡 Resolved
- ✅ Closed
- 🔴 New

Add one more context column when available:
- `Analysis` → `new`, `recommended`, or `analyzed`

| Changeset | Bug ID | Title | State | Assigned | Priority | Analysis |
|---|---|---|---|---|---|---|

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
  Route: frontend

2. Bug 103437 — "Viewer should not add/remove movements"
   Why: permission enforcement in Detail Panel;
        could generalize into a viewer-role guard pattern.
  Route: backend
```

When useful, include `Route: frontend` or `Route: backend` so the later `ado-bug-to-kb` run can land directly in the right Aura project KB page.

When the project KB target is obvious, prefer adding a target hint in the recommendation, for example:
- `Target: Aura/.github/kb/defects/frontend-fix-patterns.md`
- `Target: Aura/.github/kb/defects/backend-fix-patterns.md`

For Aura, do not recommend deprecated validation pages. If the likely follow-up requires route or manual validation context, mention `Aura/.github/kb/tasks/test-and-validate.md` instead of `components/test-routes.md`.

After composing the response, update shared context:

1. Set `lastUpdated`.
2. Append `tfvc-defect-scan` to `generatedBy` if missing.
3. Update `scopes[<scopeKey>]` with:
  - `scopeKey`
  - `lastScanStartChangeset`
  - `lastScanDepth`
  - `lastScanAt`
  - `lastRecommendedDefects`
4. For each defect found in this scan, ensure `defects[<id>]` exists.
5. For each defect entry, prefer stable fields such as:
  - `id`
  - `scopeKey`
  - `analysisStatus`
  - `changesets`
  - `kbRefs`
  - `kbScope`
  - `promotionCandidate`
6. For recommended defects, set or refresh fields such as:
  - `lastSeenInScope`
  - `lastSeenChangeset`
  - `recommendedBy`
  - `recommendedAt`
  - `analysisStatus` = `recommended` unless already `analyzed`
  - `kbScope` = `project`
  - `promotionCandidate` = `false` by default unless the scan clearly found a cross-project pattern

Do not overwrite prior analysis details written by `ado-bug-to-kb`.

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
