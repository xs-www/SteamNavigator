# `framework/ui/components/sn_ship_view.gd`

> 作用：船厂中央改装台：同一坐标系里切换船体侧视占位渲染与纵剖图（每槽位一个 SNSlotTarget 贴片），并预留可替换的 2.5D 渲染器接口。

- 关键依赖：`SNSlotTarget`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNShipView` | L1 |
| `slot_drop_requested (signal)` | L21 |
| `slot_activated (signal)` | L22 |
| `set_renderer(node: Node) -> void` | L67 |
| `has_renderer() -> bool` | L83 |
| `set_ship_model(model: Dictionary) -> void` | L87 |
| `set_slots(slots: Array) -> void` | L95 |
| `set_mode(next: int) -> void` | L118 |
| `highlight_slots(slot_ids: Array) -> void` | L128 |

## 契约与约束

- `Mode.EXTERIOR` 画侧视占位（水面/烟/明轮动画），`Mode.CUTAWAY` 画纵剖图并显示槽位贴片；两种模式复用同一套槽位布局。
- `set_slots(slots)` 为每个描述重建一个 SNSlotTarget；字段：id、content_type、index、title、module、replace_module_id、fixed、hint、tooltip。
- 贴片只在 CUTAWAY 可见；点击发 `slot_activated(slot)`，同类型部件拖到贴片发 `slot_drop_requested(payload, slot)`，本控件不发命令。
- 2.5D 接入协议：`set_renderer(node)` 把节点作为铺满本控件的子节点挂入，并立即下发 `ship_view_update(model)` / `ship_view_set_mode(mode)`；`has_renderer()` 判定是否已替换；传 `null` 恢复内置占位。
- 渲染器实现 `ship_view_update(model)`、`ship_view_set_mode(mode)`、`ship_view_highlight(slot_ids)` 即可；缺方法时用 `has_method` 跳过，不报错。
- 槽位贴片、拖放与命中布局都留在本控件，未来 2.5D 场景只画船体、可完全忽略输入，页面无需改动。
- 无渲染器或侧视模式下每帧 `queue_redraw` 驱动动画；接入渲染器后的纵剖图只在数据/尺寸变化时重绘。

## 重点逻辑

### `set_renderer(node)`

- 先移除并 `queue_free` 旧渲染器，再 `add_child` + `move_child(..., 0)` 压到绘制底层。
- Control 渲染器铺满本控件并设为 `MOUSE_FILTER_IGNORE`，避免抢走槽位贴片的拖放。
- 挂载后立即下发当前 model 与 mode，渲染器不必等待下一次刷新。

### `set_slots(slots) / set_mode(next) / highlight_slots(slot_ids)`

- `set_slots` 深拷贝描述、重建全部贴片并重新布局；`set_mode` 同步贴片可见性与渲染器 mode；`highlight_slots` 同时给贴片与渲染器发高亮。
- 布局固定两行：非货舱槽一行、货舱槽一行；贴片宽 84–148 px，控件宽 < 80 px 时跳过布局。
- 槽位描述是深拷贝，页面后续修改 vm 不会反向影响已建贴片。

模块索引：[framework/ui](../README.md)
