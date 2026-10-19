# `framework/ui/screens/port/contracts_screen.gd`

> 作用：委托页面场景：按可接/进行中分组渲染主线与普通委托卡，并发出接取或规划出航意图。

- 关键依赖：`SNBadge`、`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContractsScreen` | L1 |
| `command_requested (signal)` | L8 |
| `navigation_requested (signal)` | L9 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L20 |

## 契约与约束

- bind(view_model, translate) 接收 Shell 已补齐 destination_reachable、unlock_names、completed_names 的展示模型，不自行查询航行或定义注册表。
- 接取操作发出 contract.accept；规划操作发出 navigation_requested(voyage, destination)，由 Shell 保存目的港并切页。
- 卡片固定显示主线/普通、风险、目的地、剩余期限、载重、预计航程、说明、报酬与声誉；不足 24 小时使用危险色。
- 非直达目的港禁用规划按钮并显示中转提示；普通委托持有上限与主线完成状态来自 ViewModel。

模块索引：[framework/ui](../../README.md)
