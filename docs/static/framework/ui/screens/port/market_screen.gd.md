# `framework/ui/screens/port/market_screen.gd`

> 作用：港口市场页面（图标直接交易）：账册摘要 + 行情图标网格（左键 +1 / 右键清空 / 拖拽交易）+ 补给区块；整块市场面板是卖出落点，把拖入的船舱 / 仓库货物映射成 `trade.sell {source}` 命令。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MarketScreen` | L1 |
| `command_requested (signal)` | L35 |
| `SUPPLY_CARD_SCENE` | L37 |
| `TILE_SCRIPT` | L38 |
| `ZONE_SCRIPT` | L39 |
| `MARKET_GRID_COLUMNS` | L43 |
| `GRID_SEPARATION` | L44 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L50 |
| `handle_sell_drop(data: Dictionary) -> void` | L77 |

Direct-manipulation port market page (Bounty Train style).

The icon grid replaces the old buy/sell quantity buttons: a market tile holds a
pending amount (left click +1, right click clears) and dragging it to the left
backpack buys into cargo / warehouse. Conversely the whole market panel is the
sell drop target for `cargo_item` / `warehouse_item` payloads.

## 外观来源（外部贴图 + SNSkin）
- 「市场账册摘要」用 Theme 变体 `SNParchmentPanel`（暖纸面），纸面正文改用
  `SNSkin.color("ink.primary")` / `paper.ink_muted`；行情格子是 `SNItemTile`
  （`panel_recess` / `panel_steel` 皮肤纹理）；整个面板的落点用透明
  `SNDropZone`（高亮时仍是皮肤纹理 + token 染色）。
- 其余文字颜色取 `SNSkin.color(token)`（text.light / text.muted /
  brass.highlight / state.water）。
- 尺寸约束：行情网格 4 列（108 px 格子 + 8 px 间距），适配 Shell 提供的
  640 px 右侧面板（内层 592 px）；`_grid_label` 保持 72 px 最小宽。

## 契约与约束
- `bind(view_model, translate)` 可重复调用：每次先清空自建子节点再重建。
- ViewModel 字段按 `docs/design/MARKET_UI_REFACTOR.md` §3；行情行 `icon` 已由
  Shell 解析成 `Texture2D`，本页不解析资产路径。
- 图标行 `stock<=0` 或 `buyable=false` 时不可拖拽（仍显示，标注「仅收购」）。
- 待交易上限只按 `stock` 设置，不预扣金币与剩余载重：数量可以点到库存上限，
  金币 / 载重不足由 `trade.buy` 失败并在状态栏报错（页面刷新后归零）。
- 拖入市场面板的载荷 kind 只认 `cargo_item` / `warehouse_item`，命令固定为
  `trade.sell {item_id, amount, source}`。
- `_grid_label` / `_label` / `_loc` 是测试与旧调用方依赖的 helper，保留签名。

模块索引：[framework/ui](../../README.md)
