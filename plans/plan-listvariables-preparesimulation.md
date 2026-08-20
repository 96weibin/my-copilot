# 🎯 修复 ListVariables 在未完成 PrepareSimulation 时抛错

## Understanding
用户希望修复 `ListVariables` 调用偶发抛出“Simulation has not been prepared.”的问题。根据现有代码，最可能原因是创建 session 后异步排队的 `PrepareSimulation` 尚未完成，而控制器立即又发起了 `ListVariables` 调用，导致时序竞争。
## Assumptions
- `BeginUnitSimulationSession` 当前设计上允许先返回 session，再在 worker 线程异步准备 simulation。
- `PrepareSimulation` 是幂等的；在同一 worker 调用中显式再次调用可作为补偿，不会破坏已准备好的状态。
- 最小且安全的修复点优先放在 `SimulatorController.ListVariables` 路径，避免扩大行为变化范围。
## Approach
先核对 `AutoCheckSingularity`/`PrepareSimulation` 的现有语义，确认在 `ListVariables` 路径中补一次原子 prepare 不会引入行为偏差。随后修改 `SimulatorController.ListVariables`，将 prepare 与 list 合并到同一次 `_simManager.Invoke(...)` 中执行，复用 GraphQL 路径中已经采用的抗竞态模式。必要时补充服务端保护逻辑，最后通过编译验证。

核心文件会是 [Planning/PlanningModel/AspenTech.Psc.PlanningModel.SimulationApi/Simulation/SimulatorController.cs](Planning/PlanningModel/AspenTech.Psc.PlanningModel.SimulationApi/Simulation/SimulatorController.cs) 与 [Planning/PlanningModel/AspenTech.Psc.PlanningModel.SimulationApi/Services/SimulationServices.cs](Planning/PlanningModel/AspenTech.Psc.PlanningModel.SimulationApi/Services/SimulationServices.cs)，前者是触发路径，后者决定 prepare 的幂等与状态语义。
## Key Files
- `Planning/PlanningModel/AspenTech.Psc.PlanningModel.SimulationApi/Simulation/SimulatorController.cs` - `ListVariables` API 当前直接调用服务，存在时序竞争。
- `Planning/PlanningModel/AspenTech.Psc.PlanningModel.SimulationApi/Services/SimulationServices.cs` - `PrepareSimulation`/`ListVariables` 的状态行为与幂等语义。
- `Planning/PlanningModel/AspenTech.Psc.PlanningModel.SimulationApi/Simulation/IPlanningUnitSimulationManager.cs` - session 建立时如何异步排队 prepare。
## Risks & Open Questions
- `ListVariables` 重新触发 prepare 时，若无法获取原始 `doAutoCheckSingularity` 选项，需确认使用当前状态或保守值不会改变用户预期。
- 如果根因还包含 prepare 失败而非纯竞态，控制器修复只能解决时序问题，不能掩盖配置错误。

**Last Updated**: 2026-06-30 08:01:01

## 📝 Plan Steps
-  **核对 prepare 语义**
-  **修改 `SimulatorController.ListVariables`**
-  **视需要补强服务端保护**
-  **编译验证修复**

