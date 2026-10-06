# Team Plum PI 4 Planning Feature 清单

## 范围与数据状态

- 范围依据：Weibin 与 PO 于 2026-08-24 的确认；该确认替代本文件先前的假设优先级。
- ADO 是 Feature 状态、Area、迭代和估算的权威来源；本文件的范围分类反映 PO 讨论结论，不替代 PO/PM 的 backlog 排序与承诺决策。
- PI 4 时间：2026-08-27 至 2026-11-04。当前为 PI Planning 收敛阶段。
- 团队需要预留较大容量用于 **defect backlog reduction**；因此 PI 4 不应再广泛新增 Feature。

## 当前计划结论

PI 4 以 4 个明确方向为主：两个延续项、一个客户承诺项，以及一个以测试完成为目标的候选项。以下 3 个 Feature 暂不纳入 PI 4 实施范围，等待 Vikas 批准和后续优先级决定。

| 分类 | ID | Feature | PI 4 处理方式 | Planning 含义 |
| --- | ---: | --- | --- | --- |
| 延续项 | 13996 | AUS - Model-Level Data Area Role-Based Access Control | 继续交付 | 将现有工作和剩余 Story 重新估算、排入迭代。 |
| 延续项 | 13323 | Rework blend header bias to match classic MBO | 继续交付 | 将现有工作和剩余 Story 重新估算、排入迭代。 |
| 承诺项 | 121144 | AUM - BAPCO Commitment Gaps from Contract Items | 必须纳入 | 客户承诺优先，先核实剩余范围、依赖与端到端测试。 |
| 测试候选项 | 133441 | AURA - Create GraphQL Query to Read Material Class, Strapping Table, Material Parent/Child Relationship | 倾向纳入，仅以完成测试为目标 | 在不挤占承诺项和 defect backlog reduction 容量的前提下安排。 |
| 暂不纳入 | 124991 | AUM - Adding GraphQL to Enable Multiple Orders Creation | 不计划实施 | 等待 Vikas 批准；不创建 PI 4 承诺或预排 Story。 |
| 暂不纳入 | 119939 | Gas Stream MSCF Visibility in Balance Tab & Reporting | 不计划实施 | 等待 Vikas 批准；不创建 PI 4 承诺或预排 Story。 |
| 暂不纳入 | 119932 | Material Group-Based Smart Filtering and Validation for Tank and Product Selection | 不计划实施 | 等待 Vikas 批准；不创建 PI 4 承诺或预排 Story。 |

## 容量与排序原则

1. 先保障 `#121144` 的客户承诺、`#13996` 与 `#13323` 的延续交付。
2. 在完成上述工作估算后，预留显著可见的 PI 容量用于 open defect backlog reduction，并在迭代中持续补充已 ready 的 defect。
3. `#133441` 只在测试范围、验收人和剩余工作量明确后安排；它不是压缩 defect 容量来换取的新开发承诺。
4. `#124991`、`#119939`、`#119932` 在 Vikas 明确批准前保持 Out of Scope。即便存在候选清单，也不计入 Team Plum 的 PI 4 容量承诺。
5. 其余 Feature 数量保持严格受控；当前沟通预期最多约 30 个 Feature 会被实施，但这不是 PI 4 的交付承诺或 Team Plum 的容量指标。

## 近期 Planning 动作

| 动作 | 建议负责人 | 完成标准 |
| --- | --- | --- |
| 核实 3 个纳入项的已完成、剩余 Story、依赖和验收条件 | 各 Feature owner 与技术 owner | 每个 Feature 有可估算、可迭代交付的 Story 清单。 |
| 更新 `#121144` 的剩余估算和跨 UI、GraphQL、Excel Import 的测试范围 | AUM owner、QE 与 PO | 客户承诺的剩余工作与风险已明确。 |
| 明确 `#133441` 是否只有测试、具体测试责任人及完成定义 | AURA owner、QE 与 PO | 决定它进入哪个迭代，或保留为不承诺候选项。 |
| 定义 defect backlog reduction 的容量目标与优先 defect 集 | PO、ATL、QE 与开发 owner | 每个迭代有保留容量和经过 triage 的 defect 列表。 |
| 记录 Vikas 对 3 个暂不纳入项的决定 | PO/PM | 批准前保持 Out of Scope；批准后再进入 refinement。 |

## PI Planning 三天执行记录

以下节奏来自 ATL 的现场工作记录，用于后续 PI Planning 准备；不替代 ADO 中的工作项状态、排期、容量和优先级事实。

### Day 1：容量准备

- Day 1 无需安排 ATL 发言内容。
- 跟进团队成员完成 PI 休假计划填写。
- 根据休假计划提前计算团队及各 Iteration 的可用 capacity，作为后续 Story 排期的输入。

### Day 2：Breakout 与计划编排

- 提前邀请 PO、PM 参加 Day 2 上午的 breakout session，澄清功能范围、验收预期、依赖和待决问题。
- 下午与上海团队共同分析 Feature，并将 Feature、依赖和计划放入 Lucidchart。
- 将 Feature 拆分为可交付的 User Story，分配到具体 Iteration。
- 每个 Iteration 预留 15% capacity 用于修复 Bug，5% 用于 customer support；其余 capacity 再用于 Feature/Story 承诺。
- 更新 Lucidchart，并为当晚的 plan demo 准备可展示的最终计划。

### Day 3：最终确认与 PI 启动

- 在 final plan demo 前与团队再过一遍计划，确认范围、排期、容量预留和未决风险。
- 组织 confidence vote 与 retrospective，记录需要调整的事项和责任人。
- 晚间会议同步当日修改内容、风险和待跟进行动。
- Day 3 结束后进入新 PI；提醒团队更新 User Story 状态，补全 Acceptance Criteria (AC) 及其他必要工作项信息。

### 后续可复用检查项

| 时点 | 检查项 | 完成标准 |
| --- | --- | --- |
| Day 1 结束前 | PI 休假计划与 capacity | 所有人休假已录入，按 Iteration 得到可用 capacity。 |
| Day 2 上午前 | Breakout session | 已向 PO/PM 发出会议邀请，待澄清问题已整理。 |
| Day 2 结束前 | Lucidchart 与 Story 排期 | Feature 已拆分，Story 已按 Iteration 排期，并逐个 Iteration 保留 15% Bug 与 5% customer support capacity。 |
| Day 3 结束后 | ADO 工作项质量 | Story 状态、AC、Iteration Path、owner 和依赖信息已补全或列入明确跟进行动。 |

## 数据限制

- 本文件尚未重新读取这些 Feature 的 ADO 当前状态、Area、关联 Story、估算或 owner；更新这些事实字段前必须以 ADO 实时数据核对。
- PI 4-1 团队 capacity 目前未填写，因此不能把 Story Points、个人分配或迭代承诺量视为已验证。
- defect backlog reduction 的目标容量尚未量化；在 capacity 和开放 defect triage 完成前，不能给出可信的 Feature/Story 数量上限。