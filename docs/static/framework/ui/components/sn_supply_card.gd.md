# `framework/ui/components/sn_supply_card.gd`

> 作用：单种补给品的决策卡：存量、可补上限、价格、港存、预计续航和购买操作。

- 关键依赖：`SNResourceMeter`、`SNBadge`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSupplyCard` | L1 |
| `command_requested (signal)` | L10 |
| `COLOR_TEXT_MUTED` | L12 |
| `COLOR_TEXT` | L13 |
| `COLOR_WARNING` | L14 |

## 契约与约束

- 只渲染传入的 ViewModel 并发出 `command_requested(command, params)`；不访问 CommandBus。
- 最大购买量由查询层计算；卡片禁用 +5/+10/补满时必须已有明确的 blocker 文本。
- `maximum` 为当前可达物理上限 capacity（不再是补给后可达上限）；上限被另一项补给占用时用 cap_loss 驱动 meter 的右端损失带，文案使用“可补至/上限损失/剩余可装”。
- bind() 第 4 参 tr: Callable 可省略；缺省或缺键时回退内置中文，UI Kit 展示场景无需改动。

模块索引：[framework/ui](../README.md)
