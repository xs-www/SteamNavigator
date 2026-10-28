# `framework/ui/components/sn_slot_target.gd`

> 作用：纵剖图/侧视蓝图上的单个模块槽位贴片：显示槽位与已装模块，接收 `ship_parts` 拖放载荷，只校验来源与槽位类型；支持紧凑两行模式（P2b 贴锚点窄区）与拖放开关（P2a 模式隔离）。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSlotTarget` | L1 |
| `part_dropped (signal)` | L42 |
| `slot_activated (signal)` | L43 |
| `configure(slot_data: Dictionary) -> void` | L66 |
| `set_compatible_hint(active: bool) -> void` | L87 |
| `set_compact(active: bool) -> void` | L96 |
| `is_compact() -> bool` | L107 |
| `set_drop_enabled(enabled: bool) -> void` | L112 |
| `is_drop_enabled() -> bool` | L121 |
| `is_hovering() -> bool` | L126 |

One refit slot chip in the SNShipView cutaway.

Draws the slot title, the installed module (or 空), and accepts a dragged
owned free module (SNPartRow payload, `kind = "ship_parts"`). The screen owns
the command intent; this control only validates the module category and source.

## 尺寸 / 紧凑模式（P2b，2026-10-28）
- 本控件不设 `custom_minimum_size`，尺寸由 `SNShipView` 的侧视锚点布局决定。
- `set_compact(true)`：隐藏第三行 hint、字号 10/12、内容边距收紧到 20/2（水平仍留
  20 px 避开 `panel_recess` 九宫格的 19 px 黄铜角饰），让贴片在窄侧视区域仍保持两行
  可读；`false` 恢复标题 11 / 正文 13 / hint 10 的三行样式。

## 拖放开关（P2a，2026-10-28）
- `set_drop_enabled(false)`：`_can_drop_data` / `_drop_data` 一律拒绝，供武器装配模式
  隐藏普通槽位时关闭接收；只影响接收，不影响可见性（可见性由 `SNShipView` 控制）。
- `is_hovering()`：供 `SNShipView` 轮询，让槽位圆点与贴片一起变青色。

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
  brass.base）；内容边距 8 / 4（紧凑模式 8 / 2），保持旧槽位尺寸与文字裁切。
- 文字色取 `SNSkin.color(token)`；不写十六进制色，不新增子节点。
- 尺寸/契约：`fixed` 槽位仍用最亮黄铜语义；拖放只认 `kind == "ship_parts"`
  且来源为仓库 / 随船。

模块索引：[framework/ui](../README.md)
