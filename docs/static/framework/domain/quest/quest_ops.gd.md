# `framework/domain/quest/quest_ops.gd`

> 作用：`data.quests` 持久任务状态的纯数据操作层（C3）。负责惰性 ensure、实例字段

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `QuestOps` | L1 |
| `SECTION` | L24 |
| `SCHEMA_VERSION` | L25 |
| `SOURCE_CONTENT` | L27 |
| `SOURCE_CONTRACT` | L28 |
| `STATUS_ACTIVE` | L30 |
| `STATUS_COMPLETED` | L31 |
| `SECTION_DEFAULTS` | L33 |
| `INSTANCE_DEFAULTS` | L38 |
| `ensure(state: GameState) -> Dictionary` | L54 |
| `instances(state: GameState) -> Array` | L72 |
| `ensure_instance_fields(instance: Dictionary) -> Dictionary` | L81 |
| `find_instance(state: GameState, instance_id: String) -> Dictionary` | L105 |
| `find_by_quest(state: GameState, quest_id: String) -> Array` | L115 |
| `active_content_instance(state: GameState, quest_id: String) -> Dictionary` | L126 |
| `completed_quest_ids(state: GameState) -> Array` | L134 |
| `find_by_contract(state: GameState, contract_instance_id: String) -> Dictionary` | L150 |
| `next_content_instance_id(state: GameState, quest_id: String) -> String` | L161 |
| `create_content_instance(state: GameState, quest_id: String, now: float = 0.0) -> Dictionary` | L167 |
| `create_contract_instance(state: GameState, contract_instance_id: String, quest_id: String, now: float = 0.0) -> Dictionary` | L179 |
| `mark_completed(instance: Dictionary, now: float = 0.0) -> bool` | L195 |
| `is_active_content(instance: Dictionary) -> bool` | L207 |

规范化、按 id / 委托实例查找、新建实例与完成标记；不读取内容注册表、不发事件，
状态机语义在 `QuestService`，任务追踪展示在 `task.view`。

- 关键依赖：`GameState.data`、`Result`（无；本类只返回数据）

## 契约与约束
- 状态形状（任务契约）：`{schema_version: 1, instances: [{instance_id, source:
  "content"|"contract", quest_id, contract_instance_id, stage_index, counters, flags,
  status: "active"|"completed", started_at, completed_at}]}`；`data.quests` 惰性 ensure，
  **不改 `state.schema_version`**，旧档无该块 = 没有任务。
- 只存引用与进度（quest_id / contract_instance_id / counters / flags），不复制内容
  定义的 payload、目的地、时限或奖励。
- `ensure()` 是唯一写入口（命令事务内调用）；查询侧用 `instances()` / `find_*`
  只读访问，缺失时返回空数组 / 空字典，不创建块。
- `instance_id` 确定性：内容任务 `"<quest_id>#<n>"`（同任务第 n 次接取），委托追踪
  `"contract:<contract_instance_id>"`；同 seed + 同操作序列可复现。
- 进度字段（counters / flags / stage_index）逐键回填，读档后行为与旧档一致。

模块索引：[framework/domain](../README.md)
