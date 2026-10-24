# `framework/ui/screens/port/market_screen.gd`

> 作用：港口市场页面场景：展示行情、真实价格历史、持仓成本及买卖操作；作为泊位侧栏时按 620 px 窄列设计（纵向商品条目列表，替代旧九列表格），外层 PageScroll 负责竖向滚动。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MarketScreen` | L1 |
| `command_requested (signal)` | L29 |
| `SPARKLINE_SCENE` | L31 |
| `SUPPLY_CARD_SCENE` | L32 |
| `ENTRY_SEPARATION` | L34 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L39 |

Port market presentation screen.

The shell supplies a complete market ViewModel, including intelligence
trends. Trading actions are emitted as intent and executed by the shell.

Layout: the screen shares the window with the persistent 3D port stage, so
it is designed for a 620 px berth sidebar. Goods render as a vertical list of
compact entries instead of the old full-width nine-column grid; rows break
vertically rather than clipping horizontally, and the outer PageScroll owns
vertical scrolling (the screen itself adds no ScrollContainer).

## 外观来源（外部贴图 + SNSkin）
- 「市场账册摘要」用 Theme 变体 `SNParchmentPanel`（暖纸面），纸面正文改用
  `SNSkin.color("ink.primary")`（数据行）/ `paper.ink_muted`（说明），保证纸面
  对比度；商品行仍用 `SNInsetPanel`（钢制凹槽）承载密集价格数据。
- 其余文字颜色取 `SNSkin.color(token)`（text.light / text.muted / state.water /
  state.success / state.danger），趋势色与 sparkline 线色同源于 token。
- 买卖数量按钮用 `SNCompactButton`（小铭牌）并保持 `custom_minimum_size = (34, 28)`；
  数量按钮宽度不足 80，按规范不加图标以免溢出。
- 尺寸约束：`_grid_label` 的 72 px 最小宽、趋势单元格 136 px、sparkline 64×24、
  行间距 7 与所有节点结构/文本不变。

模块索引：[framework/ui](../../README.md)
