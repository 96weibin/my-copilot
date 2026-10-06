---
name: tfvc-team-daily-report
description: 'Generate, inspect, configure, or schedule the Team Plum TFVC daily changeset report. Use when the user asks for 每日 TF commit, TFVC 日报, Team Plum commit report, AUM/AURA changes today, Capulin backend changes, 查看今天代码提交, 补跑日报, or schedule the report at 10 AM.'
argument-hint: 'Describe whether to run, inspect, configure, troubleshoot, or schedule the Team Plum TFVC report'
user-invocable: true
---

# TFVC Team Daily Report

Use the deterministic scripts in this skill to report AUM/AURA TFVC changesets relevant to Team Plum.

## Sources

- Configuration: `C:/Users/ZHAOWE/.copilot/agile/projects/plum/tfvc-daily-report.json`
- Team roster: `C:/Users/ZHAOWE/.copilot/agile/projects/plum/agile-team-roster.md`
- Detailed Plum identities: `C:/Users/ZHAOWE/.copilot/agile/projects/plum/profile.md`
- Runner: `scripts/invoke-tfvc-team-daily-report.ps1`
- Scheduler: `scripts/register-tfvc-team-daily-report-task.ps1`

## Classification Contract

1. A changeset touching configured AUM or AURA paths is project-related.
2. Plum identity or verified Plum Area Path is `Plum direct`.
3. Capulin identity or verified Capulin Area Path is included in Team Plum scope as `Capulin backend counterpart`.
4. Other roster/Area matches are shown as other Agile Teams.
5. Path-only matches are team-unconfirmed.
6. `frontend`, `backend`, and `mixed` describe changed paths only. Never infer Capulin solely from backend code.
7. Preserve conflicting Area and identity evidence instead of silently choosing one team.

## Run

Dry run without ADO or checkpoint writes:

```powershell
./scripts/invoke-tfvc-team-daily-report.ps1 -DryRun -SkipAdo
```

Normal run:

```powershell
./scripts/invoke-tfvc-team-daily-report.ps1
```

The first successful run scans from 10:00 on the previous business day. Later runs scan after the last successful changeset ID. A complete success, including no new changesets, exits `0`; any TFVC, ADO, parse, or write failure exits nonzero and does not advance the checkpoint.

## ADO Authentication

The runner reads an ADO Work Items Read PAT from the environment variable configured by `patEnvironmentVariable` (default: `AZURE_DEVOPS_PAT`). This matches the ADO MCP configuration in VS Code. Never request or paste the PAT into chat, source files, command arguments, or logs.

For an interactive agent, VS Code passes `${env:AZURE_DEVOPS_PAT}` to the ADO MCP server. The runner checks Process, User, then Machine scope. For Task Scheduler, the variable must be persisted in User or Machine scope; a variable available only inside a particular VS Code process is insufficient. Preflight checks presence only and never prints the value. If a PAT appears in chat, logs, or command history, do not use it; revoke it and create a replacement.

## Schedule

After a successful normal run, and after confirming `AZURE_DEVOPS_PAT` is available to the scheduled Windows user, register the configured weekday 10:00 task:

```powershell
./scripts/register-tfvc-team-daily-report-task.ps1
```

Use `-Force` only when the user approves replacing an existing task. Query the task after registration and use `schtasks /Run` for an end-to-end check.

## Maintenance

- Update reviewed people/team facts in the roster/profile first, then synchronize `identityOverrides` when email, CORP account, or aliases are known.
- Do not mark Capulin Area Path verified until observed from ADO.
- Do not manually advance or reset state without explaining the replay/skip impact and receiving confirmation.
- Runtime reports, logs, and state are local ignored artifacts. Do not stage them.