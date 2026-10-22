# `framework/domain/quest/quest_service.gd`

> 作用：抽象任务（Quest）状态机（C3）。把 `quests` 2.0 内容定义（stage 链 + 目标 DSL）

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `QuestService` | L1 |
| `EVENT_STARTED` | L35 |
| `EVENT_UPDATED` | L36 |
| `EVENT_COMPLETED` | L37 |
| `TASK_PRIORITY` | L40 |
| `TASK_KIND` | L41 |
| `TASK_CATEGORY_KEY` | L42 |
| `STEP_KIND` | L44 |
| `definition(hub: RegistryHub, quest_id: String) -> ContentDefinition` | L52 |
| `stages_of(hub: RegistryHub, quest_id: String) -> Array` | L58 |
| `current_stage(hub: RegistryHub, instance: Dictionary) -> Dictionary` | L67 |
| `start(context, quest_id: String) -> Dictionary` | L81 |
| `start_state(state: GameState, hub: RegistryHub, quest_id: String) -> Dictionary` | L91 |
| `auto_start_state(state: GameState, hub: RegistryHub) -> Dictionary` | L123 |
| `auto_start(context) -> Dictionary` | L156 |
| `complete(context, instance_id: String) -> Dictionary` | L166 |
| `observe(context, event: String, data: Dictionary = {}) -> Dictionary` | L200 |
| `track_contract(state: GameState, contract: Dictionary) -> Dictionary` | L254 |
| `complete_contract_by_instance(state: GameState, contract_instance_id: String, completed_at: float = 0.0) -> Dictionary` | L265 |
| `instance_view(state: GameState, hub: RegistryHub, instance: Dictionary) -> Dictionary` | L283 |
| `active_instances(state: GameState, hub: RegistryHub = null) -> Array` | L345 |
| `has_active_content(state: GameState) -> bool` | L364 |

实例化进 `data.quests`，按 `cmd:*` / `ui:*` 事件推进 counter、跨 stage 前进并完成；
委托接取时生成 contract 来源的追踪实例，委托完成时标记该实例 completed。

- 关键依赖：`ContentTypes.QUEST`、`QuestOps`、`GameState.ensure_story()`（前置 flag）、
  `ContentDefinition`、`Result`

## 契约与约束
- **Contract 独立**：quest 不复制委托 payload / 目的地 / 时限 / 奖励；contract 来源
  实例只存 `contract_instance_id` 作追踪引用，进度与结算仍由 `ContractOps` 负责。
- 起点：`start(context, quest_id)` 校验定义存在、`repeatable`、重复接取与
  `prerequisites.quests_completed / flags`（flag 读 `data.story.flags`）；
  成功返回 `autosave:true`（任务进度需要落盘）。
- **auto_start**：`auto_start_state(state, hub)` 在 run 初始化末尾（1.0 `RunFactory` 与
  v2 `CampaignFactory`）启动所有 enabled 且 `data.auto_start == true` 的 content quest；
  幂等（已 active / 已完成 / 前置不满足只记入 `skipped`，绝不失败开局），定义按 id 排序。
- 推进：`observe(context, event, data)` 只作用于 active **content** 实例；目标复用剧情
  DSL（`event` / `counter` / `at_least` / `match`），`payload.amount` 累加到 counter，
  无 counter 的目标使用隐式出现次数计数；本 stage 全部 objective 达标才前进。
  **一次 observe 对同一 counter 只累加一次 amount**（多个 objective 共享 counter 不双加）。
  成功返回 `autosave:true`。
- 完成：最后一个 stage 达标或 `complete()` 手动完成；重复完成/接取返回结构化失败。
  `complete()` 拒绝 `source == "contract"` 的追踪实例（`quest_source_forbidden`），
  委托实例的生命周期由 `ContractOps` 驱动。
- 事件：`quest.started` / `quest.updated` / `quest.completed`（payload 只含实例引用与
  stage 序号，不含内容 payload）。
- 存档：状态只在 `data.quests`（`QuestOps` 惰性 ensure），不改 `state.schema_version`；
  旧档无块 = 无任务，行为不变。
- `instance_view()` 给 `task.view` / 命令返回用：标题与 steps 全部来自内容 key，不写死 ID。

模块索引：[framework/domain](../README.md)
