# Steam Navigator — Lua Script SDK S0：公开 API 盘点与 Script API 1.0 契约草案

> **文档状态**：S0 契约草案（Draft 0.1，未实现；不改变任何运行时行为）
> **代码快照**：HEAD `db75204`（2026-10-23）。本文的计数与代码事实以该提交为准；工作区中与 Lua SDK 无关的 D2 fleet 未提交改动不计入（会改变 `Result.fail` 与测试用例计数，但不改变本文的 API 盘点结论）。
> **上游文档**：[LUA_MODDING_SDK.md](LUA_MODDING_SDK.md)（Draft 0.1，§4 目标 API、§6 权限、§7 确定性、§15 S0）
> **用途**：S0-1 交付。威胁模型（`TM-*`）、测试矩阵（`TC-*`）与后续 SDK 文档引用本文的 `Q-*` / `C-*` / `E-*` / `API-*` / `OQ-*` 编号，编号一经发布不得复用。
>
> **阅读约定**：
> - **代码现状** = 当前提交真实存在、可直接调用的行为；**目标契约** = 本文件为 Script API 1.0 提出的、S1/S2 才落地的约定。两类内容分节书写，不混用"已实现"与"计划"。
> - 本文不是 Lua 运行时设计；Host、沙箱、调度器见 [LUA_MODDING_SDK.md](LUA_MODDING_SDK.md) 与 S0-2 威胁模型。
> - 所有"暴露分级"只描述**若**将来经 Script Host 暴露的风险，不代表当前已对脚本开放（当前对脚本开放面为零）。

## 1. 范围、方法与计数证据

### 1.1 实际读取的源文件

| 类别 | 文件 | 用途 |
| --- | --- | --- |
| 注册表 | `framework/application/queries/query_registry.gd`、`framework/application/commands/command_registry.gd` | 枚举全部 Query / Command 名称与 handler 绑定 |
| 总线与信封 | `framework/application/query_bus.gd`、`command_bus.gd`、`result.gd`、`domain_event_bus.gd` | 事务语义、返回值信封、事件信封 |
| 应用入口 | `framework/application/framework_api.gd` | 确认公开面只经 `FrameworkApi.register` 注册 |
| Query handler | `framework/application/queries/*.gd`（19 个） | 读取 `execute(params, context)` 签名、params、返回 `data` 顶层字段 |
| Command handler | `framework/application/commands/*.gd`（15 个） | 读取参数校验、成功 `data` / `events`、状态变更范围 |
| 领域事件产生点 | `framework/domain/**`（voyage / explore / clue / story / quest / fleet / debt / sim / economy / events）；另读 `contracts` / `run` / `ship` 以解析事件 payload 与返回结构 | 从 `"type": ...` 字面量与 `EVENT_*` 常量枚举事件 |
| 版本与能力 | `framework/core/framework_info.gd`、`framework/bootstrap/app_context.gd`、`framework/modding/dependency_resolver.gd` | `VERSION` / `API_VERSION` / `CAPABILITIES` 与能力校验 |
| 模组契约 | `framework/modding/mod_manifest.gd`、`mod_loader.gd`、`mod_package.gd`、`mod_scanner.gd`、`framework/core/path_guard.gd`、`registries/registry_hub.gd`、`schemas/manifest.schema.json`、`content_types.json`、`sdk/README.md`、`sdk/validate.gd`、`sdk/examples/example_fleet/manifest.json` | Manifest 字段、Schema 约束、文件白名单、加载/冻结流程、SDK 现状 |
| 安全边界 | `framework/core/path_guard.gd` 的 `FORBIDDEN_EXTENSIONS` / `is_safe_relative` 与 `mod_scanner.gd` 的 `forbidden_file` 判定 | 确认 `.lua` 在现有内容模组中会被显式拒绝 |
| 规范背景 | `README.md`、`docs/README.md`、`docs/design/README.md`、`docs/design/LUA_MODDING_SDK.md` | 文档风格与上游目标 |

UI ViewModel（`framework/ui/**`）不进入本文契约：表格只引用 Query handler 的返回结构，不把 UI 组件字段当公开 API。

### 1.2 枚举方法

1. **Query / Command**：直接读两个注册表的 `register_all`，逐行取 `bus.register(&"name", Callable(类, "方法"))`；handler 文件按 `class_name` 定位。
2. **Event**：对 `framework/application/**` 与 `framework/domain/**` 做两类检索——`"type": "…"` 事件字面量、`EVENT_* := "…"` 常量；再核对每条事件的 payload 构造点。事件由 `CommandBus` 在命令成功提交后统一 `publish_many`，领域服务只负责"返回事件数组"。
3. **信封**：读 `result.gd`（`ok/error_code/message_key/data/events`）与 `domain_event_bus.gd`（`event_id/event_type/game_time/source/payload/schema_version`）。
4. **能力**：读 `FrameworkInfo.CAPABILITIES`（当前 17 项，全部 `content.*`）与 `DependencyResolver._check_capabilities`（未知能力 → 禁用整个 Mod）。
5. **Manifest**：读 `schemas/manifest.schema.json`（`additionalProperties: false`、`type.const = "content"`）与 `ModManifest.from_dict`（MVP 只接受 `type=content`）。

### 1.3 计数证据

在仓库根目录执行（PowerShell，只读）：

```powershell
# Query：19
(Select-String framework/application/queries/query_registry.gd -Pattern 'bus\.register').Count
# Command：42
(Select-String framework/application/commands/command_registry.gd -Pattern 'bus\.register').Count
# 合计 61，与全仓 bus.register(&" 命中数一致
(Select-String framework -Recurse -Include *.gd -Pattern '\.register\(&"').Count
```

| 对象 | 计数 | 证据 |
| --- | --- | --- |
| Query | **19** | `query_registry.gd` 第 6–24 行，19 条 `bus.register` |
| Command | **42** | `command_registry.gd` 第 6–47 行，42 条 `bus.register`（⚠ 任务书预期 43，实测 42，见 §1.4） |
| Event type | **53** | 事件字面量去重 48 个，其中 `discover_contract_destination` 是效果 op 不是事件 → 47；加 `EVENT_*` 常量 6 个（`quest.*` 3 + `story.*` 3）= 53 |
| 事件构造文件 | **20**（10 个应用命令 + 10 个领域文件） | `Select-String '"type": "\|"type": EVENT_'` 去重后 20 个文件；事件由 `CommandBus` 统一发布 |
| `Result.fail` 调用点 | 267 | `git grep 'Result\.fail(' HEAD -- framework`，37 个文件；去重后 **105** 个稳定字面量 `error_code` |
| Manifest 能力清单 | **17** | `FrameworkInfo.CAPABILITIES`，全部 `content.*`；**当前不存在任何 `script.*` 能力** |
| Manifest 允许的 `type` | **1** | `schemas/manifest.schema.json` `const: "content"`；`mod_manifest.gd` 对非 `content` 直接报 `invalid_type` |

### 1.4 与任务书数字的差异（必须显式记录）

- 任务书写"43 个 command"，**代码实测为 42 个**。证据：`command_registry.gd` 注册行 6–47 共 42 行；全仓 `bus.register(&"` 共 61 处 = 19 Query + 42 Command；`CommandBus.names()` 运行时也只返回这 42 个名字。本文以代码为准，`C-01…C-42` 编号完整覆盖注册表，未虚构第 43 个。
- Query 19 个与任务书一致；Event 实际 **53** 个，多于任务书"~40"的估计，属正常偏差（任务书为约数）。
- 若后续提交在注册表中新增条目，本文件编号必须**追加**而不是重排，并在文首更新代码快照。

## 2. 现有公开面盘点（代码现状）

### 2.1 统一结果信封 `Result`

`framework/application/result.gd`。所有 Query/Command handler 的失败路径必须返回该结构；成功路径可返回 `Result.ok(...)`，QueryBus 会把普通 Dictionary 自动包成 `Result.ok(result)`。

| 字段 | 类型 | 语义 | 备注 |
| --- | --- | --- | --- |
| `ok` | bool | 成功/失败唯一判据 | `Result.is_ok()` 只读此字段 |
| `error_code` | String | 机器可读稳定码，snake_case | 失败时非空；成功为空串 |
| `message_key` | String | 本地化键，默认 `ui.error.<error_code>` | 面向用户文本与机器码分离 |
| `data` | Dictionary | 成功载荷；失败时放 `details` | 结构由各 handler 定义，不是统一 schema |
| `events` | Array | 待发布领域事件（`{type, payload}`） | 仅 `ok=true` 时由 `CommandBus` 发布 |
| `autosave` | bool（可选，非信封字段） | 命令成功后请求自动存档 | 仅个别 Command 附带；**不得透给脚本** |
| `autosave_meta` | Dictionary（可选） | 自动存档元数据 | 同上 |

**契约要点**：`Result` 没有 `warnings` / `schema_version` / `trace_id`；脚本侧需要的错误码、message_key、details 白名单都从此结构投影，不透传 handler 内部异常文本。

### 2.2 领域事件信封 `DomainEventBus`

`framework/application/domain_event_bus.gd`。

| 字段 | 类型 | 语义 |
| --- | --- | --- |
| `event_id` | String | 进程内递增 `evt-%08d`，从 1 开始；不跨存档，不作为业务 ID |
| `event_type` | String | 领域事实名，如 `voyage.completed` |
| `game_time` | float | 游戏内小时；由 `CommandBus` 传 `state.now()` |
| `source` | String | 当前**恒为 `"framework"`**（`CommandBus` 固定传参），不区分命令来源 Mod |
| `payload` | Dictionary | 事件载荷；`publish` 时 `duplicate(true)` |
| `schema_version` | String | 当前为全局常量 `"1.0"`，不按 event_type 区分 |

