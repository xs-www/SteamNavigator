# `framework/ui/components/sn_slot_target.gd`

> 作用：纵剖图上的单个槽位贴片：显示槽位与已装模块，接收 `ship_parts` 拖放载荷，只校验来源与槽位类型。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSlotTarget` | L1 |
| `part_dropped (signal)` | L32 |
| `slot_activated (signal)` | L33 |
| `configure(slot_data: Dictionary) -> void` | L53 |
| `set_compatible_hint(active: bool) -> void` | L73 |

One refit slot chip in the SNShipView cutaway.

Draws the slot title, the installed module (or 空), and accepts a dragged
owned free module (SNPartRow payload, `kind = "ship_parts"`). The screen owns
the command intent; this control only validates the module category and source.

## 拖放载荷契约（2026-10-26 修复）
- `_drop_data` 必须把**完整拖拽载荷**（`{kind:"ship_parts", part:{...}}`）原样
  duplicate 后从 `part_dropped` 发出，不能只发内层 `part`：船厂页
  `_on_slot_drop(payload, slot)` 的契约是按 `SNPartRow._get_drag_data()` 的载荷
  形状解析 `payload.part`。只发内层 part 会让真实拖放在页面侧静默落空
  （空槽安装 / 已装替换都不触发命令），而直接调用页面函数的测试发现不了。
- `part_dropped(payload, slot)` → `SNShipView.slot_drop_requested` →
  `ShipyardScreen._on_slot_drop` 全链路保持同一载荷形状。

## 外观来源（外部贴图 + SNSkin）
- 槽位底板不再手搓 `StyleBoxFlat`：取 `SNSkin.style("panel_recess")`（仪表凹槽
  纹理），悬停 / 匹配 / 固定槽位改用 `SNSkin.style("panel_steel")` 并以
  `modulate_color = SNSkin.color(token)` 区分（state.water / brass.highlight /
  brass.base）；内容边距固定回 8 / 4，保持旧槽位尺寸与文字裁切。
- 文字色取 `SNSkin.color(token)`；不写十六进制色，不新增子节点。
- 尺寸/契约：`fixed` 槽位仍用最亮黄铜语义；槽位尺寸由 SNShipView 的布局决定，
  本控件不设 custom_minimum_size；拖放只认 `kind == "ship_parts"` 且来源为
  仓库 / 随船。

模块索引：[framework/ui](../README.md)
