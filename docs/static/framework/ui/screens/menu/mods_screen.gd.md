# `framework/ui/screens/menu/mods_screen.gd`

> 作用：已加载模组列表页面场景：只读展示本次启动实际载入的模组及依赖。

- 关键依赖：`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ModsScreen` | L1 |
| `action_requested (signal)` | L5 |
| `TEXT` | L7 |
| `MUTED` | L8 |
| `BRASS` | L9 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L13 |

## 契约与约束

- bind(vm, translate) 只消费 app.view 的 mods 摘要，不扫描文件系统、不改变加载顺序。
- 返回与重新扫描分别发出 back/retry 意图，Bootstrap 重试由 Shell 执行。
- 每个模组显示名称、ID、版本、来源、依赖与 required 标记。

模块索引：[framework/ui](../../README.md)
