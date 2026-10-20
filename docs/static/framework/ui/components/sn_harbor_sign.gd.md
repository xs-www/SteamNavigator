# `framework/ui/components/sn_harbor_sign.gd`

> 作用：2.5D 港口主界面的主题化边缘招牌：`Button` 子类，用自绘木板/木纹/铁框/黄铜铆钉/四角包边/设施徽记/指向场景的箭头替代主题 StyleBox，悬停/按下/焦点用黄铜光晕与明暗反馈；点击、焦点、tooltip、`text` 语义仍由 Button 提供。

- 关键依赖：`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `COLOR_TEXT` | L18 |
| `COLOR_PRIMARY_TEXT` | L19 |
| `COLOR_MUTED` | L20 |
| `COLOR_BRASS` | L21 |
| `COLOR_BRASS_DIM` | L22 |
| `COLOR_IRON` | L23 |
| `COLOR_WOOD` | L24 |
| `COLOR_WOOD_LIGHT` | L25 |
| `COLOR_WOOD_DARK` | L26 |
| `COLOR_EMBLEM` | L27 |
| `GLYPH_COLOR` | L28 |
| `configure(label_text: String, sign_primary: bool, sign_facility: String, sign_arrow: int) -> void` | L63 |

## 契约与约束

- `configure(text, primary, facility, arrow)` 一次性写入标签/主次/徽记/箭头方向（-1 左列指向场景右侧、1 右列指向左侧、0 无箭头）；Shell 在把控件加入树前调用。
- `_ready()` 把 normal/hover/pressed/focus/disabled StyleBox 全部换成 `StyleBoxEmpty` 并把内建字体颜色设为透明，避免 Button 自带绘制与本组件重复；标签、箭头与徽记全部由 `_draw()` 绘制。
- 木纹/缝线以 `text.hash()` 取确定性相位，不使用随机数；悬停/焦点/按下只触发 `queue_redraw()`，没有每帧处理。
- `text` 保留完整标签（含「▶/◀」字形）供测试、tooltip 与无障碍；绘制时剥离箭头字形后在朝向场景的一侧画真实三角形。
- 徽记按设施 id 区分（exchange 硬币 / contracts 告示行 / supply 水滴 / intel 灯塔 / shipyard 船坞 / voyage 菱形），不依赖贴图资产。

## 重点逻辑

### `_draw()`

- 先画投影与木板底、确定性木纹与两条板缝，再画铁框（2 px）、黄铜内线、四角包边、两列黄铜铆钉；悬停/焦点加外圈黄铜光晕，按下加深底色。
- 文字用主题 font/font_size 居中绘制在徽记与箭头之间的可读区；颜色随 primary/悬停/按下切换。

模块索引：[framework/ui](../README.md)
