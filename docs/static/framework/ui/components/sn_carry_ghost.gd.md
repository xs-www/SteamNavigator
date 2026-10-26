# `framework/ui/components/sn_carry_ghost.gd`

> 作用：市场「拿起 / 放下」手势的光标幽灵：把被拿起的商品图标、名称与 ×数量画成跟随鼠标的浮层（点击落点放下、右键取消），由 Shell 挂在页面滚动区之外的浮层里，任何页面都可复用。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNCarryGhost` | L1 |
| `POINTER_OFFSET` | L36 |
| `ICON_SIZE` | L37 |
| `CONTENT_MARGIN` | L38 |
| `TITLE_FONT_SIZE` | L39 |
| `AMOUNT_FONT_SIZE` | L40 |
| `HINT_FONT_SIZE` | L41 |
| `begin(icon: Texture2D, title: String, amount: int, hint: String = "") -> void` | L61 |
| `set_amount(amount: int) -> void` | L79 |
| `end() -> void` | L93 |
| `is_carrying() -> bool` | L100 |
| `amount() -> int` | L104 |
| `carried_icon() -> Texture2D` | L110 |
| `place_at(mouse: Vector2) -> Vector2` | L116 |

Pointer-follow ghost for the direct-manipulation market interaction
(v0.2.0-dev.3 feedback #1: the icon must float on the cursor while the player
carries the goods, and the count follows the pointer).

The page owns the *pending* amount (`SNItemTile`) and decides when a payload is
picked up; this control only paints the carried stack next to the cursor. It is
mounted on a shell overlay outside the `PageScroll`, so the page margins and
the scroll container can never clip it.

## 外观来源（外部贴图 + SNSkin）
- 底板取 `SNSkin.style("panel_steel")` 克隆，内容边距 10 / 6，并以
  `modulate_color = SNSkin.color("brass.highlight")` 表示「手上拿着货」；
  图标 40 px，文字色取 `text.light` / `brass.highlight` / `text.muted`。
- 不新增 `StyleBoxFlat`、不写十六进制色、不硬编码皮肤路径。
- 根节点与整棵子树的 `mouse_filter` 全部是 `IGNORE`：光标幽灵绝不吞鼠标事件，
  落点点击仍由 `SNDropZone` / `SNItemTile` 处理。

## 契约与约束
- `begin(icon, title, amount, hint)` 开始 / 更新携带；`set_amount()` 只改数量
  （归零等价于 `end()`）；`end()` 收起且停止 `_process`。
- 跟随在 `_process` 里读 `get_viewport().get_mouse_position()`，偏移固定
  `POINTER_OFFSET`（+18, +12）并钳制在视口内；`Viewport.gui_is_dragging()` 为真
  时隐藏——原生拖拽预览已经跟着鼠标，两个幽灵不该重叠（原生拖拽保留为兼容手势）。
- `place_at(mouse)` 是纯函数：返回钳制后的左上角坐标。headless 测试里鼠标恒为
  (0,0)，测试用 `place_at(Vector2.ZERO)` 断言偏移与视口钳制，不依赖真实鼠标。
- 数量只由宿主页面写入；本组件不校验库存 / 载重 / 金币（命令层负责失败提示）。

模块索引：[framework/ui](../README.md)
