---
name: agile-timeline-context
description: "Read and summarize ADO PI and iteration timelines for ATL work, then refresh a local reviewed snapshot. Use when the user asks 当前 PI, 当前 iteration, iteration 从哪天到哪天, PI 日期, planning dates, remaining days, timeline, milestone, or 项目现在处于什么阶段."
argument-hint: "可指定项目、Team、PI 或 Iteration；默认使用 Team Plum。"
user-invocable: true
---

# Agile Timeline Context

Read Team and Iteration configuration from Azure DevOps, determine the current delivery period, and maintain a transparent local snapshot for continuity.

## Default project

Read `C:/Users/ZHAOWE/.copilot/agile/projects/plum/profile.md` first. Unless the user specifies another scope, use:

- Organization: `aspentechnology`
- Project: `AspenTech SAFe`
- Team: `Plum`
- Time zone for presentation: `Asia/Shanghai`
- Snapshot: `C:/Users/ZHAOWE/.copilot/agile/projects/plum/timeline.json`

## Source policy

1. ADO Team/Iteration configuration is the authoritative source for configured start and finish dates.
2. The local JSON file is a cache and reviewable snapshot, not a second source of truth.
3. Never silently replace an ADO date with a meeting-note date.
4. User-provided planning events that do not exist in ADO may be retained as `manualMilestones`, with `source: user` and `verificationStatus: stated`.
5. If ADO cannot be reached, use the snapshot only when it parses successfully and clearly label the output as cached, including `lastSyncedAt`.

## Procedure

1. Resolve organization, project, team, requested PI/iteration, and presentation time zone from the user request and project profile.
2. Use Azure DevOps Work/Team Settings tools to list the Team's iteration configuration and dates. Prefer Team-specific iteration data over names inferred from work items.
3. Normalize each entry into:
   - `name`
   - `path`
   - `startDate`
   - `finishDate`
   - `timeFrame` when supplied by ADO
   - `source`
   - `verificationStatus`
4. Derive PI groupings only from the configured Iteration Path hierarchy. Do not infer a PI date range from its label alone.
5. Determine the current period using the current date in `Asia/Shanghai`:
   - current when `startDate <= today <= finishDate`
   - upcoming when `today < startDate`
   - past when `today > finishDate`
6. Calculate calendar days remaining inclusively and state that the value is calendar days. Do not call it working days unless a holiday/calendar source was used.
7. Compare the normalized ADO result with the existing snapshot. Report changed dates or paths before replacing them.
8. Refresh the snapshot only after a successful ADO read. Preserve manual milestones and mark stale entries that are no longer returned by ADO rather than silently deleting them.

## Snapshot contract

Use the existing keys in `timeline.json`. Keep dates in ISO 8601 format. Set:

- `lastSyncStatus` to `success`, `partial`, or `never-synced`
- `lastSyncedAt` only after an ADO retrieval
- `source` to the exact ADO API/tool family used
- `verificationStatus` per item to `verified`, `stale`, or `stated`

Do not store tokens, cookies, personal access tokens, or raw API responses.

## Output

Return these compact sections:

1. **Current context**: PI, iteration, date range, calendar days remaining
2. **Next milestone**: next iteration boundary, PI boundary, or manual planning event
3. **Timeline**: relevant current and upcoming entries
4. **Data status**: live/cached, source, last synced time, and any conflicts or missing dates

If no verified dates are available, say so and identify the smallest missing input or ADO permission needed. Never present unverified dates as confirmed.
