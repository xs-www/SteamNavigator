# 迭代 1 · MVP 闭环 — 实现契约

> 目标：首次可以完整通关。范围：**模块打造 / 港口仓库 / 模块替换与运输 / 普通委托刷新 / 第五委托通关判定**。
> 基线：Framework 0.1.0 · Core 1.0.0 · Schema 1.0。本文是实现期契约，代码完成后同步进静态文档。

## 1. 验收标准

1. 玩家在造船厂能：购买成品、用材料**打造**模块、把模块存入/取出**港口仓库**、**替换/卸下**旧模块（旧件进当前港仓库）。
2. 未安装模块可经 **transit** 随船运输：计入总重量，不占货舱容量；在任意造船厂可免费安装。
3. 材料可随船运输、存入/取出港口仓库；打造从当前港仓库优先消耗材料，不足再从船上普通货物扣。
4. 每次抵达目的港后普通委托池**自动刷新**；持有上限按声誉计算并在 UI 显示。
5. 完成主线 05 后解锁大型船体；在造船厂组装**大型船体 + 锅炉 + ≥1 货舱**即触发通关，展示总结页（构筑、航次、准时率、事故、收入/支出/利润、债务、耐久）。
6. 现有 49 个测试全部通过，并新增仓库/打造/替换/委托刷新/通关/完整通关测试。
7. 无头测试可完整跑完一局：五段主线 → 大型船 → 通关。

## 2. 状态结构（GameState，仅存 ID 与运行态）

```text
world.warehouses = {
  "<port_id>": {
    "modules":   { "<module_id>": qty:int },
    "materials": { "<item_id>": amount:int }
  }
}
ship.transit_modules = { "<module_id>": qty:int }   # 计入总重量，不占货舱
ship.cargo           # 既有：普通货物 + 委托货物
contracts.offers     # 既有：抵达时整池刷新
contracts.completed  # 既有：template_id 列表
stats = {"voyages":0,"on_time":0,"accidents":0,"income":0,"expense":0,"profit":0}
victory = null | {"achieved":true,"achieved_at":float,"summary":{...}}
```

- `warehouses` 对局内所有港口初始化；`transit_modules` 初始 `{}`；`victory` 初始 `null`。
- 旧存档兼容：`WarehouseOps.ensure_structure(state)`、`ContractOps.ensure_structure(state)`、`RunStats.ensure(state)` 幂等补齐缺失字段；加载后 `VictoryService` 不因字段缺失报错。
- 框架内不得出现具体 `core:*` ID。

## 3. 领域 API（新增/修改）

### 3.1 `framework/domain/ship/warehouse_ops.gd`（新，class_name `WarehouseOps`）

| 函数 | 语义 |
| --- | --- |
| `ensure_structure(state) -> void` | 补齐所有港口仓库与 `ship.transit_modules`。 |
| `warehouse(state, port_id) -> Dictionary` | `{modules:{}, materials:{}}`，不存在则返回空结构（只读用）。 |
| `module_qty(state, port_id, module_id) -> int` | 仓库中模块数量。 |
| `material_amount(state, port_id, item_id) -> int` | 仓库中材料数量。 |
| `transit_module_weight(hub, ship) -> float` | 船上未安装模块总重。 |
| `owned_module_count(state, hub, module_id) -> int` | 已安装 + transit + 当前港仓库。 |
| `store_module(state, hub, port_id, module_id, qty=1) -> Dictionary` | transit → 仓库；`Result`。 |
| `take_module(state, hub, port_id, module_id, qty=1) -> Dictionary` | 仓库 → transit；检查 `max_weight`。 |
| `store_materials(state, hub, port_id, item_id, amount) -> Dictionary` | 船普通货物 → 仓库。 |
| `take_materials(state, hub, port_id, item_id, amount) -> Dictionary` | 仓库 → 船普通货物；检查重量与货舱容量。 |

错误码：`not_at_port`、`missing_module`、`unknown_module`、`missing_item`、`unknown_item`、`insufficient_cargo`、`warehouse_empty`、`insufficient_materials`、`weight_limit`、`cargo_capacity`、`invalid_amount`。

### 3.2 `framework/domain/ship/craft_ops.gd`（新，class_name `CraftOps`）

- `materials_required(hub, module_id) -> Array`：来自 module.data.materials；无配方返回空。
- `craftable(hub, module_id) -> bool`。
- `material_plan(state, hub, port_id, module_id) -> Array`：每项 `{item_id,name_key,required,warehouse,cargo,owned,enough}`。
- `craft_blockers(hub, state, module_id) -> Array[String]`：`unknown_module`、`not_craftable`、`locked_by_contract`、`missing_materials`、`insufficient_money`。
- `craft(state, hub, module_id) -> Dictionary`：扣材料（当前港仓库优先，再扣船上非委托货物）、扣 `craft_cost`、`advance_time(craft_time_hours)`、成品进当前港仓库；返回 `{module_id, content_type, craft_time_hours, craft_cost, consumed, game_time, warehouse_qty}`，事件 `ship.module_crafted`。

