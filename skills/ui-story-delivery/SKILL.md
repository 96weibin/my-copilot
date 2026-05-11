---
name: ui-story-delivery
description: "Deliver frontend UI features from an ADO work item. TRIGGER when: user provides an ADO work item ID / number and says 'implement', 'help me implement', '帮我实现', '这个 Story 怎么做', 'UI 需求', 'new UI requirement', 'start implementation', '开始实现', 'ADO + 编号', '看一下这个需求', '帮我看这个需求'. Reads the User Story and its Parent from ADO, extracts Description and Acceptance Criteria, locates any Figma link, captures the Figma design from Chrome DevTools, then delivers a KB-grounded implementation plan. DO NOT TRIGGER for: backend-only tickets, build/infra tasks, or general code review requests."
argument-hint: "ADO work item ID (number), e.g. 12345"
user-invocable: true
---

# UI Story Delivery

Use this skill when the user has a new frontend UI requirement tied to an ADO work item and wants an implementation plan grounded in the actual design and acceptance criteria.

中文说明：当用户说"帮我实现 ADO 12345"或"这个 Story 怎么做"时，使用这个 skill。它会自动读取 User Story 与 Parent，提取验收标准，找到 Figma 链接并截取设计页面，最后结合当前工作区的 KB 给出落地方案。

## Goal

Produce a concrete, KB-grounded implementation plan that maps Acceptance Criteria to code entry points, referencing actual Figma design context captured from Chrome.

## Decision Tree

```
User provides ADO ID?
├── Yes → Run full workflow
└── No  → Ask for ADO ID before proceeding
            ↓
Read Work Item (expand: all)
            ↓
Extract: Title, Description, Acceptance Criteria, Figma links, Parent ID
            ↓
Parent ID found?
├── Yes → Read Parent Work Item → extract its Description, AC, Figma links
└── No  → Continue without parent context
            ↓
Figma link found (from WI or Parent)?
├── Yes → Ask user quick mode or deep mode
│         ├── Quick mode → list pages + snapshot + screenshot
│         └── Deep mode  → invoke figma-design-inspector and embed findings
└── No  → Ask user for Figma URL or page name (or continue without if user skips)
            ↓
KB found in current workspace (.github/kb)?
├── Yes → Read README.md + common-overview.md + relevant project page
└── No  → Proceed with codebase exploration only
            ↓
Produce Implementation Plan
```

## Procedure

### Step 1 — Read the Work Item

Call `mcp_ado_wit_get_work_item` with `expand: "all"` on the provided ADO ID.

Extract and note these fields:
- `System.Title`
- `System.Description` (HTML — strip tags for reading)
- `Microsoft.VSTS.Common.AcceptanceCriteria` (HTML — strip tags)
- `System.Parent` (integer ID if present)
- `System.WorkItemType`
- All `relations` entries — scan `url` values for `figma.com` links

### Step 2 — Read the Parent Work Item

If `System.Parent` is populated:
- Call `mcp_ado_wit_get_work_item` with the parent ID and `expand: "all"`
- Extract Title, Description, AcceptanceCriteria, and any Figma hyperlinks from relations
- Note parent work item type (Feature, Epic, etc.) for context framing

### Step 3 — Locate and Capture the Figma Design

**Link priority:**
1. Hyperlink relations on the User Story whose URL contains `figma.com`
2. Hyperlink relations on the Parent whose URL contains `figma.com`
3. If none found: ask the user for the Figma URL, or ask them to navigate Chrome to the right frame first

**Mode selection:**
1. Ask the user to choose mode:
    - `Quick mode` — fast capture for straightforward stories
    - `Deep mode` — call `figma-design-inspector` for detailed interactive exploration
2. If user does not specify, default to `Quick mode`.

**Quick mode capture sequence:**
1. Call `mcp_io_github_chr_list_pages` — identify any open Figma tab
2. Prefer selecting an already open and logged-in matching Figma tab
3. If no match exists, ask user to confirm the target URL before navigation
4. If login wall appears (SSO/password/sign in), ask user to complete login in browser
5. After login, show a `vscode_askQuestions` confirm prompt and continue only if user selects `已完成登录，继续`
6. If user selects `还没完成`, stop and wait
7. Call `mcp_io_github_chr_take_snapshot` — preferred; reads accessibility tree with component names, labels, states
8. Call `mcp_io_github_chr_take_screenshot` — supplement if visual layout context is needed

