# `tools/godot/capture_clue_expansion.gd`

> 作用：阶段 4.4 线索扩展的真实渲染截图工具（窗口模式）。开一局真实对局（seed

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L30 |
| `OUT_DIR` | L31 |
| `WINDOW` | L32 |
| `SEED` | L33 |
| `STEADY_BUILD` | L34 |
| `STRATEGY_ID` | L35 |
| `WATCHDOG_SECONDS` | L36 |
| `TMP_PREFIX` | L37 |
| `SEA_CHART_SCREEN_SCRIPT` | L39 |
| `CLUE_LOG_SCREEN_SCRIPT` | L40 |
| `SHOTS` | L42 |
| `_init() -> void` | L54 |

20260421），通过真实领域入口准备一条 `port_goods` 货物行情线索（第二个已发现港口 +
`ClueService.acquire_goods` + `clue.investigate` 升到 4 级），打开真正的海图页，
抓「货物行情线索面板」与「前往该港」统一出航确认弹窗两张图。

用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
  godot --path . --resolution 1440x900 --script res://tools/godot/capture_clue_expansion.gd

输出（1440×900，写入 `docs/design/screenshots/exploration/`）：
  clue_goods_lead.png    货物行情线索面板：类型 / 港口 / 参考价 / 库存供需 /
                         精确买卖价 / 剩余时效 /「前往该港」按钮（无探索出航按钮）
  clue_goods_depart.png  点击「前往该港」后的统一出航确认弹窗（kind = goods）

## 契约与约束
- 行情线索用真实服务与真实命令构造：`ClueService.acquire_goods`（命名流
  `RngService.STREAM_EXPLORATION`）+ `clue.investigate` ×3 升到 4 级；第二个已发现
  港口用 `WorldOps.discover_port_id` / `MapOps.discover` 做成测试夹具（真实对局里
  由探索 / 抵达产生），不伪造渲染数据。
- 硬性断言：`sea_chart.view.clues` 里的货物线索含 type / goods / expires_at /
  remaining_hours / can_sail 且**不含** target_port_id / credibility / 真实
  search_zone；面板文本含类型、港口名、精确行情、剩余时效；`SailButton` 存在且启用、
  `ExploreButton` 不存在；确认弹窗标题走 `ui.confirm.title.goods` 且「启航」可用。
- 先写 `res://tmp_clue_expansion_*`，全部成功后才移入 `docs/`，失败不留半套。
- 纯色/近纯色画面视为"读到未绘制纹理"，判失败；写完 PNG 会读回再验一次。
- 120 s 看门狗兜底：脚本错误会让协程中断而不退出，避免窗口挂住。

模块索引：[tools](../README.md)
