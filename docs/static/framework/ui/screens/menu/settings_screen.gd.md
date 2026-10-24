# `framework/ui/screens/menu/settings_screen.gd`

> 作用：设置页面场景：展示语言、自动存档与配置位置，并发出设置修改意图。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SettingsScreen` | L1 |
| `action_requested (signal)` | L24 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L29 |

- 关键依赖：`settings` / Shell 组合的视图模型、`SNSectionHeader`、`SNSkin`、纹理化 Theme

## 契约与约束
- bind(vm, translate) 接收 locale、autosave_enabled 与 show_settings_path，不直接读写
  SettingsService。
- 语言与自动存档操作发出 set_locale/toggle_autosave；Shell 更新运行时上下文并持久化。
- 设置项标签保留固定字段宽度（96 px），横向选项和状态文案禁止智能折成逐字竖排
  （`_label` 关闭自动换行，test_ui_shell 直接调用 `_label` 断言这一点）。
- 返回主菜单只发出 back 意图；配置保存结果由 Shell 状态条反馈。

## 皮肤与节点约束（UI 贴图层）
- 表单用 `SNParchmentPanel` 纸面承托，说明条用 `SNPanel` 钢框；字段名
  `ink.primary`、当前值/说明 `paper.ink_muted`，按钮统一 Theme 变体
  （语言切换 `SNSecondaryButton`、自动存档 `SNPlateButton`、返回 `SNGhostButton`）。
- 颜色只取 `SNSkin.color(token)`；`_label(text, size, color)` 签名与 96 px 字段宽、
  两行设置结构、按钮文本均不变。

模块索引：[framework/ui](../../README.md)
