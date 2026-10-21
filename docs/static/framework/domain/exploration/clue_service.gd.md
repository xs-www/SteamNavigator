# `framework/domain/exploration/clue_service.gd`

> 作用：线索的领域服务——港口位置线索（抵达传闻 / 情报站购买）与货物行情线索

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ClueService` | L1 |
| `SOURCE_RUMOR` | L46 |
| `SOURCE_INTEL` | L47 |
| `SOURCE_WAIT` | L48 |
| `SOURCE_CONTRACT` | L49 |
| `SOURCES` | L50 |
| `TYPE_PORT_LOCATION` | L53 |
| `TYPE_PORT_GOODS` | L54 |
| `TYPES` | L55 |
| `DIRECTION_MIN_LEVEL` | L58 |
| `CIRCLE_MIN_LEVEL` | L59 |
| `NAME_MIN_LEVEL` | L60 |
| `GOODS_PRICE_MIN_LEVEL` | L62 |
| `GOODS_SUPPLY_MIN_LEVEL` | L63 |
| `GOODS_EXACT_MIN_LEVEL` | L64 |
| `FALLBACK_GOODS_EXPIRY_HOURS` | L66 |
| `clues(state: GameState) -> Dictionary` | L70 |
| `active(state: GameState) -> Array` | L76 |
| `normalize_clue(clue: Dictionary) -> Dictionary` | L85 |
| `is_expired(clue: Dictionary, at_time: float) -> bool` | L102 |
| `active_count(state: GameState, at_time: float = -1.0) -> int` | L109 |
| `sweep_expired(state: GameState, at_time: float = -1.0) -> Array[String]` | L122 |
| `find_clue(state: GameState, clue_id: String) -> Dictionary` | L147 |
| `eligible_target_ids(state: GameState) -> Array[String]` | L158 |
| `on_arrival(context) -> Dictionary` | L178 |
| `wait_clue_chance(rules: Dictionary, hours: int) -> float` | L202 |
| `on_wait(context, hours: int) -> Dictionary` | L214 |
| `on_contract_completed(context, completed: Array) -> Dictionary` | L241 |
| `buy(context) -> Dictionary` | L297 |
| `acquire(context, source_key: String, rng: RandomNumberGenerator, target_port_id: String = "") -> Dictionary` | L349 |
| `acquire_goods(context, source_key: String, rng: RandomNumberGenerator) -> Dictionary` | L433 |
| `goods_candidates(context) -> Array` | L513 |
| `investigate(context, clue_id: String) -> Dictionary` | L565 |
| `travel(context, clue_id: String, strategy_id: String) -> Dictionary` | L693 |
| `mark_attempt_failed(state: GameState, clue_id: String, at_time: float = -1.0) -> int` | L743 |
| `mark_resolved(state: GameState, clue_id: String) -> bool` | L753 |
| `view(state: GameState, _context = null) -> Array` | L767 |
| `view_entry(state: GameState, clue: Dictionary) -> Dictionary` | L780 |
| `clue_acquired_event(clue: Dictionary) -> Dictionary` | L867 |
| `clue_investigated_event(clue: Dictionary) -> Dictionary` | L880 |
| `clue_investigation_failed_event(clue: Dictionary, cost: int, hours: float) -> Dictionary` | L892 |
| `clue_expired_event(clue_ids: Array[String]) -> Dictionary` | L907 |
| `expired_events_of(clue_ids: Array[String]) -> Array` | L915 |

（`port_goods`：已发现港口 + 货物 + 冻结行情快照 + 到期时间）的生成、逐级调查披露
（`investigate`，1→2→3→4）、时效清理、按等级裁剪的只读视图、线索生命周期
（active → resolved / expired；失败探索不再消耗线索）以及发现概率的规则计算。

- 关键依赖：`GameState.data.clues`（惰性 ensure）、`WorldOps`、`MapOps`、
  `ExplorationRules`、`ShipOps`、`VoyageCalculator`、`MarketOps`、
  `RngService.STREAM_EXPLORATION`

## 契约与约束
- 线索是纯数据，全部可 JSON 化；旧存档没有 `data.clues` 时由 `GameState.ensure_clues()`
  补齐，旧线索条目由 `normalize_clue()` 惰性补 `type` / `target_goods_id` /
  `goods_snapshot` / `expires_at` / `unlock_source`，不改 `schema_version`。
- 港口位置线索的目标只能是坐标世界里**未发现**、且没有被其它活跃线索指向的港口；
  没有目标时 `acquire` 返回 `{}`（不报错）。测试 / 确定性入口可以显式给
  `target_port_id` 跳过筛选，但仍然必须存在于坐标世界。
- 货物线索（4.4）的目标 = **已发现、非当前港**的港口 + 该港 `buyable` 的非补给货物；
  获得时冻结 `goods_snapshot`（买价 / 卖价 / 库存 / 供需 / 记录时间），按
  `goods_clue_expiry_hours[source]` 秒表到期；行情不随后市重抽。
- 随机全部走命名流 `RngService.STREAM_EXPLORATION`：港口传闻 `rumor:<port>:<time>`、
  购买 `intel:<port>:<time>`，4.4 新增来源见 §11（`wait:*` / `contract:*`）。
- 线索**获得时固定为 level 1**（阶段 4.3.2 / U2 起不再用 `level_weights` 抽等级）；
  等级只由 `investigate` 逐级推进（1→2→3→4，上限 4）。`level_weights` 仍保留在
  Core / schema / `ExplorationRules.DEFAULTS` 中，留给后续线索系统（内容兼容）。
- 同一线索的 `target_port_id` / `credibility` / 搜索区 / 方向角 / 航程区间在获得时
  固定，调查只是**逐级披露**，绝不重抽目标。货物线索逐级披露：
  1 级港口名 → 2 级参考价区间 → 3 级区间 + 供需 / 库存 → 4 级精确买卖价。
- 调查消耗（4.4 起真实生效）：金币 / 在港小时 / 成功率来自 Core，失败照扣成本但不
  升级、线索保留；`investigation_cost/hours = 0` 且 `chance = 1` 时保持 4.3 行为。
- 查询视图裁剪：任何类型、任何等级都不输出 `target_port_id`、`credibility`、
  真实 `search_zone` 与未披露的 `goods_snapshot` 明细；港口位置线索保持
  `level < 4` 无 `name_key`、`level < 3` 无 `circle`、level 1 无方向。
- 时效：`expires_at > 0 且 <= now` 的线索由**命令路径**的 `sweep_expired()` 移入
  `data.clues.expired`（保留整条快照）并释放 `max_active_clues` 名额；查询只过滤不写。
- `on_arrival` / `buy` / 新来源钩子永远不阻断抵达 / 出航 / 等待流程：抽不到线索时
  只返回空结果。
- 线索不会被删除：发现进 `resolved`、过期进 `expired`；**探索失败不消耗线索**
  （阶段 4.3 / U3）——`mark_attempt_failed` 只累加 `attempts`、写
  `last_attempt_at`，线索仍留在 active 且可再次 `explore.start`。旧存档 `failed`
  列表只保留历史 id，不再写入新条目。

模块索引：[framework/domain](../README.md)
