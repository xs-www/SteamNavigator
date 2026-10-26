# `framework/ui/components/sn_carry_ghost.gd`

> 作用：市场「拿起 / 放下」手势的光标幽灵：把被拿起的商品图标、名称、×数量与预计消费画成跟随鼠标的浮层（点击落点放下、右键取消），由 Shell 挂在页面滚动区之外的浮层里，任何页面都可复用。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNCarryGhost` | L1 |
| `POINTER_OFFSET` | L61 |
| `PANEL_STYLE_ID` | L62 |
| `BRASS_TINT_TOKEN` | L63 |
| `CONTENT_MARGIN` | L64 |
| `begin(icon: Texture2D, title: String, amount: int, hint: String = "", cost_text: String = "") -> void` | L137 |
| `set_amount(amount: int) -> void` | L164 |
| `end() -> void` | L178 |
| `is_carrying() -> bool` | L185 |
| `amount() -> int` | L189 |
| `cost_text() -> String` | L195 |
| `carried_icon() -> Texture2D` | L201 |
| `place_at(mouse: Vector2) -> Vector2` | L207 |

## 场景化（P0，见 docs/specs/UI_SCENE_MIGRATION.md）
静态骨架在 `sn_carry_ghost.tscn`：根 `Control` 挂本脚本（`visible = false`、
`mouse_filter = IGNORE`、根节点引用 `steam_navigator_theme.tres`），子树为
`GhostPanel(PanelContainer, IGNORE) → GhostRow(HBoxContainer, separation 8, IGNORE) →
Icon(TextureRect, 40×40, expand_mode=1, stretch_mode=5, IGNORE) +
Labels(VBoxContainer, separation 1, IGNORE) → Title(13) / Amount(14) /
Cost(11, 初始隐藏) / Hint(10)`，四行都是 `Label`、`autowrap_mode=0`、`mouse_filter=IGNORE`。
层级、尺寸、间距、字号、初始隐藏都是设计常量，只写在场景里。

**实例化契约（R1）**：调用方必须
`preload("res://framework/ui/components/sn_carry_ghost.tscn").instantiate()`，
禁止 `SNCarryGhost.new()`——脚本 `.new()` 没有场景子树，`_ensure_refs()` 全部解析为空，
幽灵会静默空白；节点名 `GhostPanel` / `GhostRow` / `Icon` / `Labels` / `Title` /
`Amount` / `Cost` / `Hint` 是查找契约（R2），不要改名。脚本只做延迟解析
（`_ensure_refs()`）、固定黄铜色调、`_sync_bounds()`、`place_at()` 与跟随鼠标，
允许在未进树时先 `begin()`（R3）。

Pointer-follow ghost for the direct-manipulation market interaction
(v0.2.0-dev.3 feedback #1: the icon must float on the cursor while the player
carries the goods, and the count follows the pointer).

The page owns the *pending* amount (`SNItemTile`) and decides when a payload is
picked up; this control only paints the carried stack next to the cursor. It is
mounted on a shell overlay outside the `PageScroll`, so the page margins and
the scroll container can never clip it.

The ghost carries the **selected amount** (`×N`) plus an optional estimated cost
line (`预计消费 %d 金`): the market tile badge shows the remaining stock instead,
so the two numbers never duplicate each other.

## 外观来源（外部贴图 + SNSkin）
- 底板取 `SNSkin.style("panel_steel")` 克隆，内容边距 10 / 6，并以
  `modulate_color = SNSkin.color("brass.highlight")` 表示「手上拿着货」；
  图标 40 px、四行字号写在场景里；文字色取 `text.light` / `brass.highlight` /
  `text.muted`，全部由脚本写 token（场景里不复制颜色值，R4）。
- 不新增 `StyleBoxFlat`、不写十六进制色、不硬编码皮肤路径。
- 根节点与整棵子树的 `mouse_filter` 全部是 `IGNORE`：光标幽灵绝不吞鼠标事件，
  落点点击仍由 `SNDropZone` / `SNItemTile` 处理。

## 契约与约束
- `begin(icon, title, amount, hint, cost_text)` 开始 / 更新携带；`cost_text` 为空
  时隐藏预计消费行（非市场页面 / 没有单价时）。`set_amount()` 只改数量
  （归零等价于 `end()`）；`end()` 收起且停止 `_process`。
- 预计消费行在 `×数量` 下方、字号更小；文本由 Shell 用 `ui.market.estimated_cost`
  格式化（`unit_price × amount`），组件本身不计算金额。
- 跟随在 `_process` 里读 `get_viewport().get_mouse_position()`，偏移固定
  `POINTER_OFFSET`（+18, +12）并钳制在视口内；`Viewport.gui_is_dragging()` 为真
  时隐藏——原生拖拽预览已经跟着鼠标，两个幽灵不该重叠（原生拖拽保留为兼容手势）。
- `place_at(mouse)` 是纯函数：返回钳制后的左上角坐标。headless 测试里鼠标恒为
  (0,0)，测试用 `place_at(Vector2.ZERO)` 断言偏移与视口钳制，不依赖真实鼠标。
- 数量 / 金额只由宿主页面写入；本组件不校验库存 / 载重 / 金币（命令层负责失败提示）。

模块索引：[framework/ui](../README.md)
