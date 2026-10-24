# `framework/ui/components/sn_badge.gd`

> 作用：紧凑状态徽标：中性、成功、警告和危险四种语义；底色、描边与文字色全部由纹理化 Theme 的 `SN*Badge` 变体提供，控件本身只做语义映射。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNBadge` | L2 |
| `VARIATIONS` | L25 |

- 关键依赖：`assets/ui/theme/steam_navigator_theme.tres` 的 `SNBadge` / `SNSuccessBadge` / `SNWarningBadge` / `SNDangerBadge`（Label 变体）。

## 契约与约束
- 保持 `extends Label`，不改成 HBox/容器：页面与测试按文本、尺寸和 Label 类型查找徽标。
- `Tone` 只切换 `theme_type_variation`；字号、内容边距、纹理底色由 Theme 统一，控件不写颜色。
- 颜色不能作为状态的唯一表达，调用方必须同时给出明确文字（如「已完成」「中等风险」）。

## 用法
```gdscript
var badge := SNBadge.new()
badge.tone = SNBadge.Tone.WARNING
badge.text = "中等风险"
```

模块索引：[framework/ui](../README.md)
