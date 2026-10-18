# `framework/application`

> 应用层：命令/查询总线、公共 API 注册、领域事件与用例。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `command_bus.gd` | 命令执行器：在 GameState 深拷贝上运行用例，成功才提交并发布领域事件。 | [查看](./command_bus.gd.md) |
| `commands/command_registry.gd` | 命令名到静态用例的绑定表。 | 本页 |
| `commands/contract_commands.gd` | 委托接取命令包装。 | 本页 |
| `commands/debt_commands.gd` | 借款命令包装。 | 本页 |
| `commands/intel_commands.gd` | 情报刷新命令：设施、费用、快照。 | 本页 |
| `commands/run_start.gd` | run.start 命令：调用 RunFactory 并写回状态/随机流。 | 本页 |
| `commands/ship_commands.gd` | 船厂流程：购买并安装船体/锅炉/货舱/导航/安全/客舱。 | [查看](./commands/ship_commands.gd.md) |
| `commands/supply_commands.gd` | 按市场价购买煤水与维修命令包装。 | 本页 |
| `commands/trade_commands.gd` | trade.buy / trade.sell 命令包装与市场事件。 | 本页 |
| `commands/voyage_commands.gd` | 预览/出航/事件选择命令包装。 | 本页 |
| `domain_event_bus.gd` | 已提交领域事件的 envelope、历史与订阅信号。 | [查看](./domain_event_bus.gd.md) |
| `framework_api.gd` | 注册全部命令与查询。 | 本页 |
| `queries/app_view.gd` | 启动与菜单 ViewModel：状态、模组、计数、构筑、命令列表。 | 本页 |
| `queries/intel_view.gd` | 情报独立界面 ViewModel：快照时间/年龄、已发现港口市场表和 NPC 预计动向。 | [查看](./queries/intel_view.gd.md) |
| `queries/map_view.gd` | 海图 ViewModel：港口坐标、发现/访问、设施与航线。 | 本页 |
| `queries/port_memory_view.gd` | 点击已访问港口时的只读市场记忆 ViewModel：上次在港的价格、储备与可买标记。 | [查看](./queries/port_memory_view.gd.md) |
| `queries/port_view.gd` | 主界面 ViewModel：当前港、市场、目的地、船只、委托、策略、情报、通知与统计。 | [查看](./queries/port_view.gd.md) |
| `queries/query_registry.gd` | 查询名到 ViewModel 构造器的绑定表。 | 本页 |
| `queries/shipyard_view.gd` | 船厂独立界面 ViewModel：当前模块、槽位占用和所有可购买模块的限制原因。 | [查看](./queries/shipyard_view.gd.md) |
| `queries/supply_view.gd` | 补给界面 ViewModel：煤水价/库存、载重余量、可补上限、预计续航与维修报价。 | [查看](./queries/supply_view.gd.md) |
| `queries/voyage_preview.gd` | 出航预览查询包装。 | 本页 |
| `query_bus.gd` | 只读查询执行器：给处理器临时克隆的 GameState，返回 ViewModel。 | [查看](./query_bus.gd.md) |
| `result.gd` | 统一 `{ok,error_code,message_key,data,events}` 结果构造。 | 本页 |

## 模块契约

- UI 与测试使用同一命令/查询入口。
- 命令事务克隆提交；查询只读 ViewModel。
