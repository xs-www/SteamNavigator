# `framework/domain`

> 纯领域逻辑：航行、市场、委托、船只/模块实例/仓库/打造订单、地图、世界生成（坐标空间+程序化陆地+贝塞尔航线）、事件、债务与通关判定。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `contracts/contract_ops.gd` | 委托实例生成、装载、交付结算、接取规则、普通委托池生成与抵达刷新。 | [查看](./contracts/contract_ops.gd.md) |
| `contracts/formula_registry.gd` | 框架拥有的安全期限公式注册表，供委托数据引用。 | [查看](./contracts/formula_registry.gd.md) |
| `contracts/run_factory.gd` | 新局工厂：选构筑/地图配置、生成船只与市场、NPC、仓库/运输/统计/通关结构、初始主线与普通委托。 | [查看](./contracts/run_factory.gd.md) |
| `debt/debt_service.gd` | 固定利率贷款：借款、收入优先还款、逾期扣声誉。 | [查看](./debt/debt_service.gd.md) |
| `economy/intel_service.gd` | 生成不可变的市场/NPC 情报快照，并保留生成时间。 | [查看](./economy/intel_service.gd.md) |
| `economy/market_memory_service.gd` | 每港“上次在港时”的市场快照：价格、储备、可买标记与时间戳。 | [查看](./economy/market_memory_service.gd.md) |
| `economy/market_ops.gd` | 市场价格、买卖、补给商品与维修结算；煤/水价格随港口库存浮动。 | [查看](./economy/market_ops.gd.md) |
| `economy/npc_trader_simulator.gd` | 后台 NPC 商船：在港口间运输/采购商品，推动库存与价格。 | [查看](./economy/npc_trader_simulator.gd.md) |
| `events/condition_evaluator.gd` | 解析 all/any/not 组合器并调用条件操作码，限制条件节点数。 | [查看](./events/condition_evaluator.gd.md) |
| `events/condition_op_registry.gd` | 白名单条件操作码及其只读判定实现。 | [查看](./events/condition_op_registry.gd.md) |
| `events/effect_executor.gd` | 顺序执行效果列表，失败即中止并返回带索引的错误。 | [查看](./events/effect_executor.gd.md) |
| `events/effect_op_registry.gd` | 白名单效果操作码及其纯实现（货币、补给、货物、船只与模块、委托、情报、通知）。 | [查看](./events/effect_op_registry.gd.md) |
| `map/map_generator.gd` | 程序生成 4–5 港口连通分支网络，并验证 MVP 硬约束。 | [查看](./map/map_generator.gd.md) |
| `map/map_ops.gd` | GameState.world 上的港口/航线查询、设施可见性、发现与 BFS。 | [查看](./map/map_ops.gd.md) |
| `run/victory_service.gd` | 通关判定与服务：主线全部完成 + 造船厂内组装最低可运行大型船（大型船体 + 锅炉 + ≥1 货舱）。 | [查看](./run/victory_service.gd.md) |
| `ship/craft_ops.gd` | 模块打造：读取模块 JSON 配方、规划材料来源、仓库优先消耗、扣费并生成带工时的打造订单，时间到位后把成品写入下单港仓库。 | [查看](./ship/craft_ops.gd.md) |
| `ship/ship_modules.gd` | 船舶模块实例层：为每个已装模块维护稳定 instance_id 与 0..1 condition，对齐扁平槽位键，并作为损伤/维修/存档的唯一写入口。 | [查看](./ship/ship_modules.gd.md) |
| `ship/ship_ops.gd` | 船只组合的纯函数：模块/货物/煤水/旅客/随船运输重量、容量、槽位、安装/卸下规则与派生属性。 | [查看](./ship/ship_ops.gd.md) |
| `ship/warehouse_ops.gd` | 港口仓库与随船运输：每港独立保存模块/材料，transit 模块计入重量但不占货舱。 | [查看](./ship/warehouse_ops.gd.md) |
| `voyage/voyage_calculator.gd` | 纯计算航行预览：速度、耗时、煤水、准点、风险来源与可行性阻断。 | [查看](./voyage/voyage_calculator.gd.md) |
| `voyage/voyage_service.gd` | 航行执行：校验预览、扣补给/工资、抽取事件、事件选择、抵达结算与失败回滚。 | [查看](./voyage/voyage_service.gd.md) |
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
