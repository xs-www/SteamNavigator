# `framework/ui/components/sn_part_row.gd`

> 作用：船厂右侧部件 HUD 的单行条目：用标签区分已装 / 仓库 / 随船 / 可购买，持有且可装的行是拖拽来源。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNPartRow` | L1 |
| `activated (signal)` | L9 |
| `drag_started (signal)` | L10 |
| `TEXT` | L12 |
| `MUTED` | L13 |
| `BRASS` | L14 |
| `TEAL` | L15 |
| `RED` | L16 |
| `GREEN` | L17 |
| `configure(part_data: Dictionary, tag_text: String, tag_color: Color, meta_text: String, hint_text: String, can_drag: bool) -> void` | L32 |
| `set_compatible_hint(active: bool) -> void` | L57 |

## 契约与约束

- `configure(part, tag_text, tag_color, meta_text, hint_text, can_drag)` 之后重复调用只刷新内容，不重建子节点。
- `draggable` 行实现 `_get_drag_data`：返回 `{"kind": "ship_parts", "part": part}` 并调用 `set_drag_preview`，由 SNSlotTarget 消费。
- 不可拖拽行（已装 / 购买候选）左键点击发 `activated(part)`；只有 ShipyardScreen 会把购买行转成安装命令。
- 标签文字与颜色由调用方本地化后传入；控件不读 _tr、不访问总线。

模块索引：[framework/ui](../README.md)
