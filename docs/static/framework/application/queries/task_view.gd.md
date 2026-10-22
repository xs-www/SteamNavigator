# `framework/application/queries/task_view.gd`

> 作用：任务追踪聚合查询（`task.view`，阶段 4.6 Phase A / C3 Phase B）。只读地把剧情

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TaskViewQuery` | L1 |
| `KIND_STORY` | L26 |
| `KIND_QUEST` | L27 |
| `KIND_MAIN` | L28 |
| `KIND_MAIN_OFFER` | L29 |
| `KIND_CONTRACT` | L30 |
| `STEP_OBJECTIVE` | L32 |
| `STEP_ACCEPT` | L33 |
| `STEP_LOAD` | L34 |
| `STEP_PASSENGER` | L35 |
| `STEP_SAIL` | L36 |
| `STEP_DELIVER` | L37 |
| `execute(_params: Dictionary, context) -> Dictionary` | L40 |

当前目标、内容 Quest 实例、主线委托、已接普通委托聚合成统一的 Task 列表，并把委托
拆成「备货 / 接客 / 前往 / 抵达交付」步骤、把 Quest 拆成当前 stage 的 objective 步骤，
供 HUD 任务条与委托页任务面板显示。

- 关键依赖：`StoryViewQuery`（仅取 objective 字段）、`QuestOps`（只读实例）、
  `QuestService.instance_view()`、`GameState.contracts()`、
  `ShipOps.cargo_amount` / `ShipOps.passenger_capacity`、`MapOps`

## 契约与约束
- 只读：不写状态、不发事件、不创建 `data.quests` 块；任务与步骤全部从当前状态派生。
- 只聚合「剧情目标 + 已接委托 + 待接主线 + active content Quest」；普通可接委托池与
  `hidden` Quest 不进入任务列表。
- **contract 来源的 Quest 实例不重复渲染**：委托任务仍由 `data.contracts` 推导，Quest
  只贡献 content 来源任务，避免同一委托出现两条任务。
- 目标名 / 货物名只输出内容 key（`*_name_key`），框架不写死内容 ID。
- 不输出 `player_sourced` 等内部 payload 字段；步骤只暴露 UI 需要的
  `kind / done / progress / target / 名称 key`。
- 排序：剧情 300 > Quest 250 > 主线 200 > 待接主线 150 > 普通委托 100；同优先级先比
  Quest 的 `tracking.priority`（降序），再按 id。

模块索引：[framework/application](../README.md)
