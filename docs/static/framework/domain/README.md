# `framework/domain`

> 纯领域逻辑：航行、市场、委托、船只/模块实例/仓库/打造订单、地图、世界生成（坐标空间+程序化陆地+贝塞尔航线）、事件、债务与通关判定、D0 tick 模拟与 D1 战斗规则。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `base/base_ops.gd` | Phase D3 基地（base）的纯结构与计算层：规范化 `data.base`、解析基地/建筑/ | [查看](./base/base_ops.gd.md) |
| `base/base_production_system.gd` | Phase D3 基地的确定性 tick 系统：每游戏小时支付维护费/建筑维护/工人工资， | [查看](./base/base_production_system.gd.md) |
| `base/base_service.gd` | Phase D3 基地的领域用例：占领基地、建造/升级建筑、雇工/派工、仓储存取与 | [查看](./base/base_service.gd.md) |
| `campaign/assembly_utils.gd` | CampaignFactory 世界装配链路（区域 / 地点 / 航路 / 阵营 / 图鉴）共用的 | [查看](./campaign/assembly_utils.gd.md) |
| `campaign/campaign_factory.gd` | 战役开局装配（WORLD_SCHEMA_V2_RUNTIME §6.2）。从 `start_profiles` 定义解析 | [查看](./campaign/campaign_factory.gd.md) |
| `campaign/discovery_assembler.gd` | v2 战役的图鉴装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 9）。按 | [查看](./campaign/discovery_assembler.gd.md) |
| `campaign/faction_assembler.gd` | v2 战役的阵营装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 8）。按 | [查看](./campaign/faction_assembler.gd.md) |
| `campaign/map_generation_spec.gd` | 把 Content Schema 2.0 的 `world_profiles` / `map_configs` / `route_templates` | [查看](./campaign/map_generation_spec.gd.md) |
| `campaign/region_assembler.gd` | v2 战役的区域装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 5）。按 | [查看](./campaign/region_assembler.gd.md) |
| `campaign/route_assembler.gd` | v2 战役的航路装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 7）。为海图世界的每条边 | [查看](./campaign/route_assembler.gd.md) |
| `campaign/site_assembler.gd` | v2 战役的地点装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 6）。每个区域按 | [查看](./campaign/site_assembler.gd.md) |
| `combat/combat_ops.gd` | Phase D1 战斗自动结算的纯规则层。把「玩家船 + encounter_table 抽出的敌舰组合 + | [查看](./combat/combat_ops.gd.md) |
| `combat/combat_service.gd` | Phase D1 战斗自动结算的运行时门面：解析遭遇表、调用 `CombatOps` 纯规则层， | [查看](./combat/combat_service.gd.md) |
| `contracts/contract_ops.gd` | 委托实例生成、装载、交付结算、接取规则、普通委托池生成与抵达刷新。 | [查看](./contracts/contract_ops.gd.md) |
| `contracts/formula_registry.gd` | 框架拥有的安全期限公式注册表，供委托数据引用。 | [查看](./contracts/formula_registry.gd.md) |
| `contracts/run_factory.gd` | 开局装配的共享 helper（C4 起不再持有 1.0 `map_profiles` 几何路径）。提供 | [查看](./contracts/run_factory.gd.md) |
| `debt/debt_service.gd` | 固定利率贷款：借款、收入优先还款、逾期扣声誉。 | [查看](./debt/debt_service.gd.md) |
| `economy/intel_service.gd` | 生成不可变的市场/NPC 情报快照，并保留生成时间。 | [查看](./economy/intel_service.gd.md) |
| `economy/market_memory_service.gd` | 每港“上次在港时”的市场快照：价格、储备、可买标记与时间戳。 | [查看](./economy/market_memory_service.gd.md) |
| `economy/market_ops.gd` | 市场价格、买卖（可落船货舱或当前港仓库）、补给商品与维修结算；煤/水价格随港口库存浮动。 | [查看](./economy/market_ops.gd.md) |
| `economy/npc_trader_simulator.gd` | 后台 NPC 商船：在港口间运输/采购商品，推动库存与价格。 | [查看](./economy/npc_trader_simulator.gd.md) |
| `events/condition_evaluator.gd` | 解析 all/any/not 组合器并调用条件操作码，限制条件节点数。 | [查看](./events/condition_evaluator.gd.md) |
| `events/condition_op_registry.gd` | 白名单条件操作码及其只读判定实现。 | [查看](./events/condition_op_registry.gd.md) |
| `events/effect_executor.gd` | 顺序执行效果列表，失败即中止并返回带索引的错误。 | [查看](./events/effect_executor.gd.md) |
| `events/effect_op_registry.gd` | 白名单效果操作码及其纯实现（货币、补给、货物、船只与模块、委托、情报、通知）。 | [查看](./events/effect_op_registry.gd.md) |
| `exploration/clue_service.gd` | 线索的领域服务——港口位置线索（抵达传闻 / 情报站购买）与货物行情线索 | [查看](./exploration/clue_service.gd.md) |
| `exploration/exploration_calculator.gd` | 把「一条线索的搜索区 + 当前船况 + 锅炉策略 + 探索规则」折算成探索出航预览 | [查看](./exploration/exploration_calculator.gd.md) |
| `exploration/exploration_rules.gd` | 读取并合并探索系统规则（`map_configs` 定义的 | [查看](./exploration/exploration_rules.gd.md) |
| `exploration/explore_voyage_service.gd` | 探索航次的领域执行——出航（只扣工资、记录出发库存与每小时煤水费率、写探索 | [查看](./exploration/explore_voyage_service.gd.md) |
| `fleet/fleet_ops.gd` | Phase D2 舰队（fleet）的纯结构助手：惰性维护 `data.fleet`、解析旗舰条目、 | [查看](./fleet/fleet_ops.gd.md) |
| `fleet/fleet_service.gd` | Phase D2 舰队的领域用例：舰长指派、编队/槽位、战术选择、增删舰船。 | [查看](./fleet/fleet_service.gd.md) |
| `map/map_generator.gd` | 程序生成 4–5 港口连通分支网络，并验证 MVP 硬约束。 | [查看](./map/map_generator.gd.md) |
| `map/map_ops.gd` | GameState.world 上的港口/航线查询、设施可见性、发现与 BFS。 | [查看](./map/map_ops.gd.md) |
| `port/port_time_service.gd` | 在港时间推进的统一领域入口。推进游戏时间，并让打造订单、NPC 市场模拟与 | [查看](./port/port_time_service.gd.md) |
| `quest/quest_ops.gd` | `data.quests` 持久任务状态的纯数据操作层（C3）。负责惰性 ensure、实例字段 | [查看](./quest/quest_ops.gd.md) |
| `quest/quest_service.gd` | 抽象任务（Quest）状态机（C3）。把 `quests` 2.0 内容定义（stage 链 + 目标 DSL） | [查看](./quest/quest_service.gd.md) |
| `ruins/expedition_service.gd` | Phase D5 遗迹远征的领域用例：开始远征、进入房间、选择事件选项、撤退与结算。 | [查看](./ruins/expedition_service.gd.md) |
| `ruins/ruin_ops.gd` | Phase D5 遗迹远征的纯结构/计算层：生成确定性房间序列、掷危险、结算事件效果、 | [查看](./ruins/ruin_ops.gd.md) |
| `run/victory_service.gd` | 通关判定与服务：主线全部完成 + 造船厂内组装最低可运行大型船（大型船体 + 锅炉 + ≥1 货舱）。 | [查看](./run/victory_service.gd.md) |
| `ship/craft_ops.gd` | 模块打造：读取模块 JSON 配方、规划材料来源、仓库优先消耗、扣费并生成带工时的打造订单，时间到位后把成品写入下单港仓库。 | [查看](./ship/craft_ops.gd.md) |
| `ship/module_ops.gd` | Content Schema 2.0 统一模块类型 `modules` 的分类访问器：按 `data.v2_category` | [查看](./ship/module_ops.gd.md) |
| `ship/ship_modules.gd` | 船舶模块实例层：为每个已装模块维护稳定 instance_id 与 0..1 condition，对齐扁平槽位键，并作为损伤/维修/存档的唯一写入口。 | [查看](./ship/ship_modules.gd.md) |
| `ship/ship_ops.gd` | 船只组合、重量、容量与派生属性的纯规则；模块实例 condition 会按槽位缩放能力贡献，舰载武器重量计入总重。 | [查看](./ship/ship_ops.gd.md) |
| `ship/warehouse_ops.gd` | 港口仓库（模块、材料、武器）与随船运输模块的状态操作；旧存档缺分区时惰性补齐。 | [查看](./ship/warehouse_ops.gd.md) |
| `ship/weapon_ops.gd` | 玩家旗舰的舰载武器所有权与装配纯规则；校验 hull socket、weapon class、来源、价格和重量，并维护 `ship.weapon_loadout`。 | [查看](./ship/weapon_ops.gd.md) |
| `sim/simulation_service.gd` | 最小确定性 tick / 模拟框架（Phase D0）。以 1 游戏小时为固定步长推进 | [查看](./sim/simulation_service.gd.md) |
| `sim/tick_scheduler.gd` | SimulationService 的确定性 tick 系统注册表。系统用 `(id, priority, | [查看](./sim/tick_scheduler.gd.md) |
| `story/story_service.gd` | 新手剧情 / 教学系统的领域状态机。读取当前场景定义（`map_configs`， | [查看](./story/story_service.gd.md) |
| `trade/auto_trade_ops.gd` | Phase D4 自动贸易的纯结构/计算层：规范化 `data.trade`、读取贸易策略与 | [查看](./trade/auto_trade_ops.gd.md) |
| `trade/auto_trade_service.gd` | Phase D4 自动贸易的领域用例：启动/停止/切换贸易策略，手动暂停/恢复； | [查看](./trade/auto_trade_service.gd.md) |
| `trade/auto_trade_system.gd` | Phase D4 自动贸易的确定性 tick 系统：按策略在港口之间自动买卖，处理航程、 | [查看](./trade/auto_trade_system.gd.md) |
| `voyage/voyage_calculator.gd` | 纯计算航行预览：速度、耗时、煤水、准点、风险来源与可行性阻断。 | [查看](./voyage/voyage_calculator.gd.md) |
| `voyage/voyage_estimator.gd` | 把「一条航线 + 当前船况 + 锅炉策略 + 航行规则」折算成海图右侧面板需要的 | [查看](./voyage/voyage_estimator.gd.md) |
| `voyage/voyage_presentation.gd` | 航行演出（海图系统阶段 3）的**纯状态机**：把一次已经由 `voyage.start` | [查看](./voyage/voyage_presentation.gd.md) |
| `voyage/voyage_service.gd` | 航行执行：校验预览、出发扣工资、抽取事件、事件选择、抵达结算（按实际航行 | [查看](./voyage/voyage_service.gd.md) |
| `world/chart_world_projection.gd` | 把**唯一世界**（海图 `WorldMap` / `state.data["world_map"]`）转换成玩法层使用的 | [查看](./world/chart_world_projection.gd.md) |
| `world/fog_grid.gd` | 战争迷雾网格，维护未探索、已探索海岸与当前可见三种状态。 | [查看](./world/fog_grid.gd.md) |
| `world/fog_ops.gd` | 战争迷雾高层操作，把 FogGrid 与 WorldMap、GameState 接合。 | [查看](./world/fog_ops.gd.md) |
| `world/land_generator.gd` | 程序化生成陆地多边形，支持大陆、大岛、小岛和环礁。 | [查看](./world/land_generator.gd.md) |
| `world/landmass.gd` | 表示世界地图中的陆地多边形，支持大陆、大岛、小岛、环礁四种原型。 | [查看](./world/landmass.gd.md) |
| `world/region.gd` | 表示世界地图中的行政区域，区分沿岸区域和远洋区域。 | [查看](./world/region.gd.md) |
| `world/route_calculator.gd` | 计算避开陆地的港口间贝塞尔航路、出航角度和连通关系。 | [查看](./world/route_calculator.gd.md) |
| `world/world_generator.gd` | 世界生成总控，协调区域、陆地、港口放置、连通性、出航角与航线预计算。 | [查看](./world/world_generator.gd.md) |
| `world/world_map.gd` | 世界地图顶层容器，保存陆地、港口、区域、连通性、已算好的航线与本世界种子。 | [查看](./world/world_map.gd.md) |
| `world/world_ops.gd` | 世界地图查询与状态变更接口，替代 MVP 时期的 MapOps。 | [查看](./world/world_ops.gd.md) |
| `world/world_port.gd` | 表示锚定在陆地海岸线上的世界港口及其设施、连通性信息。 | [查看](./world/world_port.gd.md) |

## 模块契约

- 领域函数尽量输入确定、输出确定；随机必须来自 RngService 命名流。
- 不读写文件、不创建 UI、不直接访问场景树。
- 仓库/运输/打造只操作 GameState 纯数据；通关判定读取注册表合同与船只派生属性。
- 世界生成器使用坐标空间模型（替代 MVP 时期的抽象图），港口锚定在程序生成的陆地海岸线上。
- D0 SimulationService / TickScheduler 只推进 data.sim 与已注册 tick 系统，不改写既有 port.wait / 航行时间语义；D1 CombatOps 纯规则、CombatService 负责落盘与 data.combat 记录；D2 FleetOps 维护 data.fleet 结构、FleetService 负责 captain / formation / doctrine / 增删舰校验。
