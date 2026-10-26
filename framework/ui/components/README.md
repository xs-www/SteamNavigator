# Steam Navigator Godot UI 控件

组件分两类：

- **场景化（scene-backed）**：`.tscn` 保存静态骨架（容器、字号、间距、鼠标穿透、皮肤钩子），`.gd` 只做数据绑定、动态行与自绘。必须 `preload("res://.../x.tscn").instantiate()`，**不能 `.new()`**（脚本 alone 没有子树）。
- **脚本-only**：自绘或完全动态的控件，直接 `preload("res://.../x.gd").new()`。

迁移契约、边界与批次见 [docs/specs/UI_SCENE_MIGRATION.md](../../../docs/specs/UI_SCENE_MIGRATION.md)。
本次 P0 场景化的浮层/弹窗：`SNInteractionHint`、`SNCarryGhost`、`SNVoyageConfirm`。其余 `sn_*.tscn` 目前仍是单节点壳，P1 批次会把静态结构搬进去。

| 控件 | 场景 | Inspector 入口 |
| --- | --- | --- |
| `SNButton` | `sn_button.tscn` | `variant`、`compact`；主/次/危险/幽灵四种语义状态。 |
| `SNPanel` | `sn_panel.tscn` | `variant`；基础/高架/内嵌三种表面层级。 |
| `SNBadge` | `sn_badge.tscn` | `tone`；中性/成功/警告/危险四种状态。 |
| `SNSectionHeader` | `sn_section_header.tscn` | `eyebrow`、`title`、`detail`。 |
| `SNResourceMeter` | `sn_resource_meter.tscn` | 名称、当前值、最大值、单位、提示和色调。 |
| `SNSupplyCard` | `sn_supply_card.tscn` | `bind(data, title, blocker_labels)`；煤/水补给决策卡，发 `command_requested`。 |
| `SNSparkline` | `sn_sparkline.tscn` | `set_values(prices, color)`；真实价格历史不足时不伪造折线。 |
| `SNInteractionHint` | `sn_interaction_hint.tscn` | `show_at(at, message, is_error)` / `hide_hint()`；命令成功/失败在指针旁浮出的提示。 |
| `SNCarryGhost` | `sn_carry_ghost.tscn` | `begin(icon, title, amount, hint, cost_text)` / `set_amount()` / `end()`；市场「拿起」光标幽灵。 |
| `SNVoyageConfirm` | `sn_voyage_confirm.tscn` | `bind(departure, translate)`；出航确认弹窗（预估 / 锅炉策略 / 阻断 / 取消·启航）。 |
| `SNIntelTable` | 脚本-only | `bind(columns, rows, current_port_id, tr)`；情报页「商品 × 港口」对比矩阵，`？`/`-` 规则与红降绿升百分比。 |

场景根节点或公共 UI 父节点设置：

```gdscript
theme = preload("res://assets/ui/theme/steam_navigator_theme.tres")
```

可运行 `res://framework/ui/showcase/ui_kit_showcase.tscn` 查看全部状态。展示场景不依赖 AppContext，可在 Godot 中单独运行。
