# `framework/ui/screens/flow/port_memory_screen.gd`

> 作用：港口记忆流程场景：只读展示上次到港时的市场和设施快照。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PortMemoryScreen` | L1 |
| `navigation_requested (signal)` | L24 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L29 |

- 关键依赖：`port.memory` 查询结果、`SNSectionHeader`、`SNSkin`、纹理化 Theme

## 契约与约束
- bind(vm, translate) 接收 port.memory 结果及 Shell 补齐的 age_text/facility_labels，
  不直接查询端口记忆或注册表。
- 市场快照不提供交易按钮；返回操作只发出 overview navigation_requested。
- 快照表四列使用明确最小宽度与横向间距，所有密集字段禁用自动换行，避免中文被
  压成逐字竖排；`_label(text, size, color)` / `_grid_label(..., minimum_width)`
  签名被 test_ui_shell 直接调用，不得改。
- 查询失败时展示 error_text，并仍保留返回总览入口。

## 皮肤与节点约束（UI 贴图层）
- 快照是账册页：主面板与错误面板都用 `SNParchmentPanel`，正文取
  `ink.primary`、次要说明取 `paper.ink_muted`、价格用 `brass.shadow`；
  返回按钮用 `SNGhostButton`。颜色不再写常量，统一 `SNSkin.color(token)`。
- 表格宽度（760 总宽 / 240/140/140/160 列）与 `PORT_MEMORY` 四列结构不变。

模块索引：[framework/ui](../../README.md)
