# `framework/ui/components/sn_section_header.gd`

> 作用：章节标题组合控件：眉题、标题、可选右侧说明，并可挂一枚 16–18 px 的皮肤图标；文字颜色与字号由 Theme 的 SNEyebrowLabel/SNTitleLabel/SNDetailLabel 变体决定。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSectionHeader` | L2 |
| `ICON_SIZE` | L24 |

- 关键依赖：`assets/ui/theme/steam_navigator_theme.tres`（三个 Label 变体）；`SNSkin.icon(id)` / `SNSkin.icon_rect(id, size)`。

## 契约与约束
- 内部子节点只创建一次，运行时与 `@tool` 编辑器预览共享同一同步路径。
- `detail` 为空时隐藏右侧标签，标题区自动占满剩余宽度；`detail` 可省略号截断，不能把同行按钮挤出可视区。
- `icon_id` 可选：为空时**不创建**图标节点，节点结构、行为与历史版本完全一致；图标缺失（皮肤未就绪）时隐藏图标而不是报错。
- 图标固定 17 px，位于眉题/标题左侧，不参与文字排版安全区计算。

## 用法
```gdscript
var header := SNSectionHeader.new()
header.eyebrow = "UI KIT"
header.title = "皮肤验收"
header.icon_id = "nav_chart"
```

模块索引：[framework/ui](../README.md)