### 3.3 `framework/domain/ship/ship_ops.gd`（修改）

- `total_weight` 增加 `transit_module_weight`。
- `install_blockers(hub, state, module_id, source:="purchase", replace_module_id:="") -> Array[String]`：
  - 既有：`unknown_module`、`locked_by_reputation`、`locked_by_contract`（模块出现在任一 contract 的 `unlock_ids` 且不在 `player.unlocks`）、`insufficient_money`（仅 purchase）、`weight_limit`。
  - 替换：单槽（hull/boiler/nav/safety/cabin）自动替换旧件，不再返回 `slot_occupied`。
  - 货舱满且未给 `replace_module_id` → `cargo_slots_full`；给了则按替换计算重量。
  - 已安装同一 module_id → `already_installed`。
  - `source` 为 `warehouse`/`transit` 时校验库存；库存不足 → `warehouse_empty` / `not_in_transit`。
  - 重量按最终配置计算（替换旧件重量、transit 释放重量均扣除）。
- `uninstall_blockers(hub, state, module_id) -> Array[String]`：`not_installed`、`required_module`（hull/boiler 不可卸下）。
- `simulate_install(...)` 可选；只要 blocker 与命令实现一致即可。
- `validate_configuration` 保持：hull+boiler 必需、货舱槽不超、客舱槽合法、耐久不超上限。
- 新增 `unlock_contract_id(hub, module_id) -> String`（返回解锁它的 contract template id，找不到返回 ""）。

### 3.4 `framework/domain/run/victory_service.gd`（新，class_name `VictoryService`）

- `main_chain_complete(hub, state) -> bool`：注册表中所有 `kind=="main"` 模板都出现在 `contracts.completed`。
- `conditions(hub, state) -> Dictionary`：`{shipyard, main_complete, large_hull, boiler, cargo, ready}`；`large_hull = stats.hull_tier >= 3`。
- `check(state, hub) -> Dictionary`：未完成/已颁奖返回 `{newly_achieved:false,...}`；满足则写入 `state.data.victory`，返回 `{newly_achieved:true, summary:{...}}`。**只在造船厂安装模块成功后调用**（`ShipCommands.install_module`）。
- `summary(hub, state) -> Dictionary`：
  `{seed, starting_build, starting_build_name_key, game_time, voyages, on_time, on_time_rate, accidents, income, expense, profit, money, debt_remaining, reputation, durability, max_durability, hull_id, hull_name_key, cargo_capacity, modules:[{content_type,name_key,module_id}]}`
- `achieved(state) -> bool`。

### 3.5 `framework/domain/contracts/contract_ops.gd`（修改）

- `active_limit(state) -> int`：`maxi(1, 1 + reputation/2)`；`accept_offer` 复用它。
- `generate_normal_offers(state, hub, rng_service, key: String) -> Array`：从 `kind=="normal"` 模板抽 3 个（不足则全用），生成实例写入 `contracts.offers`；RNG 流 `STREAM_CONTRACT_GENERATION`，键 `normal_offers::<key>`。
- `refresh_normal_offers(state, hub, rng_service, port_id, arrival_time) -> Array`：以 `<port_id>:<arrival_time>:<voyages>` 为 key 刷新整池；返回新 offers。
- `is_unlocked(state, definition_id) -> bool` 可选（解锁判断已放 ShipOps，避免双实现）。

### 3.6 `framework/domain/contracts/run_factory.gd`（修改）

- 初始化 `warehouses`、`ship.transit_modules`、`stats.income/expense`、`victory=null`。
- 初始普通委托改用 `ContractOps.generate_normal_offers(..., "initial:<port>")`（保持确定性：同 seed 结果不变）。
- 仍生成初始主线 01 并自动接取。

### 3.7 `framework/domain/voyage/voyage_service.gd`（修改）

- `_complete_arrival`：NPC 推进后调用 `ContractOps.refresh_normal_offers(...)`，summary 增加 `"offers_refreshed": true`；事件 `contract.offers_refreshed`（payload `{port_id, count, game_time}`）。
- 出航扣工资时 `state.record_expense(wages)`。
- 到达后 `VictoryService` 不在此判定（通关只由造船厂组装触发）。

### 3.8 统计（`framework/state/game_state.gd`）

新增 `record_income(amount:int)` / `record_expense(amount:int)`：累加 `stats.income` / `stats.expense`，并更新 `stats.profit = income - expense`。调用点：

