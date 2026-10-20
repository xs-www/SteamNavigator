# `tools/godot/capture_exploration.gd`

> 作用：探索系统（海图阶段 4.1）的真实渲染截图工具。窗口模式挂载真正的

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L38 |
| `OUT_DIR` | L39 |
| `WINDOW` | L40 |
| `SEED` | L41 |
| `STEADY_BUILD` | L42 |
| `STRATEGY_ID` | L43 |
| `WATCHDOG_SECONDS` | L44 |
| `TMP_PREFIX` | L45 |
| `DRIVE_STEP` | L47 |
| `MAX_DRIVE_SECONDS` | L48 |
| `MAX_CLUE_ATTEMPTS` | L49 |
| `WANTED_LEVELS` | L51 |
| `SEA_CHART_SCREEN_SCRIPT` | L53 |
| `SETTLEMENT_SCREEN_SCRIPT` | L54 |
| `SHOTS` | L56 |
| `_init() -> void` | L69 |

`main.tscn`，用真实命令开一局（seed 20260421）、真实 `clue.buy` 买线索、
真实 `explore.start` / `explore.settle` 走完整探索演出，按
`docs/design/EXPLORATION_SYSTEM.md` §6 的里程碑抓图：海图线索可视化
（level 2 方向箭头 / level 3 虚线圆 / level 4 `？港名？` + 面板线索区块）、
探索演出（世界航线 + 到搜索区的虚线预测线 + `?` 终点 + 航程条 `？`）、
结算页探索结果区块（发现 / 失败两条都拍）。

用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
  godot --path . --resolution 1440x900 --script res://tools/godot/capture_exploration.gd

输出（1440×900，写入 `docs/design/screenshots/exploration/`）：
  exploration_chart_clues.png    海图线索：方向箭头、虚线圆、`？港名？`，选中线索高亮 + 右侧面板线索区块
  exploration_chart_route.png    探索演出：世界航线 + 到 `?` 的虚线预测线 + 底部航程条目的地 `？`
  exploration_arrival.png        第一次探索（发现）抵达结算：探索结果区块
  exploration_result_found.png   另一次发现结算（不同港口）
  exploration_result_failed.png  失败漂流结算：额外煤水 / 耐久损失 / 线索作废

## 契约与约束
- 全程用真实领域入口：`run.start` / `clue.buy` / `ClueService.acquire`
  （`RngService.STREAM_EXPLORATION` 命名流补充等级）/ 面板按钮 → `explore.start` →
  Shell 在 `ARRIVAL_READY` 自动 `explore.settle`。发现/失败只用契约 §2 的
  `outcome_roll`（出发时抽定，0 = 必发现、0.999 = 必失败）覆盖，不伪造结算结果。
- 开始港若是 iron_harbour（无情报站），照 `framework/tests/cases/test_exploration.gd`
  的做法补一个 `intel` 设施，`clue.buy` 本身仍是真实命令。
- **硬性断言**（不满足 exit 1 但已抓到的图照存）：`sea_chart.view.clues` 不含
  `target_port_id` / `credibility` / 真实 `search_zone`；面板线索文本非空且不含
  `ui.*` 原始键名；探索中 `SNSeaChartView._unknown_destination` 非空、航程条目的地
  显示 `？`、船 icon 沿航线切线；`explore.settle` 后成功当前港变为目标港 / 失败线索
  进入 failed；结算 summary 含 `explore` 且结算页有 `ExploreBlock`。
- 先写 `res://tmp_exploration_*`，全部 5 张成功后才移入 `docs/`，失败不留半套。
- 纯色/近纯色画面视为"读到未绘制纹理"，判失败；写完 PNG 会读回再验一次。
- 120 s 看门狗兜底：脚本错误会让协程中断而不退出，避免窗口挂住。

模块索引：[tools](../README.md)
