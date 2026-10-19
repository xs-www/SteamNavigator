# `framework/ui/screens/menu/settings_screen.gd`

> 作用：设置页面场景：展示语言、自动存档与配置位置，并发出设置修改意图。

- 关键依赖：`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SettingsScreen` | L1 |
| `action_requested (signal)` | L5 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L12 |

## 契约与约束

- bind(vm, translate) 接收 locale、autosave_enabled 与 show_settings_path，不直接读写 SettingsService。
- 语言与自动存档操作发出 set_locale/toggle_autosave；Shell 更新运行时上下文并持久化。
- 设置项标签保留固定字段宽度，横向选项和状态文案禁止智能折成逐字竖排。
- 返回主菜单只发出 back 意图；配置保存结果由 Shell 状态条反馈。

模块索引：[framework/ui](../../README.md)
