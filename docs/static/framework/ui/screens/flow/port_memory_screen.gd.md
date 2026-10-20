# `framework/ui/screens/flow/port_memory_screen.gd`

> 作用：港口记忆流程场景：只读展示上次到港时的市场和设施快照。

- 关键依赖：`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PortMemoryScreen` | L1 |
| `navigation_requested (signal)` | L5 |
| `TEXT` | L7 |
| `MUTED` | L8 |
| `BRASS` | L9 |
| `TEAL` | L10 |
| `RED` | L11 |
| `GREEN` | L12 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L16 |

## 契约与约束

- bind(vm, translate) 接收 port.memory 结果及 Shell 补齐的 age_text/facility_labels，不直接查询端口记忆或注册表。
- 市场快照不提供交易按钮；返回操作只发出 overview navigation_requested。
- 快照表四列使用明确最小宽度与横向间距，所有密集字段禁用自动换行，避免中文被压成逐字竖排。
- 查询失败时展示 error_text，并仍保留返回总览入口。

模块索引：[framework/ui](../../README.md)
