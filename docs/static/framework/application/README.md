# `framework/application`

> 应用层：命令/查询总线、公共 API 注册、领域事件与用例（交易、委托、出航、船厂/仓库/打造订单、在港等待、通关、D0 sim 时钟、D1 战斗结算）。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `command_bus.gd` | 命令执行器：在 GameState 深拷贝上运行用例，成功才提交并发布领域事件。 | [查看](./command_bus.gd.md) |
| `commands/combat_commands.gd` | `combat.resolve` 命令入口（Phase D1 自动战斗）。把参数（可选 | [查看](./commands/combat_commands.gd.md) |
| `commands/command_registry.gd` | 命令名到静态用例的绑定表（含船厂/仓库/打造/在港等待、D0 `sim.*`、D1 `combat.resolve` 与 D2 `fleet.*` 命令）。 | 本页 |
| `commands/contract_commands.gd` | 委托接取命令包装。 | 本页 |
| `commands/debt_commands.gd` | 借款命令包装。 | 本页 |
| `commands/explore_commands.gd` | 探索系统的命令包装（`explore.start` / `explore.settle` / `explore.decide` / | [查看](./commands/explore_commands.gd.md) |
| `commands/fleet_commands.gd` | Phase D2 舰队的命令入口：`fleet.assign_captain` / `fleet.set_formation` / | [查看](./commands/fleet_commands.gd.md) |
| `commands/intel_commands.gd` | 情报刷新命令：设施、费用、快照。 | 本页 |
| `commands/port_commands.gd` | 港口停留用例：在本港消耗时间，让打造订单、NPC 市场与债务期限一起推进。 | [查看](./commands/port_commands.gd.md) |
| `commands/quest_commands.gd` | 抽象任务（Quest）的命令包装（C3）：`quest.start`（接取内容任务）、 | [查看](./commands/quest_commands.gd.md) |
| `commands/run_start.gd` | `run.start` 命令入口（C4 起所有开局统一走 CampaignFactory）。无 | [查看](./commands/run_start.gd.md) |
| `commands/ship_commands.gd` | 船厂用例：购买/仓库/随船运输三种来源安装模块（含替换）、卸下模块、打造模块，并在安装成功后检查通关。 | [查看](./commands/ship_commands.gd.md) |
| `commands/sim_commands.gd` | Phase D0 模拟时钟的四个命令入口：`sim.pause` / `sim.resume` / | [查看](./commands/sim_commands.gd.md) |
| `commands/story_commands.gd` | 新手剧情 / 教学系统的命令包装：`story.advance`（剧情卡继续）、 | [查看](./commands/story_commands.gd.md) |
| `commands/supply_commands.gd` | 按市场价购买煤水与维修命令包装。 | 本页 |
| `commands/trade_commands.gd` | trade.buy / trade.sell 命令包装与市场事件。 | 本页 |
| `commands/voyage_commands.gd` | 预览/出航/事件选择命令包装。 | 本页 |
| `commands/warehouse_commands.gd` | 仓库命令包装：ship.transit 与当前港仓库之间的模块/材料存取。 | [查看](./commands/warehouse_commands.gd.md) |
| `domain_event_bus.gd` | 已提交领域事件的 envelope、历史与订阅信号。 | [查看](./domain_event_bus.gd.md) |
| `framework_api.gd` | 注册全部命令与查询。 | 本页 |
| `queries/app_view.gd` | 启动与菜单 ViewModel：状态、模组、计数、构筑、命令列表。 | 本页 |
| `queries/campaign_view.gd` | v2 战役运行时快照查询（`campaign.view`，Phase B B3）。只读地输出 | [查看](./queries/campaign_view.gd.md) |
| `queries/clue_list_view.gd` | 线索列表页的只读查询（`clue.list`）。返回全部 active 线索的等级裁剪视图 | [查看](./queries/clue_list_view.gd.md) |
| `queries/combat_log.gd` | `combat.log` 只读查询：按时间顺序输出持久化的战斗摘要（最新在最后），供 | [查看](./queries/combat_log.gd.md) |
| `queries/combat_view.gd` | `combat.view` 只读查询：输出玩家当前武装 / 结构耐久、可选遭遇表摘要与最近 | [查看](./queries/combat_view.gd.md) |
| `queries/fleet_view.gd` | `fleet.view` 只读查询：输出旗舰 / 名册 / captain 指派 / 编队与槽位 / | [查看](./queries/fleet_view.gd.md) |
| `queries/intel_view.gd` | 情报独立界面 ViewModel：快照时间/年龄、商品 × 港口对比矩阵（含未探索港口列）与 NPC 预计动向。 | [查看](./queries/intel_view.gd.md) |
| `queries/map_view.gd` | 海图 ViewModel：港口坐标、发现/访问、设施与航线。 | 本页 |
| `queries/port_memory_view.gd` | 点击已访问港口时的只读市场记忆 ViewModel：上次在港的价格、储备与可买标记。 | [查看](./queries/port_memory_view.gd.md) |
| `queries/port_view.gd` | 主界面 ViewModel：当前港、市场、目的地、船只、委托、策略、情报、通知、统计与通关状态。 | [查看](./queries/port_view.gd.md) |
| `queries/query_registry.gd` | 查询名到 ViewModel 构造器的绑定表（含 shipyard/victory、D0 `sim.view`、D1 `combat.view` / `combat.log` 与 D2 `fleet.view`）。 | 本页 |
| `queries/sea_chart_view.gd` | 为可缩放 2D 海图生成只读视图模型（`sea_chart.view`），输出世界边界、 | [查看](./queries/sea_chart_view.gd.md) |
| `queries/shipyard_view.gd` | 船厂独立界面 ViewModel：当前/随船运输模块、已装模块效果、港口仓库、打造配方与所有可购买模块的限制原因。 | [查看](./queries/shipyard_view.gd.md) |
| `queries/sim_view.gd` | `sim.view` 只读查询：输出模拟时钟的 paused / speed / tick / 步长 / | [查看](./queries/sim_view.gd.md) |
| `queries/story_view.gd` | 新手剧情 / 教学系统的只读查询（`story.view`）。输出剧情卡、目标条、功能 / | [查看](./queries/story_view.gd.md) |
| `queries/supply_view.gd` | 补给界面 ViewModel：煤水价/库存、载重余量、可补上限、预计续航与维修报价。 | [查看](./queries/supply_view.gd.md) |
| `queries/task_view.gd` | 任务追踪聚合查询（`task.view`，阶段 4.6 Phase A / C3 Phase B）。只读地把剧情 | [查看](./queries/task_view.gd.md) |
| `queries/tavern_view.gd` | 酒馆页（`tavern.view`）的只读查询——把原「情报站」的物价情报矩阵 | [查看](./queries/tavern_view.gd.md) |
| `queries/victory_view.gd` | 通关页 ViewModel：是否通关、通关时间与完整 run summary。 | [查看](./queries/victory_view.gd.md) |
| `queries/voyage_preview.gd` | 出航预览查询包装。 | 本页 |
| `query_bus.gd` | 只读查询执行器：给处理器临时克隆的 GameState，返回 ViewModel。 | [查看](./query_bus.gd.md) |
| `result.gd` | 统一 `{ok,error_code,message_key,data,events}` 结果构造。 | 本页 |

## 模块契约

- UI 与测试使用同一命令/查询入口。
- 命令事务克隆提交；查询只读 ViewModel。
- 船厂新增命令 ship.uninstall_module / ship.craft_module 与 warehouse.* 四个存取命令，均经 CommandRegistry 注册。
- 迭代 2 新增 port.wait：在本港消耗时间并结算打造订单、推进 NPC 市场与债务期限。
- D0 新增 sim.pause / sim.resume / sim.set_speed / sim.advance + sim.view；D1 新增 combat.resolve + combat.view / combat.log；D2 新增 fleet.assign_captain / set_formation / set_doctrine / add_ship / remove_ship + fleet.view，均经 CommandRegistry / QueryRegistry 注册。