**Deep mode capture sequence:**
1. Invoke `figma-design-inspector` with the Figma URL or frame name
2. Reuse its structured findings directly in this skill's Design Context section
3. If deep mode fails, fall back to Quick mode and note the fallback in output

**Extract from Figma:**
- Component names and hierarchy from the a11y snapshot
- Labels, placeholder text, error messages, button text (→ will become i18n keys)
- Interaction states visible: default / hover / focus / error / empty / loading / disabled
- Layout structure and grouping from the screenshot

### Step 4 — Read the KB

Check whether the current workspace has a KB:
- Try `.github/kb/README.md` — if it exists, read it as the index
- Read `.github/kb/common-overview.md` — workspace shape, build commands, entry points
- Read the relevant project page under `.github/kb/projects/`
- If a feature-specific page exists for the requirement area, read it too

If no KB exists in the current workspace, skip this step and note it in the output.

### Step 5 — Produce the Implementation Plan

Output the plan using the structure below. **Do not auto-edit code** unless the user explicitly confirms they want code changes after reviewing the plan.

---

## Output Structure

### 📋 Requirement Summary

| Field | Value |
|---|---|
| ADO ID | #XXXX |
| Title | … |
| Type | User Story / Bug / Task |
| Parent | #YYYY — Parent Title |

**Description (condensed):**
> …

### ✅ Acceptance Criteria → Implementation Mapping

For each acceptance criterion, map it to the concrete code entry point:

| # | Acceptance Criterion | Entry Point | Notes |
|---|---|---|---|
| 1 | … | `path/to/file.ts` | … |

### 🎨 Design Context (from Figma)

- **Capture mode:** Quick or Deep
- **Components identified:** list from snapshot/inspector output
- **Interaction states:** states visible in design
- **Key labels / strings:** list — candidates for i18n entries
- **Layout notes:** brief visual structure description
- **Comments/Properties insights (if inspected):** concise notes from right panel

If Figma was not captured: `⚠️ Design not captured — implementation based on AC only.`

### 🏗️ Implementation Entry Points

**App entry (if applicable):** state which app or module owns this feature

List files to create or modify, ordered by implementation sequence:

1. `path/to/component.ts` — what to add / change
2. `path/to/component.html` — template changes
3. `locales/en/<file>.json` — i18n keys to add: `key.name`

### ⚠️ Risks & Dependencies

- **Cross-repo API:** note if the backing API is not visible in this workspace
- **Breaking changes:** shared components or services affected
- **Missing info:** ambiguous AC or design contradictions

### 🧪 Test Guidance

Key scenarios to verify, derived directly from the AC:

- Scenario 1: …
- Scenario 2: …

### ❓ Pending Confirmations

Open questions for product owner or designer before implementation finalizes.

---

## Rules

- **Never guess API response shapes** — if the contract is not in this workspace, mark it as a cross-repo dependency.
- **i18n first** — if the design has visible text strings, list the i18n keys before listing component files.
- **No code edits by default** — deliver the plan and wait for user confirmation.
- **Strip HTML tags** from `System.Description` and `AcceptanceCriteria` when displaying.
- **If ADO fields are empty**, note which fields are missing and proceed with available data.
- **KB is optional** — if no `.github/kb` exists in the current workspace, proceed without it.
- **Prefer logged-in Figma pages** — avoid opening a fresh unauthenticated page when an existing tab can be reused.
- **Authentication-aware capture** — if login wall appears, pause capture and resume only after user login plus explicit confirm.

## Companion Tools

| Tool | Purpose |
|---|---|
| `mcp_ado_wit_get_work_item` | Read ADO Work Item (use `expand: "all"`) |
| `mcp_io_github_chr_list_pages` | List open Chrome tabs to find Figma |
| `mcp_io_github_chr_take_snapshot` | Capture Figma a11y tree (preferred) |
| `mcp_io_github_chr_take_screenshot` | Capture Figma visual layout |
| `figma-design-inspector` | Deep Figma exploration and structured design findings |