其他事实：

- `publish_many` 把事件字典中的 `"type"`（兼容 `"event_type"`）映射为信封 `event_type`，`payload` 取 `"payload"`；非 Dictionary 项被跳过。
- 历史容量 `max_history = 500`，`get_history` / `last_event` / `has_event` 是调试/测试设施，**不是第三方兼容契约**（与设计文档 §2.3 一致）。
- `event_published` 信号逐条发出；同一次命令的 N 条事件共享同一 `game_time`。
- **现状风险**：`CommandBus.execute` 只在 `ok=true` 分支发布 `events`。部分领域服务在失败 `Result` 上携带 `expired_events`（如 `clue_service.gd` 的 `not_at_port` / `clue_limit` 失败路径），这些事件**不会到达总线**。S2 若要求"状态已变则事件必达"，需要单独修复（见 `OQ-08`）。

### 2.3 Query 盘点（全量 19，注册顺序）

暴露分级定义：`PUBLIC-SAFE` = 字段均可直接给第三方；`PROJECTION-REQUIRED` = 需宿主按白名单裁剪/过滤后才可公开；`INTERNAL-ONLY` = 不应进入 Script API。

| ID | 名称 | handler | params | 返回 `data` 关键字段 | 运行时对象/引用风险 | 分级 |
| --- | --- | --- | --- | --- | --- | --- |
| Q-01 | `app.view` | `AppViewQuery.execute` | 无 | `status/status_key/framework_version/api_version/report/mods/content_counts/content_total/registry_frozen/scenarios/has_run/run_summary/autosave_available/commands/queries` | 无 Godot 对象；但 `commands`/`queries` 枚举内部总线，`report` 含扫描路径与诊断 | INTERNAL-ONLY |
| Q-02 | `port.view` | `PortViewQuery.execute` | 无 | `has_run/at_sea/voyage/current_port(id,name_key,diorama,town_visuals,size…)/time/money/reputation/debt/market[]/destinations[]/strategies[]/ship/contracts{main,main_offer,active,offers…}/intelligence/notices/unlocks/stats/victory` | 全为 JSON-like；`diorama` / `town_visuals` / `hull_model_path` 是资产路径字符串，`market[]` 仅当前港 | PROJECTION-REQUIRED |
| Q-03 | `map.view` | `MapViewQuery.execute` | 无 | `has_run/current_port_id/at_sea/ports[{id,name_key,x,y,discovered,visited,facilities_known,facilities,current}]/routes[{a,b,distance,base_risk}]` | 无对象；**未发现港口也输出 `name_key`**，是隐藏信息泄漏点 | PROJECTION-REQUIRED |
| Q-04 | `voyage.preview` | `VoyagePreviewQuery.execute` | `{destination_id, strategy_id}`（缺参 → `missing_destination`/`missing_strategy`） | `origin_id/destination_id/destination_name_key/distance/duration_hours/arrival_time/coal_required/coal_available/water_required/water_available/crew_wages/feasible/blockers/risk_score/risk_label/risk_sources/contract/deadline/on_time/revenue_estimate/...` | 无对象；`blockers[].message_key` 是本地化键，`contract` 是委托实例深拷贝 | PROJECTION-REQUIRED |
| Q-05 | `intel.view` | `IntelViewQuery.execute` | 无 | `has_run/has_report/generated_at/generated_label/age_hours/current_port_id/columns[]/rows[]/ports[]/npcs[]/cost/money/can_refresh/has_tavern_facility(has_intel_facility)` | 快照深拷贝；未发现港口以遮罩列表示 | PROJECTION-REQUIRED |
| Q-06 | `tavern.view` | `TavernViewQuery.execute` | 无 | `has_run/current_port_id/current_port_name_key/has_tavern_facility/intel/clues/active_clue_count/max_active_clues/can_buy_clue/money` | 复合 UI ViewModel，内嵌 `intel.view` 全量 | INTERNAL-ONLY |
| Q-07 | `shipyard.view` | `ShipyardViewQuery.execute` | 无 | `has_run/at_port/has_shipyard/port_id/money/ship{hull_model_key,hull_model_path,visual,modules,transit_modules,durability,max_durability,worst_module_condition,...}/warehouse/craft/orders/wait_options/candidates[]` | `hull_model_path` 为 `res://` 路径、`visual` 为 `ShipVisualPlan`、`candidates[].effect` 是内容 `data` 原块 | PROJECTION-REQUIRED |
| Q-08 | `supply.view` | `SupplyViewQuery.execute` | 无 | `has_run/at_port/port_id/port_name_key/has_supply/coal_price/water_price/coal_stock/water_stock/money/coal/water/coal_view/water_view/durability/total_weight/max_weight/remaining_weight/max_coal/max_water/repair/can_repair` | 纯数值与稳定 key，无对象 | PUBLIC-SAFE |
| Q-09 | `port.memory` | `PortMemoryViewQuery.execute` | `{port_id?}`（缺省当前港；未知港 → `unknown_port`） | `has_run/port_id/name_key/visited/current/has_memory/captured_at/captured_label/age_hours/market[{item_id,name_key,unit_weight,price,stock,buyable,is_supply}]/facilities/facilities_known` | 只读最近访问快照；纯值 | PROJECTION-REQUIRED |
| Q-10 | `victory.view` | `VictoryViewQuery.execute` | 无 | `has_run/achieved/achieved_at/achieved_at_label/summary` | 无对象；`summary` 深拷贝 | PUBLIC-SAFE |
| Q-11 | `sea_chart.view` | `SeaChartViewQuery.execute` | `{strategy_id?}` | `has_run/world_bounds/landmasses[]/ports[]/routes[]/fog/fog_radii/coastal_cell_count/current_port_id/ship_position/at_sea/world_seed/port_count/discovered_count/visited_count/clues[]/expiring_clue_count/explore/can_buy_clue` | 无对象；体量大，含 `world_seed`、迷雾网格与全部坐标 | PROJECTION-REQUIRED |
| Q-12 | `clue.list` | `ClueListViewQuery.execute` | 无 | `has_run/now/max_active/active_count/clues[]/expired[]` | 已按等级裁剪（不含 `target_port_id`/`credibility`/真实搜索区）；仍含调查成本与成功率 | PROJECTION-REQUIRED |
| Q-13 | `story.view` | `StoryViewQuery.execute` | 无 | `active/completed/skipped/flow_id/stage_index/stage/unlocked_features/unlocked_items/unlocked_modules/can_skip/objective/...` | UI 门禁数据；不输出 counters/flags | PROJECTION-REQUIRED |
| Q-14 | `task.view` | `TaskViewQuery.execute` | 无 | `has_run/current_port_id/at_sea/tasks[]/task_count/active_task_id/active_task` | 纯值，但 `tasks` 是剧情/委托/Quest 的 UI 聚合，字段随 UI 演进 | INTERNAL-ONLY |
| Q-15 | `campaign.view` | `CampaignViewQuery.execute` | 无 | `has_run/is_v2/setup/regions[]/sites[]/factions/codex/exploration{rules,clues}` | codex 全量 + 探索规则；纯值 | PROJECTION-REQUIRED |
| Q-16 | `sim.view` | `SimViewQuery.execute` | 无 | `paused/speed/tick/step_hours/game_time/time_label/systems[{id,priority}]` | 纯数值，无对象 | PUBLIC-SAFE |
| Q-17 | `combat.view` | `CombatViewQuery.execute` | 无 | `has_run/player{durability,max_durability,weapons[],unmounted_sockets[]}/encounters[]/last_battle` | `unmounted_sockets` 暴露内容缺口；`last_battle` 深拷贝 | PROJECTION-REQUIRED |
| Q-18 | `combat.log` | `CombatLogQuery.execute` | `{limit=20}`（clamp 1..`CombatService.MAX_BATTLES`） | `battles[{id,sequence,at_time,port_id,encounter_table_id,outcome,rounds,durability_before,durability_after,money,item_count,enemies}]/total` | 调试摘要；不含逐回合日志 | INTERNAL-ONLY |
| Q-19 | `fleet.view` | `FleetViewQuery.execute` | 无 | `flagship_id/ship_count/max_ships/ships[{ship_id,is_flagship,archetype_id,archetype_name_key,captain_id,captain_name_key,formation_slot,condition}]/formation_id/formation/doctrine_id/doctrine` | 纯值 + 本地化 key | PROJECTION-REQUIRED |

**分级小结**：PUBLIC-SAFE 3 个（Q-08、Q-10、Q-16）；INTERNAL-ONLY 4 个（Q-01、Q-06、Q-14、Q-18）；其余 12 个 PROJECTION-REQUIRED。Q-04 本身只读且字段稳定，但含 `contract` 实例深拷贝，按上表暂列 PROJECTION-REQUIRED，裁剪后可作为 PUBLIC-SAFE（见 API-Q-04）。

### 2.4 Command 盘点（全量 42，注册顺序）

"玩家意图/作弊风险"只表示脚本直接调用该命令时的滥用空间；`PROJECTION-REQUIRED` 含"可由脚本触发但必须限频/限权/重校验"的命令。所有命令都经 `CommandBus` 的 clone-and-commit：失败不提交状态、不发布事件。

