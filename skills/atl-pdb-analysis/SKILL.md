---
name: atl-pdb-analysis
description: "Analyze Azure DevOps PD Bugs/PDBs for an ATL: counts, Priority and Severity, State and aging, stale items, Owner and Iteration, Product, Area Path, and Source. Use when the user asks PDB 统计, PD Bug analysis, post development bugs, defect backlog, priority distribution, aging, owner load, or Team Plum PDB status."
argument-hint: "指定范围，例如：Team Plum 当前 PI；也可提供 PDB ID、ADO Query URL 或 Dashboard URL 用于首次字段校验。"
user-invocable: true
---

# ATL PDB Analysis

Produce a read-only, reproducible view of the PD Bug backlog from Azure DevOps. The report is for situational awareness; it must not silently turn uncertain field mappings into facts.

## Default project context

Read these files before querying:

- `C:/Users/ZHAOWE/.copilot/agile/projects/plum/profile.md`
- `C:/Users/ZHAOWE/.copilot/agile/projects/plum/ado-field-map.json`
- `C:/Users/ZHAOWE/.copilot/agile/projects/plum/timeline.json` when the range is "current PI" or "current iteration"

Default scope is Team Plum's open PD Bug backlog using its verified saved query. Always display the resolved scope and the saved query's excluded states. Apply a current PI or current iteration constraint only when the user requests that narrower view.

## Safety boundary

- Read ADO only. Do not edit work items, queries, dashboards, boards, assignments, state, priority, Story Points, Area Path, or Iteration Path.
- Do not assume every `Bug` is a PD Bug.
- Do not infer a PDB classifier solely from the phrases used in meeting notes.
- Do not execute a broad Bug query until the PDB classifier is verified.

## Phase 1: Discover and verify the PDB schema

Read `ado-field-map.json` and inspect `pdbClassifier.verificationStatus`.

If it is not `verified`:

1. Prefer an existing ADO Query or Dashboard widget that the team already uses for PD Bugs.
2. Otherwise request one known PD Bug ID and, ideally, one known internal/new-feature Bug ID as a negative control.
3. Read both items with all available fields and compare:
   - Work Item Type
   - Tags
   - Area Path and Iteration Path
   - Product/category fields
   - defect type, origin, source, or classification fields
   - State values
4. Identify the smallest stable filter that includes the known PD Bug and excludes the negative control.
5. Save only verified ADO reference names and allowed values to `ado-field-map.json`. Keep display names separately.
6. Record `verifiedAt`, `verifiedFrom`, and non-sensitive sample IDs used for verification.

If no stable classifier can be proven, stop and report exactly what is missing. Do not substitute all Bugs.

If it is `verified`, prefer the saved Query recorded in the field map as the baseline open-backlog definition. Read its current WIQL when practical so a later Dashboard change is not hidden by stale local configuration.

## Phase 2: Resolve scope and query

1. Resolve organization, project, team, PI/iteration, Area Path, and optional date/state filters.
2. If the request is ambiguous, use Team Plum + the verified open-backlog Query and state that default prominently.
3. Use the verified saved Query or reproduce its classifier, Area Path, and state constraints through an ADO Query/WIQL operation. Add Team/Iteration constraints only when requested.
4. Fetch fields in batches. Use only verified optional field names; always request core fields when available:
   - `System.Id`
   - `System.Title`
   - `System.WorkItemType`
   - `System.State`
   - `System.AssignedTo`
   - `System.AreaPath`
   - `System.IterationPath`
   - `System.CreatedDate`
   - `System.ChangedDate`
   - the verified Priority field from the field map
   - `Microsoft.VSTS.Common.Severity`
5. Include all verified Product and Source fields from the field map. For Team Plum PDBs, distinguish Product Family, Product Name, Product Area, and Product SubArea instead of collapsing them silently.
6. De-duplicate by `System.Id`. Preserve missing values as `Unspecified`; do not drop those rows.
7. Record retrieval time and the exact filter in the report. Do not persist the full work-item payload locally.

## Metrics

Use calendar-day buckets unless the user asks for another definition.

### Backlog age

Calculate from `System.CreatedDate` to the report time:

- `0-7 days`
- `8-30 days`
- `31-90 days`
- `91-180 days`
- `181+ days`
- `Unknown`

### Staleness

Calculate separately from `System.ChangedDate`:

- `Updated in 0-7 days`
- `Stale 8-30 days`
- `Stale 31-90 days`
- `Stale 91+ days`
- `Unknown`

Do not label age as staleness or vice versa.

### Distributions

Report:

- total count
- Priority and Severity
- State
- backlog age and staleness
- Assigned To, including `Unassigned`
- Iteration Path, including `Unscheduled`
- Product, Area Path, and Source when those fields are verified

For identity fields, display a stable friendly name when ADO supplies one. Do not expose email addresses unless the user explicitly needs them.

## Output format

1. **Scope and freshness**: organization/project/team, classifier, PI/iteration, retrieval time, live or cached
2. **Summary**: total and the most important distributions
3. **Age and staleness**: separate tables plus oldest/stalest item IDs when useful
4. **Ownership and scheduling**: owner and Iteration Path distributions
5. **Product context**: Product, Area Path, and Source distributions
6. **Data quality**: missing Priority, Severity, owner, iteration, Product, Source, and any schema uncertainty

The first version does not automatically produce an ATL action list. Provide actions only when the user asks for recommendations.

## Failure handling

- Authentication or permission failure: state which ADO scope/tool failed and stop; do not fall back to guessed data.
- Dashboard total differs from the query: show both totals and compare classifier, team, state, Iteration Path, and refresh time.
- Optional field unavailable: omit that dimension and list it under Data quality.
- More than one valid PDB classifier: present the alternatives and ask which team convention is authoritative before saving the map.
