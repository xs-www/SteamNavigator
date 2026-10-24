# `framework/ui/components/sn_part_row.gd`

> 作用：船厂右侧部件 HUD 的单行条目：用标签区分已装 / 仓库 / 随船 / 可购买，持有且可装的行是拖拽来源。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNPartRow` | L1 |
| `activated (signal)` | L22 |
| `drag_started (signal)` | L23 |
| `configure(part_data: Dictionary, tag_text: String, tag_color: Color, meta_text: String, hint_text: String, can_drag: bool) -> void` | L39 |
| `set_compatible_hint(active: bool) -> void` | L64 |

One module entry in the shipyard parts HUD.

A row is one of: installed (已装), owned free module (仓库/随船, draggable),
purchasable candidate (点击购买安装). Owned free rows produce the
`ship_parts` drag payload consumed by SNSlotTarget.

## 外观来源（外部贴图 + SNSkin）
- 行底板不再手搓 `StyleBoxFlat`：普通行取 `SNSkin.style("panel_recess")`（仪表凹槽
  纹理），可拖 / 匹配高亮行改用 `SNSkin.style("panel_steel")` 并用
  `modulate_color = SNSkin.color(...)` 着色；内容边距固定回 8 / 4，保持旧行高。
- 拖拽预览用同一套钢制九宫格 + 10 / 6 内边距；文字色全部取
  `SNSkin.color(token)`（text.light / text.muted / state.water），无十六进制色。
- 尺寸约束：标签 64 px 右对齐、行内间距 8、字号 13/11/10 与信号/拖拽载荷
  `{"kind": "ship_parts", "part": ...}` 保持不变；不新增包装容器。

模块索引：[framework/ui](../README.md)
