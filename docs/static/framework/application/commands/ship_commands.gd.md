# `framework/application/commands/ship_commands.gd`

> 作用：船厂用例：购买/仓库/随船运输三种来源安装模块（含替换）、卸下模块、打造模块，并在安装成功后检查通关。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipCommands` | L1 |
| `VALID_SOURCES` | L13 |
| `install_module(params: Dictionary, context) -> Dictionary` | L16 |
| `uninstall_module(params: Dictionary, context) -> Dictionary` | L109 |
| `craft_module(params: Dictionary, context) -> Dictionary` | L152 |

## 契约与约束

- 必须在有 shipyard 设施的港口且处于港口状态；仓库命令则只要求停靠任意港口。
- source ∈ {purchase, warehouse, transit}：purchase 扣 purchase_price；warehouse/transit 为免费旧件重装。
- 槽位/重量/货币/声誉/合同解锁失败原因由 `ShipOps.install_blockers()` 统一生成，避免 UI 与命令漂移。
- 单槽模块（船体/锅炉/导航/安全/客舱）自动替换，旧件写入当前港仓库；货舱槽满时需 replace_module_id。
- 购买船体替换后耐久为新上限；warehouse/transit 船体替换取 min(当前耐久, 新上限)。
- 船体替换成功后在同一事务内调用 `FleetService.reconcile_flagship_after_hull_change()`：旗舰 archetype 随 hull 变化，无法指挥新 archetype 的舰长会被释放并发布空的 `fleet.captain_assigned` 事件。
- 安装/卸下同一步维护 `ship.module_instances`：单槽替换用 `ShipModules.install_slot()` 生成全新实例（满状态、新 id），货舱追加用 `append_cargo()`、按位置删除用 `remove_cargo()`，避免旧条件串到新模块。
- `ship.uninstall_module` 只允许卸下导航/安全/客舱/货舱，船体与锅炉返回 required_module。
- `ship.craft_module` 复用 CraftOps：仓库材料优先、再扣船上普通货物，扣 craft_cost 后生成打造订单（不再即时推进时间/入库），发布事件 ship.craft_ordered；成品等 ready_at 后由 CraftOps.settle_orders 写入下单港仓库。
- install 成功后调用 `VictoryService.check()`，结果放入 data.victory，新通关时追加 run.victory_achieved 事件。
- 所有修改在命令事务内完成，失败自动回滚。

## 重点逻辑

### `install_module(params, context)`

- 先由 install_blockers 生成完整 blocker 列表；失败时返回第一个 blocker 作为 error_code。
- 替换逻辑只移除当前槽位的旧模块（货舱按 replace_module_id），旧件进当前港仓库后再装新件。
- 购买价与打造费通过 `state.record_expense()` 计入统计支出。

### `uninstall_module(params, context)`

- 从船只配置移除模块并写入当前港仓库；船体/锅炉由 uninstall_blockers 拒绝。

### `craft_module(params, context)`

- CraftOps.craft 返回材料来源明细（warehouse/cargo）、order_id/ready_at/remaining_hours 与当前订单列表；命令层只负责设施检查、事件与结果包装。

模块索引：[framework/application](../README.md)
