# AUM Order 模块高频缺陷模式

从 TFVC changeset 历史（`$/UnifiedPIMS/Releases/Main/Psc/Aum`，2026-04 ~ 2026-05）
与 ADO 工作项联合分析得出，涵盖 19 个 Order 相关 Bug/Story。
供后续开发防范和 code review 参考。

---

## Pattern 1：Role Guard 补丁式修复

**相关 Bug：** 103437 ✅、103475 ✅、104976 🔴、105046 🔴
**相关 CS：** 241410（Zhou, Mengling）、241619（Xie, Anna）

### Context

- Bug 103437 / 103475：发现 **Viewer** 可在 Order Detail Panel 添加/删除/关联 Movement → 修复
- Bug 104976 / 105046：发现 **Case-only Author** 无法创建/删除 Order，也无法移除 Movement → 再次修复

每次只修当次发现的角色，遗漏其他角色，同类 bug 反复出现。

权限逻辑分散在多处：`order-property.html/.ts`、`movement-summary-table.ts`、
`delete-order-dialog.ts`、`object-state.ts`，没有统一的 role-check 入口。

### Anti-Pattern（不要这样做）

```ts
// ❌ 各组件各自判断，新增角色时容易遗漏
if (this.currentUser.role === 'Viewer') {
    this.canAddMovement = false;
}
```

### Recommended Pattern

**Step 1：** 在 `services/order-permission.ts` 中统一定义权限矩阵：

```ts
export const ORDER_PERMISSIONS = {
    canCreateOrder:    ['Owner', 'Engineer', 'CaseAuthor'],
    canDeleteOrder:    ['Owner', 'Engineer', 'CaseAuthor'],
    canAddMovement:    ['Owner', 'Engineer', 'CaseAuthor'],
    canRemoveMovement: ['Owner', 'Engineer', 'CaseAuthor'],
    canLinkOrder:      ['Owner', 'Engineer', 'CaseAuthor'],
};

export function hasOrderPermission(
    action: keyof typeof ORDER_PERMISSIONS,
    userRole: string
): boolean {
    return ORDER_PERMISSIONS[action].includes(userRole);
}
```

**Step 2：** 所有组件统一调用，不各自判断：

```ts
// order-property.ts
import { hasOrderPermission } from '../services/order-permission';

get canAddMovement(): boolean {
    return hasOrderPermission('canAddMovement', this.currentUserRole);
}
```

**Step 3：** 模板绑定 computed property，不写内联判断：

```html
<button click.delegate="addMovement()" if.bind="canAddMovement">
    Add Movement
</button>
```

### Checklist

- [ ] 新增 Order 操作时，权限矩阵是否同时覆盖所有角色（Owner / Engineer / CaseAuthor / Viewer / ReadOnly）？
- [ ] Order Detail Panel 和 Movement 列表的按钮可见性是否都走统一的 `hasOrderPermission`？
- [ ] 删除/关联类操作是否也做了后端 mutation 层的权限校验（不能仅依赖前端隐藏按钮）？

---

## Pattern 2：Order-Movement 状态同步

**相关 Bug：** 102257 ✅
**相关 CS：** 241372（Zhou, Mengling）—— 9 个文件横跨前后端
**涉及文件：** `movement-summary-table.ts`、`order-property.ts`、`order-view-table.ts`、
`movements-services.ts`、`order-template-service.ts`、`CRUDMovements.cs`

### Context

在 Order Detail Panel 中更改 Movement 状态（如 Scheduled → Active，或 Active → Completed）后，
该 Movement 从 Order 的 movement 列表中**消失**。

`movement-summary-table` 只在初始加载时查询一次关联 movement，没有订阅 mutation 后的刷新信号。
Movement 状态变更 mutation 执行成功，但前端本地数据未更新 → 条目消失（实为过滤结果未刷新）。

### Recommended Pattern

```ts
// movements-services.ts
async updateMovementState(movementId: string, newState: string): Promise<void> {
    await this.graphql.mutate(UPDATE_MOVEMENT_STATE, { movementId, newState });
    // ✅ mutation 完成后，主动通知 Order 侧刷新
    this.orderMovementsRefreshSignal.dispatch(movementId);
}
```

```ts
// movement-summary-table.ts
attached(): void {
    // ✅ 订阅刷新信号，而不是依赖一次性加载
    this.subscription = this.movementsService.orderMovementsRefreshSignal
        .subscribe(() => this.loadMovements());
}

detached(): void {
    this.subscription?.dispose(); // ✅ 防止内存泄漏
}
```

### Checklist

- [ ] Movement 状态变更 mutation 执行后，是否主动触发了 Order 侧 movement 列表的刷新？
- [ ] `movement-summary-table` 是否订阅刷新信号（而非依赖一次性 `attached()` 加载）？
- [ ] GraphQL mutation 返回值是否包含足够的关联字段，供前端判断关联关系是否仍有效？
- [ ] 组件 `detached()` 时是否 dispose 了订阅？
