# `framework/ui/components/sn_sea_chart_panel.gd`

> 作用：海图右侧信息面板。选中港口后展示港口名、原型、区域、设施列表，以及

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSeaChartPanel` | L1 |
| `voyage_requested (signal)` | L27 |
| `explore_requested (signal)` | L29 |
| `purchase_clue_requested (signal)` | L31 |
| `COMPASS_KEYS` | L34 |
| `COMPASS_FALLBACK` | L36 |
| `LEVEL_FALLBACK` | L40 |
| `SOURCE_FALLBACK` | L43 |
| `get_clue() -> Dictionary` | L85 |
| `set_can_buy_clue(can_buy: Dictionary) -> void` | L91 |
| `clear() -> void` | L95 |
| `compass_key(angle: float) -> String` | L428 |

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
- **线索区块**（探索系统 4.1）：`bind_clue(clue)` 时面板改成显示一条线索——标题、
  来源（只给来源不给 credibility 数字）、等级、八方位、航程区间、预计航程/煤水/
  风险/可行性（不可行时列出 blockers 的 message_key）。「循此线索出航」发出
  `explore_requested(clue_id)`；`can_buy_clue.available` 时多一个购买按钮，发出
  `purchase_clue_requested`，由 Shell 执行 `clue.buy` 并刷新海图。
  面板仍不计算任何数值：预计值全部来自查询层的 `clue["estimated"]`。

模块索引：[framework/ui](../README.md)
