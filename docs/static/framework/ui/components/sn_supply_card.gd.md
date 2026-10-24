# `framework/ui/components/sn_supply_card.gd`

> 作用：单种补给品的决策卡：存量、可补上限、价格、港存、预计续航和购买操作。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSupplyCard` | L1 |
| `command_requested (signal)` | L24 |

One supply commodity card (coal or water).

The card only renders a ViewModel and emits intent; the shell owns commands.
bind() takes an optional tr callable for the cap-loss/headroom copy; without it
the card keeps its original Chinese wording. ViewModels without capacity keep
the legacy "current + max_buy" meter scale.

## 外观来源（外部贴图 + SNSkin）
- 卡片底层用 Theme 变体 `SNElevatedPanel`；资源条 `SNResourceMeter` 走
  `SNBrassProgressBar` / `SNWaterProgressBar` 的纹理填充。文字色全部取
  `SNSkin.color(token)`（text.light / text.muted / state.warning），不写十六进制。
- 按钮：步进 `+5 / +10` 用 `SNCompactButton`（小铭牌，保持 38 px 高、不撑宽卡片），
  补满用 `SNPrimaryButton` + `Button.icon = SNSkin.icon("action_confirm")`
  （`icon_max_width` 16，不加包装容器，按钮 `text` 不变）。
- 尺寸约束：三个按钮 `custom_minimum_size = (0, 38)` 不变；内容区
  `Content` 节点名与行顺序（标题 / 资源条 / 信息行 / 阻断 / 操作）保持不变。

模块索引：[framework/ui](../README.md)