| ID | 名称 | handler | params | 成功 `data` 关键字段 | 成功事件 | 状态变更范围 | 玩家意图/作弊风险 | 分级 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C-01 | `run.start` | `RunStartCommand.execute` | `{starting_scenario?, start_profile?, seed?, tutorial?, force?}` | `starting_scenario_id/seed/money/current_port_id/main_contract` | `run.started`（另有 `autosave`） | 整个 `GameState` 替换 + `context.rng` 替换 | 非玩法行为；脚本调用会重置世界 | INTERNAL-ONLY |
| C-02 | `trade.buy` | `TradeCommands.buy` | `{port_id?, item_id, amount=1}` | `item_id/amount/unit_price/total/money/stock/trade_margin` | `market.changed` | 金钱、货物、市场库存/价格 | 高：可脚本化套利/刷钱 | PROJECTION-REQUIRED |
| C-03 | `trade.sell` | `TradeCommands.sell` | `{port_id?, item_id, amount=1}` | `item_id/amount/unit_price/revenue/money/stock` | `market.changed` | 金钱、货物、市场库存/价格 | 高：同上 | PROJECTION-REQUIRED |
| C-04 | `supply.buy_coal` | `SupplyCommands.buy_coal` | `{port_id?, amount=10}` | `kind/amount/unit_price/total/money/stock/port_stock/price_after`（成功时附 `item_id`） | `supply.purchased` | 金钱、煤舱、市场库存/价格 | 中：补给经济 | PROJECTION-REQUIRED |
| C-05 | `supply.buy_water` | `SupplyCommands.buy_water` | `{port_id?, amount=10}` | 同上（`kind=water`） | `supply.purchased` | 金钱、水舱、市场库存/价格 | 中 | PROJECTION-REQUIRED |
| C-06 | `supply.repair` | `SupplyCommands.repair` | `{port_id?}` | `repaired/durability_repaired/modules_repaired/cost/money/durability` | `ship.repaired` | 金钱、船体耐久、全部模块 condition | 中：可绕过风险/修理成本 | PROJECTION-REQUIRED |
| C-07 | `intel.refresh` | `IntelCommands.refresh` | 无 | `cost/generated_at/generated_label/ports/npcs` | `intelligence.updated` | 金钱、情报快照 | 低：花钱买快照 | PROJECTION-REQUIRED |
| C-08 | `debt.borrow` | `DebtCommands.borrow` | `{amount=limit}` | `principal/total_due/due_time/money` | `debt.borrowed` | 债务、金钱 | 高：可脚本化借钱 | PROJECTION-REQUIRED |
| C-09 | `contract.accept` | `ContractCommands.accept` | `{instance_id}` | `instance_id/slot/contract` | `contract.accepted` | 委托池、active 委托 | 中 | PROJECTION-REQUIRED |
| C-10 | `voyage.preview` | `VoyageCommands.preview` | `{destination_id, strategy_id}` | 与 Q-04 同（`preview` 内容直接在 `data`） | 无 | 只读，不提交状态 | 低；语义与 Q-04 重复 | PUBLIC-SAFE（建议脚本只走 Query 通道） |
| C-11 | `voyage.start` | `VoyageCommands.start` | `{destination_id, strategy_id}` | `preview/arrived/event` 或 `preview/arrived/summary`（`autosave`） | `voyage.started`、`voyage.event_triggered`、`voyage.completed`、`port.discovered`、`port.arrived`、`contract.*`、`debt.*`、`market.changed`、`ship.module_crafted` 等 | 出航状态、时间、合同、市场、订单、债务 | 高：推动世界与结算 | PROJECTION-REQUIRED |
| C-12 | `event.choose_option` | `VoyageCommands.choose_option` | `{option_id}` | `failed/reason/restored` 或 `failed/event_result` | `voyage.failed` 或 `voyage.completed` + 选项效果事件（`ship.damaged` 等） | 事件分支、可能回滚到出航前 | 高：可决定风险事件结果 | PROJECTION-REQUIRED |
| C-13 | `explore.start` | `ExploreCommands.start` | `{clue_id, strategy_id}` | `{preview, presentation}`；失败码 `explore_not_feasible` | `explore.started` | 探索航次、煤水 | 中 | PROJECTION-REQUIRED |
| C-14 | `explore.settle` | `ExploreCommands.settle` | 无 | `{result, destination, summary}`（`autosave`） | `explore.finished`、`port.discovered`、`port.arrived` + 入港服务事件 | 探索结果、发现、时间、市场 | 中 | PROJECTION-REQUIRED |
| C-15 | `explore.decide` | `ExploreCommands.decide` | `{choice: continue\|turn_back}` | `continue` → `{continued,destination,remaining_hours}`；`turn_back` → 返航 summary | `continue` **不发事件**；`turn_back` 发 `explore.finished` + 入港服务事件 | 资源告警决策/提前返航 | 中 | PROJECTION-REQUIRED |
| C-16 | `clue.buy` | `ExploreCommands.buy` | 无 | `cost/clue_id/source_key/clue` | `clue.acquired`（失败路径可能带 `clue.expired`，但失败不发布） | 金钱、线索列表 | 低 | PROJECTION-REQUIRED |
| C-17 | `clue.investigate` | `ExploreCommands.investigate` | `{clue_id}` | `success/expired/clue_id/level/next_level/cost/hours/success_chance/charged/roll/view` | `clue.investigated` 或 `clue.investigation_failed` | 金钱、时间、线索等级 | 低；`roll` 属内部 RNG 值，必须裁剪 | PROJECTION-REQUIRED |
| C-18 | `clue.travel` | `ExploreCommands.travel` | `{clue_id, strategy_id}` | 同 `voyage.start`（目标港由领域层解析） | 同 `voyage.start` + 线索相关事件 | 移动、时间、市场 | 中 | PROJECTION-REQUIRED |
| C-19 | `story.advance` | `StoryCommands.advance` | 无 | `{view}` | `story.stage_entered` / `story.completed` / `story.feature_unlocked` | 剧情阶段、解锁 | 非第三方玩法入口 | INTERNAL-ONLY |
| C-20 | `story.skip` | `StoryCommands.skip` | 无 | `{view}`（`autosave`） | `story.completed` | 跳过教程并解锁全部 FEATURES | INTERNAL-ONLY |
| C-21 | `story.observe` | `StoryCommands.observe` | `{event, data?}` | `{view?}` | 视条件触发 `story.*` | 由 Shell 转发 UI 事件推进剧情 | INTERNAL-ONLY |
| C-22 | `quest.start` | `QuestCommands.start` | `{quest_id}` | `instance/view` | `quest.started` | 创建 Quest 实例 | 中 | PROJECTION-REQUIRED |
| C-23 | `quest.complete` | `QuestCommands.complete` | `{instance_id}` | `instance/view`（`autosave`） | `quest.completed` | 完成任务实例 | 中：调试/系统钩子口 | PROJECTION-REQUIRED |
| C-24 | `quest.observe` | `QuestCommands.observe` | `{event, data?}` | 空/推进结果 | `quest.updated` / `quest.completed` | 由 Shell 转发成功命令/UI 事件 | INTERNAL-ONLY |
| C-25 | `port.wait` | `PortCommands.wait` | `{hours}`（1..240） | `hours/game_time/time_label/completed_orders/npc_events/debt_events/clue` | `port.waited`、`ship.module_crafted`、`market.changed`、`debt.overdue`、`clue.*` | 时间、订单、市场、债务、线索 | 中：可跳过时间获取收益 | PROJECTION-REQUIRED |
| C-26 | `ship.install_module` | `ShipCommands.install_module` | `{module_id, source=purchase\|warehouse\|transit, replace_module_id?, slot?}` | `module_id/content_type/category/source/price/replaced_module_id/money/total_weight/victory` | `ship.module_installed`（可能 + `run.victory_achieved`） | 金钱/仓库/船体配置/通关判定 | 高：配置与通关 | PROJECTION-REQUIRED |
| C-27 | `ship.uninstall_module` | `ShipCommands.uninstall_module` | `{module_id}` | `module_id/content_type/category/warehouse_qty` | `ship.module_uninstalled` | 船体配置、港口仓库 | 中 | PROJECTION-REQUIRED |
| C-28 | `ship.craft_module` | `ShipCommands.craft_module` | `{module_id}` | 打造订单 data（`order_id`/`craft_cost`/`craft_time_hours`/`ready_at` 等） | `ship.craft_ordered` | 材料、仓库、订单 | 高：可脚本化打造 | PROJECTION-REQUIRED |
| C-29 | `warehouse.store_module` | `WarehouseCommands.store_module` | `{module_id, qty=1}` | `module_id/qty/transit_qty/warehouse_qty` | `warehouse.module_stored` | 随船运输 ↔ 港口仓库 | 中 | PROJECTION-REQUIRED |
| C-30 | `warehouse.take_module` | `WarehouseCommands.take_module` | `{module_id, qty=1}` | `module_id/qty/transit_qty/warehouse_qty/transit_weight` | `warehouse.module_taken` | 同上 | 中 | PROJECTION-REQUIRED |
| C-31 | `warehouse.store_materials` | `WarehouseCommands.store_materials` | `{item_id, amount}` | `item_id/amount/warehouse_amount/cargo_amount` | `warehouse.materials_stored` | 货舱 ↔ 仓库材料 | 中 | PROJECTION-REQUIRED |
| C-32 | `warehouse.take_materials` | `WarehouseCommands.take_materials` | `{item_id, amount}` | `item_id/amount/warehouse_amount/cargo_amount` | `warehouse.materials_taken` | 同上 | 中 | PROJECTION-REQUIRED |
| C-33 | `sim.pause` | `SimCommands.pause` | 无 | `sim.view` 同结构 | 无 | `data.sim.paused=true` | 低：暂停 | PUBLIC-SAFE |
| C-34 | `sim.resume` | `SimCommands.resume` | 无 | 同上 | 无 | `data.sim.paused=false` | 低 | PUBLIC-SAFE |
| C-35 | `sim.set_speed` | `SimCommands.set_speed` | `{speed}`（`MIN_SPEED..MAX_SPEED`） | 同上 | 无 | `data.sim.speed` | 低：有界 | PUBLIC-SAFE |
| C-36 | `sim.advance` | `SimCommands.advance` | `{hours}`（`>0` 且 `<=MAX_ADVANCE_HOURS`） | `{ticks,hours_requested,hours_advanced,paused,speed,tick,start_tick,end_tick,game_time,time_label}` | `sim.tick` × tick 数 | 模拟时间、tick 调度 | 高：可快进时间（当前 D0 不接玩法，接玩法后风险升级） | PROJECTION-REQUIRED |
| C-37 | `combat.resolve` | `CombatCommands.resolve` | `{encounter_table_id?, seed?, encounter_id?/settlement_key?}` | `battle/durability/loot_applied/already_settled`（`autosave`） | `combat.resolved` | 耐久、战利品、战斗记录 | 高：显式 `seed` 可决定战斗结果；幂等 key 是唯一缓解 | PROJECTION-REQUIRED |
| C-38 | `fleet.assign_captain` | `FleetCommands.assign_captain` | `{ship_id?, captain_id?}` | `ship_id/captain_id/previous_captain_id`（清空时）或 `wage_per_voyage` | `fleet.captain_assigned` | `data.fleet` 编成 | 中 | PROJECTION-REQUIRED |
| C-39 | `fleet.set_formation` | `FleetCommands.set_formation` | `{formation_id}` 和/或 `{ship_id, slot}` | `formation_id/ship_id/slot` | `fleet.formation_changed` / `fleet.slot_assigned` | `data.fleet` 编队 | 中 | PROJECTION-REQUIRED |
| C-40 | `fleet.set_doctrine` | `FleetCommands.set_doctrine` | `{doctrine_id}` | `doctrine_id` | `fleet.doctrine_changed` | `data.fleet` 战术 | 中 | PROJECTION-REQUIRED |
| C-41 | `fleet.add_ship` | `FleetCommands.add_ship` | `{archetype_id, captain_id?, formation_slot?}` | 新船 entry（`ship_id/archetype_id/captain_id/formation_slot/condition`） | `fleet.ship_added` | 舰队名册 | **高：当前无扣费/购买校验，脚本可免费加船** | PROJECTION-REQUIRED |
| C-42 | `fleet.remove_ship` | `FleetCommands.remove_ship` | `{ship_id}`（旗舰不可删） | `ship_id` | `fleet.ship_removed` | 舰队名册 | 中 | PROJECTION-REQUIRED |

