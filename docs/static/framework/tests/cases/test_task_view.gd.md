# `framework/tests/cases/test_task_view.gd`

> 作用：任务追踪聚合查询（`task.view`，阶段 4.6 Phase A）测试：剧情目标 / 待接主线 /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SEED` | L13 |
| `STEADY_BUILD` | L14 |
| `test_task_view_without_a_run_is_empty() -> void` | L17 |
| `test_pending_main_offer_is_a_task() -> void` | L27 |
| `test_main_contract_derives_load_sail_and_deliver_steps() -> void` | L48 |
| `test_story_objective_is_the_highest_priority_task() -> void` | L80 |
| `test_active_contract_is_tracked_but_the_offer_pool_is_not() -> void` | L95 |
| `test_content_quest_is_tracked_between_story_and_contracts() -> void` | L125 |

已接主线的 Task 形状、委托步骤（接取 / 备货 / 前往 / 交付）与优先级排序。

## 契约与约束
- 只读聚合：测试只调用 `run.start` / `contract.accept` / `supply.buy_coal`
  等现有命令，再断言 `task.view` 派生结果；不写任务状态。
- 普通可接委托池不生成 Task；只有 main_offer / main / active 进入列表。
- 任务名 / 货物名输出内容 key，测试不依赖具体中文文案。

模块索引：[framework/tests](../README.md)
