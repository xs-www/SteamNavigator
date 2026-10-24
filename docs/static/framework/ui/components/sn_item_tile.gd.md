# `framework/ui/components/sn_item_tile.gd`

> 作用：市场 / 船只背包的单个物品图标格子：显示图标、名称、分类与价格信息与待交易数量角标；左键单击（release）待交易数量 +1（不超过 `max_pending`）、右键清空，可拖拽时把带 `kind` 与 `amount` 的载荷交给 SNDropZone。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNItemTile` | L1 |
| `pending_changed (signal)` | L39 |
| `TILE_MIN_SIZE` | L41 |
| `ICON_HEIGHT` | L42 |
| `DRAG_PREVIEW_ICON` | L43 |
| `configure(data: Dictionary) -> void` | L72 |
| `bind(data: Dictionary) -> void` | L91 |
| `increment_pending() -> void` | L96 |
| `clear_pending() -> void` | L107 |
| `drag_payload() -> Dictionary` | L117 |
| `icon_texture() -> Texture2D` | L128 |
| `pending_badge() -> SNBadge` | L133 |

One icon tile of the direct-manipulation market screen.

The tile owns only the *pending* amount (the quantity waiting on the icon);
the hosting screen re-binds the page after a command, which resets it. A left
click bumps the pending amount **on release** (a drag also starts with a left
press, so incrementing on press would double-count the dragged unit); right
click clears it; dragging emits a copy of the configured payload with
`amount = max(pending, 1)`.

## 外观来源（外部贴图 + SNSkin）
- 底板取 `SNSkin.style("panel_recess")`；悬停 / 有待交易数量时改用
  `SNSkin.style("panel_steel")` 克隆，并以 `modulate_color = SNSkin.color(...)`
  区分（state.water = 悬停，brass.highlight = 有数量）；内外边距固定 9 / 8 / 9 / 10，
  图标区不随状态跳动。
- 文字颜色取 `SNSkin.color(token)`；数量角标复用 `SNBadge`（Theme 变体），
  锁定标记用 `SNSkin.icon("status_locked")`，不写路径与十六进制色。
- 尺寸：整格 `custom_minimum_size = (108, 132)`，图标区 58 px，文字 13 / 11；
  行情网格 4 列（展开填充 592 px 右侧面板），背包网格 2 列。

## 契约与约束
- `configure()` 接收 `{title, subtitle, meta, icon: Texture2D, max_pending,
  draggable, payload: Dictionary, locked?}`；`payload` 必须带顶层 `kind`。
- 委托货 / 不可交易行由 `draggable=false` + `locked=true` 表达，同时
  `max_pending=0`，左键与拖拽都无效。
- 左键只在 **release** 时 +1；拖拽起手（press → `_get_drag_data`）不改变 pending，
  `_dragging` 期间的释放事件只复位标记、不 +1，因此「点 3 下再拖」携带 3 件。
- `max_pending` 只反映该图标当前的**可用数量**（市场 stock / 船舱可售 / 仓库存量），
  不预扣金币与剩余载重：数量仍可点到库存上限，金币 / 载重不足由命令层失败并在
  状态栏报错，页面刷新后 pending 归零。这是本轮有意保留的边界，不是 bug。
- `drag_payload()` 返回副本并把 `amount` 设为 `max(pending, 1)`，测试可直接调用；
  `_get_drag_data()` 复用同一份载荷并挂拖拽预览。

模块索引：[framework/ui](../README.md)
