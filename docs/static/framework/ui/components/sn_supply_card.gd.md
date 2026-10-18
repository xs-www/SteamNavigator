# `framework/ui/components/sn_supply_card.gd`

> 作用：单种补给品的决策卡：存量、可补上限、价格、港存、预计续航和购买操作。

- 关键依赖：`SNResourceMeter`、`SNBadge`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSupplyCard` | L1 |
| `command_requested (signal)` | L7 |
| `bind(data: Dictionary, title: String, blocker_labels: Array = []) -> void` | L13 |

## 契约与约束

- 只渲染传入的 ViewModel 并发出 `command_requested(command, params)`；不访问 CommandBus。
- 最大购买量由查询层计算；卡片禁用 +5/+10/补满时必须已有明确的 blocker 文本。
- `maximum` 是补给后可达上限，不是固定舱容；UI 文案使用“可补至”避免误导。

模块索引：[framework/ui](../README.md)
