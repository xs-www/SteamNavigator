# `framework/ui/components/sn_ship_view.gd`

> 作用：船厂中央船体视图；正常态承载 2.5D 船体/程序化船身，改装态绘制每船侧视/俯视蓝图线稿、模块拖放槽位，以及 hull `weapon_sockets[].blueprint` 驱动的武器槽位框和高亮。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNShipView` | L1 |
| `slot_drop_requested (signal)` | L54 |
| `slot_activated (signal)` | L55 |
| `SLOT_H` | L70 |
| `CARGO_SLOT_H` | L71 |
| `BLUEPRINT_SOCKET_MIN_SIZE` | L72 |
| `BLUEPRINT_SOCKET_MAX_SIZE` | L73 |
| `BLUEPRINT_SIDE_RATIO` | L74 |
| `BLUEPRINT_VIEW_GAP` | L75 |
| `SLOT_DOCK_MARGIN` | L76 |
| `SLOT_DOCK_GAP` | L77 |
| `SECTION_TEXTURE_PATH` | L80 |
| `set_renderer(node: Node) -> void` | L135 |
| `has_renderer() -> bool` | L151 |
| `has_section_texture() -> bool` | L156 |
| `section_texture_size() -> Vector2` | L160 |
| `set_ship_model(model: Dictionary) -> void` | L170 |
| `has_blueprint_views() -> bool` | L179 |
| `blueprint_texture_size(view: String) -> Vector2` | L183 |
| `slot_dock_height() -> float` | L189 |
| `set_blueprint_backdrop(enabled: bool) -> void` | L200 |
| `uses_blueprint_backdrop() -> bool` | L207 |
| `blueprint_view_rect(view: String) -> Rect2` | L223 |
| `set_slots(slots: Array) -> void` | L303 |
| `set_mode(next: int) -> void` | L326 |
| `highlight_slots(slot_ids: Array) -> void` | L336 |
| `blueprint_socket_rects(view: String = "side") -> Dictionary` | L349 |

## 外观来源（外部贴图 + SNSkin）
- 舞台背景 wash、每视图框/底板与底部槽位坞条改用皮肤九宫格：
  `SNSkin.style("panel_recess" / "panel_blueprint" / "frame_open")` + `draw_style_box()`；
  皮肤缺失时退回 token 色块/描边，仍保持可读性。
- 所有颜色取 `SNSkin.color(token)`（本文件不写十六进制），文字字体取
  `get_theme_default_font()`；线稿、水面、船身等数据绘制保留，但颜色来自 token。
- `set_blueprint_backdrop(true)` 时仍不画背景 wash / 视图框 / 坞条：底板由父级
  `SNBlueprintPanel` 提供，开关语义与之前一致。

## 契约与约束
- `set_ship_model()` 接收 `shipyard.view.ship`；`ship.blueprint_views.{side,top}` 是
  已解析的线稿路径（`path`），没有线稿时回退到通用纵剖图/程序化占位。
- 武器槽位行必须包含稳定 `socket` 与 `blueprint`，后者的 `side` / `top` 是左上原点、
  0..1 的 JSON Vector2，坐标基准是各自视图的线稿纹理。
- `blueprint_view_rect(view)` 返回该视图等比适配后的屏幕矩形；
  `blueprint_socket_rects(view)` 用这个矩形把归一化坐标映射为屏幕框；缺失、越界或
  形状错误的坐标跳过，不影响其它槽位和模块拖放。没有线稿时 rect 回退为整个 Control，
  保持旧内容兼容。
- CUTAWAY 同时绘制 side（上方）与 top（下方）两个视图；槽位框空槽为灰、已装武器为
  黄铜、`highlight_slots()` 命中的 socket 为青色高亮；购买/安装命令仍由船厂页面发出。
- 有每船线稿时船厂页把整列换成 `SNBlueprintPanel` 九宫格蓝图底板；页面调用
  `set_blueprint_backdrop(true)` 后本视图只把线稿、视图标签、武器槽位框和槽位 chip
  画在底板的深蓝内容区上。底板由 Theme 提供，本视图不持有底板纹理。
- `set_renderer()` / `set_slots()` / `set_blueprint_backdrop()` / `highlight_slots()` /
  `blueprint_view_rect()` / `blueprint_socket_rects()` 与 `SNSlotTarget` 槽位契约完全
  不变；本文件只替换绘制来源，不改命中、拖放与渲染器转发逻辑。

Refit stage for the centre of the shipyard screen.

Two modes share one coordinate space:
  EXTERIOR — a side view of the current ship (procedural placeholder today).
  CUTAWAY  — dual blueprint views from the hull's `blueprint_views`; when absent,
             the authored longitudinal section (assets/ui/shipyard/ship_section.png)
             or the procedural fallback is used. SNSlotTarget chips stay on top so
             owned free modules can be dragged straight onto a slot.

## 2.5D integration contract
`set_renderer(node)` swaps the procedural placeholder for a real renderer.
The node is added as a child filling this control and must expose:
  func ship_view_update(model: Dictionary) -> void
  func ship_view_set_mode(mode: int) -> void
  func ship_view_highlight(slot_ids: Array) -> void
Slot chips, drag & drop, and hit layout stay here, so a future 2.5D scene
only has to draw the hull and can ignore input entirely. Passing null
restores the built-in placeholder. Nothing in the screen depends on how the
ship is drawn, so the swap needs no screen change.

模块索引：[framework/ui](../README.md)
