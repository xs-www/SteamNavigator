# `framework/ui/components/sn_slot_target.gd`

> 作用：纵剖图上的单个槽位贴片：显示槽位与已装模块，接收 `ship_parts` 拖放载荷，只校验来源与槽位类型。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSlotTarget` | L1 |
| `part_dropped (signal)` | L9 |
| `slot_activated (signal)` | L10 |
| `TEXT` | L12 |
| `MUTED` | L13 |
| `BRASS` | L14 |
| `TEAL` | L15 |
| `RED` | L16 |
| `DROP_HINT` | L17 |
| `configure(slot_data: Dictionary) -> void` | L36 |
| `set_compatible_hint(active: bool) -> void` | L56 |

## 契约与约束

- `configure(slot)` 接收 id/content_type/index/title/module/hint/tooltip/fixed；`fixed` 槽位（船体/锅炉）用更亮的黄铜描边。
- 只接受 `kind == "ship_parts"`、`part.source` ∈ {warehouse, transit}、`content_type` 与槽位一致、`can_install` 未显式为 false 的载荷；购买候选不能拖入。
- 接收后发 `part_dropped(part, slot)`；左键点击发 `slot_activated(slot)`。命令构造与领域规则属于 ShipyardScreen。
- 悬停/拖入（`_can_drop_data` 通过）用 DROP_HINT 描边；`set_compatible_hint(true)` 用 TEAL 描边，由 SNShipView.highlight_slots 驱动。
- `_ready` 之后重复 configure 只刷新文本与样式，不重建子节点；空槽显示“空槽位”。

模块索引：[framework/ui](../README.md)
