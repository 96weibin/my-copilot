---
name: ui-regression-runner
description: "Run browser-based regression from ADO Test Cases with Chrome DevTools MCP. TRIGGER when user says '跑 regression', '按 TC 执行', '执行测试计划', 'run test case', 'run regression', '按测试步骤点一遍', or provides ADO test plan/suite/test case IDs and asks to execute in web UI. Default to one test case per run unless the user explicitly asks for batch execution. DO NOT TRIGGER for backend-only tests, API-only tests, or non-browser automation requests."
argument-hint: "For one regression run, provide media URL, one ADO TC ID or link, and optionally help KB path / project KB path"
user-invocable: true
---

# UI Regression Runner

用于把 ADO Test Case 的步骤转成 Chrome DevTools MCP 可执行动作，并按步骤执行、截图取证、记录结论。

这个 skill 默认优先吸收两类知识来源：
- Help KB：告诉 agent 产品如何用、页面入口在哪里、字段和流程是什么意思
- Project KB：告诉 agent 代码结构、历史缺陷模式、实现约束和容易踩坑的地方

## Goal

在浏览器内按 TC 步骤执行回归，产出可追踪的执行记录：
- 每一步的操作
- 每一步的观察结果
- Pass/Fail/Blocked
- 必要截图或页面证据

并在执行前先判断：
- 这个 TC 是否适合浏览器自动化
- 哪些步骤只能做到半自动
- 哪些步骤会被环境、外部工具或业务判定阻塞

并且在真正执行前，先基于 KB 和 TC 给用户做一段简短讲解：
- 这个 TC 实际在验证什么
- 准备走哪条页面路径
- 哪些地方目前仍然不清楚

## Single-TC Default

默认一次只跑一个 TC。

当用户说“run regression”而没有明确说明批量执行时：

1. 按单个 TC 处理。
2. 不自动展开到整套 suite 或整批 case。
3. 若用户后续明确要求批量，再升级为 batch 模式。

## Required Inputs At Skill Entry

调用 skill 后，先确认这一轮执行所需的最小输入：

1. media URL
2. 一个 ADO TC 号，或一个可解析到单个 TC 的 ADO 链接
3. help KB 路径（可选但优先）
4. project KB 路径（可选但优先）

输入收集规则：

1. media URL 缺失时，直接问用户。
2. ADO TC 号或链接缺失时，直接问用户。
3. help KB 路径缺失时，先尝试从已知工作区或常见 KB 位置推断；找不到再问用户。
4. project KB 路径缺失时，先尝试从当前项目或常见 `.github/kb` 位置推断；找不到再问用户。
5. 若用户给的是链接，优先从链接中解析 TC 标识，而不是再额外要求 plan/suite。
6. 在这 4 类输入没有补齐到可执行状态前，不进入浏览器执行步骤。

## Preconditions

执行前必须满足：
1. 已拿到 media URL。
2. 已拿到单个 ADO TC 号或链接，并可读取该 TC。
3. 目标站点可访问且账号已登录。
4. 已确定模型或业务上下文（例如具体 model name）。
5. 若用户提供 help KB 或项目 KB，先读取相关内容再执行。

若缺少任一前提，先补前提再执行，不盲跑。

## Procedure

### Step -1 - Collect Missing Inputs

先补齐本轮单 TC 执行所需输入：

1. media URL
2. ADO TC 号或链接
3. help KB 路径
4. project KB 路径

执行规则：

1. 对 KB 路径先做自动发现，不要一上来就问用户。
2. 只有在自动发现失败时，才向用户追问缺失路径。
3. 如果用户只提供 TC 号，也可以先继续读取 TC；不强制要求用户一开始就提供 plan 和 suite。
4. 如果用户给出的信息指向多个 TC，暂停并要求用户收敛到单个 TC。

### Step 0 - Read Available Knowledge

若用户提供 KB 路径，或自动发现到相关 KB，优先读取：

