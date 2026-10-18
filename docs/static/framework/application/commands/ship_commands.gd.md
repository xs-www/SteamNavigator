# `framework/application/commands/ship_commands.gd`

> 作用：船厂最小流程：购买并安装船体/锅炉/货舱/导航/安全/客舱。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipCommands` | L1 |

## 契约与约束

- 必须在有 shipyard 设施的港口且处于港口状态。
- 货币、槽位、舱位、重量与解锁声誉任一不满足即失败。
- 替换船体时重新校验货舱/客舱槽位并把耐久设为新船体上限。
- 所有修改在命令事务内完成，失败自动回滚。

模块索引：[framework/application](../README.md)
