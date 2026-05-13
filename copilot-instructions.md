# Global Copilot Instructions

These rules apply across all projects and sessions.

## Git Workflow (IMPORTANT)

**For the global `~/.copilot` repository (`skills/`, `kb/`, `agents/`):**

1. Write the file(s)
2. Run `git add <files>` to stage
3. **STOP — do NOT commit or push**
4. Tell the user what was staged and ask them to review with `git diff --staged` before committing

**For project repositories (`.github/kb/`, source code, etc.):**

Same rule — write files and stage with `git add`, then stop.  
Only commit when the user explicitly says "commit", "提交", or equivalent.  
Only push when the user explicitly says "push", "推送", or equivalent.

> Rationale: The user wants to review all changes before they land in git history.

## Language

- Respond in the user's language (Chinese or English based on the conversation)
- KB files: use the language established in the target file

## Skills Location

- Global skills: `C:\Users\ZHAOWE\.copilot\skills\`
- Global KB: `C:\Users\ZHAOWE\.copilot\kb\`
- Global agents: `C:\Users\ZHAOWE\.copilot\agents\`
