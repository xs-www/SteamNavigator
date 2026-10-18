# `framework/application/queries/port_view.gd`

> 作用：主界面 ViewModel：当前港、市场、目的地、船只、委托、策略、情报、通知与统计。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PortViewQuery` | L1 |

## 契约与约束

- 所有数值只读复制；市场行同时给出库存、单价、持有与可售数量。
- 目的地只列当前港的相邻航线，标记未知设施与风险。
- 委托 ViewModel 额外提供目的港名称键与期限显示文本。
- 不返回 ContentDefinition 或 GameState 内部引用。

模块索引：[framework/application](../README.md)
