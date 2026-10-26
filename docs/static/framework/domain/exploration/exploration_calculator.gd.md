# `framework/domain/exploration/exploration_calculator.gd`

> 作用：把「一条线索的搜索区 + 当前船况 + 锅炉策略 + 探索规则」折算成探索出航预览

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ExplorationCalculator` | L1 |
| `RISK_MIN` | L25 |
| `RISK_MAX` | L26 |
| `OVERLOAD_THRESHOLD` | L27 |
| `OVERLOAD_RISK` | L28 |
| `LOW_DURABILITY_RATIO` | L29 |
| `LOW_DURABILITY_RISK` | L30 |
| `preview(context, clue_id: String, strategy_id: String = "") -> Dictionary` | L35 |
| `effective_speed(context, strategy_id: String = "") -> float` | L158 |

（距离、耗时、煤水、工资、风险、发现概率、绕陆航线），供 `explore.start` 与海图
右侧面板使用。纯投影：不写状态、不抽发现结果。

- 关键依赖：`ClueService`、`ExplorationRules`、`WorldOps`、`RouteCalculator`、
  `ShipOps`、`VoyageCalculator`

## 契约与约束
- 航速 / 载重系数 / 煤水费率 / 工资 / 风险来源与 `VoyageCalculator.preview` 同一套
  公式与钳位：航速 = 船速 × 策略 `speed_mul` × 载重系数；煤 = 耗时 × 煤耗 ×
  `coal_mul`；水 = 耗时 ×（水耗 × `water_mul` + 乘客 × 0.06）；风险钳位 [0.01, 0.7]。
- 距离按坐标世界 `origin.position -> zone.center` 的**直线距离**；`route_path` 另用
  `RouteCalculator` 生成绕陆航线（失败退回直线），只用于演出画线。
- 探索航线不是海图世界的一条边，因此基础风险取探索规则：`risk_base +
  risk_per_unreliability * (1 - credibility)`，再叠加策略 / 超载 / 低耐久 / 装备风险。
- `discovery_chance` 只是展示值（规则函数），真实判定在 `explore.settle` 用出发时
  抽定的 `outcome_roll` 比较，预览绝不泄露 roll。
- 不可行时仍返回 `Result.ok`，把原因放进 `blockers`；`explore.start` 负责拒绝并保证
  不扣任何资源。

模块索引：[framework/domain](../README.md)