### 2.5 Event 盘点（全量 53，按 event_type 字典序）

payload 均为 JSON-like 字典；"适配第三方"是该事件能否作为 Script API 公共事件（见 §3.3 候选）。所有事件由 `CommandBus` 在命令成功后发布，`source="framework"`。

| ID | event_type | payload 结构（当前代码） | 产生时机 | 适合第三方 | payload 裁剪建议 |
| --- | --- | --- | --- | --- | --- |
| E-01 | `cargo.damaged` | `{weight}` | 航行事件效果 `damage_cargo` | 是 | 保留；`weight` 已足够 |
| E-02 | `clue.acquired` | `{clue_id, source_key, level}` | 买线索 / 等待 / 抵达 / 委托完成抽线索 | 是 | 保留（目标港本就未进 payload） |
| E-03 | `clue.expired` | `{clue_ids[], count}` | 任意命令路径的线索 sweep | 是 | 保留；`clue_ids` 需限条数 |
| E-04 | `clue.investigated` | `{clue_id, level}` | `clue.investigate` 成功升级 | 是 | 保留 |
| E-05 | `clue.investigation_failed` | `{clue_id, level, cost, hours}` | 调查判定失败 | 是 | 保留；`cost/hours` 可保留 |
| E-06 | `combat.resolved` | `{battle_id, encounter_table_id, settlement_key, outcome, rounds, durability, money}` | `combat.resolve` 新结算 | 是 | 保留；`settlement_key` 可选裁剪 |
| E-07 | `content.unlocked` | `{id}` | 航行事件效果 `unlock_definition` | 是 | 保留 |
| E-08 | `contract.accepted` | `{instance_id, template_id, slot, destination, deadline}` | `contract.accept` | 是 | 保留 |
| E-09 | `contract.completed` | `{instance_id, template_id, on_time, late, base_money, on_time_bonus, compensation, payout, debt{gross,to_debt,to_player,debt_cleared}, reputation, unlocks[], deadline, arrival_time}` | 抵港 / 事件完成委托 | 是 | **裁剪到 `instance_id/template_id/on_time/payout/arrival_time`** |
| E-10 | `contract.late` | 同 E-09（`contract_result` 全量） | 迟交委托 | 是 | 同 E-09；或删除该事件、以 `on_time=false` 表达 |
| E-11 | `contract.offers_refreshed` | `{port_id, count, game_time}` | 抵港刷新普通委托池 | 是 | 保留 |
| E-12 | `debt.borrowed` | `{principal, total_due, due_time}` | `debt.borrow` | 是 | 保留 |
| E-13 | `debt.overdue` | `{remaining, due_time, reputation}` | 时间推进检查逾期 | 是 | 保留 |
| E-14 | `explore.finished` | `{result, destination, clue_id, arrival_time}`（失败分支附 `attempts`） | 探索结算 / 掉头 | 是 | 保留；`result` 枚举需稳定文档化 |
| E-15 | `explore.started` | `{clue_id, origin, duration_hours, coal_used, water_used}` | `explore.start` | 是 | 保留 |
| E-16 | `fleet.captain_assigned` | `{ship_id, captain_id}` | 舰队指派/清空舰长 | 是 | 保留（空 captain 表达清空） |
| E-17 | `fleet.doctrine_changed` | `{doctrine_id}` | `fleet.set_doctrine` | 是 | 保留 |
| E-18 | `fleet.formation_changed` | `{formation_id}` | `fleet.set_formation` 整队切换 | 是 | 保留 |
| E-19 | `fleet.ship_added` | `{ship_id, archetype_id}` | `fleet.add_ship` | 是 | 保留 |
| E-20 | `fleet.ship_removed` | `{ship_id}` | `fleet.remove_ship` | 是 | 保留 |
| E-21 | `fleet.slot_assigned` | `{ship_id, slot, formation_id}` | 单船槽位指派 | 是 | 保留 |
| E-22 | `intelligence.updated` | `{generated_at}`（效果 op）或 `{generated_at, cost}`（`intel.refresh`） | 刷新情报 / 航行事件效果 | 是 | **统一为 `{generated_at}`，`cost` 由调用方自明** |
| E-23 | `market.changed` | `{port_id, item_id, source, stock, price_after}`（玩家交易）或 `{port_id,item_id,source:"npc",npc_id,action,stock,price_before,price_after}` | 玩家买卖 / NPC 到货 | 是 | 统一必填 `port_id/item_id/source/stock/price_after`；NPC 字段选填 |
| E-24 | `notice.emitted` | `{text_key}` | 航行事件效果 `emit_notice` | 是 | 保留；**只给 key，不给文本** |
| E-25 | `passenger.injured` | `{amount}` | 航行事件效果 `injure_passenger` | 是 | 保留；需要 `contract_id` 时另议 |
| E-26 | `port.arrived` | `{port_id, arrival_time}` | 普通抵港 | 是 | 保留 |
| E-27 | `port.discovered` | `{port_id}` | 首次抵港/探索发现 | 是 | 保留 |
| E-28 | `port.waited` | `{port_id, hours, game_time}` | `port.wait` | 是 | 保留 |
| E-29 | `quest.completed` | `{instance_id, quest_id, source}` | Quest 目标达成/手动完成 | 是 | 保留 |
| E-30 | `quest.started` | `{instance_id, quest_id, source}` | `quest.start` / auto_start | 是 | 保留 |
| E-31 | `quest.updated` | `{instance_id, quest_id, stage_index}` | Quest 目标推进 | 是 | 保留 |
| E-32 | `run.started` | `{starting_scenario, seed, start_profile, world_profile, map_config}` | `run.start` | 否（生命周期事件） | 第三方可订阅但不得依赖 `seed` 明文；建议只暴露 `starting_scenario` |
| E-33 | `run.victory_achieved` | 胜利 summary：`{seed, starting_scenario, starting_scenario_name_key, game_time, voyages, on_time, on_time_rate, accidents, income, expense, profit, money, debt_remaining, reputation, durability, max_durability, hull_id, hull_name_key, cargo_capacity, modules[]}` | 任意触发 `VictoryService.check` 的命令 | 是 | 裁剪到 `game_time/voyages/on_time_rate/profit/reputation`；**不含 `seed`** |
| E-34 | `ship.craft_ordered` | `{order_id, module_id, content_type, port_id, craft_cost, craft_time_hours, ready_at}` | `ship.craft_module` | 是 | 保留 |
| E-35 | `ship.damaged` | `{amount, durability}` | 航行事件效果 `damage_ship` | 是 | 保留 |
| E-36 | `ship.module_crafted` | `{order_id, module_id, content_type, port_id, warehouse_qty}` | 打造订单结算（等待/抵港/调查工时） | 是 | 保留 |
| E-37 | `ship.module_damaged` | `ShipModules.damage` 结果：`{ok, slot, index, instance_id, condition, disabled, newly_disabled}` | 航行事件效果 `damage_module` | 是 | 去掉 `ok`；保留 `slot/condition/disabled` |
| E-38 | `ship.module_installed` | `{module_id, content_type, category, source, price, replaced, replaced_module_id}` | `ship.install_module` | 是 | 保留；`replaced` 与 `replaced_module_id` 重复，二选一 |
| E-39 | `ship.module_uninstalled` | `{module_id, content_type, category, warehouse_qty}` | `ship.uninstall_module` | 是 | 保留 |
| E-40 | `ship.repaired` | `{repaired, cost}` | `supply.repair` | 是 | 保留 |
| E-41 | `sim.tick` | `{tick, game_time, step_hours}` | `sim.advance` 每 tick | 是（需高频保护） | 保留；订阅需限频/合并（每命令最多可发多 tick） |
| E-42 | `story.completed` | `{flow_id, skipped}` | 剧情完成 / 跳过 | 是 | 保留 |
| E-43 | `story.feature_unlocked` | `{feature}` | 剧情阶段解锁功能 | 是 | 保留 |
| E-44 | `story.stage_entered` | `{flow_id, stage_index, stage_id}` | 剧情阶段推进 | 是 | 保留 |
| E-45 | `supply.purchased` | `{kind, amount, total}` | `supply.buy_coal` / `buy_water` | 是 | 保留 |
| E-46 | `voyage.completed` | `{destination, arrival_time}` 或 `{destination, arrival_time, chosen_option}` | 抵港 / 风险事件结算完成 | 是（首选公共事件） | 保留；可追加 `origin` |
| E-47 | `voyage.event_triggered` | `{event_id, category, option_ids[]}` | 出航时抽到风险事件 | 是 | 保留 |
| E-48 | `voyage.failed` | `{destination, reason, restored_pre_voyage}` | 风险事件导致航程失败 | 是 | 保留；`reason` 是 option_id |
| E-49 | `voyage.started` | `{origin, destination, strategy_id, duration_hours, coal_used, water_used}` | `voyage.start` | 是 | 保留 |
| E-50 | `warehouse.materials_stored` | `WarehouseOps.store_materials` data：`{item_id, amount, warehouse_amount, cargo_amount}` | C-31 | 是 | 保留 |
| E-51 | `warehouse.materials_taken` | `WarehouseOps.take_materials` data：`{item_id, amount, warehouse_amount, cargo_amount}` | C-32 | 是 | 保留 |
| E-52 | `warehouse.module_stored` | `WarehouseOps.store_module` data：`{module_id, qty, transit_qty, warehouse_qty}` | C-29 | 是 | 保留 |
| E-53 | `warehouse.module_taken` | `WarehouseOps.take_module` data：`{module_id, qty, transit_qty, warehouse_qty, transit_weight}` | C-30 | 是 | 保留 |

