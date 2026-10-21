# `framework/application/queries/task_view.gd`

> 作用：任务追踪聚合查询（`task.view`，阶段 4.6 Phase A）。只读地把剧情当前目标、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TaskViewQuery` | L1 |
| `KIND_STORY` | L20 |
| `KIND_MAIN` | L21 |
| `KIND_MAIN_OFFER` | L22 |
| `KIND_CONTRACT` | L23 |
| `STEP_OBJECTIVE` | L25 |
| `STEP_ACCEPT` | L26 |
| `STEP_LOAD` | L27 |
| `STEP_PASSENGER` | L28 |
| `STEP_SAIL` | L29 |
| `STEP_DELIVER` | L30 |
| `execute(_params: Dictionary, context) -> Dictionary` | L33 |

主线委托、已接普通委托聚合成统一的 Task 列表，并把委托拆成「备货 / 接客 / 前往 /
抵达交付」步骤，供 HUD 任务条与委托页任务面板显示。

- 关键依赖：`StoryViewQuery`（仅取 objective 字段）、`GameState.contracts()`、
  `ShipOps.cargo_amount` / `ShipOps.passenger_capacity`、`MapOps`

## 契约与约束
- 只读：不写状态、不发事件；任务与步骤全部从当前状态派生。
- 只聚合「剧情目标 + 已接委托 + 待接主线」；普通可接委托池不进入任务列表。
- 目标名 / 货物名只输出内容 key（`*_name_key`），框架不写死内容 ID。
- 不输出 `player_sourced` 等内部 payload 字段；步骤只暴露 UI 需要的
  `kind / done / progress / target / 名称 key`。
- 排序：剧情 300 > 主线 200 > 待接主线 150 > 普通委托 100；同优先级按 id。

模块索引：[framework/application](../README.md)
