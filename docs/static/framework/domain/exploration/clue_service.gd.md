# `framework/domain/exploration/clue_service.gd`

> 作用：港口位置线索的领域服务——生成（抵达传闻 / 酒馆购买）、按等级裁剪的只读视图、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ClueService` | L1 |
| `SOURCE_RUMOR` | L26 |
| `SOURCE_INTEL` | L27 |
| `SOURCES` | L28 |
| `DIRECTION_MIN_LEVEL` | L30 |
| `CIRCLE_MIN_LEVEL` | L31 |
| `NAME_MIN_LEVEL` | L32 |
| `clues(state: GameState) -> Dictionary` | L36 |
| `active(state: GameState) -> Array` | L41 |
| `find_clue(state: GameState, clue_id: String) -> Dictionary` | L45 |
| `eligible_target_ids(state: GameState) -> Array[String]` | L56 |
| `on_arrival(context) -> Dictionary` | L76 |
| `buy(context) -> Dictionary` | L99 |
| `acquire(context, source_key: String, rng: RandomNumberGenerator, target_port_id: String = "") -> Dictionary` | L142 |
| `mark_failed(state: GameState, clue_id: String) -> bool` | L212 |
| `mark_resolved(state: GameState, clue_id: String) -> bool` | L223 |
| `view(state: GameState, _context = null) -> Array` | L236 |
| `view_entry(state: GameState, clue: Dictionary) -> Dictionary` | L246 |
| `clue_acquired_event(clue: Dictionary) -> Dictionary` | L276 |

线索生命周期（active → resolved / failed）以及发现概率的规则计算。

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
- 查询视图裁剪：`level < 4` 不含 `name_key`、`level < 3` 不含 `circle`；**任何等级**
  都不输出 `target_port_id`、`credibility` 与 `search_zone` 中心误差来源。
  等级 1 不披露方向（`direction_angle` 固定 0），2 级披露方向，3/4 级再加圆圈。
- `on_arrival` / `buy` 永远不阻断抵达 / 出航流程：抽不到线索时只返回空结果。
- 线索不会被删除：失效进 `failed`，发现进 `resolved`，两者都保留 id 供 UI 提示。

模块索引：[framework/domain](../README.md)
