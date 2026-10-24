# `framework/ui/screens/port/supply_screen.gd`

> 作用：补给与维修页面场景：绑定 SupplyView，组合煤水决策卡、资源摘要与维修操作；作为泊位侧栏时按 620 px 窄列设计（卡片单列堆叠、badge 可换行），外层 PageScroll 负责竖向滚动。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SupplyScreen` | L1 |
| `command_requested (signal)` | L25 |
| `SUPPLY_CARD_SCENE` | L27 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L32 |

Supply and repair presentation screen.

The shell owns queries and commands. This scene only binds a SupplyView
dictionary, renders it, and emits the player's command intent.

Layout: the screen shares the window with the persistent 3D port stage, so it
is designed for a 620 px berth sidebar. The coal/water cards stack in a single
column and the summary badges flow onto an extra row instead of widening the
page; the outer PageScroll owns vertical scrolling.

## 外观来源（外部贴图 + SNSkin）
- 摘要与维修面板用 Theme 变体 `SNInsetPanel` / `SNElevatedPanel`（钢制）；
  `SNBadge` 负责四色状态；煤水卡内部由 `SNSupplyCard` 自己换皮。
- 文字与状态色取 `SNSkin.color(token)`（text.light / text.muted /
  brass.highlight / state.danger），本文件无内联十六进制色与 StyleBoxFlat。
- 尺寸约束：维修按钮高度 38（`SNPrimaryButton`）、煤水卡 `custom_minimum_size =
  (0, 0)` + EXPAND_FILL、badge `HFlowContainer` 自动换行均保持不变。

模块索引：[framework/ui](../../README.md)