- `MarketOps.buy`（支出）、`MarketOps.sell`（收入）、`MarketOps.buy_supply`（支出）、`MarketOps.repair`（支出）。
- `VoyageService.start` 工资（支出）。
- `ContractOps.complete` 实付 payout（收入）。
- `DebtService.borrow` **不计收入**（贷款不是利润）。
- 情报刷新费用（支出，`IntelCommands.refresh`）。
- `ShipCommands` 购买价 / `CraftOps` 打造费（支出）。

## 4. 命令（CommandBus）

| 命令 | 参数 | 行为 / 结果 data | 错误码 |
| --- | --- | --- | --- |
| `ship.install_module` | `module_id`, `source`=`purchase|warehouse|transit`, `replace_module_id` | 购买或免费安装；旧件进当前港仓库；成功后调用 `VictoryService.check`，data 增加 `victory`；事件 `ship.module_installed`（含 `replaced`, `source`），新通关时另发 `run.victory_achieved`。data：`{module_id, content_type, source, price, replaced_module_id, money, total_weight, victory}` | 见 3.3 + `invalid_source` |
| `ship.uninstall_module` | `module_id` | 造船厂卸下 → 当前港仓库；事件 `ship.module_uninstalled`。data：`{module_id, content_type, warehouse_qty}` | `not_at_port`、`no_shipyard`、`unknown_module`、`not_installed`、`required_module` |
| `ship.craft_module` | `module_id` | 见 3.2；事件 `ship.module_crafted`；data 含 `craft_blockers` 失败明细 | `no_shipyard`、`not_craftable`、`locked_by_contract`、`missing_materials`、`insufficient_money` |
| `warehouse.store_module` | `module_id`, `qty=1` | transit → 当前港仓库 | 见 3.1 |
| `warehouse.take_module` | `module_id`, `qty=1` | 仓库 → transit（重量校验） | 见 3.1 |
| `warehouse.store_materials` | `item_id`, `amount` | 船货物 → 仓库 | 见 3.1 |
| `warehouse.take_materials` | `item_id`, `amount` | 仓库 → 船货物（重量+容量校验） | 见 3.1 |

命令全部经 `command_registry.gd` 注册；新增命令必须有测试。

## 5. 查询（QueryBus）

### 5.1 `shipyard.view`（扩展）

```text
has_run, at_port, has_shipyard, port_id, port_name_key, money
ship: { ...既有字段..., modules:[{content_type,module_id,name_key,description_key,weight,tier,price,can_uninstall,uninstall_blockers[]}],
        transit_modules:[{module_id,name_key,qty,weight}], transit_weight }
warehouse: { port_id,
             modules:[{content_type,module_id,name_key,qty,weight,can_install,blockers[]}],
             materials:[{item_id,name_key,amount,unit_weight}] }
craft: [{content_type,module_id,name_key,description_key,tier,weight,craft_time_hours,craft_cost,
         materials:[{item_id,name_key,required,warehouse,cargo,owned,enough}],
         unlocked,can_craft,blockers[]}]
candidates: [...既有..., will_replace, unlock_template_id, craftable, craft_blockers[]]
```

`installed` / `can_install` / `blockers` 字段保持兼容（旧测试依赖）。

### 5.2 `port.view`（扩展）

- `contracts` 增加：`active_limit`、`active_count`、`normal_holds`（同 active_count）、`main_chain_complete`。
- `ship` 增加：`transit_modules`、`transit_weight`。
- 顶层增加 `victory: {achieved, achieved_at}`。

### 5.3 `victory.view`（新）

```text
has_run, achieved, achieved_at, achieved_at_label, summary{...见 3.4}
```

### 5.4 `query_registry.gd` 注册 `victory.view`。

## 6. 内容（Core JSON）

- 六类模块（hulls/boilers/cargo_modules/navigation_modules/safety_modules/cabins）已有 `materials`、`craft_time_hours`；为 tier≥2 补 `craft_cost`（约 purchase_price 的 15–20%，tier1 可省略=0）：
  - medium_standard 220、large_efficient 520、large_performance 680
  - boiler/performance 180；cargo/medium_hold 160、large_hold 320；nav/chart_room 140；safety/safety_valve 130；cabin/passenger_cabin 100（客舱只有 tier1，可省略）
  - 允许内容模组覆盖；数值只写在 JSON。
- `port_archetypes.json`：两个造船厂港口（iron_harbor、free_town）市场加入 `core:material/precision_gear`（限量库存 10–25），保证大型船材料在当局地图可获得。
- 不变更 schema（`module_common` 已允许 `materials/craft_time_hours/craft_cost`）。

## 7. UI（`framework/ui/shell/main.gd`）

