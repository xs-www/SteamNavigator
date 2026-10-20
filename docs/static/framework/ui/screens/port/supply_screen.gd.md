# `framework/ui/screens/port/supply_screen.gd`

> 作用：补给与维修页面场景：绑定 SupplyView，组合煤水决策卡、资源摘要与维修操作；作为泊位侧栏时按 620 px 窄列设计（卡片单列堆叠、badge 可换行），外层 PageScroll 负责竖向滚动。

- 关键依赖：`SNSupplyCard`、`SNBadge`、`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SupplyScreen` | L1 |
| `command_requested (signal)` | L13 |
| `SUPPLY_CARD_SCENE` | L15 |
| `COLOR_TEXT` | L16 |
| `COLOR_MUTED` | L17 |
| `COLOR_BRASS` | L18 |
| `COLOR_RED` | L19 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L24 |

## 契约与约束

- bind(view_model, translate) 是唯一数据入口；页面不查询 AppContext、不访问 QueryBus/CommandBus，也不保存领域状态。
- 煤水购买与维修统一发出 command_requested(command, params)，由 Shell 执行并决定刷新、音效和错误反馈。
- 页面可重复 bind；每次先清理旧展示节点，页面实例复用时不会叠加卡片或信号。
- 阻断码只转换为展示文案，不在页面重新计算库存、重量、金钱或维修规则。
- 维修卡把报价拆成「缺失耐久 X（船体 A · 部件 B）」，module_points>0 时追加「含部件损耗」徽标；数值全部来自 supply.view 的 repair 字段。
- 窄列布局：煤/水卡放 `VBoxContainer` 单列堆叠（`custom_minimum_size=(0,0)` + EXPAND_FILL），摘要与维修 badge 用 `HFlowContainer` 自动换行；页面自身不加 ScrollContainer，宽度交给 Shell 的 `DockPanel`（620-640 px）约束。

模块索引：[framework/ui](../../README.md)