### 2.6 代码现状与设计文档的冲突清单

以下冲突均以**代码现状为准**，S2 落地前不得把 [LUA_MODDING_SDK.md](LUA_MODDING_SDK.md) 的示例当作可用契约。

| # | 设计文档位置 | 设计文档写法 | 代码现状 | 处理建议 |
| --- | --- | --- | --- | --- |
| 1 | §3 示例 Manifest | `"type": "hybrid"`、顶层 `"scripts": {...}` | `schemas/manifest.schema.json` 顶层 `additionalProperties:false` + `type.const="content"`：`hybrid` 与 `scripts` 都会被 Schema 直接拒绝；`mod_manifest.gd` 对非 `content` 报 `invalid_type` 且不解析 `scripts`。即使 Schema 放行，`mod_scanner.gd` 第 119–136 行的文件白名单只允许 `.json`、`localization/*.csv`、`assets/*` 六类扩展名，`scripts/main.lua` 会报 `forbidden_file`；`.lua` 甚至不在 `PathGuard.FORBIDDEN_EXTENSIONS` 中，是被扫描器白名单**先**拒绝的 | 不是"加个可选字段"即可：需按 §4.6 升 Manifest Schema v2 并同步 ModManifest / ModScanner / PathGuard / SDK 校验；旧 `api_version=1.0` 模组继续走 v1 Schema |
| 2 | §3 / §6.2 能力 | `script.events.subscribe`、`script.query.ship`、`script.command.ship`、`script.storage` | `FrameworkInfo.CAPABILITIES` 仅 17 个 `content.*`；未知能力由 `DependencyResolver._check_capabilities` 记 `unsupported_capability` 并**禁用整个 Mod** | 按 §4.7：复用同一 `capabilities` 字段、按前缀分流到两套白名单，并区分"整包禁用"与"仅脚本层禁用" |
| 3 | §4.3 示例查询 | `sn.query("ship.get", {ship_id})` 返回 `ship`、含 `boiler_condition` | **不存在 `ship.get` query**；也**不存在 `boiler_condition` 字段**。现有近似数据在 Q-02/Q-07 的 `ship{}` 与 Q-17 的 `player{}`；锅炉 condition 在 `data.ship.module_instances.boiler.condition`（由 `ShipModules.condition` 读取） | 作为 Script API 新投影（`API-Q-01`），字段名不得直接沿用 `boiler_condition` |
| 4 | §4.3 示例命令 | `sn.command("ship.apply_damage", {...})` | **不存在该命令**。领域层只有内部效果 op `damage_ship`（`framework/domain/events/effect_op_registry.gd`），只能由航行事件/剧情效果触发，无公开命令入口 | S2 新增宿主用例；在此之前标注"需新增宿主用例，S2 落地" |
| 5 | §4.3 示例事件 | `voyage.completed` 的 `event.payload.ship_id` | `voyage.completed` 存在（E-46），但 payload 是 `{destination, arrival_time[, chosen_option]}`，**没有 `ship_id`** | 订阅方用 `run_summary`/`fleet.view` 取船信息；或 S2 扩展 payload（需版本化） |
| 6 | §4.2 命令语义 | `sn.command()` 返回入队回执，结果经 `script.command_result` 回调 | 现有 `CommandBus.execute` **同步**返回 `Result`，无队列、无回调通道 | Script Host 自行实现延迟队列与结果通道（`OQ-05`） |
| 7 | §3 缺省 `scripts` | 无 `scripts` 即纯数据 Mod | 现状本就只有纯数据 Mod；Manifest 无 `scripts` 字段 | 保持一致，S2 仅增量增加可选字段 |
| 8 | §5 生命周期 | 内容通过后执行 Lua、`on_load`/`on_unload` | 现有加载链到 `RegistryHub.freeze_all()` 即结束，无脚本阶段；`ModLoader` 无脚本钩子 | S2 在 freeze 后新增脚本阶段，失败不得静默 |
| 9 | §4.1 API 面 | `sn.mod.info()` / `sn.api.version()` / `sn.events.on/off` / `sn.storage` | 均不存在；且 Manifest 不含脚本元数据 | 按 §3/§4 的 1.0 契约实现；`api_version` 与 `script_api_version` 必须分开 |
| 10 | §6.2 权限表 | 能力按资源域授予 | 现有内容能力只在加载期做一次白名单校验，**没有逐调用授权**机制 | S2 实现每调用一次宿主侧授权（声明≠授权） |

## 3. 首批可公开候选 API（Script API 1.0 草案）

> 本节全部是**目标契约**，当前代码均未实现（候选 Query 只是现有 Query 的投影；新语义命令标注"S2 落地"）。

### 3.1 命名与暴露原则

1. **不暴露总线名**：Lua 侧不出现 `QueryBus` / `CommandBus` / `DomainEventBus` / `RegistryHub` / handler 类名；唯一入口是 `sn`（与设计文档 §4 一致）。
2. **语义名，不暴露实现名**：脚本名可以比内部命令更窄（例如 `market.snapshot` 投影自 `port.view`），但不得把 UI ViewModel 的字段原样当契约。
3. **默认拒绝**：未在 Manifest 声明 capability 的调用一律失败；声明了也要逐调用校验。
4. **字段白名单投影**：只返回脚本需要的字段，删除 `res://` 资产路径、`visual`、原始内容 `effect`、内部 RNG 值（如 C-17 的 `roll`）、`autosave` 等。
5. **命令回执 ≠ 业务结果**：`sn.command()` 只表示"请求被宿主接受并排队"；业务结果通过版本化回调通道返回（`OQ-05`）。
6. **稳定 ID**：`API-Q-*` / `API-E-*` / `API-C-*` 是后续文档与测试的锚点，只能追加。

### 3.2 候选 Query 白名单（7 项）

