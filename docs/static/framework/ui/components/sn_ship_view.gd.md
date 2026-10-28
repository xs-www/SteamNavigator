# `framework/ui/components/sn_ship_view.gd`

> 作用：船厂中央船体视图；正常态承载 2.5D 船体/程序化船身，改装态绘制每船**侧视**蓝图线稿、内容锚点圆点（`ship.slot_anchors` + `weapon_sockets[].blueprint.side`）、圆点到模块方框/武器贴片的折线，以及可拖放的槽位贴片与武器贴片。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNShipView` | L1 |
| `slot_drop_requested (signal)` | L86 |
| `slot_activated (signal)` | L87 |
| `weapon_drop_requested (signal)` | L90 |
| `weapon_socket_hovered (signal)` | L92 |
| `weapon_socket_unhovered (signal)` | L93 |
| `WEAPON_TARGET_SCRIPT` | L98 |
| `SLOT_H` | L113 |
| `CARGO_SLOT_H` | L114 |
| `BLUEPRINT_SOCKET_MIN_SIZE` | L115 |
| `BLUEPRINT_SOCKET_MAX_SIZE` | L116 |
| `BLUEPRINT_SIDE_RATIO` | L119 |
| `BLUEPRINT_VIEW_GAP` | L120 |
| `WEAPON_CARD_MIN_WIDTH` | L124 |
| `WEAPON_CARD_MAX_WIDTH` | L125 |
| `WEAPON_CARD_HEIGHT` | L126 |
| `WEAPON_CARD_MIN_HEIGHT` | L127 |
| `WEAPON_CARD_WIDTH_RATIO` | L128 |
| `WEAPON_CARD_GAP` | L129 |
| `WEAPON_CARD_MARGIN` | L130 |
| `BLUEPRINT_CHIP_SIDE_SPLIT` | L135 |
| `SLOT_CHIP_MIN_WIDTH` | L136 |
| `SLOT_CHIP_MAX_WIDTH` | L137 |
| `SLOT_CHIP_WIDTH_RATIO` | L138 |
| `SLOT_CHIP_HEIGHT` | L139 |
| `SLOT_CHIP_MIN_HEIGHT` | L140 |
| `SLOT_CHIP_HEIGHT_RATIO` | L141 |
| `SLOT_CHIP_GAP` | L142 |
| `SLOT_CHIP_MARGIN` | L143 |
| `SLOT_CHIP_COMPACT_HEIGHT` | L145 |
| `ANCHOR_DOT_RADIUS` | L147 |
| `ANCHOR_LEADER_OUT` | L148 |
| `BLUEPRINT_CHIP_LANES` | L151 |
| `SECTION_TEXTURE_PATH` | L154 |
| `set_renderer(node: Node) -> void` | L238 |
| `has_renderer() -> bool` | L254 |
| `has_section_texture() -> bool` | L259 |
| `section_texture_size() -> Vector2` | L263 |
| `set_ship_model(model: Dictionary) -> void` | L273 |
| `has_blueprint_views() -> bool` | L285 |
| `blueprint_texture_size(view: String) -> Vector2` | L289 |
| `slot_dock_height() -> float` | L296 |
| `set_blueprint_backdrop(enabled: bool) -> void` | L304 |
| `uses_blueprint_backdrop() -> bool` | L311 |
| `blueprint_view_rect(view: String) -> Rect2` | L331 |
| `set_slots(slots: Array) -> void` | L405 |
| `set_mode(next: int) -> void` | L432 |
| `set_module_chips_visible(visible: bool) -> void` | L444 |
| `module_chips_visible() -> bool` | L457 |
| `set_weapon_patches_visible(visible: bool) -> void` | L464 |
| `weapon_patches_visible() -> bool` | L477 |
| `highlight_slots(slot_ids: Array) -> void` | L491 |
| `slot_anchor_rects() -> Dictionary` | L508 |
| `slot_chip_rects() -> Dictionary` | L529 |
| `blueprint_socket_rects(view: String = "side") -> Dictionary` | L540 |
| `weapon_socket_display_rects(view: String = "side") -> Dictionary` | L581 |
| `set_weapon_drop_enabled(enabled: bool) -> void` | L641 |
| `is_weapon_drop_enabled() -> bool` | L649 |
| `weapon_targets() -> Array` | L654 |
| `weapon_target(socket_id: String, view: String = "") -> Control` | L659 |

## 外观来源（外部贴图 + SNSkin）
- 舞台背景 wash、视图框/底板改用皮肤九宫格：
  `SNSkin.style("panel_recess" / "panel_blueprint" / "frame_open")` + `draw_style_box()`；
  皮肤缺失时退回 token 色块/描边，仍保持可读性。
- 所有颜色取 `SNSkin.color(token)`（本文件不写十六进制），文字字体取
  `get_theme_default_font()`；线稿、水面、船身等数据绘制保留，但颜色来自 token。
- `set_blueprint_backdrop(true)` 时仍不画背景 wash / 视图框：底板由父级
  `SNBlueprintPanel` 提供，开关语义与之前一致。

## 契约与约束
- `set_ship_model()` 接收 `shipyard.view.ship`；`ship.blueprint_views.{side,top}` 是
  已解析的线稿路径（`path`），没有线稿时回退到通用纵剖图/程序化占位。
- 武器槽位行必须包含稳定 `socket` 与 `blueprint`；`blueprint.side` 是左上原点、
  0..1 的 JSON Vector2，坐标基准是侧视图线稿纹理。
- `blueprint_view_rect(view)` 返回该视图等比适配后的屏幕矩形；`blueprint_socket_rects(view)`
  用这个矩形把归一化坐标映射为屏幕框；缺失、越界或形状错误的坐标跳过，不影响其它
  槽位和模块拖放。没有线稿时 rect 回退为整个 Control，保持旧内容兼容。
- **P2b（2026-10-28）单侧视 + 圆点折线**：
  * CUTAWAY 有 `blueprint_views` 时只绘制 side（`top` 暂不绘制、不再生成武器贴片），
    `blueprint_view_rect("side")` 独占可用区域；`blueprint_view_rect("top")` /
    `blueprint_socket_rects("top")` 仍按旧双视图公式返回可计算坐标（兼容语义，不绘制）。
  * `ship.slot_anchors`（键：hull / boiler / navigation_module / safety_module /
    passenger_cabin / cargo_modules[[x,y],...]）给出普通模块槽位的侧视归一化锚点；
    内容缺失时每个槽位回退到面板内通用锚点（不崩）。武器槽位仍用
    `weapon_sockets[].blueprint.side`。
  * 每个槽位（模块 + 武器）在锚点画圆点（黄铜 idle / 青色高亮），用「水平出线 + 斜线
    到方框边缘」的折线连到自己的方框；`highlight_slots()` 与拖拽悬停时圆点、方框一起变色。
  * 普通模块方框（`SNSlotTarget`）不再停靠底部 dock，改为贴着锚点摆放：锚点 x<0.6 放右、
    否则放左；按 y 排序后纵向避让，必要时向外开第二条车道，全部 clamp 在侧视图矩形内，
    互不重叠、不出界。面板小/槽位多时方框进入紧凑两行模式（隐藏第三行 hint）。
  * 旧无 `blueprint_views` 的船继续走 `_draw_section_texture()` / `_draw_cutaway_placeholder()`
    与原有槽位排布（含 `_draw_slot_leaders()`），回退路径不变。
- **P2a（2026-10-28）模式隔离**：`set_module_chips_visible(bool)` /
  `set_weapon_patches_visible(bool)`（默认均 true）分别控制普通槽位方框+圆点、
  武器贴片+圆点的可见性与拖放接收（仍保证 `weapon_targets()` 数量 = 每个 socket 一枚）。
  无 `blueprint_views` 的旧船忽略这两个开关，保持旧 dock 语义。
- 武器贴片契约（2026-10-27，玩家反馈「装配后看不出装在哪 / 武器不能拖动安装」）：
  * `set_ship_model()` 的 `model.weapon_sockets[]` 每行至少含 `socket` / `socket_class` /
    `blueprint` / `weapon_id`；可选展示字段 `display_name`（已装武器本地化名，空槽 ""）、
    `slot_label`（短标签，如「左舷1」）、`slot_title`（完整友好名，作 tooltip）、
    `empty_text`、`occupied`。缺字段时按 `SNWeaponSocketTarget` 的兜底规则推导，不崩。
  * 每个 socket 只要有 `blueprint.side` 坐标就生成一枚 side 贴片（P2b 起不再有 top 贴片）；
    贴片始终随 CUTAWAY 可见（EXTERIOR 隐藏）。
  * `weapon_socket_display_rects("side")` 返回与模块方框统一排布后的 ≥96×30 可读贴片矩形：
    同一锚点/过近的槽位（如 Port_1 / Starboard_1 共用同一 side 坐标）沿垂直方向扇出，
    互不重叠，并 clamp 在 `blueprint_view_rect("side")` 内。`blueprint_socket_rects()`
    保持原有的 28–42 px 小框语义，不变。
  * 拖放：贴片只接受 `{kind:"ship_weapon", weapon_id, weapon_class, source, name}`，
    `weapon_class == socket_class` 才接受；`_drop_data` 经 `weapon_dropped` 汇总为
    `weapon_drop_requested(payload, socket)`。`set_weapon_drop_enabled(false)` 只关闭
    拖放接收（非武器分类 / 非装配页签），不影响贴片可见性；默认接受。
- 有每船线稿时船厂页把整列换成 `SNBlueprintPanel` 九宫格蓝图底板；页面调用
  `set_blueprint_backdrop(true)` 后本视图只把线稿、视图标签、圆点折线、武器贴片和槽位
  chip 画在底板的深蓝内容区上。底板由 Theme 提供，本视图不持有底板纹理。
- 新增公共读取 API（测试 / 屏幕用）：`slot_anchor_rects()` 返回每个槽位圆点的小矩形
  （键 = 模块槽位 id / 武器 socket 名），`slot_chip_rects()` 返回普通模块方框矩形；
  两者都只包含当前可见的那一组。

Refit stage for the centre of the shipyard screen.

Two modes share one coordinate space:
  EXTERIOR — a side view of the current ship (procedural placeholder today).
  CUTAWAY  — the side blueprint view from the hull's `blueprint_views`; slots are
             drawn as anchor dots with leader lines to draggable chips. When absent,
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
