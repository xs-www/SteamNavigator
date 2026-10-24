# `framework/ui/components/sn_resource_meter.gd`

> 作用：煤水、耐久与载重共用的标签化资源存量条：无上限损失时用纹理化 Theme ProgressBar，有损失时自绘三段式条（已用 / 空余 / 右缘损失带），两套画法都取同一套皮肤纹理。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNResourceMeter` | L2 |
| `BAR_HEIGHT` | L32 |
| `FILL_STYLE_IDS` | L35 |
| `FILL_COLOR_TOKENS` | L39 |
| `TROUGH_STYLE_ID` | L42 |
| `TROUGH_FALLBACK_TOKEN` | L43 |
| `BORDER_FALLBACK_TOKEN` | L44 |
| `VALUE_COLOR_TOKEN` | L45 |
| `HINT_COLOR_TOKEN` | L46 |
| `LOSS_ALPHA` | L47 |
| `loss_bar_segments(width: float, current: float, maximum: float, loss: float) -> Dictionary` | L186 |

- 关键依赖：`assets/ui/theme/steam_navigator_theme.tres` 的 `SNBrassProgressBar` / `SNWaterProgressBar` / `SNDangerProgressBar`；`SNSkin.style("meter_trough"/"meter_fill_amber"/"meter_fill_aqua"/"meter_fill_rust")`；`SNSkin.color(token)`。

## 契约与约束
- 当前值显示在 [0, maximum]；`maximum_value` 下限 0.1，避免无效 ProgressBar 范围。
- `tone` 只切换 Theme variation 与填充纹理（黄铜 / 水青 / 锈红），名称、数值、单位与安全提示保持同一信息结构。
- `loss_value <= 0` 时继续使用主题 ProgressBar（耐久 / 载重路径不变）；`loss_value > 0` 时切换到自绘三段条：
  填充 `[0, current]`、空余 `[current, maximum]`、贴右边缘的损失带 `[maximum, maximum + loss]`。
- 条的总跨度为 `maximum + loss`，因此上限缩水（maximum 降、loss 升）时填充比例恒定不上升；
  几何由静态纯函数 `loss_bar_segments()` 计算，绘制与测试共用同一来源。
- `BAR_HEIGHT = 14`、节点名（Header/Name、Header/Value、Progress、LossBar、Hint）与既有信号/文案格式保持不变。
- 绘制只用 `draw_style_box` + 皮肤纹理；皮肤缺失时才退回 token 颜色，不写十六进制色值，也不新建 StyleBoxFlat。

## 用法
```gdscript
var meter := SNResourceMeter.new()
meter.label_text = "淡水"
meter.current_value = 39.0
meter.maximum_value = 50.0
meter.tone = SNResourceMeter.Tone.WATER
meter.loss_value = 10.0   # 显示右缘损失带
```

模块索引：[framework/ui](../README.md)