1. Help KB
	- 目标模块页（例如 scheduling.md、aura.md）
	- 与模型管理、事件、仿真、优化相关的章节

2. Project KB
	- `README.md`
	- `project-map.md`
	- `defects/index.md`
	- 其他与当前模块或 TC 相关的 KB 页面

如果项目 KB 采用 AURA 风格的 module-first 结构，优先读取顺序改为：

1. `README.md`
2. `project-map.md`
3. `how-to-use.md`（如果存在）
4. `modules/` 下与当前模块最相关的页面
5. `flows/` 下与当前跨层场景相关的页面
6. `patterns/` 下的 fix/review patterns
7. `runbooks/` 下的验证与操作页面
8. `troubleshooting/` 下的故障隔离页面

### Step 0.8 - Explain The TC Before Running

在开始浏览器操作前，必须先结合 TC 步骤和已读取的 KB，给用户一个简短的预讲解。

讲解至少覆盖 3 件事：

1. 这个 TC 在测什么
2. 准备怎么执行
3. 当前哪里还不理解

具体输出要求：

1. 用业务语言概括这个 TC 的目标
	- 它是在验证哪个模块、哪类用户流、哪种结果
2. 把 TC 步骤翻译成执行计划
	- 预计会打开哪些页面
	- 会改哪些字段或触发哪些动作
	- 会在哪里做验证
3. 明确列出当前不理解或不确定的点
	- TC 描述过于抽象的地方
	- KB 没覆盖的页面或字段
	- 需要用户补充的模型、数据、预期值、术语映射

如果存在疑点，处理规则如下：

1. 先说清楚疑点，不要直接盲跑。
2. 若疑点会影响执行路径或结果判定，先向用户确认再执行。
3. 若疑点不阻塞执行，可以明确标注“先按当前理解执行”。

建议输出结构：

1. TC 在做什么
2. 我准备怎么跑
3. 我现在不理解什么

### Knowledge Value Rules

执行 regression 时，优先这样使用知识：

1. Help KB
	- 用于理解产品工作流、入口位置、事件类型、字段含义、页面期望行为
	- 对“按步骤执行”和“页面结果是否大体合理”价值最高

2. Project KB
	- 用于理解本项目实现边界、历史缺陷热点、模块归属、已知异常模式
	- 对“失败后排查”和“识别是否疑似历史问题复现”价值最高
	- 如果结构完整到 `modules / flows / patterns / runbooks / troubleshooting` 这一级，它不只是排障材料，也可以直接指导 regression 的执行顺序与验证路径

3. 当两者冲突时
	- UI 行为和产品术语以 Help KB 为先
	- 实现限制和缺陷风险以 Project KB 为先

### Step 0.5 - Automation Feasibility Triage

在真正执行前，先把 TC 分成三类：

1. Browser-Executable
	- 完全可以在 Chrome DevTools MCP 中执行和校验

2. Semi-Automated
	- 浏览器动作可执行，但结果需要人工业务判定
	- 例如趋势曲线是否“正确”、业务值是否“合理”

3. Blocked-by-External-Dependency
	- 依赖 SQL、Excel、本地客户端、服务权限或缺失测试数据

若 TC 属于第 2 或第 3 类，必须在开始前明确告诉用户哪些步骤会停住。

### Step 1 - Gather TC Data

读取并确认：
1. Test Plan
2. Suite
3. TC 明细（含 Microsoft.VSTS.TCM.Steps）

把 Steps 拆为可执行单元：
- ActionStep -> 执行动作
- ValidateStep -> 校验动作

并为每一步打标签：
- UI Action
- UI Validation
- Human Judgment
- External Dependency

在完成步骤拆解后，先不要立刻进入浏览器；先产出一次面向用户的 TC 讲解，再决定是否继续执行。

### Step 2 - Open Target App Context

在 Chrome DevTools MCP 中：
1. 打开目标 URL
2. 验证登录态
3. 进入指定模块/模型/页面

