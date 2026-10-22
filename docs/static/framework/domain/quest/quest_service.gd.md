# `framework/domain/quest/quest_service.gd`

> 作用：抽象任务（Quest）状态机（C3）。把 `quests` 2.0 内容定义（stage 链 + 目标 DSL）

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `QuestService` | L1 |
| `EVENT_STARTED` | L27 |
| `EVENT_UPDATED` | L28 |
| `EVENT_COMPLETED` | L29 |
| `TASK_PRIORITY` | L32 |
| `TASK_KIND` | L33 |
| `TASK_CATEGORY_KEY` | L34 |
| `STEP_KIND` | L36 |
| `definition(hub: RegistryHub, quest_id: String) -> ContentDefinition` | L44 |
| `stages_of(hub: RegistryHub, quest_id: String) -> Array` | L50 |
| `current_stage(hub: RegistryHub, instance: Dictionary) -> Dictionary` | L59 |
| `start(context, quest_id: String) -> Dictionary` | L73 |
| `complete(context, instance_id: String) -> Dictionary` | L106 |
| `observe(context, event: String, data: Dictionary = {}) -> Dictionary` | L134 |
| `track_contract(state: GameState, contract: Dictionary) -> Dictionary` | L184 |
| `complete_contract_by_instance(state: GameState, contract_instance_id: String, completed_at: float = 0.0) -> Dictionary` | L195 |
| `instance_view(state: GameState, hub: RegistryHub, instance: Dictionary) -> Dictionary` | L213 |
| `active_instances(state: GameState, hub: RegistryHub = null) -> Array` | L275 |
| `has_active_content(state: GameState) -> bool` | L294 |

实例化进 `data.quests`，按 `cmd:*` / `ui:*` 事件推进 counter、跨 stage 前进并完成；
委托接取时生成 contract 来源的追踪实例，委托完成时标记该实例 completed。

- 关键依赖：`ContentTypes.QUEST`、`QuestOps`、`GameState.ensure_story()`（前置 flag）、
  `ContentDefinition`、`Result`

## 契约与约束
- **Contract 独立**：quest 不复制委托 payload / 目的地 / 时限 / 奖励；contract 来源
  实例只存 `contract_instance_id` 作追踪引用，进度与结算仍由 `ContractOps` 负责。
- 起点：`start(context, quest_id)` 校验定义存在、`repeatable`、重复接取与
  `prerequisites.quests_completed / flags`（flag 读 `data.story.flags`）。
- 推进：`observe(context, event, data)` 只作用于 active **content** 实例；目标复用剧情
  DSL（`event` / `counter` / `at_least` / `match`），`payload.amount` 累加到 counter，
  无 counter 的目标使用隐式出现次数计数；本 stage 全部 objective 达标才前进。
- 完成：最后一个 stage 达标或 `complete()` 手动完成；重复完成/接取返回结构化失败。
- 事件：`quest.started` / `quest.updated` / `quest.completed`（payload 只含实例引用与
  stage 序号，不含内容 payload）。
- 存档：状态只在 `data.quests`（`QuestOps` 惰性 ensure），不改 `state.schema_version`；
  旧档无块 = 无任务，行为不变。
- `instance_view()` 给 `task.view` / 命令返回用：标题与 steps 全部来自内容 key，不写死 ID。

模块索引：[framework/domain](../README.md)
