# `dev_scenes/sea_chart/sea_chart_preview.gd`

> 作用：海图系统（阶段 2）的独立预览场景，把 `sea_chart.view` 查询、`SNSeaChartView`

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PREVIEW_PROFILE` | L18 |
| `PREVIEW_NAMES` | L71 |
| `SEED` | L85 |
| `PANEL_WIDTH` | L86 |
| `VISION_RADIUS` | L87 |
| `PORT_REVEAL_RADIUS` | L88 |
| `set_variant(variant_name: String) -> void` | L162 |
| `get_chart() -> SNSeaChartView` | L388 |
| `get_panel() -> SNSeaChartPanel` | L392 |

与 `SNSeaChartPanel` 按真实布局（海图铺满 + 右侧 320 px 信息面板）拼起来，供窗口截图
与人工目视验收使用。不属于主流程，不写存档。

## 契约与约束
- 用与 `framework/tests/test_case.gd` 相同的 Bootstrap 配置加载 loose Core，
  再用 `WorldGenerator.generate()` 造一个可复现世界（seed 固定）。
- 三种变体通过 `set_variant()` 切换，只改变迷雾/已发现集合/船只位置：
  `fresh`（仅起点港已发现，大片黑雾）、`explored`（多个已发现港口 + 航线 +
  海岸灰雾）、`voyage`（在航 + 选中目的港，右侧面板有数据）。
- 迷雾由 `FogOps` 真实生成：标记海岸单元 → 港口揭示 → 船只视野 → alpha 平滑，
  因此截图同时验证阶段 1 与阶段 2。
- 所有数据都来自真实查询，预览不伪造端口/航线坐标。

模块索引：[dev_scenes](../README.md)