若模型未准备好，先执行准备动作（例如 Import Snapshot 或 Create New）。

### Step 2.5 - Capture Baseline Before Editing Anything

在开始修改模型、事件或输入前，先记录当前基线：

1. 现有告警
	- 例如 `Validation Failed`
	- `Initial simulation state is invalid`

2. 当前模型状态
	- 当前 work area
	- 当前 case
	- 当前可见趋势或关键数值

3. 当前选中的模型或资源

目的：避免把页面原本存在的问题误记为本次 regression 新发现。

### Step 3 - Execute Step by Step

对每个步骤循环：
1. 执行动作（click/fill/type/press/drag/wait）
2. 读取页面状态（snapshot）
3. 给出步骤结论（Pass/Fail/Blocked）
4. 必要时截图

优先使用稳定入口，而不是脆弱的画布操作：
- Event Summary Grid
- Event Track Properties
- 详情弹窗
- 可搜索的输入框/列表
- Job Status 页面

只有在没有稳定入口时，才直接操作 Canvas / Gantt 图元。

### Step 3.5 - Validate the Immediate Effect of Each Change

如果某一步会修改模型状态，修改后必须立刻做一个最小验证：

1. 字段值是否变化
2. Apply / Save 是否成功
3. 页面是否出现新错误
4. 下游视图是否可见更新
	- 例如 Trends
	- Event Summary Grid
	- Job Status

### Step 4 - Handle Decision Gates

遇到以下情况进入人工判定点：
1. 业务语义判断（例如趋势正确性、业务计算合理性）
2. 非浏览器依赖（SQL、Excel、本地客户端）
3. 权限或数据环境不足
4. TC 描述缺少模型名、初始数据场景、期望数值口径

在判定点要明确写出：
- 需要用户提供什么信息
- 当前已完成到哪一步

### Step 5 - Close with Evidence Report

输出执行报告：
1. 执行范围（Plan/Suite/TC）
2. 自动化可行性分级（完全自动 / 半自动 / 外部阻塞）
2. 步骤结果汇总
3. 失败或阻塞原因
4. 环境告警与基线风险
5. 下一步建议

## Output Format

建议用以下结构：

1. 执行对象
2. TC 在做什么
3. 我准备怎么跑
4. 我现在不理解什么
5. 前置环境与基线
6. 步骤执行明细（Step N / Action / Observation / Result）
7. 问题与阻塞
8. 总结结论

在“前置环境与基线”中明确区分：
- 执行前已存在的问题
- 执行过程中新增的问题

Result 仅使用：Pass / Fail / Blocked。

## Guardrails

1. 不把页面已有历史告警误判为本次新问题。
2. 不编造未观察到的结果。
3. 不能执行的步骤必须标记 Blocked 并写明原因。
4. 涉及敏感输入时不通过模型通道收集秘密信息。
5. 如果用户提供了 Help KB 或 Project KB，不要跳过它们直接盲点页面。

## Practical Notes

1. 文件上传受工作区沙箱限制，若源文件不在可访问目录，先复制到本机临时目录后再上传。
2. Gantt/Canvas 场景优先走可稳定入口（Event Summary Grid、上下文菜单、详情弹窗），避免仅依赖画布坐标点击。
3. 运行类动作（如 Run Optimizer）应至少验证是否成功进入 Job Status，并记录当前状态（Queued/Running/Completed/Failed）。
4. 如果项目已有 `.github/kb`，但内容只有 defect patterns，说明它更适合辅助排障，不足以单独支撑高质量 regression 执行。
5. 如果 Help KB 已覆盖对应模块（例如 Scheduling），它通常能显著降低“页面入口不熟”和“步骤含义不清”的成本。
6. 如果 AUS 项目 KB 未来采用 AURA 风格结构，优先从 `project-map -> modules -> flows -> runbooks` 建骨架，再逐步补 `patterns` 和 `troubleshooting`。
