# `dev_scenes/sea_chart/sea_chart_preview.gd`

> 作用：海图系统（阶段 2）的独立预览场景，把 `sea_chart.view` 查询、`SNSeaChartView`

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PREVIEW_PROFILE` | L20 |
| `PREVIEW_NAMES` | L82 |
| `SEED` | L94 |
| `PANEL_WIDTH` | L95 |
| `VISION_RADIUS` | L96 |
| `PORT_REVEAL_RADIUS` | L97 |
| `set_variant(variant_name: String) -> void` | L189 |
| `get_chart() -> SNSeaChartView` | L429 |
| `get_panel() -> SNSeaChartPanel` | L433 |

与 `SNSeaChartPanel` 按真实布局（海图铺满 + 右侧 320 px 信息面板）拼起来，供窗口截图
与人工目视验收使用。不属于主流程，不写存档。

## 契约与约束
- 用与 `framework/tests/test_case.gd` 相同的 Bootstrap 配置加载 loose Core，
  再用 `WorldGenerator.generate()` 造一个可复现世界（seed 固定）。
- 四个变体通过 `set_variant()` 切换，只改变迷雾/已发现集合/船只位置：
  `fresh`（仅起点港已发现，大片黑雾）、`bare`（诊断：整图已揭示，无迷雾干扰）、
  `explored`（多港口 + 航线 + 沿岸航行留下的永久灰雾带与整岛剪影）、
  `voyage`（在航 + 选中目的港，右侧面板有数据，船停在 45% 弧长处）。
- `explored` / `voyage` 会按路径真实回放 `FogOps.update_ship_vision`，所以灰雾带是
  阶段 1 的真实产出，不是画上去的；`bare` 用全 VISIBLE 网格表达"无迷雾"（查询在没有
  迷雾数据时会注入全黑网格，所以不能靠"缺数据"表达已揭示）。
- 所有数据都来自真实查询，预览不伪造港口/航线坐标。

模块索引：[dev_scenes](../README.md)
