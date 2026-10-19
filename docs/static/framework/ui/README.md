# `framework/ui`

> 展示层。固定 Shell、四个菜单场景、七个功能页、五个流程页与海图组件均已场景化；Shell 仅保留上下文解析、ViewModel 组合、导航、命令和转场。共享 Godot Theme、可复用控件与 UI Kit 展示场景保持统一视觉。船厂中央改装台（SNShipView）与部件 HUD（SNSlotTarget/SNPartRow）是独立可复用组件，未来 2.5D 渲染器经 set_renderer 接入。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `components/README.md` | 框架源文件：README.md | 本页 |
| `components/map_canvas.gd` | 海图绘制与港口点击组件：显示航路、经纬网、洋流、罗盘、图例及港口状态。 | [查看](./components/map_canvas.gd.md) |
| `components/map_canvas.tscn` | 框架源文件：map_canvas.tscn | 本页 |
| `components/sn_badge.gd` | 紧凑状态徽标：中性、成功、警告和危险四种语义色。 | [查看](./components/sn_badge.gd.md) |
| `components/sn_badge.tscn` | 框架源文件：sn_badge.tscn | 本页 |
| `components/sn_button.gd` | 可复用语义按钮：在 Inspector 中选择主操作、次操作、危险或幽灵样式。 | [查看](./components/sn_button.gd.md) |
| `components/sn_button.tscn` | 框架源文件：sn_button.tscn | 本页 |
| `components/sn_intel_table.gd` | 商品 × 港口对比表控件：一次渲染情报矩阵的列头、价格/趋势单元格与图例。 | [查看](./components/sn_intel_table.gd.md) |
| `components/sn_panel.gd` | 可复用界面表面：基础、高架与内嵌三种层级。 | [查看](./components/sn_panel.gd.md) |
| `components/sn_panel.tscn` | 框架源文件：sn_panel.tscn | 本页 |
| `components/sn_part_row.gd` | 船厂右侧部件 HUD 的单行条目：用标签区分已装 / 仓库 / 随船 / 可购买，持有且可装的行是拖拽来源。 | [查看](./components/sn_part_row.gd.md) |
| `components/sn_part_row.tscn` | 框架源文件：sn_part_row.tscn | 本页 |
| `components/sn_resource_meter.gd` | 煤水、耐久与载重共用的标签化资源存量条。 | [查看](./components/sn_resource_meter.gd.md) |
| `components/sn_resource_meter.tscn` | 框架源文件：sn_resource_meter.tscn | 本页 |
| `components/sn_section_header.gd` | 章节标题组合控件：眉题、标题和可选右侧说明。 | [查看](./components/sn_section_header.gd.md) |
| `components/sn_section_header.tscn` | 框架源文件：sn_section_header.tscn | 本页 |
| `components/sn_ship_view.gd` | 船厂中央改装台：同一坐标系里切换船体侧视占位渲染与纵剖图（每槽位一个 SNSlotTarget 贴片），并预留可替换的 2.5D 渲染器接口。 | [查看](./components/sn_ship_view.gd.md) |
| `components/sn_ship_view.tscn` | 框架源文件：sn_ship_view.tscn | 本页 |
| `components/sn_slot_target.gd` | 纵剖图上的单个槽位贴片：显示槽位与已装模块，接收 `ship_parts` 拖放载荷，只校验来源与槽位类型。 | [查看](./components/sn_slot_target.gd.md) |
| `components/sn_slot_target.tscn` | 框架源文件：sn_slot_target.tscn | 本页 |
| `components/sn_sparkline.gd` | 市场价格历史迷你折线；只有两个以上真实样本才绘制。 | [查看](./components/sn_sparkline.gd.md) |
| `components/sn_sparkline.tscn` | 框架源文件：sn_sparkline.tscn | 本页 |
| `components/sn_supply_card.gd` | 单种补给品的决策卡：存量、可补上限、价格、港存、预计续航和购买操作。 | [查看](./components/sn_supply_card.gd.md) |
| `components/sn_supply_card.tscn` | 框架源文件：sn_supply_card.tscn | 本页 |
| `screens/flow/at_sea_screen.gd` | 航行中流程场景：显示起终港、预计抵达时间或等待结算状态。 | [查看](./screens/flow/at_sea_screen.gd.md) |
| `screens/flow/at_sea_screen.tscn` | 框架源文件：at_sea_screen.tscn | 本页 |
| `screens/flow/event_screen.gd` | 航行事件流程场景：展示事件说明、当前资源和本次抽取的处理选项。 | [查看](./screens/flow/event_screen.gd.md) |
| `screens/flow/event_screen.tscn` | 框架源文件：event_screen.tscn | 本页 |
| `screens/flow/port_memory_screen.gd` | 港口记忆流程场景：只读展示上次到港时的市场和设施快照。 | [查看](./screens/flow/port_memory_screen.gd.md) |
| `screens/flow/port_memory_screen.tscn` | 框架源文件：port_memory_screen.tscn | 本页 |
| `screens/flow/settlement_screen.gd` | 抵达结算流程场景：展示航次收入、准时率、延误、剩余资源、交付明细与伤员。 | [查看](./screens/flow/settlement_screen.gd.md) |
| `screens/flow/settlement_screen.tscn` | 框架源文件：settlement_screen.tscn | 本页 |
| `screens/flow/victory_screen.gd` | 通关总结流程场景：展示种子、构筑、航次、准时率、事故、财务、债务、耐久和最终模块。 | [查看](./screens/flow/victory_screen.gd.md) |
| `screens/flow/victory_screen.tscn` | 框架源文件：victory_screen.tscn | 本页 |
| `screens/menu/main_menu_screen.gd` | 启动主菜单页面场景：展示启动状态与主入口，并把用户操作转成 Shell 意图。 | [查看](./screens/menu/main_menu_screen.gd.md) |
| `screens/menu/main_menu_screen.tscn` | 框架源文件：main_menu_screen.tscn | 本页 |
| `screens/menu/mods_screen.gd` | 已加载模组列表页面场景：只读展示本次启动实际载入的模组及依赖。 | [查看](./screens/menu/mods_screen.gd.md) |
| `screens/menu/mods_screen.tscn` | 框架源文件：mods_screen.tscn | 本页 |
| `screens/menu/new_game_screen.gd` | 新航程配置页面场景：选择初始构筑和随机种子，展示启动内容摘要与警告。 | [查看](./screens/menu/new_game_screen.gd.md) |
| `screens/menu/new_game_screen.tscn` | 框架源文件：new_game_screen.tscn | 本页 |
| `screens/menu/settings_screen.gd` | 设置页面场景：展示语言、自动存档与配置位置，并发出设置修改意图。 | [查看](./screens/menu/settings_screen.gd.md) |
| `screens/menu/settings_screen.tscn` | 框架源文件：settings_screen.tscn | 本页 |
| `screens/port/contracts_screen.gd` | 委托页面场景：按可接/进行中分组渲染主线与普通委托卡，并发出接取或规划出航意图。 | [查看](./screens/port/contracts_screen.gd.md) |
| `screens/port/contracts_screen.tscn` | 框架源文件：contracts_screen.tscn | 本页 |
| `screens/port/intel_screen.gd` | 航路情报页面场景：展示情报摘要、商品×港口矩阵与 NPC 商船动向。 | [查看](./screens/port/intel_screen.gd.md) |
| `screens/port/intel_screen.tscn` | 框架源文件：intel_screen.tscn | 本页 |
| `screens/port/market_screen.gd` | 港口市场页面场景：展示行情、真实价格历史、持仓成本及买卖操作。 | [查看](./screens/port/market_screen.gd.md) |
| `screens/port/market_screen.tscn` | 框架源文件：market_screen.tscn | 本页 |
| `screens/port/overview_screen.gd` | 港口总览页面场景：组合港口横幅、海图、主线目标、通关清单、船只摘要、快捷操作、财务与航行记录。 | [查看](./screens/port/overview_screen.gd.md) |
| `screens/port/overview_screen.tscn` | 框架源文件：overview_screen.tscn | 本页 |
| `screens/port/shipyard_screen.gd` | 船厂页面场景：中央 SNShipView 改装台 + 右侧按槽位分组的部件 HUD（已装/仓库/随船/购买），下方保留打造订单、港口仓库、配方、购买与通关清单面板。 | [查看](./screens/port/shipyard_screen.gd.md) |
| `screens/port/shipyard_screen.tscn` | 框架源文件：shipyard_screen.tscn | 本页 |
| `screens/port/supply_screen.gd` | 补给与维修页面场景：绑定 SupplyView，组合煤水决策卡、资源摘要与维修操作。 | [查看](./screens/port/supply_screen.gd.md) |
| `screens/port/supply_screen.tscn` | 框架源文件：supply_screen.tscn | 本页 |
| `screens/port/voyage_screen.gd` | 出航规划页面场景：选择目的港与锅炉策略，展示完整 voyage.preview 并发出出航意图。 | [查看](./screens/port/voyage_screen.gd.md) |
| `screens/port/voyage_screen.tscn` | 框架源文件：voyage_screen.tscn | 本页 |
| `shell/main.gd` | 可玩 UI 组合根：解析上下文、查询 ViewModel、执行命令、处理导航/转场，并把已迁移页面挂载到场景宿主。 | [查看](./shell/main.gd.md) |
| `shell/main.tscn` | 框架源文件：main.tscn | 本页 |
| `showcase/ui_kit_showcase.gd` | 独立 UI Kit 展示与视觉冒烟场景，集中实例化全部可复用控件和状态。 | [查看](./showcase/ui_kit_showcase.gd.md) |
| `showcase/ui_kit_showcase.tscn` | 框架源文件：ui_kit_showcase.tscn | 本页 |

## 模块契约

- UI 只识别 Query/Command 与定义类型，不识别 core 内容。
- 公共视觉状态优先进入 Theme variation；业务页面只负责布局与数据绑定。
- 页面场景不得直接持有 AppContext；查询、命令、跨页导航、全局提示与音效属于 Shell。
