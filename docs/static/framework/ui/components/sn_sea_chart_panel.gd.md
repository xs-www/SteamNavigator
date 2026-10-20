# `framework/ui/components/sn_sea_chart_panel.gd`

> 作用：海图右侧信息面板。选中港口后展示港口名、原型、区域、设施列表，以及

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSeaChartPanel` | L1 |
| `voyage_requested (signal)` | L21 |
| `clear() -> void` | L48 |

**航程预估**（距离 / 预计时间 / 煤水消耗 / 风险 / 是否已探索），并提供「启航」按钮。

- 关键依赖：`sea_chart.view` 中的 port/route 字典与本地化回调。

## 契约与约束
- `bind(port_data, route_data, translate)` 注入数据；`clear()` 回到「点击港口」提示。
- 面板不自行计算距离/时间/风险/消耗；所有数值由查询层（`VoyageEstimator`）给出。
- 风险分档直接复用 `VoyageCalculator.risk_label`（low/medium/high），文案与颜色走本地化；
  查询给的 `risk_label` 优先，避免海图与出航预览对同一个分数给出不同档位。
- `risk_level < 0` 表示该航线没有可用的基础风险（坐标世界缺抽象地图对应边），
  显示「无法评估」而不是「无风险」。
- 煤水块只在查询给出 `supplies` 时出现；`sufficient=false` 用警示色并提示，
  但不在这里拦截出航（阻断仍由出航页的 `voyage.preview` 决定）。
- 点击「启航」发出 `voyage_requested(port_id)`，由 Shell 路由到 `voyage.start`。

模块索引：[framework/ui](../README.md)
