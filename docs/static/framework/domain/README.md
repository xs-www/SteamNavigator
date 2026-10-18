# `framework/domain`

> 纯领域逻辑：航行、市场、委托、船只、地图、事件与债务。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `contracts/contract_ops.gd` | 委托实例生成、装载、交付结算与接取规则。 | [查看](./contracts/contract_ops.gd.md) |
| `contracts/formula_registry.gd` | 框架拥有的安全期限公式注册表，供委托数据引用。 | [查看](./contracts/formula_registry.gd.md) |
| `contracts/run_factory.gd` | 新局工厂：选构筑/地图配置、生成船只与市场、NPC、初始主线与普通委托。 | [查看](./contracts/run_factory.gd.md) |
| `debt/debt_service.gd` | 固定利率贷款：借款、收入优先还款、逾期扣声誉。 | [查看](./debt/debt_service.gd.md) |
| `economy/intel_service.gd` | 生成不可变的市场/NPC 情报快照，并保留生成时间。 | [查看](./economy/intel_service.gd.md) |
| `economy/market_memory_service.gd` | 每港“上次在港时”的市场快照：价格、储备、可买标记与时间戳。 | [查看](./economy/market_memory_service.gd.md) |
| `economy/market_ops.gd` | 市场价格、买卖、补给商品与维修结算；煤/水价格随港口库存浮动。 | [查看](./economy/market_ops.gd.md) |
| `economy/npc_trader_simulator.gd` | 后台 NPC 商船：在港口间运输/采购商品，推动库存与价格。 | [查看](./economy/npc_trader_simulator.gd.md) |
| `events/condition_evaluator.gd` | 解析 all/any/not 组合器并调用条件操作码，限制条件节点数。 | [查看](./events/condition_evaluator.gd.md) |
| `events/condition_op_registry.gd` | 白名单条件操作码及其只读判定实现。 | [查看](./events/condition_op_registry.gd.md) |
| `events/effect_executor.gd` | 顺序执行效果列表，失败即中止并返回带索引的错误。 | [查看](./events/effect_executor.gd.md) |
| `events/effect_op_registry.gd` | 白名单效果操作码及其纯实现（货币、补给、货物、船只、委托、情报、通知）。 | [查看](./events/effect_op_registry.gd.md) |
| `map/map_generator.gd` | 程序生成 4–5 港口连通分支网络，并验证 MVP 硬约束。 | [查看](./map/map_generator.gd.md) |
| `map/map_ops.gd` | GameState.world 上的港口/航线查询、设施可见性、发现与 BFS。 | [查看](./map/map_ops.gd.md) |
| `ship/ship_ops.gd` | 船只组合的纯函数：模块/货物/煤水/旅客重量、容量、槽位、持续时间与派生属性。 | [查看](./ship/ship_ops.gd.md) |
| `voyage/voyage_calculator.gd` | 纯计算航行预览：速度、耗时、煤水、准点、风险来源与可行性阻断。 | [查看](./voyage/voyage_calculator.gd.md) |
| `voyage/voyage_service.gd` | 航行执行：校验预览、扣补给/工资、抽取事件、事件选择、抵达结算与失败回滚。 | [查看](./voyage/voyage_service.gd.md) |

## 模块契约

- 领域函数尽量输入确定、输出确定；随机必须来自 RngService 命名流。
- 不读写文件、不创建 UI、不直接访问场景树。
