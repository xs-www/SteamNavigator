# `framework/tests/cases/test_quest_service.gd`

> 作用：C3 抽象任务（Quest）运行时测试：`data.quests` 惰性状态 + 存档 round-trip、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SEED` | L19 |
| `STEADY_BUILD` | L20 |
| `GUIDE_QUEST` | L21 |
| `test_quests_block_is_lazy_and_survives_save() -> void` | L27 |
| `test_old_state_without_quests_has_no_quest_tasks() -> void` | L55 |
| `test_contract_accept_creates_tracking_instance() -> void` | L72 |
| `test_contract_completion_marks_tracking_instance_completed() -> void` | L90 |
| `test_guide_quest_advances_stages_and_completes() -> void` | L104 |
| `test_complete_command_completes_once() -> void` | L147 |
| `test_unknown_quest_and_missing_parameters() -> void` | L158 |
| `test_prerequisites_and_repeatable() -> void` | L172 |
| `test_task_view_aggregates_content_quests_without_duplicating_contracts() -> void` | L250 |
| `test_auto_start_is_idempotent_and_content_driven() -> void` | L290 |
| `test_one_observe_adds_a_shared_counter_once() -> void` | L313 |
| `test_quest_complete_rejects_contract_instances() -> void` | L345 |
| `test_quest_validator_reports_dangling_references_and_bad_events() -> void` | L357 |

`QuestService` 状态机（auto_start / start / observe / complete / prerequisites /
repeatable）、counter 去重、contract 实例保护、CrossReferenceValidator 的 quest 引用/
事件格式校验，委托接取生成 contract 追踪实例与完成联动，以及 `task.view` 的 quest 聚合。

- 关键依赖：`bootstrap_core()`、`QuestOps`、`QuestService`、`ContentTypes.QUEST`、
  `ContractOps.complete`、`TaskViewQuery`、`SaveService`

## 契约与约束
- 用真实 Core 的 `core:quest/first_voyage_guide`（3 stage / guide）验证完整推进；
  需要 prerequisites / repeatable 等边界时用「core 基线 + 合成 quest 定义」的 hub，
  不改 dev_mods/core。
- contract 来源实例只做追踪：不复制委托 payload，不重复出现在 task.view。
- 旧档无 `data.quests` 块时行为不变（无任务、不 bump schema_version）。

模块索引：[framework/tests](../README.md)
