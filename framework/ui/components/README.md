# Steam Navigator Godot UI 控件

这些控件直接使用 `res://assets/ui/theme/steam_navigator_theme.tres`，可从 FileSystem 面板拖入场景，也可通过 `class_name` 在脚本中实例化。

| 控件 | 场景 | Inspector 入口 |
| --- | --- | --- |
| `SNButton` | `sn_button.tscn` | `variant`、`compact`；主/次/危险/幽灵四种语义状态。 |
| `SNPanel` | `sn_panel.tscn` | `variant`；基础/高架/内嵌三种表面层级。 |
| `SNBadge` | `sn_badge.tscn` | `tone`；中性/成功/警告/危险四种状态。 |
| `SNSectionHeader` | `sn_section_header.tscn` | `eyebrow`、`title`、`detail`。 |
| `SNResourceMeter` | `sn_resource_meter.tscn` | 名称、当前值、最大值、单位、提示和色调。 |
| `SNSupplyCard` | `sn_supply_card.tscn` | `bind(data, title, blocker_labels)`；煤/水补给决策卡，发 `command_requested`。 |
| `SNSparkline` | `sn_sparkline.tscn` | `set_values(prices, color)`；真实价格历史不足时不伪造折线。 |

场景根节点或公共 UI 父节点设置：

```gdscript
theme = preload("res://assets/ui/theme/steam_navigator_theme.tres")
```

可运行 `res://framework/ui/showcase/ui_kit_showcase.tscn` 查看全部状态。展示场景不依赖 AppContext，可在 Godot 中单独运行。