| ID | Script 侧名称 | 映射的现有实现 | 投影/裁剪说明 | 参数 | 能力 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| API-Q-01 | `ship.get` | 投影自 Q-02 `port.view.ship{}` + Q-07 `shipyard.view.ship{}` + Q-19 `fleet.view.ships[]` | 返回 `{ship_id:"flagship", hull_id, archetype_id, archetype_name_key, durability, max_durability, coal, water, worst_module_condition, modules[{slot,module_id,name_key,condition,disabled}], cargo{used,capacity}, weight{total,max}}`；**不含** `hull_model_path` / `visual` / `transit_*` | 无（1.0 只有旗舰） | `script.query.ship` | PROJECTION-REQUIRED；S2 新增宿主投影 |
| API-Q-02 | `ship.cargo` | 投影自 Q-02 `ship.cargo[]` | 返回 `[{item_id, amount, total_cost, is_contract}]`；删除 `average_cost` 等展示字段 | 无 | `script.query.ship` | PROJECTION-REQUIRED；S2 新增宿主投影 |
| API-Q-03 | `market.snapshot` | 投影自 Q-02 `port.view.market[]` | 返回 `[{item_id, category, tier, price, stock, buyable, cargo_amount, sellable_amount}]`；仅当前港；**不含** `recent_prices` / 趋势百分比 | 无 | `script.query.market` | PROJECTION-REQUIRED；S2 新增宿主投影 |
| API-Q-04 | `voyage.preview` | Q-04（现有 `voyage.preview`，字段白名单） | 保留 `destination_id/distance/duration_hours/arrival_time/coal_required/coal_available/water_required/water_available/feasible/blockers[{code}]/risk_score`；**删除** `contract` 全量、`revenue_estimate`、`risk_sources` | `{destination_id, strategy_id}` | `script.query.voyage` | 现有 Query 可直接复用（按白名单裁剪后） |
| API-Q-05 | `sim.clock` | Q-16（现有 `sim.view`） | 原样：`{paused,speed,tick,step_hours,game_time,time_label}`；删除 `systems[]` | 无 | `script.query.sim` | 现有 Query 可直接复用（PUBLIC-SAFE） |
| API-Q-06 | `fleet.get` | 投影自 Q-19 `fleet.view` | 返回 `{flagship_id, ship_count, max_ships, ships[{ship_id,is_flagship,archetype_id,captain_id,formation_slot,condition}], formation_id, doctrine_id}`；只保留稳定 ID/数值，不返回 `*_name_key` 等展示字段 | 无 | `script.query.fleet` | PROJECTION-REQUIRED；S2 新增宿主投影 |
| API-Q-07 | `campaign.status` | 投影自 Q-15 `campaign.view` + Q-03 `map.view` | 返回 `{game_time, is_v2, current_port_id, discovered_ports, visited_ports, money, reputation, debt_remaining}`；**不返回** `world_seed`、`codex` 全量、探索规则内部值 | 无 | `script.query.campaign` | PROJECTION-REQUIRED；S2 新增宿主投影 |

### 3.3 候选 Event 白名单（8 项）

事件订阅统一走 `sn.events.on(event_type, callback)` + `sn.events.off(token)`；宿主按 `event_type` 做 payload 二次裁剪，**不转发 `DomainEventBus` 内部历史**。

| ID | event_type | 映射事件 | 脚本可见 payload（目标契约） | 产生时机 | 能力 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| API-E-01 | `voyage.completed` | E-46 | `{destination, arrival_time, chosen_option?}` | 抵港 / 风险事件结算完成 | `script.events.subscribe` | 首批 PoC 事件（设计文档 §11.1 要求） |
| API-E-02 | `port.arrived` | E-26 | `{port_id, arrival_time}` | 任意抵港 | `script.events.subscribe` | 与 E-46 同批发出，注意去重 |
| API-E-03 | `market.changed` | E-23 | `{port_id, item_id, source, stock, price_after}` | 玩家交易 / NPC 到货 | `script.events.subscribe` | 高频事件，需限频/合并 |
| API-E-04 | `contract.completed` | E-09 | `{instance_id, template_id, on_time, payout, arrival_time}` | 抵港完成委托 | `script.events.subscribe` | 裁掉 `debt/unlocks/reputation` 明细 |
| API-E-05 | `combat.resolved` | E-06 | `{battle_id, outcome, rounds, durability, money}` | 自动战斗结算 | `script.events.subscribe` | 不暴露 `settlement_key` |
| API-E-06 | `ship.module_crafted` | E-36 | `{module_id, content_type, port_id, warehouse_qty}` | 打造订单结算 | `script.events.subscribe` | 与 C-28 的 `ship.craft_ordered` 区分 |
| API-E-07 | `run.victory_achieved` | E-33 | `{game_time, voyages, on_time_rate, profit, reputation}` | 通关判定成功 | `script.events.subscribe` | **不含 `seed`** |
| API-E-08 | `clue.acquired` | E-02 | `{clue_id, source_key, level}` | 线索进入日志 | `script.events.subscribe` | 目标港/可信度/搜索区已不在 payload |

### 3.4 候选 Command 白名单（5 项）

| ID | Script 侧名称 | 映射 | 参数（脚本侧） | 回执 | 能力 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| API-C-01 | `sim.set_speed` | C-35（现有） | `{speed}` | `{accepted:true, request_id}`；结果走命令结果通道 | `script.command.sim` | 现有命令可复用（有界、无经济影响） |
| API-C-02 | `notice.emit` | **新宿主用例**（包装 `EffectOpRegistry` 的 `emit_notice` / `GameState.push_notice`，发布 `notice.emitted`） | `{text_key, params?}` | 同上 | `script.command.notice` | **需新增宿主用例，S2 落地** |
| API-C-03 | `ship.apply_damage` | **新宿主用例**（包装效果 op `damage_ship`，发布 `ship.damaged`） | `{amount, reason}` | 同上 | `script.command.ship` | **需新增宿主用例，S2 落地**；`reason` 进审计日志，不进事件 |
| API-C-04 | `quest.start` | C-22（现有） | `{quest_id}` | 同上 | `script.command.quest` | 现有命令可复用；必须先补 Quest 前置/重复校验的脚本侧错误映射 |
| API-C-05 | `supply.repair` | C-06（现有） | 无（当前港） | 同上 | `script.command.supply` | 现有命令可复用；只能作用于玩家船 |

**明确不开放（1.0）**：`run.start`（C-01）、`story.*`（C-19…C-21）、`quest.observe`（C-24）、`combat.resolve`（C-37，可指定 seed 决定结果）、`fleet.add_ship`（C-41，无扣费）、`warehouse.*`（C-29…C-32，绕过物流）、全部 `trade.*` / `debt.borrow` / `ship.craft_module`（经济作弊面）。若未来开放，必须单列威胁条目与用户授权 UI。

## 4. 版本与能力契约（目标契约）

### 4.1 `api_version` 与 `script_api_version`

| 字段 | 位置 | 当前值 | 语义 | 兼容判定 |
| --- | --- | --- | --- | --- |
| `api_version` | Manifest（现有） | `"1.0"` | **内容 SDK / Content Schema 契约**版本，管 JSON 内容能力 | `ModManifest.accepts_api(framework_major, framework_minor)`：major 必须相等，minor ≤ 宿主 minor |
| `script_api_version` | 脚本块（提案） | 尚不存在，目标 `"1.0"` | **Lua Script API** 版本，管 API 名称/事件 payload/命令语义 | 同一判定规则：major 相等且 minor ≤ 宿主 minor；不同 major 拒绝加载脚本 |
| `FrameworkInfo.VERSION` | 代码常量 | `"0.1.0"` | 框架自身版本 | 不参与 Manifest 兼容判定 |
| `api_version`（`app.view` 暴露值） | Query 数据 | `FrameworkInfo.API_VERSION = "1.0"` | 当前框架支持的 Content API | 与 Manifest 字段同名但方向相反（宿主声明支持） |

**规则**：
- 两个版本**独立演进**：改 Content Schema 不必升 `script_api_version`；改事件 payload 必须升 `script_api_version`。
- `script_api_version` 采用 `<major>.<minor>`（与现有 Manifest 一致）；只有 major.minor，不带 patch。
- **1.x 内允许**：新增 Query/Command/Event、给 payload 增加可选字段、新增能力、新增错误码。
- **1.x 内禁止**（必须升 2.0）：删除/改名 API、改 payload 字段类型、改事件触发时机、改命令事务语义、改变错误码含义。
- **2.0**：允许破坏性变更，但必须提供迁移说明与至少一个 1.x 兼容窗口；脚本模组声明 `script_api_version: "1.x"` 时在 2.0 宿主上明确拒绝，而不是静默降级。

### 4.2 capability 命名规范

| 能力（提案） | 覆盖范围 | 默认 |
| --- | --- | --- |
| `script.query.ship` | API-Q-01/02 | 拒绝 |
| `script.query.market` | API-Q-03 | 拒绝 |
| `script.query.voyage` | API-Q-04 | 拒绝 |
| `script.query.sim` | API-Q-05 | 拒绝 |
| `script.query.fleet` | API-Q-06 | 拒绝 |
| `script.query.campaign` | API-Q-07 | 拒绝 |
| `script.events.subscribe` | 全部公共事件订阅 | 拒绝 |
| `script.command.sim` | API-C-01 | 拒绝 |
| `script.command.notice` | API-C-02 | 拒绝 |
| `script.command.ship` | API-C-03 | 拒绝 |
| `script.command.quest` | API-C-04 | 拒绝 |
| `script.command.supply` | API-C-05 | 拒绝 |
| `script.storage` | 私有键值存储（`sn.storage`） | 拒绝 |
| `script.random` | `sn.random()` / `sn.random_int()` | 拒绝 |
| `script.log` | `sn.log()` | 拒绝 |

约束：
- 命名格式 `script.<类别>.<域>`，全小写 snake_case；类别只允许 `query` / `command` / `events` / `storage` / `random` / `log`。
- capability 名称**不带版本**；版本由 `script_api_version` 表达。
- **默认拒绝**；空 capability 集合的脚本模组不得调用任何 `sn.*`（`sn.api.version()` / `sn.mod.info()` 除外，属于元信息）。
- **声明 ≠ 授权**：Manifest 只表达需求，宿主在每次调用点做二次授权（与设计文档 §6.2 一致）；加载期发现未知能力沿用现有 `unsupported_capability` 错误码，禁用粒度按 §4.7 处理（`required=true` → fatal；可选模组 → 仅禁用脚本层）。
- 文件 / 网络 / OS / 原生库 / UI / SceneTree 无对应 capability，1.0 不开放。

