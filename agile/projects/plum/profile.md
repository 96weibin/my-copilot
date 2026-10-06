# Team Plum Agile Profile

## ADO Scope

- Organization: `aspentechnology`
- Project: `AspenTech SAFe`
- Team: `Plum`
- Verified board route: `t/Plum`
- Example verified Iteration Path: `AspenTech SAFe\PI 2\Iteration 2-3`
- Verified Area Path: `AspenTech SAFe\Summit Solution Train\Orchard ART\Plum`
- Current default Iteration Path on 2026-08-20: `AspenTech SAFe\PI 3\Iteration 3-5 IP`
- Presentation time zone: `Asia/Shanghai`

## Team Context

- Team size described by the user: 5 developers, 3 QE members, and 1 documentation member.
- Team base: Shanghai.
- Agile organization roster and team leadership reference: `agile-team-roster.md`.
- Capulin is the backend counterpart for Plum.
- Team members:
	- `local OP`: Zhou, Mengling | Aspen email: `mengling.zhou@aspentechnology.com` | Emerson email: `mengling.zhou@emerson.com` | Corp: `CORP\ZHOUM` | Sr Software Developer
	- `atl`: Zhao, Weibin | Aspen email: `weibin.zhao@aspentechnology.com` | Emerson email: `weibin.zhao@emerson.com` | Corp: `CORP\ZHAOWE` | Software Developer II
	- `Dev`: Xie, Anna | Aspen email: `anna.xie@aspentechnology.com` | Emerson email: `anna.xie@emerson.com` | Corp: `CORP\XIEAN` | Software Developer II
	- `Dev`: Liu, Jin (Carrie) | Aspen email: `Carrie.Liu@aspentechnology.com` | Emerson email: `carrie.liu@emerson.com` | Corp: `CORP\LINCAR` | Sr Software Developer
	- `Dev`: Gan, Alaia | Aspen email: `alaia.gan@aspentechnology.com` | Emerson email: `alaia.gan@emerson.com` | Corp: `CORP\GANAL` | Associate Software Developer I
	- `QE`: Tang, Alex (Xiaoyu) | Aspen email: `xiaoyu.tang@aspentechnology.com` | Emerson email: `xiaoyu.tang@emerson.com` | Corp: `CORP\TANGXIA` | Software Quality Engineer II
	- `QE`: Wu, Mengjiao | Aspen email: `mengjiao.wu@aspentechnology.com` | Emerson email: `mengjiao.wu@emerson.com` | Corp: `CORP\WUMEN` | Software Quality Engineer I
	- `QE`: Gu, Siyi | Aspen email: `siyi.gu@aspentechnology.com` | Emerson email: `siyi.gu@emerson.com` | Corp: `CORP\GUSI` | Associate Software Quality Engineer II
- Shanghai primarily has frontend development, QE, and documentation.
- Mexico has backend development, QE, and one frontend developer with limited routine contact.
- PO/PM roles are mainly outside Shanghai, including Houston-area collaboration.
- The user previously acted as ATL and needs a more data-driven view than daily verbal updates alone.
- A new ATL has been selected under the previous ATL arrangement.
- A Shanghai local PM role is expected; the previous ATL is the likely choice, but this is not recorded as confirmed organizational data.

## Information And Decision Boundaries

- ADO is the source of truth for work-item state, assignment, priority, iteration, and configured dates.
- Daily and weekly meeting reports provide context but do not override ADO fields.
- Product scope and priority require PO/PM confirmation.
- Backend delivery and API dependencies generally require coordination with Mexico.
- Local ATL coordination may collect questions, expose risks, maintain status visibility, and follow up decisions without making product decisions.

## Existing Delivery Rhythm

- Daily meeting: individual progress, blockers, immediate coordination.
- Iteration review and planning: outcome, carry-over, capacity, and next-iteration work.
- Weekly sync: program health, dependencies, risks, and escalations.
- PI Planning: three planning days, typically followed by breakout discussions.
- ADO Team Dashboard is expected to contain PI objectives, current iteration, velocity, work-item state, PD Bugs, internal Bugs, and flow views.

## Known PD Bug Process Facts

- PD Bugs and internal/new-feature Bugs are treated as different categories in team reporting.
- PD Bugs are reviewed by Product, Team, Iteration, Owner, and State in existing dashboards.
- PD Bugs assigned to an iteration should have Story Points because they contribute to team load/velocity under the described process.
- Incoming defects may initially have a broad/default Iteration Path and require triage.
- Plum's verified saved query is `Shared Queries/Orchard Train/Plum/Post Development Bugs`.
- PDB is the ADO Work Item Type `Post Development Bug`; verified fields and states are maintained in `ado-field-map.json`.

## Context Maintenance

- Keep stable team and collaboration facts here.
- Keep machine-readable ADO fields in `ado-field-map.json`.
- Keep PI/Iteration dates and planning milestones in `timeline.json`.
- Mark uncertain organizational information explicitly instead of silently promoting it to fact.
