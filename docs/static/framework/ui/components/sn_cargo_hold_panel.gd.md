# `framework/ui/components/sn_cargo_hold_panel.gd`

> 作用：市场页左侧「船只背包」：顶部载重 / 货舱摘要，上半船舱货物（`SNDropZone` + 图标格子，委托货带锁定标记），下半当前港仓库材料；把图标拖拽映射成买卖 / 存取命令意图。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNCargoHoldPanel` | L1 |
| `command_requested (signal)` | L34 |
| `TILE_SCRIPT` | L36 |
| `ZONE_SCRIPT` | L37 |
| `TILE_COLUMNS` | L39 |
| `ZONE_MIN_HEIGHT` | L40 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L52 |
| `cargo_zone() -> Control` | L68 |
| `warehouse_zone() -> Control` | L72 |
| `handle_cargo_drop(data: Dictionary) -> void` | L77 |
| `handle_warehouse_drop(data: Dictionary) -> void` | L97 |

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

模块索引：[framework/ui](../README.md)
