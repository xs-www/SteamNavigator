# `framework/application/queries/shipyard_view.gd`

> 作用：船厂独立界面 ViewModel：当前模块、槽位占用和所有可购买模块的限制原因。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipyardViewQuery` | L1 |

## 契约与约束

- 与 `ship.install_module` 共用 `ShipOps.install_blockers()`，UI 不复制规则。
- `candidates[].blockers` 给出全部失败码；`can_install` 为 false 时 UI 禁用按钮。
- 已安装模块标记 installed，并附加 already_installed 限制。

模块索引：[framework/application](../README.md)
