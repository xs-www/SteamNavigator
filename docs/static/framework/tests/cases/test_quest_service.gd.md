# `framework/tests/cases/test_quest_service.gd`

> 作用：C3 抽象任务（Quest）运行时测试：`data.quests` 惰性状态 + 存档 round-trip、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SEED` | L18 |
| `STEADY_BUILD` | L19 |
| `GUIDE_QUEST` | L20 |
| `test_quests_block_is_lazy_and_survives_save() -> void` | L26 |
| `test_old_state_without_quests_has_no_quest_tasks() -> void` | L53 |
| `test_contract_accept_creates_tracking_instance() -> void` | L70 |
| `test_contract_completion_marks_tracking_instance_completed() -> void` | L88 |
| `test_guide_quest_advances_stages_and_completes() -> void` | L102 |
| `test_complete_command_completes_once() -> void` | L144 |
| `test_unknown_quest_and_missing_parameters() -> void` | L155 |
| `test_prerequisites_and_repeatable() -> void` | L169 |
| `test_task_view_aggregates_content_quests_without_duplicating_contracts() -> void` | L246 |

`QuestService` 状态机（start / observe / complete / prerequisites / repeatable）、
委托接取生成 contract 追踪实例与完成联动，以及 `task.view` 的 quest 任务聚合。

- 关键依赖：`bootstrap_core()`、`QuestOps`、`QuestService`、`ContentTypes.QUEST`、
  `ContractOps.complete`、`TaskViewQuery`、`SaveService`

## 契约与约束
- 用真实 Core 的 `core:quest/first_voyage_guide`（3 stage / guide）验证完整推进；
  需要 prerequisites / repeatable 等边界时用「core 基线 + 合成 quest 定义」的 hub，
  不改 dev_mods/core。
- contract 来源实例只做追踪：不复制委托 payload，不重复出现在 task.view。
- 旧档无 `data.quests` 块时行为不变（无任务、不 bump schema_version）。

模块索引：[framework/tests](../README.md)
