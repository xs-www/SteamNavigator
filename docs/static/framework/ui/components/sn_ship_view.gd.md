# `framework/ui/components/sn_ship_view.gd`

> 作用：船厂中央改装台：`EXTERIOR` 画程序化侧视占位；`CUTAWAY` 画授权纵剖图贴图（`assets/ui/shipyard/ship_section.png`）+ 每槽位一个 `SNSlotTarget` 贴片，贴图缺失时回退程序化剖面；预留可替换的 2.5D 渲染器接口。

- 关键依赖：`SNSlotTarget`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNShipView` | L1 |
| `slot_drop_requested (signal)` | L23 |
| `slot_activated (signal)` | L24 |
| `set_renderer(node: Node) -> void` | L75 |
| `has_renderer() -> bool` | L91 |
| `has_section_texture() -> bool` | L96 |
| `section_texture_size() -> Vector2` | L100 |
| `set_ship_model(model: Dictionary) -> void` | L110 |
| `set_slots(slots: Array) -> void` | L118 |
| `set_mode(next: int) -> void` | L141 |
| `highlight_slots(slot_ids: Array) -> void` | L151 |

## 契约与约束

- `SECTION_TEXTURE_PATH` = `res://assets/ui/shipyard/ship_section.png`；`_ready()` 调用 `_load_section_texture()`，仅在 `ResourceLoader.exists` 为真时加载。`has_section_texture()` 判定是否用上授权贴图，`section_texture_size()` 返回像素尺寸（无贴图返回 `Vector2.ZERO`），供测试与调试确认贴图已导入。
- `_draw_cutaway()` 优先 `_draw_section_texture()`（cover 裁切贴图）并始终叠加 `_draw_slot_leaders()`；仅贴图缺失/未导入时才用 `_draw_cutaway_placeholder()` 程序化剖面。`Mode.EXTERIOR` 保持程序化侧视、不读贴图。
- `_draw_section_texture()` 为 cover 裁切：`cover_scale = max(dst.w/tex.w, dst.h/tex.h)`，取居中源矩形 `draw_texture_rect_region`，再叠 0.18 暗青蒙版；不改变纵横比、不移动控件。
- 槽位仍按两行排布（非货舱槽 `top = h*0.60`，货舱槽 `top = h*0.82`）；贴片宽 84–148 px（按可用跨度均分），控件宽 < 80 px 时跳过布局。
- `_chip_anchor()` 的舱室锚点（船体/锅炉/货舱/导航/安全/客舱）必须与 `tools/art/gen_shipyard_textures.py` 的 `ANCHORS` 保持同一构图比例；换图时两侧一起改。
- `Mode.EXTERIOR` 仍是程序化侧视（水面/烟/明轮动画），不读贴图；正常态与改装态共用同一套 `set_slots` 数据。
- `set_slots(slots)` 为每个描述重建一个 `SNSlotTarget`；字段：id、content_type、index、title、module、replace_module_id、fixed、hint、tooltip。贴片只在 CUTAWAY 可见；点击发 `slot_activated(slot)`，同类型部件拖到贴片发 `slot_drop_requested(payload, slot)`，本控件不发命令。
- 2.5D 接入协议不变：`set_renderer(node)` 把节点作为铺满本控件的子节点挂入并立即下发 `ship_view_update(model)` / `ship_view_set_mode(mode)`；`has_renderer()` 判定是否已替换；传 `null` 恢复内置占位。
- 渲染器实现 `ship_view_update(model)`、`ship_view_set_mode(mode)`、`ship_view_highlight(slot_ids)` 即可；缺方法时用 `has_method` 跳过，不报错。槽位贴片、拖放与命中布局都留在本控件，未来 2.5D 场景只画船体即可。
- 无渲染器或 EXTERIOR 时每帧 `queue_redraw` 驱动动画；接入渲染器后的 CUTAWAY 只在数据/尺寸变化时重绘，贴图本身不参与动画。

## 重点逻辑

### `_draw_section_texture()`

- 只处理正尺寸贴图；`destination` 恒为整个控件，`source` 按 cover 居中，保证 1792×1008 图在任意舞台尺寸下铺满且不变形。
- 绘制后统一加半透明暗色压住贴图亮度，保持与 Theme 暗青底一致；槽位引线在贴图之上。

### `_layout_slots() / _place_row()`

- 把货舱槽与非货舱槽拆成两行分别 `_place_row`；`_place_row` 计算 chip 宽高、水平居中、直接写 `position/size`（不用容器排布，便于引线定位）。
- 贴片可见性每次布局都按 `mode == CUTAWAY` 重算，避免模式切换后残留。

### `_draw_slot_leaders()`

- 从每枚贴片顶部中心画线到 `_chip_anchor` 对应舱室点；货舱按数量决定步长（≤1 时 0.055，否则 0.09）。

### `set_renderer(node)`

- 先移除并 `queue_free` 旧渲染器，再 `add_child` + `move_child(..., 0)` 压到绘制底层。
- Control 渲染器铺满本控件并设为 `MOUSE_FILTER_IGNORE`，避免抢走槽位贴片的拖放。
- 挂载后立即下发当前 model 与 mode，渲染器不必等待下一次刷新。

模块索引：[framework/ui](../README.md)
