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

## Shared Context

Use the same shared repo state file as `tfvc-defect-scan`:

- Path: `.copilot/defect-analysis-index.json`
- Purpose:
  - know which defects were already scanned
  - know which defects were already recommended by scan
  - know which defects were already analyzed into KB

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
- If a target defect already has `analysisStatus = analyzed`, mention that explicitly.
- Do not skip automatically; only skip if the user asked to avoid re-analysis.
- Prefer `kbRefs` with logical or repo-relative paths. Do not write machine-specific absolute paths.
- If `changesets` already exist in shared context, use them as the default fast path instead of re-fetching SCM from ADO or ALM.
- Default new write target to the project KB first. For Aura, treat `.github/kb/` as the Aura project KB, not a UI-only KB. Use global KB only for promoted patterns.
- When a project KB exists, read its local navigation before writing. For Aura, this means checking `Aura/.github/kb/README.md`, `Aura/.github/kb/project-map.md`, and `Aura/.github/kb/defects/index.md` so the new entry follows the current project-level IA instead of an outdated UI-only mental model.

---

## Decision Tree

```
Parse input into target list
        |
        v
Read shared context
      |
      v
Changesets already present?
  ├── Yes
  │     └── registry fast path → tf changeset / tf diff → analyze → write KB
  └── No
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

### Step 0 — Read shared context

1. Try to read `.copilot/defect-analysis-index.json` from repo root.
2. If missing, create an empty registry with `schemaVersion`, `lastUpdated`, `generatedBy`, `scopes`, and `defects`.
3. If present but older than the current schema, migrate in place before continuing.
4. For each requested defect, check whether it already appears in `defects`.
5. If present, reuse context such as:
   - `analysisStatus`
   - `recommendedBy`
   - `recommendedAt`
   - `lastSeenInScope`
   - `changesets`
      - `kbRefs`
6. Carry this context into the final report so the user can see whether this is a first analysis or a revisit.

### Step 0.5 — Fast path from shared context

If a requested defect already has usable `changesets` in shared context:

1. Use those changesets directly as the primary input.
2. Skip ADO/ALM SCM lookup unless the user explicitly asks to refresh defect metadata.
3. Keep the defect title from shared context if it exists.
4. Mark the run as `registry-fast-path` in the final report.

This is the preferred path for repeat analysis and scan-to-KB handoff.

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

First decision:
- If Step 0.5 found `changesets`, use them and continue to Step 4.
- Otherwise, resolve SCM from ADO or ALM as below.

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
1. Prefer `tf workfold <localFolder>` when the current repo is already open locally
2. Otherwise use `tf workfold` → find mapping for `$/UnifiedPIMS/Releases/Main`
3. Fall back to server-path TFVC commands only if no local mapping is available

### Step 4 — Filter and diff files

Analyze deeply: `.ts`, `.tsx`, `.js`, `.html`, `.less`, `.scss`, `.json`, `.cs`
Note briefly: `.csproj`, `.sln`
Skip: binary files, pure cosmetic style-only changes

Backend-specific rule:
1. Treat meaningful `.cs` diffs as first-class analyzable input, not as metadata.
2. When a defect is mainly backend, prefer extracting the reusable rule from service, controller, handler, import, reconciliation, report, model, or infrastructure logic.
3. Only fall back to a brief note when the `.cs` change is wiring-only, rename-only, or too project-specific to generalize.

Classify frontend vs backend before writing KB:
1. If the meaningful diff is mainly under `Aura/AspenUnified.AuraServices/UI` or `Aum/AspenUnified.AumServices/UI`, treat it as **frontend** by default.
2. If the meaningful diff is mainly under non-`UI` service, domain, import, reconciliation, report, or model code, treat it as **backend** by default.
3. If one defect spans both, either split the extracted patterns across both KB pages or explicitly say it is mixed and write only the reusable part to the right target page.
4. For Aura, both frontend and backend pages still live under the same project KB root: `Aura/.github/kb/`.

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
- Branching on the wrong business state or entity state
- Unit or value normalization missing before comparison or aggregation
- Deduplication missing before downstream fan-out or validation
- Shared contract or infrastructure rule enforced in the wrong layer
- i18n key inconsistency

For backend `.cs` diffs, prefer patterns such as:
- guard conditions on domain invariants
- normalization before compare or aggregate
- import or sync branching based on business state
- deduplication at the boundary before expansion
- moving validation to the owning service or handler layer instead of leaving it implicit

### Step 6 — Route to KB

| Fix type | Target KB file |
|---|---|
| Aura frontend defects | `Aura/.github/kb/defects/frontend-fix-patterns.md` |
| Aura backend defects | `Aura/.github/kb/defects/backend-fix-patterns.md` |
| AUM project defects | `Aum/.github/kb/defects/order-patterns.md` |
| Project-specific logic | `<project>/.github/kb/...` |
| Promoted Aurelia patterns | `~/.copilot/kb/aurelia-form-patterns.md` |
| Promoted ag-Grid patterns | `~/.copilot/kb/ag-grid-patterns.md` |
| Promoted TypeScript general patterns | `~/.copilot/kb/coding-patterns.md` |
| Non-project backend-only fix | Skip (mention it was backend) |

Prefer project KB (`.github/kb/`) by default. For Aura defects, route frontend/UI patterns to `defects/frontend-fix-patterns.md` and backend/domain-service patterns to `defects/backend-fix-patterns.md`, both under the Aura project KB root. Use the `...Services/UI` path as the primary frontend signal for Aura and AUM. Write to global `~/.copilot/kb/` only when the pattern is explicitly marked as promoted or is clearly cross-project and already de-coupled from project business terms.

Aura-specific routing notes:
- `Aura/.github/kb/` is now a project-level KB root, not a frontend-only folder.
- `Aura/.github/kb/defects/frontend-fix-patterns.md` and `Aura/.github/kb/defects/backend-fix-patterns.md` are the default landing pages for extracted defect rules.
- `Aura/AspenUnified.AuraServices/UI/.github/kb/` is a frozen historical sub-KB. Do not write new defect content there.
- `Aura/.github/kb/tasks/test-and-validate.md` is the maintained validation page. If a defect pattern depends on a specific route or manual verification path, link that task page instead of the deprecated `components/test-routes.md` page.

Before writing:
1. Read the project KB navigation pages when they exist so the new content matches the current IA.
2. Read target file.
3. Check for near-duplicate entries.
4. Append under the right `##` heading; create heading if missing.
5. Include trimmed diff excerpts as code blocks.

