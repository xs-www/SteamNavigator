# `framework/ui/components/sn_cargo_hold_panel.gd`

> 作用：市场页左侧「船只背包」：顶部载重 / 货舱摘要，上半船舱货物（`SNDropZone` + 图标格子，委托货带锁定标记），下半当前港仓库材料；把图标拖拽映射成买卖 / 存取命令意图。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNCargoHoldPanel` | L1 |
| `command_requested (signal)` | L37 |
| `TILE_SCRIPT` | L39 |
| `ZONE_SCRIPT` | L40 |
| `TILE_COLUMNS` | L42 |
| `ZONE_MIN_HEIGHT` | L43 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L55 |
| `cargo_zone() -> Control` | L71 |
| `warehouse_zone() -> Control` | L75 |
| `set_offer(offer: Dictionary) -> void` | L81 |
| `clear_offer() -> void` | L88 |
| `handle_cargo_drop(data: Dictionary) -> void` | L93 |
| `handle_warehouse_drop(data: Dictionary) -> void` | L113 |

Left-hand "ship hold" column of the direct-manipulation market page.

Layout: summary (weight / cargo) on top, then two skin-backed drop zones:
`船舱货物` (left accepts `market_item` for buy-into-cargo and `warehouse_item`
for take-from-warehouse) and `港口仓库` (accepts `market_item` for buy-into-
warehouse and `cargo_item` for store-into-warehouse). The panel only emits
command intent; the Shell executes `trade.*` / `warehouse.*`.

## 外观来源（外部贴图 + SNSkin）
- 外层用 Theme 变体 `SNPanel`；两个落点由 `SNDropZone` 提供
  `panel_recess` / `panel_steel` 纹理高亮，本面板不手搓 StyleBox。
- 文字颜色全部取 `SNSkin.color(token)`（text.light / text.muted /
  brass.highlight / state.warning），图标格子里的锁定标记来自
  `SNSkin.icon("status_locked")`，无硬编码路径与十六进制色。
- 尺寸：固定 360 px 宽（Shell 设置），格子 2 列；面板自身不设最小高度，
  竖直方向随内容增长、由外层 PageScroll 滚动。

## 契约与约束
- `bind(view_model, translate)` 可重复调用：每次先清空自建子节点再重建。
- ViewModel 字段按 `docs/design/MARKET_UI_REFACTOR.md` §3：`ship.hold` /
  `warehouse.materials` 的 `icon` 已由 Shell 解析成 `Texture2D`。
- 落点命令固定：market_item→cargo 区 `trade.buy{destination:"cargo"}`、
  market_item→仓库区 `trade.buy{destination:"warehouse"}`、
  cargo_item→仓库区 `warehouse.store_materials`、
  warehouse_item→cargo 区 `warehouse.take_materials`。
- 委托货（`is_contract`）格子不可拖拽、不产生命令。
- `set_offer(offer)` / `clear_offer()` 是「拿起 / 放下」手势的入口：把市场商品
  offer 转发给船舱 / 仓库两个 `SNDropZone`，玩家点一下落点即可放下。格子自己
  也把 `drop_host` 指向所在 zone，保证点 zone 内的子格子同样能放下。

模块索引：[framework/ui](../README.md)
