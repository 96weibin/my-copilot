---
name: ui-regression-runner
description: "Run browser-based regression from ADO Test Cases with Chrome DevTools MCP. TRIGGER when user says '跑 regression', '按 TC 执行', '执行测试计划', 'run test case', 'run regression', '按测试步骤点一遍', or provides ADO test plan/suite/test case IDs and asks to execute in web UI. DO NOT TRIGGER for backend-only tests, API-only tests, or non-browser automation requests."
argument-hint: "Provide target URL, ADO plan/suite/TC IDs, and model/context name"
user-invocable: true
---

# UI Regression Runner

用于把 ADO Test Case 的步骤转成 Chrome DevTools MCP 可执行动作，并按步骤执行、截图取证、记录结论。

## Goal

在浏览器内按 TC 步骤执行回归，产出可追踪的执行记录：
- 每一步的操作
- 每一步的观察结果
- Pass/Fail/Blocked
- 必要截图或页面证据

## Preconditions

执行前必须满足：
1. 目标站点可访问且账号已登录。
2. ADO Test Plan/Suite/TC 可读取。
3. 已确定模型或业务上下文（例如具体 model name）。

若缺少任一前提，先补前提再执行，不盲跑。

## Procedure

### Step 1 - Gather TC Data

读取并确认：
1. Test Plan
2. Suite
3. TC 明细（含 Microsoft.VSTS.TCM.Steps）

把 Steps 拆为可执行单元：
- ActionStep -> 执行动作
- ValidateStep -> 校验动作

### Step 2 - Open Target App Context

在 Chrome DevTools MCP 中：
1. 打开目标 URL
2. 验证登录态
3. 进入指定模块/模型/页面

若模型未准备好，先执行准备动作（例如 Import Snapshot 或 Create New）。

### Step 3 - Execute Step by Step

对每个步骤循环：
1. 执行动作（click/fill/type/press/drag/wait）
2. 读取页面状态（snapshot）
3. 给出步骤结论（Pass/Fail/Blocked）
4. 必要时截图

### Step 4 - Handle Decision Gates

遇到以下情况进入人工判定点：
1. 业务语义判断（例如趋势正确性、业务计算合理性）
2. 非浏览器依赖（SQL、Excel、本地客户端）
3. 权限或数据环境不足

在判定点要明确写出：
- 需要用户提供什么信息
- 当前已完成到哪一步

### Step 5 - Close with Evidence Report

输出执行报告：
1. 执行范围（Plan/Suite/TC）
2. 步骤结果汇总
3. 失败或阻塞原因
4. 环境告警与基线风险
5. 下一步建议

## Output Format

建议用以下结构：

1. 执行对象
2. 步骤执行明细（Step N / Action / Observation / Result）
3. 问题与阻塞
4. 总结结论

Result 仅使用：Pass / Fail / Blocked。

## Guardrails

1. 不把页面已有历史告警误判为本次新问题。
2. 不编造未观察到的结果。
3. 不能执行的步骤必须标记 Blocked 并写明原因。
4. 涉及敏感输入时不通过模型通道收集秘密信息。

## Practical Notes

1. 文件上传受工作区沙箱限制，若源文件不在可访问目录，先复制到本机临时目录后再上传。
2. Gantt/Canvas 场景优先走可稳定入口（Event Summary Grid、上下文菜单、详情弹窗），避免仅依赖画布坐标点击。
3. 运行类动作（如 Run Optimizer）应至少验证是否成功进入 Job Status，并记录当前状态（Queued/Running/Completed/Failed）。
