# `tools/godot/capture_exploration.gd`

> 作用：探索系统（海图阶段 4.1 + 4.2 资源告急决策）的真实渲染截图工具。窗口模式

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L58 |
| `OUT_DIR` | L59 |
| `WINDOW` | L60 |
| `SEED` | L61 |
| `STEADY_BUILD` | L62 |
| `STRATEGY_ID` | L63 |
| `WATCHDOG_SECONDS` | L64 |
| `TMP_PREFIX` | L65 |
| `DRIVE_STEP` | L67 |
| `MAX_DRIVE_SECONDS` | L68 |
| `MAX_CLUE_ATTEMPTS` | L69 |
| `WANTED_LEVELS` | L71 |
| `SEA_CHART_SCREEN_SCRIPT` | L73 |
| `SETTLEMENT_SCREEN_SCRIPT` | L74 |
| `EVENT_SCREEN_SCRIPT` | L75 |
| `SHOTS` | L77 |
| `_init() -> void` | L95 |

挂载真正的 `main.tscn`，用真实命令开一局（seed 20260421）、真实 `clue.buy` 买线索、
真实 `explore.start` / `explore.settle` / `explore.decide` 走完整探索演出，按
`docs/design/EXPLORATION_SYSTEM.md` §6 的里程碑抓图：海图线索可视化
（level 2 方向箭头 / level 3 虚线圆 / level 4 `？港名？` + 面板线索区块）、
探索演出（世界航线 + 到搜索区的虚线预测线 + `?` 终点 + 航程条 `？`）、
路线资源告急决策页（继续 / 掉头）、以及结算页探索结果区块
（发现 / 失败漂流 / 掉头返航 / 告警后继续）。

用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
  godot --path . --resolution 1440x900 --script res://tools/godot/capture_exploration.gd

输出（1440×900，写入 `docs/design/screenshots/exploration/`）：
  exploration_chart_clues.png      海图线索：方向箭头、虚线圆、`？港名？`，选中线索高亮 + 右侧面板线索区块
  exploration_chart_investigate.png 4.3.2：选中 2 级线索时的「调查线索」按钮 +「下一级：已知航程」预告
  exploration_depart_confirm.png   4.3.4：海图内出航确认弹窗（预估 / 锅炉策略 / 取消 / 启航）
  exploration_chart_route.png      探索演出：世界航线 + 到 `?` 的虚线预测线 + 底部航程条目的地 `？`
  exploration_arrival.png          第一次探索（发现）抵达结算：探索结果区块
  exploration_result_found.png     另一次发现结算（不同港口）
  exploration_result_failed.png    失败漂流结算：额外煤水 / 耐久损失 / 线索保留（4.3）
  exploration_resource_alert.png   4.2 资源告急页：标题/描述/煤水耐久/继续探索/掉头返航
  exploration_turned_back.png      4.2 / 4.3.5 掉头返航结算：港口 / 额外损耗 / 线索保留
  exploration_alert_continue.png   4.2 告警后继续探索的结算（证明继续路径照常 settle）

## 契约与约束
- 全程用真实领域入口：`run.start` / `clue.buy` / `ClueService.acquire`
  （`RngService.STREAM_EXPLORATION` 命名流）/ `clue.investigate`（4.3.2 逐级升级）/
  海图面板按钮 → 出航确认弹窗 → `explore.start` → Shell 在 `ARRIVAL_READY`
  自动 `explore.settle`；4.2 的告警选项通过真实 `EventScreen` 按钮 →
  `explore.decide` → `VoyagePresentation.force_arrival()`。
  发现/失败只用契约 §2 的 `outcome_roll`（出发时抽定，0 = 必发现、0.999 = 必失败）
  覆盖，不伪造结算结果；告警用真实 `ExplorationCalculator.preview` 的
  `coal_required`，把出发煤量压到 `×1.05`（与 `test_voyage_flow.gd` 的告警前置一致）。
- 开始港若是 iron_harbour（无情报站），照 `framework/tests/cases/test_exploration.gd`
  的做法补一个 `intel` 设施，`clue.buy` 本身仍是真实命令。
- **硬性断言**（不满足 exit 1 但已抓到的图照存）：`sea_chart.view.clues` 不含
  `target_port_id` / `credibility` / 真实 `search_zone`；面板线索文本非空且不含
  `ui.*` 原始键名；探索中 `SNSeaChartView._unknown_destination` 非空、航程条目的地
  显示 `？`、船 icon 沿航线切线；`explore.settle` 后成功当前港变为目标港 / 失败
  线索仍 active（4.3/U3，只记 attempts）、`failed` 列表不新增；结算 summary 含
  `explore` 且结算页有 `ExploreBlock`。
- 4.2 追加：告警页处于 `EVENT_WAIT` 且 `_presentation.skip() == NONE`（决策不可被
  跳过）、文案全部本地化且不泄露目标港、`sea_chart.view.explore` 暴露
  `alert_needed/alert_progress/alert_decided`；掉头后 `current_port == origin`、线索
  仍 active、`summary.explore.result == "turned_back"`、命令日志里没有
  `not_exploring` 也没有第二次 `explore.settle`；继续路径会正常 `explore.settle`
  并保留 `alert_decided == "continue"`，重复回答返回 `alert_already_decided`。
- 4.4.3：`clue.investigate` 有 Core 成功率（0.75）与成本，所以逐级升级改为
  「重试直到目标等级」的循环（每次失败照扣 20 金 / 6h，但不升级）；升级次数以
  `[EVIDENCE] ... attempts` 记录。
- 先写 `res://tmp_exploration_*`，全部 8 张成功后才移入 `docs/`，失败不留半套。
- 纯色/近纯色画面视为"读到未绘制纹理"，判失败；写完 PNG 会读回再验一次。
- 120 s 看门狗兜底：脚本错误会让协程中断而不退出，避免窗口挂住。

模块索引：[tools](../README.md)
