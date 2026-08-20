# 🎯 排查 UnitSimulation 日志未出现在 GetLogRecords 的原因

## Understanding
用户确认调用的是 `UnitSimulation/` 下的接口，但在 `SetEquationNLEStatus` 内 `AddLogRecord` 后，随后调用 `GetLogRecords` 看不到新增日志。目标是通过代码链路排查实际原因，而不是仅猜测时序问题。
## Assumptions
- 用户前端是分两次调用，不认为是请求时序问题。
- 需要优先排查 Scheduling 模块的 `UnitSimulation` controller 和对应 session/dispatcher/simulation 实例。
- 当前先做诊断和结论输出，除非发现明确代码缺陷再做最小修复。
## Approach
从 [SimulationApiController.cs](Scheduling/SchedulingModel/AspenTech.Psc.SchedulingModel.Simulator/Controllers/SimulationApiController.cs) 的 `SetEquationNLEStatus` 与 `GetLogRecords` 路由开始，追踪到 [SimulationManager.cs](Scheduling/SchedulingModel/AspenTech.Psc.SchedulingModel.Simulator/SimulationManager.cs)、[SimulationDispatcher.cs](Scheduling/SchedulingModel/AspenTech.Psc.SchedulingModel.Simulator/SimulationDispatcher.cs) 和 [Simulation.cs](Scheduling/SchedulingModel/AspenTech.Psc.SchedulingModel.Simulator/Simulation.cs)。同时搜索前端/调用端对 `SetEquationNLEStatus`、`GetLogRecords`、`BeginSession`、`EndSession` 的实际使用，确认是否存在重新建 session、不同 route prefix、或返回值被前端忽略的问题。
## Key Files
- Scheduling/SchedulingModel/AspenTech.Psc.SchedulingModel.Simulator/Controllers/SimulationApiController.cs - UnitSimulation API 入口
- Scheduling/SchedulingModel/AspenTech.Psc.SchedulingModel.Simulator/SimulationManager.cs - sessionId 到 UnitOp/dispatcher 的映射
- Scheduling/SchedulingModel/AspenTech.Psc.SchedulingModel.Simulator/SimulationDispatcher.cs - 单个 UnitOp 对应的 Simulation 实例与异步队列
- Scheduling/SchedulingModel/AspenTech.Psc.SchedulingModel.Simulator/Simulation.cs - AddLogRecord、GetLogRecords、SetEquationNLEStatus 实现
## Risks & Open Questions
- 前端代码可能不在当前 solution 或搜索被过滤，需要用多种搜索方式定位。
- 如果发现是运行时 session 状态问题，可能需要临时诊断日志而非纯静态代码就能完全证明。

**Last Updated**: 2026-07-30 09:02:52

## 📝 Plan Steps
-  **Inspect UnitSimulation controller and simulator manager routing**
-  **Inspect Simulation log mutation and save/reset behavior**
-  **Search caller usage for session lifecycle and log fetching**
-  **Identify root-cause candidates from code evidence**
-  **Report findings and propose minimal fix or diagnostic patch**

