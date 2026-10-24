# `framework/ui/components/sn_button.gd`

> 作用：可复用语义按钮：在 Inspector 中选择主操作、次操作、危险或幽灵样式，并可挂一枚皮肤图标；外观全部来自外部贴图驱动的 Theme variation，代码不写颜色与 StyleBox。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNButton` | L2 |
| `ICON_MAX_WIDTH` | L27 |
| `HEIGHT_DEFAULT` | L28 |
| `HEIGHT_COMPACT` | L29 |

- 关键依赖：`assets/ui/theme/steam_navigator_theme.tres` 的 `SNPrimaryButton` / `SNSecondaryButton` / `SNDangerButton` / `SNGhostButton` / `SNCompactButton`；`SNSkin.icon(id)` 取图标。

## 契约与约束
- `variant`（PRIMARY/SECONDARY/DANGER/GHOST）与 `compact` 是既有公开 API，枚举顺序与含义不变。
- `compact=true` 使用 `SNCompactButton` 小铭牌纹理，最小高度约 31 px；非 compact 保持 44 px。
- `icon_id` 可选：非空时把 `SNSkin.icon(icon_id)` 赋给 `Button.icon` 并统一 `icon_max_width=20`；空串只清理由 icon_id 设置的图标，不覆盖外部直接赋值的 `Button.icon`。不新增包装容器，文字/节点结构不变，现有调用无需改动。
- 图标缺失（皮肤未就绪）时保留无图标按钮，不报错。
- 不做尺寸位移/动画；hover/pressed/focus 由 Theme 状态样式负责。

## 用法
```gdscript
var button := SNButton.new()
button.variant = SNButton.Variant.PRIMARY
button.icon_id = "action_confirm"
button.text = "确认"
```

模块索引：[framework/ui](../README.md)
