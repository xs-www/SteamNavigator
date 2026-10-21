# `framework/domain/exploration/clue_service.gd`

> 作用：港口位置线索的领域服务——生成（抵达传闻 / 酒馆购买）、逐级调查披露

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ClueService` | L1 |
| `SOURCE_RUMOR` | L40 |
| `SOURCE_INTEL` | L41 |
| `SOURCES` | L42 |
| `DIRECTION_MIN_LEVEL` | L44 |
| `CIRCLE_MIN_LEVEL` | L45 |
| `NAME_MIN_LEVEL` | L46 |
| `clues(state: GameState) -> Dictionary` | L50 |
| `active(state: GameState) -> Array` | L55 |
| `find_clue(state: GameState, clue_id: String) -> Dictionary` | L59 |
| `eligible_target_ids(state: GameState) -> Array[String]` | L70 |
| `on_arrival(context) -> Dictionary` | L90 |
| `buy(context) -> Dictionary` | L113 |
| `acquire(context, source_key: String, rng: RandomNumberGenerator, target_port_id: String = "") -> Dictionary` | L156 |
| `investigate(context, clue_id: String) -> Dictionary` | L237 |
| `mark_attempt_failed(state: GameState, clue_id: String, at_time: float = -1.0) -> int` | L283 |
| `mark_resolved(state: GameState, clue_id: String) -> bool` | L293 |
| `view(state: GameState, _context = null) -> Array` | L306 |
| `view_entry(state: GameState, clue: Dictionary) -> Dictionary` | L316 |
| `clue_acquired_event(clue: Dictionary) -> Dictionary` | L348 |
| `clue_investigated_event(clue: Dictionary) -> Dictionary` | L361 |

（`investigate`，1→2→3→4）、按等级裁剪的只读视图、线索生命周期（active →
resolved；失败探索不再消耗线索）以及发现概率的规则计算。

- 关键依赖：`GameState.data.clues`（惰性 ensure）、`WorldOps`、`MapOps`、
  `ExplorationRules`、`ShipOps`、`VoyageCalculator`、`RngService.STREAM_EXPLORATION`

## 契约与约束
- 线索是纯数据，全部可 JSON 化；旧存档没有 `data.clues` 时由 `GameState.ensure_clues()`
  补齐，不改 `schema_version`。
- 目标只能是坐标世界里**未发现**、且没有被其它活跃线索指向的港口；没有目标时
  `acquire` 返回 `{}`（不报错）。测试 / 确定性入口可以显式给 `target_port_id` 跳过筛选，
  但仍然必须存在于坐标世界。
- 随机全部走命名流 `RngService.STREAM_EXPLORATION`，key 规则见
  `docs/design/EXPLORATION_SYSTEM.md` §4：传闻 `rumor:<port>:<time>`、
  购买 `intel:<port>:<time>`。同 seed + 同状态必须复现。
- 线索**获得时固定为 level 1**（阶段 4.3.2 / U2 起不再用 `level_weights` 抽等级）；
  等级只由 `investigate` 逐级推进（1→2→3→4，上限 4）。`level_weights` 仍保留在
  Core / schema / `ExplorationRules.DEFAULTS` 中，留给后续线索系统（内容兼容）。
- 同一线索的 `target_port_id` / `credibility` / `search_zone` / 方向角 / 航程区间在
  获得时固定，调查只是**逐级披露**（方向 → 圆圈 → 名称），绝不重抽目标。
- `investigate` 门禁：有 run、线索在 active、在港（`is_at_port()`）、`level < 4`；
  成功只改 `level`。具体消耗由 Core 预留 `investigation_cost` / `investigation_hours`
  （4.3 初始 0，不做资源判定、不扣钱、不推进时间），只随返回体与查询暴露给后续迭代。
- 查询视图裁剪：`level < 4` 不含 `name_key`、`level < 3` 不含 `circle`；**任何等级**
  都不输出 `target_port_id`、`credibility` 与 `search_zone` 中心误差来源。
  等级 1 不披露方向（`direction_angle` 固定 0），2 级披露方向，3/4 级再加圆圈。
- `on_arrival` / `buy` 永远不阻断抵达 / 出航流程：抽不到线索时只返回空结果。
- 线索不会被删除：发现进 `resolved` 并移出 active；**探索失败不消耗线索**
  （阶段 4.3 / U3）——`mark_attempt_failed` 只累加 `attempts`、写
  `last_attempt_at`，线索仍留在 active 且可再次 `explore.start`。旧存档 `failed`
  列表只保留历史 id，不再写入新条目。
- 每条线索在获得时固定 `attempts: 0` / `last_attempt_at: 0.0`；查询视图原样
  输出这两个字段，UI 据此提示「已尝试 N 次」。

模块索引：[framework/domain](../README.md)
