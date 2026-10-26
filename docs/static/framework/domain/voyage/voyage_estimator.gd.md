# `framework/domain/voyage/voyage_estimator.gd`

> 作用：把「一条航线 + 当前船况 + 锅炉策略 + 航行规则」折算成海图右侧面板需要的

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VoyageEstimator` | L1 |
| `LOW_SUPPLY_RATIO` | L27 |
| `estimate(context: Dictionary,, distance: float,, base_risk: float,, strategy: ContentDefinition) -> Dictionary` | L38 |

预计航程数据（耗时、煤水消耗、风险档位）。它是 `VoyageCalculator` 的只读投影，
不写状态、不改存档，也不做可行性判定。

## 契约与约束
- **距离只有一把尺子**：`distance` 就是海图世界该边的 `WorldMap.edges[].distance`
  （= 绘制路径折线长度 = `voyage.preview` 计费的 `MapOps.route_between().distance`，
  后者由 `ChartWorldProjection.from_chart` 从同一条海图边派生）。海图查询把它原样传进来，
  不存在「展示距离 / 计费距离」两个参数。
- **公式必须与 `VoyageCalculator.preview` 一致**：航速 = 船速 × 策略 `speed_mul` ×
  载重系数；`duration = distance / speed`；煤 = `duration × coal_rate × coal_mul`；
  水 = `duration × (water_rate × water_mul + 乘客数 × 0.06)`。这些常量直接引用
  `VoyageCalculator`，不复制一份，避免海图与出航预览给出两个数字。
- **风险**：`base_risk` 存在同一条海图边上（海图世界生成时按 `route_templates.risk_range`
  掷出）；调用方直接把它传进来，读不到时才传 -1，返回 `risk_level = -1`
  （面板显示「无法评估」），绝不把 0 当成「无风险」。
- `travel_hours` 与方向无关；煤水按**出发港**的船上补给计算，所以 `supplies` 只对
  「从当前港出发」的航线有直接意义，`sea_chart.view` 负责把这条语义解释给 UI
  （目的地面板只在选中港是邻居时才展示补给块）。

模块索引：[framework/domain](../README.md)
