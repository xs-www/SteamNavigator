# `framework/application/commands/ship_commands.gd`

> 作用：船厂流程：购买并安装船体/锅炉/货舱/导航/安全/客舱。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipCommands` | L1 |

## 契约与约束

- 必须在有 shipyard 设施的港口且处于港口状态。
- 槽位/重量/货币/声誉失败原因由 `ShipOps.install_blockers()` 统一生成，避免 UI 与命令漂移。
- 替换船体时重新校验货舱/客舱槽位并把耐久设为新船体上限。
- 所有修改在命令事务内完成，失败自动回滚。

模块索引：[framework/application](../README.md)
