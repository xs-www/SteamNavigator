# `framework/domain/story/story_service.gd`

> 作用：新手剧情 / 教学系统的领域状态机。读取当前 map profile 的

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `StoryService` | L1 |
| `FEATURE_OVERVIEW` | L26 |
| `FEATURE_SUPPLY` | L27 |
| `FEATURE_CHART` | L28 |
| `FEATURE_MARKET` | L29 |
| `FEATURE_CONTRACTS` | L30 |
| `FEATURE_CLUES` | L31 |
| `FEATURE_TAVERN` | L32 |
| `FEATURE_SHIPYARD` | L33 |
| `FEATURES` | L34 |
| `EVENT_STAGE_ENTERED` | L39 |
| `EVENT_COMPLETED` | L40 |
| `EVENT_FEATURE_UNLOCKED` | L41 |
| `config(state: GameState, hub: RegistryHub) -> Dictionary` | L45 |
| `begin(state: GameState, hub: RegistryHub, rng: RngService = null) -> void` | L59 |
| `view(context) -> Dictionary` | L84 |
| `advance(context) -> Dictionary` | L140 |
| `skip(context) -> Dictionary` | L168 |
| `observe(context, event: String, data: Dictionary = {}) -> Dictionary` | L195 |

`data.story`（Core JSON）阶段表，维护 `GameState.data.story` 的进度、事件计数、
标志、功能 / 商品 / 模块解锁，并分发「发现委托目的港」等剧情效果。

- 关键依赖：`GameState.ensure_story()`、`ContentTypes.MAP_PROFILE`、`WorldOps`、
  `MapOps`、`GameState.contracts()`

## 契约与约束
- 剧情步骤 / 文案 / 解锁 / 数值全部来自 Core JSON；框架只认识 feature 键
  （`FEATURES`）与效果类型，不写死内容 ID。
- `data.story` 惰性 ensure：旧存档没有该块时视为「已看完 / 已跳过」，功能全开、
  不弹剧情（`completed=true`），不改 `schema_version`。
- 阶段推进：`mode=confirm` 由 `story.advance` 推进；条件型阶段在
  `story.observe(event, data)` 中按 `event / counter / at_least / flag / all`
  评估，可一次跨多个阶段。未知效果只 warning，不崩。
- 跳过教程必须解锁 `skip_unlocks` 里的全部功能并执行
  `discover_contract_destination`，保证跳过不会卡死。
- 查询（`story.view`）只输出公开字段；counters / flags 只暴露剧情效果需要的
  `lock_actions` 语义，不泄露内部数值。

模块索引：[framework/domain](../README.md)
