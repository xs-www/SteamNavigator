# `framework/ui/components/sn_ship_view.gd`

> 作用：船厂中央船体视图；正常态承载 2.5D 船体/程序化船身，改装态绘制每船侧视/俯视蓝图线稿、模块拖放槽位，以及 hull `weapon_sockets[].blueprint` 驱动、可读可拖放的武器槽位贴片（`SNWeaponSocketTarget`）。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNShipView` | L1 |
| `slot_drop_requested (signal)` | L70 |
| `slot_activated (signal)` | L71 |
| `weapon_drop_requested (signal)` | L74 |
| `weapon_socket_hovered (signal)` | L76 |
| `weapon_socket_unhovered (signal)` | L77 |
| `WEAPON_TARGET_SCRIPT` | L82 |
| `SLOT_H` | L97 |
| `CARGO_SLOT_H` | L98 |
| `BLUEPRINT_SOCKET_MIN_SIZE` | L99 |
| `BLUEPRINT_SOCKET_MAX_SIZE` | L100 |
| `BLUEPRINT_SIDE_RATIO` | L101 |
| `BLUEPRINT_VIEW_GAP` | L102 |
| `WEAPON_CARD_MIN_WIDTH` | L106 |
| `WEAPON_CARD_MAX_WIDTH` | L107 |
| `WEAPON_CARD_HEIGHT` | L108 |
| `WEAPON_CARD_MIN_HEIGHT` | L109 |
| `WEAPON_CARD_WIDTH_RATIO` | L110 |
| `WEAPON_CARD_GAP` | L111 |
| `WEAPON_CARD_MARGIN` | L112 |
| `SLOT_DOCK_MARGIN` | L113 |
| `SLOT_DOCK_GAP` | L114 |
| `SECTION_TEXTURE_PATH` | L117 |
| `set_renderer(node: Node) -> void` | L187 |
| `has_renderer() -> bool` | L203 |
| `has_section_texture() -> bool` | L208 |
| `section_texture_size() -> Vector2` | L212 |
| `set_ship_model(model: Dictionary) -> void` | L222 |
| `has_blueprint_views() -> bool` | L232 |
| `blueprint_texture_size(view: String) -> Vector2` | L236 |
| `slot_dock_height() -> float` | L242 |
| `set_blueprint_backdrop(enabled: bool) -> void` | L253 |
| `uses_blueprint_backdrop() -> bool` | L260 |
| `blueprint_view_rect(view: String) -> Rect2` | L276 |
| `set_slots(slots: Array) -> void` | L356 |
| `set_mode(next: int) -> void` | L382 |
| `highlight_slots(slot_ids: Array) -> void` | L395 |
| `blueprint_socket_rects(view: String = "side") -> Dictionary` | L413 |
| `weapon_socket_display_rects(view: String = "side") -> Dictionary` | L456 |
| `set_weapon_drop_enabled(enabled: bool) -> void` | L507 |
| `is_weapon_drop_enabled() -> bool` | L514 |
| `weapon_targets() -> Array` | L519 |
| `weapon_target(socket_id: String, view: String = "") -> Control` | L524 |

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
- CUTAWAY 同时绘制 side（上方）与 top（下方）两个视图；武器槽位改由贴片控件绘制：
  空槽为暗色凹槽 + muted 文字、已装为黄铜底板 + 亮色文字、`highlight_slots()` 命中的
  socket 只换青色描边（不覆盖已装/空槽差异）；购买/安装命令仍由船厂页面发出。
- 武器贴片契约（2026-10-27，玩家反馈「装配后看不出装在哪 / 武器不能拖动安装」）：
  * `set_ship_model()` 的 `model.weapon_sockets[]` 每行至少含 `socket` / `socket_class` /
    `blueprint` / `weapon_id`；可选展示字段 `display_name`（已装武器本地化名，空槽 ""）、
    `slot_label`（短标签，如「左舷1」）、`slot_title`（完整友好名，作 tooltip）、
    `empty_text`、`occupied`。缺字段时按 `SNWeaponSocketTarget` 的兜底规则推导，不崩。
  * 每个 socket 只要在 side / top 某一视图有 `blueprint` 坐标，就在该视图生成一枚贴片；
    贴片始终随 CUTAWAY 可见（EXTERIOR 隐藏）。
  * `weapon_socket_display_rects(view)` 从 `blueprint_socket_rects(view)` 的锚点派生
    ≥96×30 的可读贴片矩形：锚点相同/过近的槽位（如 Port_1 / Starboard_1 共用同一
    side 坐标）沿垂直方向扇出，互不重叠，并 clamp 在 `blueprint_view_rect(view)` 内。
    `blueprint_socket_rects()` 保持原有的 28–42 px 小框语义，不变。
  * 拖放：贴片只接受 `{kind:"ship_weapon", weapon_id, weapon_class, source, name}`，
    `weapon_class == socket_class` 才接受；`_drop_data` 经 `weapon_dropped` 汇总为
    `weapon_drop_requested(payload, socket)`。`set_weapon_drop_enabled(false)` 只关闭
    拖放接收（非武器分类 / 非装配页签），不影响贴片可见性；默认接受。
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