When the defect exposes a wider project map insight:
- Keep the fix pattern in the defect page.
- Mention adjacent module or task pages in the report as follow-up candidates.
- Do not automatically rewrite module, architecture, or troubleshooting pages in the default defect pass unless the user explicitly asks for broader KB backfill.

Promotion rule:
1. New analysis writes to project KB first.
2. Set `kbScope = project` in shared context.
3. Set `promotionCandidate = true` only if the pattern looks reusable across projects.
4. Promote to global KB in a separate curation step, not in the default write path.

### Step 7 — Report

```
✅ ado-bug-to-kb 完成: 3 defects / 4 changesets

📝 写入:
- Aura/.github/kb/defects/frontend-fix-patterns.md  → "Group row guard for workspace grids"
- Aura/.github/kb/defects/backend-fix-patterns.md   → "Normalize report plan values before actual comparison"

⏭ 跳过:
- Defect 105046  → 未记录 SCM changeset
- order-property.less  → 纯样式微调

ℹ 备注:
- 涵盖: ADO 105028、105019；ALM 1264939
- Changesets: C241638, C217415, C219270
- KB Root: Aura/.github/kb/
```

After writing KB, update shared context:

1. Set `lastUpdated`.
2. Append `ado-bug-to-kb` to `generatedBy` if missing.
3. For each analyzed defect, ensure `defects[<id>]` exists.
4. Update or set:
   - `id`
   - `scopeKey`
      - `kbScope` = `project` or `global`
      - `promotionCandidate` = `true` or `false`
   - `analysisStatus` = `analyzed`
   - `analyzedAt`
   - `changesets`
   - `kbRefs`
   - `sourceSystem` = `ADO`, `ALM`, `legacy-defect`, or `registry-fast-path`
   - `lastAnalyzedBy` = `ado-bug-to-kb`
5. Preserve earlier scan metadata such as `recommendedBy`, `recommendedAt`, and `lastSeenInScope`.

In the final report, add a short status note when relevant:
- `new analysis`
- `previously recommended by tfvc-defect-scan`
- `re-analysis of an already analyzed defect`
- `registry-fast-path`
- `project-kb-default`

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
| Only backend files changed | Deep-analyze `.cs` diffs; write KB whenever a reusable backend rule can be extracted |
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
