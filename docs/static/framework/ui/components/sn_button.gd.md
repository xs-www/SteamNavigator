# `framework/ui/components/sn_button.gd`

> 作用：可复用语义按钮：在 Inspector 中选择主操作、次操作、危险或幽灵样式。

- 关键依赖：`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNButton` | L2 |

## 契约与约束

- 只通过 `theme_type_variation` 选择视觉状态，不在业务页面复制 StyleBox。
- 默认保留键盘焦点并使用指针光标；compact 只调整高度和字号。

模块索引：[framework/ui](../README.md)
