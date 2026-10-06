# G3504 v1.3：Developer / ATL DoD 速查

**分类：** Proprietary / internal，仅供内部参考  
**来源：** Definition of Done (DoD) Guidelines, G3504 v1.3  
**用途：** Developer 日常交付与兼任 ATL 时的协调清单；以原文标准为准。

## DoD 层级与尺度

DoD 分为 Epic、Capability、Feature、User Story 四层，逐层验证完成、可交付、高质量且可验证：

| 层级 | 文档尺度 |
| --- | --- |
| User Story | 小于 1 个 iteration |
| Feature | 1 PI |
| Capability | 1 PI |
| Epic | 2 个或更多 PIs |

## Developer：Story 与代码交付

- Story 的 Acceptance Criteria（AC）清晰、可测，并可追溯到用户需要。面向用户的 AC 用 Gherkin 覆盖正向、负向和边界场景。
- 在实现前或实现同时进行 TDD/BDD 测试；测试及结果作为验收证据。Story 关联到 Feature/Epic，并填写 Story Points。
- 代码通过 GitHub PR peer review；PR 关联 Story，具备必需 reviewer、build pass，且没有 open comments。
- Unit/component tests 达到 G3504 规定的覆盖率阈值；CI 为 0 failing tests。覆盖率具体数值按 G3504 原文核对。
- 将安全、性能、可靠性、可访问性等 NFR 记录在 AC 或 NFR checklist；SonarQube 通过，满足 SAST 和 Black Duck gates。
- CVSS 4.0 分数 `>= 7` 的问题必须 triage/resolved；KEV 项全部解决。
- PO 接受后关闭 Story。

## Feature / ART 协作

- Feature 明确 title、description、AC 和 benefit hypothesis；拆分并关联 Child Stories/Enablers，记录依赖。
- 通过 CI integration/acceptance tests；保留结果、coverage 和 branch quality gates 证据。
- 明确性能等 NFR，以及 security/compliance NFR；扫描结果和 Security Artifacts 可追溯到设计/架构文档，并完成 Security Document。
- 若 Delta Risk Assessment 要求，更新 Threat Model、Pen Test、AI Inventory 及 mitigations、secure-by-default 相关内容。
- 更新所需文档和 Release Notes；在合适环境完成 E2E 验证。PM 接受后关闭 Feature。

## ATL：Capability / 跨 ART 闭环

- 写清 Capability statement、可度量的结果假设、范围边界，并确认与 Solution Vision 一致。Capability 可跨 ART，但有意按 1 PI sizing；注明 PI horizon 和 rationale。
- 多 ART 时，逐 ART 明确 owner、dependency/integration plan 和 shared NFR guardrails；每个 PI 留存集成验证证据。
- 记录所需治理审批和 solution acceptance evidence 后，才关闭 Capability。
- Epic 的 state entry/exit criteria 依赖 Epic-level Process Doc；按该文档执行，不在本页补写状态规则。

## 角色切换 Checklist

**作为 Developer，逐个 Story/PR 核对：**

- [ ] AC 可测、可追溯；Gherkin 覆盖正向/负向/边界（适用时）。
- [ ] TDD/BDD、Story 关联及 Story Points 完整；测试、review、build、coverage、quality/security gates 有证据。
- [ ] NFR 和安全问题处置有记录；PO 接受后再关闭 Story。

**作为 ATL，按 Feature/Capability 边界核对：**

- [ ] Feature 的拆分、依赖、NFR、安全文档、E2E 与 PM acceptance 闭环。
- [ ] Capability 的 PI sizing/rationale 完整；若跨 ART，owner、依赖/集成计划、shared NFR 和每 PI 验证证据齐全。
- [ ] 关闭 Capability 前记录治理审批和 solution acceptance evidence；Epic 状态标准查 Epic-level Process Doc。

Developer 通常直接负责 Story、PR、tests 和 NFR evidence；ATL 负责跨 ART 能力与集成闭环。兼任 ATL 不代表替代 PO、PM、SM、STE 或 Security 的审批职责。

## 证据放置

- **ADO：** Story/Feature/Capability 的 AC、关联层级、Story Points、依赖、NFR checklist、验收/审批记录、文档链接及关闭依据。
- **GitHub PR：** Story 关联、reviewer/review 状态、comments 处理、代码变更与相关测试说明。
- **CI / 质量与安全工具：** build、unit/component/integration/acceptance test 结果、coverage、branch quality gates、SonarQube、SAST、Black Duck 与扫描/修复结果。
- **设计/架构文档：** 可追溯的 Security Artifacts；按需附 Threat Model、Pen Test、AI Inventory/mitigations 等更新。
- 各项证据应能从对应 ADO 工作项或 PR 找到；本清单不规定原文未说明的系统字段或审批流程。