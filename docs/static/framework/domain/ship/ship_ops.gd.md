# `framework/domain/ship/ship_ops.gd`

> 作用：船只组合的纯函数：模块/货物/煤水/旅客/随船运输重量、容量、槽位、安装/卸下规则与派生属性。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipOps` | L1 |

## 契约与约束

- 总重量包含已装模块、随船运输模块（transit）、货物、煤、水、旅客；合同货箱同样计入。
- 随船运输模块计入总重量但不占货舱容量；仓库中的模块不随船。
- 货舱容量是重量容量；合同货物不可出售/抛弃。
- 每个 cargo stack 保存 total_cost；买入累加，卖出/抛弃按数量比例扣减。
- `cargo_total_cost()` 与 `cargo_average_cost()` 是 UI 显示库存成本的唯一口径。
- 派生属性计算船体基础、锅炉、导航、安全、模块 modifiers 与岗位 modifiers。
- `validate_configuration()` 检查必需船体/锅炉、货舱/客舱槽位与耐久上限。
- `module_damage_points(hub, ship)` 按「模块重量 × 缺失耐久比例」把部件损耗换算成维修点数；`has_disabled_module()` 判断是否存在 0 状态的模块实例。模块性能影响留到战斗阶段。
- `install_blockers(hub,state,module_id,source,replace_module_id)` 是 ship.install_module 与船厂 ViewModel 共用的校验源：来源库存、合同解锁、声誉、货币、槽位与最终配置重量差量。
- 合同解锁：模块出现在任一 contract.rewards.unlock_ids 且不在 player.unlocks 时返回 locked_by_contract；unlock_contract_id 给出解锁它的合同模板。
- 单槽模块自动替换（不再返回 slot_occupied）；货舱槽满且未指定 replace_module_id 时返回 cargo_slots_full；同 ID 货舱在有空槽时允许重复购买。
- `uninstall_blockers()` 只允许卸下货舱/导航/安全/客舱，船体与锅炉返回 required_module。

## 重点逻辑

### `stats(hub, ship)`

- 先取 hull.base_speed * boiler.speed_mul，再乘导航 speed_mul。
- 风险汇总 hull.base_risk + nav.risk_add + safety.risk_add + 模块/岗位 risk modifiers。
- 员工/安全设备的 damage/repair 修正以乘算累积；最终 clamp 到合理范围。

### `install_blockers(...)`

- 重量按最终配置计算：current_weight + 新件 - 被替换旧件 - transit 来源已在船上的重量。
- 单槽替换的 replaced_weight 取自当前槽位；船体替换同时把 max_weight 切换为新船体上限并校验货舱/客舱槽位。

模块索引：[framework/domain](../README.md)
