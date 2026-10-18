# `framework/domain/voyage/voyage_calculator.gd`

> 作用：纯计算航行预览：速度、耗时、煤水、准点、风险来源与可行性阻断。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VoyageCalculator` | L1 |

## 契约与约束

- 有效航速 = 船体基础 × 锅炉系数 × 策略 × 重量系数 × 导航/岗位修正。
- 重量系数在 50% 载重内为 1.0，100% 为 0.65，超载继续线性下降并触发阻断。
- 煤/水需求基于耗时与单位时间消耗；旅客额外耗水。
- 预览返回 risk_score（内部）与 risk_sources（公开），不返回事故概率。
- 工资不足、补给不足、超重、无耐久都会进入 blockers。

## 重点逻辑

### `preview(context, destination_id, strategy_id)`

- 读取 strategy ContentDefinition，缺失或船只无效直接返回 Result.fail。
- 主线目的港匹配时附加 deadline/on_time/revenue_estimate。
- 所有计算只读；查询总线会额外克隆状态，保证无副作用。

### `weight_speed_factor(load_ratio)`

- 分段线性且连续：≤0.5 → 1.0；0.5–1.0 线性降至 0.65；>1.0 继续下降，最低 0.45。

模块索引：[framework/domain](../README.md)