### 4.3 错误协议（Result → Lua 错误对象）

Lua 侧统一返回：

```lua
-- 成功
{ ok = true, value = ... }
-- 失败
{ ok = false, error = { code = "insufficient_money", message_key = "ui.error.money", details = {...} } }
```

映射规则：
1. `ok/error_code/message_key/data` 一一映射为 `ok/code/message_key/details`；`details` 只保留白名单键（如 `required`、`money`、`item_id`），其余丢弃。
2. **禁止**把 GDScript 异常文本、堆栈、`str(exception)`、文件路径透给脚本；宿主日志可记录完整内容，但日志只留在宿主侧或 `sn.log` 的限频摘要。
3. 未知错误码统一映射为 `script.internal`，并记录宿主日志（不向脚本暴露原始 `error_code` 之外的内部信息）。
4. `autosave` / `autosave_meta` / `events` 不透传；`events` 只能经 `sn.events` 订阅面看到。
5. 面向用户的文本由 `message_key` 本地化，**脚本不得依赖文本内容**。

**稳定错误码清单（脚本可见子集，来自现有 105 个码中与候选 API 相关者）**：

| 命名空间 | 码 | 含义 |
| --- | --- | --- |
| 现有业务码 | `no_run` / `not_at_port` / `not_at_sea` / `no_ship` / `no_shipyard` / `no_supply` / `insufficient_money` / `insufficient_stock` / `insufficient_cargo` / `invalid_amount` / `unknown_item` / `unknown_module` / `weight_limit` / `cargo_capacity` / `debt_exists` / `not_damaged` / `unknown_quest` / `quest_prerequisites` / `unknown_clue` / `clue_expired` / `no_clue_available` / `explore_not_feasible` / `voyage_not_feasible` / `run_already_started` / `unknown_command` / `unknown_query` | 直接透传（语义稳定，已用于 UI 本地化） |
| `script.` | `script.unknown_api` | API 名不存在或未在当前 `script_api_version` 注册 |
| `script.` | `script.invalid_args` | 参数结构/类型/范围/字段不合法 |
| `script.` | `script.permission_denied` | 未声明、未授予或跨模组访问被拒 |
| `script.` | `script.api_version_mismatch` | major 不匹配或 minor 高于宿主 |
| `script.` | `script.payload_too_large` / `script.payload_depth` | 序列化预算超限（字节 / 嵌套深度） |
| `script.` | `script.value_not_serializable` | 含 Object/RID/Callable/NaN/Inf 等 |
| `script.` | `script.schema_error` | 返回值/参数不符合登记 schema |
| `script.` | `script.budget_exceeded` | 指令/回调预算超限 |
| `script.` | `script.memory_exceeded` | VM 内存或单值大小上限超限 |
| `script.` | `script.stack_overflow` | 递归深度超限 |
| `script.` | `script.coroutine_denied` | 协程能力未开放 |
| `script.` | `script.runtime_error` | 已脱敏的未分类 VM 运行时错误 |
| `script.` | `script.library_unavailable` | 访问被禁标准库 |
| `script.` | `script.module_denied` | `require` 越界或非白名单模块 |
| `script.` | `script.bytecode_denied` | 提交 `.luac` / 二进制 chunk |
| `script.` | `script.command_rejected` | 宿主拒绝入队（白名单外/限频/批次上限/上下文不合法） |
| `script.` | `script.event_chain_limit` / `script.batch_limit` | 事件链深度 / 单批命令数超限 |
| `script.` | `script.callback_stale` | 旧 token 或已销毁 state 的回调 |
| `script.` | `script.callback_failed` | 回调异常且已撤销未提交请求 |
| `script.` | `script.storage_denied` / `script.storage_quota` | 存储命名空间越权 / 配额超限 |
| `script.` | `script.state_migration_failed` | 脚本私有状态迁移失败 |
| `script.` | `script.identity_mismatch` | 脚本身份伪造或跨模组调用 |
| `script.` | `script.not_found_or_denied` | 敏感对象不存在与无权限统一返回 |
| `script.` | `script.log_rate_limited` | 日志超频被限流 |
| `script.` | `script.unavailable` | 宿主能力未启用（如无 Lua runtime） |
| `script.` | `script.internal` | 宿主内部错误（唯一兜底，禁止细分内部原因） |

> **命名统一（S0 定稿口径）**：脚本可见错误码一律使用 `script.<snake_case>` 点分形式；威胁模型附录 A 与测试矩阵早期草稿中的下划线形式（如 `script_capability_denied`、`script_budget_exceeded`）已统一映射到本表，不得再作为契约引用。本表未出现的错误码不得进入脚本可见面；新增码必须追加并升 `script_api_version` 的 minor。

### 4.4 只读快照、拷贝与序列化限制

- Query 结果为**深拷贝的只读快照**：Host 端从 `Result.data` 复制后白名单投影；Lua 修改返回值不改变游戏状态（现有 QueryBus 已使用状态克隆，但脚本层仍需再复制一次，避免共享引用）。
- 只允许 JSON-like：`nil`、boolean、number、string、array、dictionary；禁止 Node/Resource/Object/Callable/RID/PackedArray 等 Godot 类型。
- 浮点必须有限（拒绝 NaN/±Inf）；按存档一致的方式量化到 `1e-9`；整数保证在 ±2^53 内（超出转字符串或报错）。
- 建议上限（S1 PoC 基准后定稿）：单次载荷深度 ≤ 8、对象键 ≤ 512、数组长度 ≤ 1024、单字符串 ≤ 8 KiB、单次调用总字节 ≤ 256 KiB、事件 payload 同限。
- 禁止循环引用（Host 序列化时检测并报 `script.payload_depth`）。
- 命令参数从 Lua → Host 也走同一序列化边界与预算，不能只校验 Query 方向。

### 4.5 RNG、时间与日志

引用设计文档 [LUA_MODDING_SDK.md](LUA_MODDING_SDK.md) §7.2：

- 每模组独立 PRNG stream；种子由 `Campaign seed + Mod ID + 协议版本` 派生；状态存档在 `script_states[mod_id].rng_state`（目标格式，不是现有存档字段）。
- 脚本只能读游戏内时钟（建议 `sim.clock`），不提供 wall-clock；时间分支不得依赖系统时间。
- `sn.log(level, message)`：宿主附加 `mod_id` / 脚本文件 / 回调标识；按模组限频；不输出宿主内部对象；用户可见文本走本地化 key，日志文本不作为游戏状态。
- 随机与日志都不得影响确定性：同 seed + 同事件序列 + 同命令序列必须得到同结果（由测试矩阵 `TC-STATE-003` / `TC-STATE-004` / `TC-STATE-008`、`TC-SCHED-002` / `TC-SCHED-007` 覆盖）。

### 4.6 Manifest Schema 演进契约（建议：双 Schema + 显式判别字段）

**为什么不能"加个可选字段"**（代码现状，逐条可验证）：

1. `schemas/manifest.schema.json` 顶层 `additionalProperties: false`（第 6 行）：顶层出现 `scripts` 会直接产生 `manifest_schema` 错误，不是静默忽略。
2. 同文件 `"type": {"const": "content"}`（第 29–31 行）：`type=hybrid` / `type=script` 过不了 Schema；`ModManifest.from_dict` 随后还会报 `invalid_type`。
3. `framework/modding/mod_scanner.gd` 第 119–136 行只放行 `.json`、`localization/*.csv`、`assets/` 下六类扩展名（`.png/.webp/.svg/.ogg/.wav/.glb`），其它一律 `forbidden_file`；`scripts/main.lua` 在 Schema 之前就会被扫描器拒绝。
4. `framework/core/path_guard.gd` 的 `FORBIDDEN_EXTENSIONS` 目前**不含** `.lua`，但扫描器是白名单判定，所以"把 `.lua` 从禁用表里拿掉"并不能支持脚本——必须同时改扫描器白名单。

**建议契约**：

- **新增 `schemas/manifest-v2.schema.json`**（`$id` 指向 `mod-manifest-2.json`）；`schemas/manifest.schema.json` **保持原样**，继续服务旧模组。
- v2 增加**必填** `"manifest_version": 2`（integer，`const: 2`）；**无该字段即按 v1 解析**。判别字段刻意独立于 `api_version`：`api_version` 管内容契约兼容，`manifest_version` 管 Manifest 结构，二者不兼职。
- v2 `type` 使用枚举 `["content", "script", "hybrid"]`，并用条件约束：
  - `content`：`content` 至少 1 项，`scripts` 禁止出现；
  - `script`：`scripts` 必填，`content` 可省略（解析为空数组，纯脚本模组）；
  - `hybrid`：`content` 至少 1 项，且 `scripts` 必填。
- v2 `scripts` 对象：必填 `language`（`const: "lua"`）、`entry`（相对路径）、`script_api_version`（`^\d+\.\d+$`）；可选 `modules`（相对路径数组）；`additionalProperties: false`。
- 扫描器按 `manifest_version` 选择 Schema；新增 `PathGuard.SCRIPT_EXTENSIONS = [".lua"]` 与 `is_allowed_script(path)`（仅 `scripts/` 下、`.lua`，沿用 `is_safe_relative` 的长度/深度/穿越规则）。**不要**把 `.lua` 加入 `FORBIDDEN_EXTENSIONS`（会与放行逻辑冲突）。v2 新增结构化错误码：`unsupported_manifest_version`、`invalid_script_path`、`missing_script_entry`、`script_too_large`。
- `ModManifest.from_dict` 解析 v1/v2 联合结构，新增只读字段 `manifest_version` / `scripts` / `script_api_version`；v1 行为不变；未知 `manifest_version`（如 3）显式报错，不得降级成 v1。
- 所有脚本路径必须通过新增的 `is_allowed_script`，且加载时再校验"文件确实存在"；路径不得逃出模组根（沿用 `is_safe_relative`）。