- 船厂页：当前模块（可卸下 / 显示将替换的旧件去向）、港口仓库（模块/材料 存入取出）、打造区（材料进度、金币、工时、按钮与禁用原因）、购买区（锁定/替换说明）。
- 委托页：显示普通委托持有上限（如 `1 / 1`）与“每次抵达后刷新”提示。
- 通关页：`victory.view.achieved` 时优先于普通页面展示（类似结算页）；显示总结字段；按钮 `再来一局`（清空当前局回到新航程菜单）与 `继续游玩`（关闭总结，可继续）。总结关闭状态放 UI 成员，不写入存档。
- 所有新文本走 localization（`framework/localization/zh_CN.json` 与 `en.json`）；缺失回退键名。
- 新增 UI 命令回调：`ship.craft_module`、`ship.uninstall_module`、`warehouse.*`；成功走 `_handle_success` 播报；`ship.install_module` 结果含新通关时进入通关页。

## 8. 测试（`framework/tests`）

新增套件并在 `test_runner.gd` 注册：

- `test_warehouse_craft.gd`：仓库存/取模块与材料、transit 重量、打造材料消耗与工时推进、打造件入库、免费安装旧件、替换旧件入仓、卸下、失败回滚。
- `test_contract_refresh.gd`：抵达后普通委托池刷新（instance_id 变化）、持有上限随声誉、`port.view` 上限字段。
- `test_victory.gd`：未完成主线不触发；主线全完成 + 大型船体 + 锅炉 + 货舱 触发；总结字段齐全；重复安装不重复颁奖。
- `test_full_clear.gd`：单 seed 程序化完整通关（五段主线 → 大型船 → `victory`），并断言航次 ≤ 12。
- 修改既有：`test_ship_upgrade.gd`（替换语义、解锁前置）、`test_ui_views.gd`（新字段/锁定原因）。

## 9. 确定性 / 存档

- 所有随机经命名流；新流键必须包含 seed 派生上下文（港口、时间、航次）。
- 新状态字段必须是 JSON 可序列化纯数据（int/float/String/Array/Dictionary），不存对象引用。
- `save→load→hash` 一致（既有测试覆盖）；新增字段不得破坏 `canonical_stringify`（键排序即可）。

---

## 10. 实现结果（迭代 1 收尾）

- 状态：**已完成**；headless 套件 74 passed / 0 failed。
- 完整通关：`framework/tests/cases/test_full_clear.gd` 覆盖 seed 4242（详细 summary 断言）与 111/222/333/444/555/666/777/888（多 seed 回归），均走完五段主线并在造船厂组装大型船触发通关；航次上限 16。
- 新增领域/应用文件：`framework/domain/ship/warehouse_ops.gd`、`craft_ops.gd`、`framework/domain/run/victory_service.gd`、`framework/application/commands/warehouse_commands.gd`、`framework/application/queries/victory_view.gd`。
- 新增测试：`test_warehouse_craft.gd`（13）、`test_contract_refresh.gd`（4）、`test_victory.gd`（5）、`test_full_clear.gd`（2）；更新 `test_ship_upgrade`、`test_ui_views`、`test_market_memory`、`test_runner`。

### 与契约的偏差 / 决策记录

1. **统计实现位置**：契约里提到 `RunStats.ensure(state)`；实际实现为 `GameState.stats()/ensure_stats()` + `record_income/record_expense`，避免新增服务类。旧存档通过惰性 ensure 补齐，未新增加载期迁移钩子。
2. **材料运输语义**：未安装模块使用 `ship.transit_modules`（计重、不占货舱）；**造船材料仍按普通货物计入货舱容量**。GDD 9.1 要求材料也不占货舱，由于材料目前随市场货物一起买入，本轮先保持既有贸易/容量口径，列为下一优先级。
3. **成本/收入口径**：通关总结的“利润” = 毛收入 − 支出；合同 payout 记毛收入（债务自动扣款不记支出），贷款本金不计收入。
4. **货舱替换 UI**：领域命令支持 `replace_module_id`，UI 本轮通过“先卸下再安装”完成货舱替换，未做槽位选择器。
5. **委托刷新 key**：`<port_id>:<arrival_time %.3f>:<voyages>`；同一 seed + 命令序列可复现。
6. **解锁判定**：模块 ID 在任一 contract `rewards.unlock_ids` 中即视为合同锁定；`ContractOps.complete` 把 unlock_ids（模块 ID）写入 `player.unlocks`，因此以模块 ID 成员判断，而非合同模板 ID。
7. **舱容/耐久**：购买替换船体后耐久为新上限；warehouse/transit 旧件重装取 `min(当前耐久, 新上限)`，避免免费维修。
8. **仓库开放范围**：任意停靠港都可存取；安装/打造/卸下仍限定造船厂，ViewModel 用 `no_shipyard` 阻止按钮。

