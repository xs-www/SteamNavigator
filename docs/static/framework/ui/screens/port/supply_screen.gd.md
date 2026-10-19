# `framework/ui/screens/port/supply_screen.gd`

> 作用：补给与维修页面场景：绑定 SupplyView，组合煤水决策卡、资源摘要与维修操作。

- 关键依赖：`SNSupplyCard`、`SNBadge`、`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SupplyScreen` | L1 |
| `command_requested (signal)` | L8 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L19 |

## 契约与约束

- bind(view_model, translate) 是唯一数据入口；页面不查询 AppContext、不访问 QueryBus/CommandBus，也不保存领域状态。
- 煤水购买与维修统一发出 command_requested(command, params)，由 Shell 执行并决定刷新、音效和错误反馈。
- 页面可重复 bind；每次先清理旧展示节点，页面实例复用时不会叠加卡片或信号。
- 阻断码只转换为展示文案，不在页面重新计算库存、重量、金钱或维修规则。

模块索引：[framework/ui](../../README.md)
