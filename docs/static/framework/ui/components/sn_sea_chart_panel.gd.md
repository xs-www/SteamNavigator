# `framework/ui/components/sn_sea_chart_panel.gd`

> 作用：海图右侧信息面板。选中港口后展示港口名、原型、区域、设施列表，以及

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSeaChartPanel` | L1 |
| `departure_requested (signal)` | L63 |
| `purchase_clue_requested (signal)` | L65 |
| `investigate_requested (signal)` | L67 |
| `COMPASS_KEYS` | L70 |
| `COMPASS_FALLBACK` | L72 |
| `LEVEL_FALLBACK` | L76 |
| `SOURCE_FALLBACK` | L79 |
| `MAX_CLUE_LEVEL` | L82 |
| `get_clue() -> Dictionary` | L118 |
| `set_can_buy_clue(can_buy: Dictionary) -> void` | L124 |
| `clear() -> void` | L128 |
| `compass_key(angle: float) -> String` | L656 |

**航程预估**（距离 / 预计时间 / 煤水消耗 / 风险 / 是否已探索），并提供「启航」按钮
（阶段 4.3.4 / U7 起只打开 Shell 的出航确认弹窗，不再跳转出航准备页）。

- 关键依赖：`sea_chart.view` 中的 port/route 字典与本地化回调。

## 契约与约束
- `bind(port_data, route_data, translate)` 注入数据；`clear()` 回到「点击港口」提示。
- 面板不自行计算距离/时间/风险/消耗；所有数值由查询层（`VoyageEstimator`）给出。
  距离标签直接读查询给出的 `distance`——它就是海图绘制路径的长度，也是
  `voyage.preview` 计费的同一个数（dev.3 反馈 #2 彻底修复后只剩这一把尺子）。
- 海图就是唯一世界：每条海图边都对应玩法世界的一条物理航线。**但能出航要求航线
  已解锁**（2026-10-26）：`route_data.unlocked == false` 时面板显示
  「未测绘航线：在酒馆购买海图解锁」并禁用「启航」按钮（命令层对同一 pair 也返回
  `route_locked`，面板不会承诺一个会被拒绝的航次）。
- 风险分档直接复用 `VoyageCalculator.risk_label`（low/medium/high），文案与颜色走本地化；
  查询给的 `risk_label` 优先，避免海图与出航预览对同一个分数给出不同档位。
- `risk_level < 0` 表示该航线没有可用的基础风险（海图边缺 `base_risk`），
  显示「无法评估」而不是「无风险」。
- 煤水块只在查询给出 `supplies` 时出现；`sufficient=false` 用警示色并提示，
  但不在这里拦截出航（阻断仍由确认弹窗里的 `voyage.preview` / 线索预估决定）。
- 点击「启航」发出 `departure_requested("voyage", port_id)`；线索区块的
  「循此线索出航」发出 `departure_requested("explore", clue_id)`。两者都由
  `SeaChartScreen` 转发，Shell 打开统一的出航确认弹窗（预估 + 锅炉策略切换 +
  取消/启航）后才执行 `voyage.start` / `explore.start`（4.3.4 / U7）。
- **线索区块**（探索系统 4.1）：`bind_clue(clue)` 时面板改成显示一条线索——标题、
  来源（只给来源不给 credibility 数字）、等级、八方位、航程区间、预计航程/煤水/
  风险/可行性（不可行时列出 blockers 的 message_key）。`can_buy_clue.available`
  时多一个购买按钮，发出 `purchase_clue_requested`，由 Shell 执行 `clue.buy`
  并刷新海图。
  面板仍不计算任何数值：预计值全部来自查询层的 `clue["estimated"]`。
- **逐级调查**（阶段 4.3.2 / U2）：线索区块显示「下一级：%s」预告（4 级显示已达最高），
  并多一个「调查线索」按钮，发出 `investigate_requested(clue_id)`。
  `can_investigate` 来自查询层（在港且 `level < 4`），面板只据它启用/禁用按钮。
  4.4.3 起按钮上方显示 Core 的调查成本行（金币 / 小时 / 成功率），
  `can_afford_investigation` 为假时成本行转警示色并禁用按钮。
- **货物行情线索**（阶段 4.4）：`type = port_goods` 时不显示方向 / 航程区间 / 探索
  出航按钮，改为类型标签、港口名、参考价区间（2 级起）、库存与供需（3 级起）、
  精确买卖价（4 级）与剩余时效（`ui.clue.expiry`）；底部「前往该港」按钮发
  `departure_requested("goods", clue_id)`（统一确认弹窗 → `clue.travel`）。等级文案
  用 `ui.clue.goods.level.N`；面板仍不重算行情、不读 `credibility`。

## 外观来源（外部贴图 + SNSkin）
- 面板底层用 Theme 变体 `SNPanel`（黄铜钢框纹理），内容边距由 theme 提供；
  不再 `StyleBoxFlat` / `add_theme_stylebox_override("panel")`。
- 所有文字 / 风险 / 状态色取 `SNSkin.color(token)`：text.light、text.muted、
  brass.highlight、state.water（航线信息）、state.success（已探索/可行）、
  state.warning（时效/未知风险）、state.danger（不可行/缺补给）。
- 按钮全部走 Theme 变体：启航 / 循此线索出航 / 前往该港 = `SNPrimaryButton`
  （图标 `nav_departure` / `status_route`，`icon_max_width` 18），调查 / 购买线索 =
  `SNSecondaryButton` / `SNGhostButton`；按钮 `text` 与节点名
  `DepartButton` / `ExploreButton` / `SailButton` / `InvestigateButton` /
  `PurchaseClueButton` 不变。
- 尺寸约束：`custom_minimum_size = (320, 0)` 不变；`_ready` 之后不新增子节点层级。

模块索引：[framework/ui](../README.md)
