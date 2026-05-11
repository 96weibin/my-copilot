---
name: figma-design-inspector
description: "Inspect Figma designs via Chrome DevTools MCP. TRIGGER when: user says '检查 Figma 设计', '提取这个设计细节', '查看这个 frame', '看 comments', '看 properties', '帮我分析 Figma', or asks to open a specific Figma URL/frame. Confirms target URL first, prefers reusing an already logged-in Figma tab, detects login walls, then captures snapshot/screenshot and outputs structured design findings."
argument-hint: "Figma URL or frame name, e.g. https://www.figma.com/design/... or 'Case validation panel diagnostics tab'"
user-invocable: true
---

# Figma Design Inspector

Use this skill when the user wants interactive inspection of Figma designs (design page or prototype), including Comments and Properties context.

中文说明：当用户说“检查 Figma 设计”、“看看 comments/properties”、“提取这个 frame 的细节”时，使用这个 skill。它会先确认 URL，再复用已登录页，避免无痕打开后反复登录。

## Goal

Produce a structured design analysis grounded in the actual Figma page context, including visible components, interaction states, key labels, and optional comments-derived design rationale.

## Decision Tree

```
User provided URL or frame name?
├── URL given → Confirm URL with user
└── Frame name only → Ask user for URL (or pick from open Figma tabs)
            ↓
List Chrome pages and find matching Figma tab
            ↓
Matching logged-in tab found?
├── Yes → Select existing tab
└── No  → Open/navigate to confirmed URL
            ↓
Login wall detected (SSO/password/sign in)?
├── Yes → Ask user to complete login in browser, then show confirm prompt
└── No  → Continue inspection
            ↓
Capture snapshot + screenshot
            ↓
Need comments/properties details?
├── Yes → Navigate panel and extract visible items
└── No  → Skip panel deep read
            ↓
Output structured design findings
```

## Procedure

### Step 1 - Confirm Target URL

1. Read the argument and determine whether it is a full Figma URL.
2. If not a URL, ask user for the target URL (or ask which open Figma tab to use).
3. Before using Chrome tools, confirm the exact URL with the user.

### Step 2 - Reuse Existing Logged-in Tab First

1. Call `mcp_io_github_chr_list_pages`.
2. If a matching Figma URL is already open, call `mcp_io_github_chr_select_page` and continue.
3. If not open, navigate/open the confirmed URL in Chrome context.

### Step 3 - Handle Authentication Branch

Detect login wall indicators from page content/snapshot, such as:
- `Sign in`
- `Continue with SSO`
- `Password`
- `Enter your email`

If login wall is detected:
1. Tell user to finish authentication directly in browser.
2. Do not treat login screen as design content.
3. Use `vscode_askQuestions` to show a confirm prompt, e.g.:
    - header: `figma_login_done`
    - question: `登录完成后请点击确认，我将继续抓取设计页面。`
    - options: `已完成登录，继续` / `还没完成`
4. Only continue capture after user selects `已完成登录，继续`.
5. If user selects `还没完成`, stop and wait; do not continue capture.

### Step 4 - Capture Design Context

1. Call `mcp_io_github_chr_take_snapshot` to capture accessibility tree.
2. Call `mcp_io_github_chr_take_screenshot` for visual layout.
3. If needed, interactively click/expand tabs or accordions to reveal hidden sections.

### Step 5 - Optional Comments/Properties Inspection

If user asks for comments/properties:
1. Navigate to Comments and/or Properties panel.
2. Capture visible items (author, topic, labels, control names).
3. Summarize only what is visible; do not infer hidden values.

### Step 6 - Output Structured Findings

Use the format below.

## Output Structure

### Design Target

- URL: ...
- Page type: Design / Prototype
- Focus frame: ...

### Visual Structure

- Major regions/components: ...
- Section hierarchy: ...
- Layout notes: ...

### Interaction States

- Visible states: default / selected / expanded / warning / disabled / etc.
- Click flow observations: ...

### Text and i18n Candidates

- Labels/buttons/messages visible in UI: ...
- Suggested i18n key groups: ...

### Comments and Properties (if requested)

- Comments observed: ...
- Properties observed: ...
- Design rationale hints: ...

### Implementation Hints

- Recommended component boundaries: ...
- Data contracts implied by UI: ...
- Risks/unknowns to confirm: ...

## Rules

- Prefer existing logged-in Figma tab before opening a new one.
- Always confirm URL before navigation.
- If authentication is required, pause for user login and require explicit confirm before continuing.
- Do not invent hidden design details not visible in snapshot/screenshot.
- Keep extracted strings faithful to visible UI text.

## Companion Tools

| Tool | Purpose |
|---|---|
| `mcp_io_github_chr_list_pages` | Find existing Figma tabs |
| `mcp_io_github_chr_select_page` | Reuse existing logged-in tab |
| `mcp_io_github_chr_take_snapshot` | Capture semantic structure |
| `mcp_io_github_chr_take_screenshot` | Capture visual context |
| `mcp_io_github_chr_click` | Expand sections / switch panels |
| `vscode_askQuestions` | Confirm URL with user before navigation |
