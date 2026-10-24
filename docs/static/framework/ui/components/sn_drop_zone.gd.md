# `framework/ui/components/sn_drop_zone.gd`

> 作用：图标拖拽的通用落点面板：按载荷 `kind` 过滤、命中时用 SNSkin 九宫格纹理的 `modulate_color` 高亮、放下后发出 `dropped`；拖拽结束 / 鼠标移出复位。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNDropZone` | L1 |
| `dropped (signal)` | L30 |
| `DEFAULT_STYLE_ID` | L32 |
| `HIGHLIGHT_STYLE_ID` | L33 |
| `DEFAULT_PADDING` | L34 |
| `configure(accepted_kinds: Array, style_id: String = DEFAULT_STYLE_ID) -> void` | L51 |
| `content_root() -> VBoxContainer` | L61 |
| `is_highlighted() -> bool` | L73 |

Shared drop target for the icon-direct market interaction.

The zone never decides which command runs: it only owns the "is this payload
accepted here" rule and the highlight feedback. The hosting screen / panel
maps the dropped payload to the trade or warehouse command.

## 外观来源（外部贴图 + SNSkin）
- 底板取 `SNSkin.style("panel_recess")`（可配置 `zone_style_id`），命中高亮改用
  `SNSkin.style("panel_steel")` 克隆并设置 `modulate_color = SNSkin.color(...)`；
  高亮内外边距与空闲态一致，落点不会因高亮跳动。
- 透明落点（如整块市场面板）把 `zone_style_id` 设为空串：空闲态用
  `StyleBoxEmpty`（不新增 `StyleBoxFlat`），高亮仍是皮肤纹理 + token 染色。
- 不写十六进制色、不硬编码皮肤路径。

## 契约与约束
- `accept_kinds` 里的 `kind` 是拖拽载荷的顶层字段（`market_item` / `cargo_item`
  / `warehouse_item`）；未配置 or 不匹配一律返回 false，不做模糊回退。
- `dropped` 载荷是 `duplicate(true)` 后的副本，承载方可以安全修改。
- 高亮会在 `_drop_data`、`NOTIFICATION_DRAG_END` / `NOTIFICATION_MOUSE_EXIT` 复位；
  Godot 只把拖拽结束通知发给拖拽来源，所以高亮期间用 `_process` 轮询
  `Viewport.gui_is_dragging()`，拖到空处释放也不会留下残留高亮。
- 子内容统一挂到 `content_root()` 返回的 VBox，落点自身只保留一个子节点。

模块索引：[framework/ui](../README.md)
