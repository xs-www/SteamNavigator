# `framework/ui/screens/menu/mods_screen.gd`

> 作用：已加载模组列表页面场景：只读展示本次启动实际载入的模组及依赖。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ModsScreen` | L1 |
| `action_requested (signal)` | L21 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L26 |

- 关键依赖：`app.view` 的 mods 摘要、`SNSectionHeader`、`SNSkin`、纹理化 Theme

## 契约与约束
- bind(vm, translate) 只消费 app.view 的 mods 摘要，不扫描文件系统、不改变加载顺序。
- 返回与重新扫描分别发出 back/retry 意图，Bootstrap 重试由 Shell 执行。
- 每个模组显示名称、ID、版本、来源、依赖与 required 标记。

## 皮肤与节点约束（UI 贴图层）
- 说明条用 `SNParchmentPanel` 纸签，模组条目用 `SNPanel` 钢制铭牌承托；
  模组名 `brass.highlight`、版本/来源/依赖等次要行 `text.muted`。
- 底部返回用 `SNGhostButton`、重新扫描用 `SNSecondaryButton`；按钮文本与顺序不变。
- 颜色统一 `SNSkin.color(token)`，不再保留颜色常量或内联样式；
  条目密度（13/17 px、8 px 分隔）与列表顺序不变。

模块索引：[framework/ui](../../README.md)
