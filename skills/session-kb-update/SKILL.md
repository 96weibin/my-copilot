---
name: session-kb-update
description: "Extract and persist learnings from the current session into the KB. TRIGGER when: user says '我们完成了', '收工', '今天就到这里', '结束了', 'session 结束', 'wrap up', 'we are done', '写入kb', '更新kb', '整理一下这次学到的', or signals the end of a development session. DO NOT TRIGGER for mid-session questions or when the user is still actively implementing."
argument-hint: "Optional focus area, e.g. 'ag-grid patterns' or 'EDS tokens'"
user-invocable: true
---

# Session KB Update

At the end of a development session, extract reusable patterns, bug fixes, and design decisions, then persist them into the appropriate KB pages.

中文说明：session 结束时自动提炼知识写入 KB。支持两层：全局通用技术知识 (`~/.copilot/kb/`) + 项目专属知识 (`.github/kb/`)。

## Goal

把一次性的解决过程变成可复用的知识，供未来 session 直接调用，避免重复踩坑。

## Decision Tree

```
Session ending detected?
        ↓
Read session artifacts (plan.md, SQL todos, checkpoints)
        ↓
Identify learnable content
        ↓
Classify each item:
  ├── Generic tech pattern (ag-Grid, Aurelia, TypeScript)?
  │     → Write to ~/.copilot/kb/ (global, cross-project)
  └── Project-specific pattern (EDS tokens, project routes)?
        ↓ Does project have .github/kb/?
        ├── Yes → Write to .github/kb/
        └── No  → Write to ~/.copilot/kb/ with project tag
        ↓
Report what was written (or skipped)
```

## Procedure

### Step 1 — Gather Session Context

Read in order:
1. Session `plan.md` — what problem was solved
2. SQL todos — completed tasks and their descriptions
3. Checkpoint index at `checkpoints/index.md` — titles of prior work
4. Any `files/` artifacts noted in prior checkpoints

Do **not** re-read full source files unless needed to extract a specific pattern.

### Step 2 — Discover KB Structure

1. Check if `.github/kb/` exists in the current project root.
2. If yes, read `.github/kb/README.md` to understand available KB pages and existing sections.
3. Also check `~/.copilot/kb/` for existing global KB pages.

### Step 3 — Classify and Route Content

| Content Type | Global (`~/.copilot/kb/`) | Project (`.github/kb/`) |
|---|---|---|
| ag-Grid patterns, pitfalls | `ag-grid-patterns.md` | `pages/common-data-grid.md` (if exists) |
| Design system tokens (EDS, MUI) | — | `projects/<project>.md` |
| Aurelia / framework patterns | `aurelia-patterns.md` | `projects/aura.md` (if Aura) |
| TypeScript / general coding tricks | `coding-patterns.md` | — |
| Project-specific API / data model | — | `projects/<project>.md` |
| i18n conventions | — | `projects/<project>.md` |

**Priority**: prefer project KB when available; fall back to global.

Skip if:
- Already documented in the target KB
- One-off business logic (not reusable)
- Temporary workaround

### Step 4 — Write to KB (Append-only Rules)

- **Always append**; never delete or rewrite existing correct content
- Place under most specific matching `##` section; create new section if no match
- Update `Last Updated` date in metadata
- Concise, factual language — include code examples when applicable
- Keep each entry self-contained (understandable without session context)

### Step 5 — Report

```
✅ KB Updated:
- ~/.copilot/kb/ag-grid-patterns.md → added "cellRenderer + valueFormatter conflict"
- .github/kb/projects/aura.md → added EDS Badge token table

⏭ Skipped:
- [item] — already documented / not reusable
```

If nothing new, say so clearly — no forced updates.

## Rules

- Do **not** ask for permission — write and report afterward
- **Git: write files + `git add` only. Do NOT commit or push.** Tell the user what was staged and let them review before committing.
- Do **not** write business-domain logic as general patterns— write and report afterward
- Do **not** write business-domain logic as general patterns
- If unsure → err on the side of **not** writing (quality over quantity)
- Always check target KB page first to avoid duplicates
- Prefer project KB when project has one

## Global KB Files (`~/.copilot/kb/`)

| File | What goes here |
|---|---|
| `ag-grid-patterns.md` | Column defs, renderer tricks, export pitfalls |
| `aurelia-patterns.md` | Binding, component, lifecycle patterns |
| `coding-patterns.md` | General TypeScript/JS patterns and gotchas |
| `eds-tokens.md` | Shared EDS/Shoelace token reference |

Create the file if it doesn't exist — include a `# Title` and `## Metadata` header.

## Project KB Files (`.github/kb/`)

Discover dynamically from `.github/kb/` in the current project.
Common Aura project files:
- `pages/common-data-grid.md`
- `pages/common-form-controls.md`
- `projects/aura.md`
- `projects/common.md`
