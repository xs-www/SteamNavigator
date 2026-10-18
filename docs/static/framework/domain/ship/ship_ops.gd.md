# `framework/domain/ship/ship_ops.gd`

> 作用：船只组合的纯函数：模块/货物/煤水/旅客重量、容量、槽位、持续时间与派生属性。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipOps` | L1 |

## 契约与约束

- 总重量包含已装模块、货物、煤、水、旅客；合同货箱同样计入。
- 货舱容量是重量容量；合同货物不可出售/抛弃。
- 派生属性计算船体基础、锅炉、导航、安全、模块 modifiers 与岗位 modifiers。
- `validate_configuration()` 检查必需船体/锅炉、货舱/客舱槽位与耐久上限。
- `install_blockers()` 是 ship.install_module 命令与船厂 ViewModel 共用的校验源：声誉、货币、槽位、重量替换差量。

## 重点逻辑

### `stats(hub, ship)`

- 先取 hull.base_speed * boiler.speed_mul，再乘导航 speed_mul。
- 风险汇总 hull.base_risk + nav.risk_add + safety.risk_add + 模块/岗位 risk modifiers。
- 员工/安全设备的 damage/repair 修正以乘算累积；最终 clamp 到合理范围。

模块索引：[framework/domain](../README.md)
