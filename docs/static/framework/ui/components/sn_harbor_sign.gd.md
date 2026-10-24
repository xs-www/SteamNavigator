# `framework/ui/components/sn_harbor_sign.gd`

> 作用：2.5D 港口主界面的边缘设施招牌。纹理化 `Button` 子类：底板/悬停/按下/焦点全部来自外部皮肤

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SIGN_SIZE` | L26 |
| `ICON_MAX_WIDTH` | L28 |
| `FACILITY_ICONS` | L30 |
| `configure(label_text: String, sign_primary: bool, sign_facility: String, sign_arrow: int) -> void` | L62 |

Theme 变体（`SNPrimaryButton` / `SNPlateButton`），设施徽记来自 `SNSkin.icon()`，文字由 Theme 绘制；
点击、焦点、键盘激活、tooltip 与 `text` 语义仍由 `Button` 提供。

## 外部贴图来源
- 皮肤：`assets/ui/skin/sn_v1/skin.json`（由 `tools/build_ui_skin.ps1` 从控件图集/图标图集生成）。
- 底板：Theme 的 `SNPlateButton`（普通招牌）与 `SNPrimaryButton`（主入口/海图招牌）四态纹理。
- 徽记：`SNSkin.icon()` 按 facility 映射到 `icons/*.png`（20 px 逻辑尺寸，`icon_max_width` 约束）。
- 本组件不写贴图路径、不写十六进制颜色，也不再用 `_draw()` 画木纹/铁框/铆钉/箭头。

## 用法
- Shell 在把招牌加入场景树前调用 `configure(label_text, sign_primary, sign_facility, sign_arrow)`；
  `text` 保留完整标签（含「◀ / ▶」字形）供测试、tooltip 与无障碍使用。
- `primary` 选择主按钮纹理，`facility` 选择徽记，`arrow_direction`（-1 左列 / 1 右列 / 0 无箭头）保留给
  Shell 布局与测试；`show_emblem = false` 可关闭图标。
- 皮肤/图标缺失时 `icon` 为 null，Theme 文字仍完整绘制，招牌保持可读、可点击。

## 尺寸预算
- 最小尺寸固定 `172 × 42`（与 Shell 的 `PORT_SIGN_WIDTH/HEIGHT` 一致），字号 14、图标 ≤20 px；
  招牌在 960×540 缩放下仍整体等比缩放，不裁字、不改尺寸。

模块索引：[framework/ui](../README.md)
