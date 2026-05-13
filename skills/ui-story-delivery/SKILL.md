---
name: ui-story-delivery
description: "Deliver frontend UI features from an ADO work item. TRIGGER when: user provides an ADO work item ID / number and says 'implement', 'help me implement', '帮我实现', '这个 Story 怎么做', 'UI 需求', 'new UI requirement', 'start implementation', '开始实现', 'ADO + 编号', '看一下这个需求', '帮我看这个需求'. Reads the User Story, its Parent, comments, and all linked items from ADO, locates any Figma link, captures the Figma design from Chrome DevTools, then delivers a KB-grounded implementation plan for user approval before writing any code. DO NOT TRIGGER for: backend-only tickets, build/infra tasks, or general code review requests."
argument-hint: "ADO work item ID (number), e.g. 12345"
user-invocable: true
---

# UI Story Delivery

Use this skill when the user has a new frontend UI requirement tied to an ADO work item and wants an implementation plan grounded in the actual design and acceptance criteria.

中文说明：当用户说"帮我实现 ADO 12345"或"这个 Story 怎么做"时，使用这个 skill。它会自动读取 User Story、Parent、讨论记录与所有关联链接，提取验收标准，找到 Figma 链接并截取设计页面，结合 KB 给出落地方案，经用户 approve 后再写代码。

## Goal

Produce a concrete, KB-grounded implementation plan that maps Acceptance Criteria to code entry points, referencing actual Figma design context. Present the plan for user approval **before** making any code changes.

## Decision Tree

```
User provides ADO ID?
├── Yes → Run full workflow
└── No  → Ask for ADO ID before proceeding
            ↓
Step 1: Read Work Item (expand: all)
            ↓
Step 2: Read Parent Work Item (if parent link exists)
            ↓
Step 3: Read Comments / Discussion
            ↓
Step 4: Locate Figma Link
  ├── Found → invoke figma-design-inspector (deep capture)
  └── Not found → Ask user if there is a Figma link; if none, continue without
            ↓
Step 5: Read KB (.github/kb)
            ↓
Step 6: Produce Implementation Plan
            ↓
Step 7: Wait for user approval → then implement code
```

## Procedure

### Step 1 — Read the Work Item

Call `ado-wit_get_work_item` with `expand: "all"` on the provided ADO ID.

Extract and note:
- `System.Title`
- `System.Description` (HTML — strip tags for reading; also scan raw HTML for `figma.com` hyperlinks)
- `Microsoft.VSTS.Common.AcceptanceCriteria` (HTML — strip tags; also scan raw HTML for `figma.com` hyperlinks)
- `System.Parent` (integer ID if present)
- `System.WorkItemType`
- All `relations` entries — scan `url` values for:
  - `figma.com` links
  - Parent/Child/Related work items

### Step 2 — Read the Parent Work Item

If `System.Parent` is populated:
- Call `ado-wit_get_work_item` with the parent ID and `expand: "all"`
- Extract Title, Description, AcceptanceCriteria
- Scan its Description and AC HTML for `figma.com` links
- Note parent work item type (Feature, Epic, etc.) for context framing
- If the parent also has a parent (Epic), read it too if it provides useful context

### Step 3 — Read Discussion / Comments

Call `ado-wit_list_work_item_comments` on the User Story ID.
- Read all comments to catch any design decisions, scope clarifications, or updated instructions not captured in Description/AC
- Note any mentions of Figma URLs, API contracts, or changed requirements in comments

### Step 4 — Locate and Capture the Figma Design

**Figma link search priority (in order):**
1. `<a href>` tags inside `System.Description` HTML containing `figma.com`
2. `<a href>` tags inside `AcceptanceCriteria` HTML containing `figma.com`
3. Hyperlink relations on the User Story whose URL contains `figma.com`
4. Hyperlink relations on the Parent whose URL contains `figma.com`
5. Figma URLs mentioned in Discussion comments

