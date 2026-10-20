# `framework/ui/components/sn_resource_meter.gd`

> 作用：煤水、耐久与载重共用的标签化资源存量条。

- 关键依赖：`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNResourceMeter` | L2 |
| `COLOR_BRASS` | L14 |
| `COLOR_WATER` | L15 |
| `COLOR_DANGER` | L16 |
| `COLOR_TRACK` | L17 |
| `COLOR_TRACK_BORDER` | L18 |
| `COLOR_CAP_LOSS` | L19 |
| `COLOR_CAP_LOSS_DANGER` | L20 |
| `BAR_HEIGHT` | L21 |
| `loss_bar_segments(width: float, current: float, maximum: float, loss: float) -> Dictionary` | L152 |

## 契约与约束

- 当前值在 0 到最大值之间显示；最大值最低为 0.1，避免无效 ProgressBar 范围。
- 色调只切换 Theme variation，名称、数值、单位与安全提示保持同一信息结构。
- loss_value<=0 时仍用主题 ProgressBar（耐久/载重路径不变）；loss_value>0 时改用三分段自绘条：填充 [0,current]、空余 [current,maximum]、贴右边缘的损失带 [maximum,maximum+loss]。
- 条的总跨度为 maximum+loss，因此上限缩水（maximum 降、loss 升）时填充比例恒定不上升；几何由静态纯函数 loss_bar_segments() 计算，绘制与测试共用。
- 不修改 assets/ui/theme/*.tres，自绘颜色常量镜像主题黄铜/水色/危险色。

模块索引：[framework/ui](../README.md)
