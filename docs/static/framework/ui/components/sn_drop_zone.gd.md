# `framework/ui/components/sn_drop_zone.gd`

> 作用：图标拖拽的通用落点面板：按载荷 `kind` 过滤、命中时用 SNSkin 九宫格纹理的 `modulate_color` 高亮、放下后发出 `dropped`；拖拽结束 / 鼠标移出复位。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNDropZone` | L1 |
| `dropped (signal)` | L40 |
| `DEFAULT_STYLE_ID` | L42 |
| `HIGHLIGHT_STYLE_ID` | L43 |
| `DEFAULT_PADDING` | L44 |
| `configure(accepted_kinds: Array, style_id: String = DEFAULT_STYLE_ID) -> void` | L64 |
| `set_offer(data: Dictionary) -> void` | L76 |
| `clear_offer() -> void` | L84 |
| `offer_active() -> bool` | L91 |
| `offer_payload() -> Dictionary` | L96 |
| `try_click_offer() -> bool` | L102 |
| `content_root() -> VBoxContainer` | L112 |
| `is_highlighted() -> bool` | L124 |

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

## 拿起 / 放下（点击落点，feedback #1）
- `set_offer(data)` / `clear_offer()` / `offer_active()` / `offer_payload()`：市场
  「拿起」手势的落点状态。`set_offer` 只接受 `accept_kinds` 里的载荷（不匹配直接
  清空），有 offer 时落点用皮肤纹理高亮，玩家点一下落点（左键 release）就
  `try_click_offer()` → 发出 `dropped`。原生拖拽仍是兼容手势，两条路径共用
  `dropped` 契约。
- `_gui_input` 里先 `accept_event()` 再发 `dropped`：命令成功会触发 Shell 整页重建，
  落点节点可能已被移出场景树，事后再 `accept_event()` 会拿不到 Viewport。
- `_process` 只复位**拖拽**高亮，绝不清 offer；offer 由宿主页面在携带结束时清空。

模块索引：[framework/ui](../README.md)
