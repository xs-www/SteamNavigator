# `framework/ui/components/sn_sea_chart_panel.gd`

> 作用：海图右侧信息面板。选中港口后展示港口名、原型、区域、设施列表与

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSeaChartPanel` | L1 |
| `voyage_requested (signal)` | L16 |
| `clear() -> void` | L43 |

航线信息（距离/预计时间/风险/是否已探索），并提供「启航」按钮。

- 关键依赖：`sea_chart.view` 中的 port/route 字典与本地化回调。

## 契约与约束
- `bind(port_data, route_data, translate)` 注入数据；`clear()` 回到「点击港口」提示。
- 面板不自行计算距离/时间/风险；所有数值由外部传入。
- 风险等级按阈值分四档（low/medium/high/extreme），文案与颜色均走本地化。
- 点击「启航」发出 `voyage_requested(port_id)`，由 Shell 路由到 `voyage.start`。

模块索引：[framework/ui](../README.md)