**If a Figma link is found:**
- Invoke `figma-design-inspector` with the discovered URL
- Embed its structured findings into the Design Context section of the plan

**If no Figma link is found:**
- Ask the user: "I couldn't find a Figma link in the work item. Do you have one, or should I proceed based on the AC only?"
- If user provides a URL → invoke `figma-design-inspector`
- If user says no Figma → continue without design context; note it in output

**Extract from Figma (via figma-design-inspector output):**
- Component names and hierarchy
- Labels, placeholder text, button text (→ i18n key candidates)
- Interaction states: default / hover / focus / error / empty / loading / disabled
- Layout structure and grouping
- Any comments or properties that clarify design intent

### Step 5 — Read the KB

Check whether the current workspace has a KB:
- Try `.github/kb/README.md` — if it exists, read it as the index
- Read `.github/kb/common-overview.md` — workspace shape, build commands, entry points
- Read the relevant project page under `.github/kb/projects/`
- If a feature-specific or component-specific page exists for the requirement area, read it too (e.g., `common-data-grid.md` for grid changes)

If no KB exists in the current workspace, skip this step and note it in the output.

### Step 6 — Produce the Implementation Plan

Output the plan using the structure below.

**⛔ Do NOT write any code at this step.** Present the plan and wait for explicit user approval.

### Step 7 — Implement After Approval

Only after the user says "go", "start", "implement", "开始", "approve", or similar:
- Work through the file list in implementation sequence
- Make targeted, surgical edits
- After all changes, summarize what was modified

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

**Discussion highlights (if any):**
> …

### ✅ Acceptance Criteria → Implementation Mapping

For each acceptance criterion, map it to the concrete code entry point:

| # | Acceptance Criterion | Entry Point | Notes |
|---|---|---|---|
| 1 | … | `path/to/file.ts` | … |

### 🎨 Design Context (from Figma)

- **Figma URL:** …
- **Components identified:** list from inspector output
- **Interaction states:** states visible in design
- **Key labels / strings:** list — candidates for i18n entries
- **Layout notes:** brief visual structure description
- **Design comments / properties:** concise notes from inspector

If Figma was not captured: `⚠️ Design not captured — implementation based on AC only.`

### 🏗️ Implementation Plan

**App / module entry point:** state which app or module owns this feature

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

Open questions for product owner or designer before implementation starts.

---

**👉 Awaiting your approval to start implementation.**

---

## Rules

- **Never guess API response shapes** — if the contract is not in this workspace, mark it as a cross-repo dependency.
- **i18n first** — if the design has visible text strings, list the i18n keys before listing component files.
- **No code edits until approved** — present the plan and wait for explicit user confirmation.
- **Strip HTML tags** from `System.Description` and `AcceptanceCriteria` when displaying, but scan raw HTML for Figma links.
- **If ADO fields are empty**, note which fields are missing and proceed with available data.
- **KB is optional** — if no `.github/kb` exists in the current workspace, proceed without it.
- **Prefer logged-in Figma pages** — avoid opening a fresh unauthenticated page when an existing tab can be reused.
- **Authentication-aware capture** — if login wall appears, pause capture and resume only after user login plus explicit confirm.
- **Read discussion** — always check work item comments; they often contain updated scope, design decisions, or Figma links added after the story was written.

## Companion Tools

| Tool | Purpose |
|---|---|
| `ado-wit_get_work_item` | Read ADO Work Item (use `expand: "all"`) |
| `ado-wit_list_work_item_comments` | Read Discussion / comments on the work item |
| `figma-design-inspector` | Deep Figma exploration and structured design findings |
| `io_github_chromedevtools_chrome-devtools-mcp-list_pages` | Find existing Figma tabs |
| `io_github_chromedevtools_chrome-devtools-mcp-take_snapshot` | Capture Figma a11y tree |
| `io_github_chromedevtools_chrome-devtools-mcp-take_screenshot` | Capture Figma visual layout |
