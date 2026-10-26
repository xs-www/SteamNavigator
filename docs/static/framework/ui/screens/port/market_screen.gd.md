# `framework/ui/screens/port/market_screen.gd`

> 作用：港口市场页面（图标直接交易）：账册摘要 + 行情图标网格（左键 +1 / 右键清空 / 拖拽交易）+ 补给区块；行情格右上角显示剩余库存，整块市场面板是卖出落点，把拖入的船舱 / 仓库货物映射成 `trade.sell {source}` 命令。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MarketScreen` | L1 |
| `command_requested (signal)` | L55 |
| `carry_changed (signal)` | L57 |
| `SUPPLY_CARD_SCENE` | L59 |
| `TILE_SCRIPT` | L60 |
| `ZONE_SCRIPT` | L61 |
| `MARKET_GRID_COLUMNS` | L65 |
| `GRID_SEPARATION` | L66 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L74 |
| `handle_sell_drop(data: Dictionary) -> void` | L101 |
| `carrying_tile() -> Control` | L122 |
| `cancel_carry() -> void` | L145 |

Direct-manipulation port market page (Bounty Train style).

The icon grid replaces the old buy/sell quantity buttons: a market tile holds a
pending amount (left click +1, right click clears) and dragging it to the left
backpack buys into cargo / warehouse. Conversely the whole market panel is the
sell drop target for `cargo_item` / `warehouse_item` payloads.

The market tile's top-right badge shows the **remaining stock**
(`badge_mode: "remaining"`, `max(0, stock - pending)`) instead of the selected
amount: the selected amount is already painted on the cursor ghost
(`SNCarryGhost`), together with the estimated cost.

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
- 行情格角标是 `remaining` 语义（始终可见，纯数字 = `stock - pending`）；meta
  只显示单价 + 趋势，玩家已选数量只在光标幽灵上显示，两处不重复。
- 图标行 `stock<=0` 或 `buyable=false` 时不可拖拽（仍显示，标注「仅收购」）。
- 待交易上限只按 `stock` 设置，不预扣金币与剩余载重：数量可以点到库存上限，
  金币 / 载重不足由 `trade.buy` 失败并在状态栏报错（页面刷新后归零）。
- 拖入市场面板的载荷 kind 只认 `cargo_item` / `warehouse_item`，命令固定为
  `trade.sell {item_id, amount, source}`。
- `_grid_label` / `_label` / `_loc` 是测试与旧调用方依赖的 helper，保留签名。

## 拿起 / 放下（feedback #1）
- `signal carry_changed(offer)`：市场商品格子 `pending_changed` 的聚合结果。offer
  是 `{kind:"market_item", item_id, name, icon, amount, unit_price}`，空字典表示
  放下 / 取消。Shell 用它驱动光标幽灵（SNCarryGhost，显示 `×amount` 与
  `unit_price × amount` 的预计消费）并把 offer 转发给船舱 / 仓库落点
  （`SNCargoHoldPanel.set_offer`），玩家点落点即执行 `trade.buy`。
- 同时只有一个格子被「拿起」：切换携带时先 `clear_pending()` 旧格子（避免重入：
  先清 `_carry_tile` 再清旧格子，旧格子的 0 事件不会再发 carry_changed）。
- 右键取消走 `_input`（格子 / 落点是 `MOUSE_FILTER_STOP`，普通 `_gui_input`
  收不到别处的右键）：清 pending 并发 `carry_changed({})`。
- 市场格子仍是原生拖拽来源，拖拽与拿起可共存；`_clear()` 会丢弃携带引用，
  页面重建（命令成功）后 pending 与幽灵一起归零。

模块索引：[framework/ui](../../README.md)