**兼容矩阵（建议）**：

| 模组形态 | `manifest_version` | `api_version` | Schema | 行为 |
| --- | --- | --- | --- | --- |
| 现有内容模组 / Core | 缺省（=1） | `1.0` | v1（原文件） | 与今天完全一致；不创建 VM |
| 新内容模组（v2 结构，纯数据） | `2` | `1.0` | v2 | 不声明 `scripts`；不创建 VM |
| 脚本 / 混合模组 | `2` | `1.0`（内容基线） | v2 | `scripts` + `script_api_version: "1.0"`；S2 才启用 |
| 未来 `api_version=2.0` 内容模组 | 仍由 `manifest_version` 决定 | `2.0` | v2 或更高 | 内容契约升级不自动改变 Manifest 结构 |

发布门禁：`sdk/validate.gd --mode=runtime` 与 `pack_mod --release` 必须覆盖 v2 Schema、`scripts` 静态检查（路径/入口/语法）与 `script_api_version` 兼容；任一失败不写 zip（复用现有发布门禁原则，见 `sdk/README.md`）。

### 4.7 `script.*` capability 的数据流与授权契约（建议）

**是否新开 `script_capabilities` 字段**：**建议不新开**，继续复用现有 package 级 `capabilities` 数组，在解析后按前缀分流。理由：

- 设计文档 §10 要求"同一个 manifest、同一套能力规则、同一组发布错误码"；两个数组会让 SNModMaker / CLI / 文档出现两套声明源。
- 现有 `capabilities` 已是数组且 Schema 正则允许 `script.*`；前缀分流不改变旧模组。
- 需要一个简单的分桶规则：`content.*` → 内容白名单（现有 `FrameworkInfo.CAPABILITIES` 17 项）；`script.*` → 脚本白名单（建议新增独立的 `FrameworkInfo.SCRIPT_CAPABILITIES` 常量，**不并入** `CAPABILITIES`，避免内容校验误接受脚本能力）；其它前缀 → v2 报 `invalid_capability`，v1 沿用 `unsupported_capability`。

**数据流（S2 目标）**：

1. **scan**：v1/v2 Schema 校验 + 文件白名单（§4.6）；`scripts` 块解析为 `ModManifest.scripts`。
2. **分桶**：Manifest 的 `capabilities` 拆成 `content_requested[]` / `script_requested[]`；未知前缀即失败。
3. **resolve**：内容能力对照 `FrameworkInfo.CAPABILITIES`，脚本能力对照 `SCRIPT_CAPABILITIES` + 运行时是否存在 Lua Host。未知能力沿用 `unsupported_capability`，并在结构化错误里带 `scope: "content" | "script"`。
4. **严重度**：`required=true` 的模组任何 capability 失败 → fatal；可选模组脚本能力失败 → **仅禁用脚本层，内容照常加载**，并在状态与日志记录 `script_disabled_reason`（不静默、不假装加载成功）。
5. **freeze 后协商**：`requested → granted = requested ∩ host_available ∩ user_granted`，`granted` 是脚本层的只读快照；不持久化为可扩大的权限。
6. **逐调用授权**：每次 `sn.query` / `sn.command` / `sn.events.on` 都检查"API 存在 + capability 已授予 + 参数/预算合法 + 上下文合法"；失败返回 `script.permission_denied`，状态零变更。

**"声明 ≠ 授权"的落点**：Manifest 只产生 `requested` 集合；真正可调用的是 `granted` 集合；`granted` 在脚本层内存中只读，重载/重算，脚本无法通过任何 API 扩大。这样既有现有 package 级白名单的加载期失败语义，也有每次调用的最小权限检查。

**编号说明**：本文候选 API 统一使用 `API-Q-*` / `API-C-*` / `API-E-*`，盘点条目统一使用 `Q-*` / `C-*` / `E-*`，与 S0-3 测试矩阵占位一致，不另设编号。

## 5. 待决问题清单（S1/S2 前必须定稿）

| ID | 问题 | 影响 | 建议决策点 |
| --- | --- | --- | --- |
| OQ-01 | `script_api_version` 是否复用现有 `api_version` 的 `<major>.<minor>` 两段格式，还是采用完整 SemVer？ | Manifest 解析、兼容判定、SDK 校验 | 建议两段，与现有 Manifest 保持一致 |
| OQ-02 | 纯脚本模组（`type=script`）是否允许零内容文件、`content` 字段可省略？ | Manifest 必填字段与 SDK 打包 | **建议已给 §4.6**（v2 的 `script` 允许省略 `content`）；待定：SDK 是否允许这种包进入 release 渠道 |
| OQ-03 | capability 粒度按"域"（`script.query.ship`）还是按单个 API（`script.query.ship.get`）？ | 授权 UI 复杂度与最小权限 | 建议 1.0 按域，2.0 可细化 |
| OQ-04 | 未知/未授权脚本 capability 是禁用整个 Mod，还是仅禁用脚本层？ | 与现有 `unsupported_capability` 整包禁用行为不一致 | **建议已给 §4.7**（可选模组仅禁用脚本层、内容照常；`required=true` fatal）；待定：是否新增独立错误级别/错误码 |
| OQ-05 | 命令结果如何回传：`script.command_result` 回调、任务句柄、还是 `sn.poll()`？ | 调度器与 Lua API 形态 | S1 先验证队列+回调最小闭环 |
| OQ-06 | 脚本查询的快照时间点：批次开始、调用瞬间、还是命令提交后？ | 确定性与可重放 | 建议同批次共享批次开始快照（设计 §7.1） |
| OQ-07 | 事件 payload 裁剪由宿主固定投影，还是由脚本声明字段？ | 性能与最小暴露 | 建议宿主固定白名单，脚本只能缩小 |
| OQ-08 | 失败 `Result` 携带的事件当前不会发布（`CommandBus` 只在 `ok` 分支 `publish_many`）；是否修复该语义？ | 事件契约完整性（如 `clue.expired`） | 建议 S2 前修复或以"失败不产生事件"为正式规则并清理失败路径事件 |
| OQ-09 | 同一命令的 N 条事件是否有批次边界？脚本能否看到同批后续事件？ | 递归/重入防护 | 建议批次内不可见后续事件；回调只入队命令 |
| OQ-10 | 事件 `source` 恒为 `"framework"`，是否改为 Mod ID / 命令来源以便审计与限权？ | 审计、限频、故障定位 | 建议 S2 扩展信封 `source_mod`（向后兼容可空） |
| OQ-11 | 每 event_type 是否需要独立 `schema_version`？当前 `DomainEventBus.SCHEMA_VERSION` 是全局 `"1.0"`。 | 事件演进粒度 | 建议 event_type 级版本表，信封保留 `schema_version` 字段 |
| OQ-12 | `sn.mod.info()` 返回哪些字段（ID/版本/已授权 capability/API 版本）？是否包含 checksum？ | 脚本诊断与调试 | 建议只读元信息，不含宿主路径 |
| OQ-13 | 序列化预算的具体阈值（深度/大小/键数/字符串）以 PoC 基准还是先冻结默认值？ | DoS 防护与作者体验 | 建议先按 §4.4 默认值冻结，PoC 后只允许放宽不收紧 |
| OQ-14 | `sn.storage` 的 schema 版本、迁移失败策略、配额与卸载后数据保留策略 | 存档兼容 | 建议每模组独立 `storage_schema`，迁移失败标记不可用并备份 |
| OQ-15 | 命令是否允许"代替玩家"执行（如 `trade.*`）？若允许，用户授权 UI 与限频放在哪一层？ | 作弊面与产品定位 | 建议 1.0 不允许；2.0 再评估 |
| OQ-16 | 无 Lua runtime / 平台不支持时，含 `scripts` 的 Mod 是"加载失败"还是"内容照常、脚本禁用"？ | 与设计 §3"明确失败或标记不可启用"对齐 | 建议沿用 `required` 严重度模型，脚本失败不静默 |

## 附录 A：ID 维护规则

- `Q-*` / `C-*`：按 `query_registry.gd` / `command_registry.gd` 的**注册顺序**编号；新增条目追加到末尾，不重排。
- `E-*`：按 `event_type` **字典序**编号；新增事件插入会使后续编号位移，因此后续文档引用应以 `event_type` 字符串为主键、`E-*` 为辅。
- `API-Q-*` / `API-E-*` / `API-C-*`：只增不改；删除的候选保留编号并标记 `Deprecated`。
- `OQ-*`：只增不改；定稿后在后续文档记录决议，不删除问题编号。
- 威胁模型使用 `TM-<AREA>-nn`、测试矩阵使用 `TC-<AREA>-nnn`，`AREA` 由 S0-2 威胁模型任务定义；本文不预分配。

## 附录 B：本文未覆盖的内容

- Lua VM 选型、沙箱、指令预算、内存上限、平台导出：S1 PoC（[LUA_MODDING_SDK.md](LUA_MODDING_SDK.md) §6、§11.1）。
- Script Host / 调度器 / storage 实现：S2。
- 威胁建模与验收测试：S0-2 / S0-3 独立文档。
- 存档 `script_states` 的最终 Schema：依赖 OQ-14 与 Save Schema 版本控制方案。


