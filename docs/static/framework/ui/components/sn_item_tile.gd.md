# `framework/ui/components/sn_item_tile.gd`

> 作用：市场 / 船只背包的单个物品图标格子：显示图标、名称、可选副标题与价格信息与数量角标；左键单击（release）待交易数量 +1（不超过 `max_pending`）、右键清空，可拖拽时把带 `kind` 与 `amount` 的载荷交给 SNDropZone。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNItemTile` | L1 |
| `pending_changed (signal)` | L58 |
| `TILE_MIN_SIZE` | L60 |
| `ICON_HEIGHT` | L61 |
| `DRAG_PREVIEW_ICON` | L62 |
| `BADGE_MODE_PENDING` | L65 |
| `BADGE_MODE_REMAINING` | L66 |
| `configure(data: Dictionary) -> void` | L102 |
| `bind(data: Dictionary) -> void` | L123 |
| `increment_pending() -> void` | L128 |
| `clear_pending() -> void` | L139 |
| `drag_payload() -> Dictionary` | L149 |
| `icon_texture() -> Texture2D` | L160 |
| `pending_badge() -> SNBadge` | L165 |

One icon tile of the direct-manipulation market screen.

The tile owns only the *pending* amount (the quantity waiting on the icon);
the hosting screen re-binds the page after a command, which resets it. A left
click bumps the pending amount **on release** (a drag also starts with a left
press, so incrementing on press would double-count the dragged unit); right
click clears it; dragging emits a copy of the configured payload with
`amount = max(pending, 1)`.

The subtitle line is optional: an empty `subtitle` hides the node entirely
(2026-10-28 text slimming — market tiles only show "仅收购" when the row cannot
be bought; category / material tags no longer render), so tiles without copy
keep the same title / meta / badge contract.

## 角标语义（badge_mode）
- `pending`（默认，船舱 / 仓库格）：右上角 `×N` = 已选待交易数量，pending=0 时隐藏。
- `remaining`（市场行情格）：右上角始终可见，纯数字 = `max(0, stock - pending)`，
  即「点击购买后还剩多少」；玩家已选数量由光标幽灵 `SNCarryGhost` 的 `×N` 显示，
  角标不再重复它。每 +1 立即刷新。

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
  draggable, payload: Dictionary, locked?, badge_mode?, stock?}`；`payload` 必须带顶层 `kind`。
  `badge_mode` 缺省为 `"pending"`，旧调用方（船舱 / 仓库格）行为不变。
  `subtitle` 为空字符串时副标题行自动隐藏（不占行、不进 tooltip）；市场格现在
  只在 `buyable=false` 时传入「仅收购」，其余行为不带副标题。
- 委托货 / 不可交易行由 `draggable=false` + `locked=true` 表达，同时
  `max_pending=0`，左键与拖拽都无效。
- 左键只在 **release** 时 +1；拖拽起手（press → `_get_drag_data`）不改变 pending，
  `_dragging` 期间的释放事件只复位标记、不 +1，因此「点 3 下再拖」携带 3 件。
- `max_pending` 只反映该图标当前的**可用数量**（市场 stock / 船舱可售 / 仓库存量），
  不预扣金币与剩余载重：数量仍可点到库存上限，金币 / 载重不足由命令层失败并在
  状态栏报错，页面刷新后 pending 归零。这是本轮有意保留的边界，不是 bug。
- `drag_payload()` 返回副本并把 `amount` 设为 `max(pending, 1)`，测试可直接调用；
  `_get_drag_data()` 复用同一份载荷并挂拖拽预览。
- `drop_host` 是「拿起 / 放下」的宿主落点（`SNDropZone`）：市场商品被拿起后，
  点船舱 / 仓库区里的**子格子**也要放下货物，而子格子是 `MOUSE_FILTER_STOP`，
  事件的落点点击到不了 zone。因此左键 release 先问
  `drop_host.try_click_offer()`，被落点消费就 return（不算自己的 +1）；没有 offer
  时行为与旧版一致（pending +1）。原生拖拽路径完全不受影响。

模块索引：[framework/ui](../README.md)
