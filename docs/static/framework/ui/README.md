# `framework/ui`

> 展示层。固定 Shell、四个菜单场景、七个功能页、五个流程页与海图组件均已场景化；Shell 仅保留上下文解析、ViewModel 组合、导航、命令和转场。共享 Godot Theme、可复用控件与 UI Kit 展示场景保持统一视觉。船厂中央改装台（SNShipView）与部件 HUD（SNSlotTarget/SNPartRow）是独立可复用组件，2.5D 渲染器经 set_renderer 接入。2.5D 固定舞台位于 `framework/ui/stages/`：`SNStageHost` 持有 SubViewport 与生命周期，`LocationStage` 是舞台契约，`ShipyardStage` 承载船厂 3D 船体，`PortStage` 是港口舞台骨架，`StageKit` 提供环境/水面/AABB 取景构建器；总览页已把 `PortStage` 作为全窗背景层接入，并生成 2D 设施热点（点击与顶部导航同一路径）。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `components/README.md` | 框架源文件：README.md | 本页 |
| `components/sn_badge.gd` | 紧凑状态徽标：中性、成功、警告和危险四种语义色。 | [查看](./components/sn_badge.gd.md) |
| `components/sn_badge.tscn` | 框架源文件：sn_badge.tscn | 本页 |
| `components/sn_button.gd` | 可复用语义按钮：在 Inspector 中选择主操作、次操作、危险或幽灵样式。 | [查看](./components/sn_button.gd.md) |
| `components/sn_button.tscn` | 框架源文件：sn_button.tscn | 本页 |
| `components/sn_cloud_veil.gd` | 航行演出的云层转场层（阶段 3）。全屏、不吃鼠标，用程序化云团把画面从 | [查看](./components/sn_cloud_veil.gd.md) |
| `components/sn_harbor_sign.gd` | 2.5D 港口主界面的主题化边缘招牌：`Button` 子类，用自绘木板/木纹/铁框/黄铜铆钉/四角包边/设施徽记/指向场景的箭头替代主题 StyleBox，悬停/按下/焦点用黄铜光晕与明暗反馈；点击、焦点、tooltip、`text` 语义仍由 Button 提供。 | [查看](./components/sn_harbor_sign.gd.md) |
| `components/sn_intel_table.gd` | 商品 × 港口对比表控件：一次渲染情报矩阵的列头、价格/趋势单元格与图例。 | [查看](./components/sn_intel_table.gd.md) |
| `components/sn_panel.gd` | 可复用界面表面：基础、高架与内嵌三种层级。 | [查看](./components/sn_panel.gd.md) |
| `components/sn_panel.tscn` | 框架源文件：sn_panel.tscn | 本页 |
| `components/sn_part_row.gd` | 船厂右侧部件 HUD 的单行条目：用标签区分已装 / 仓库 / 随船 / 可购买，持有且可装的行是拖拽来源。 | [查看](./components/sn_part_row.gd.md) |
| `components/sn_part_row.tscn` | 框架源文件：sn_part_row.tscn | 本页 |
| `components/sn_resource_meter.gd` | 煤水、耐久与载重共用的标签化资源存量条。 | [查看](./components/sn_resource_meter.gd.md) |
| `components/sn_resource_meter.tscn` | 框架源文件：sn_resource_meter.tscn | 本页 |
| `components/sn_sea_chart_panel.gd` | 海图右侧信息面板。选中港口后展示港口名、原型、区域、设施列表，以及 | [查看](./components/sn_sea_chart_panel.gd.md) |
| `components/sn_sea_chart_view.gd` | 可缩放/平移的 2D 海图视图，使用 `_draw()` 在世界坐标上绘制水面与图框、 | [查看](./components/sn_sea_chart_view.gd.md) |
| `components/sn_section_header.gd` | 章节标题组合控件：眉题、标题和可选右侧说明。 | [查看](./components/sn_section_header.gd.md) |
| `components/sn_section_header.tscn` | 框架源文件：sn_section_header.tscn | 本页 |
| `components/sn_ship_stage_3d.gd` | 船厂正常态的 3D 舞台适配器：把通用 `SNStageHost` 接入既有 `SNShipView.set_renderer()` 协议，加载 `ShipyardStage` 承载船体、环境、灯光与水面；节点本身只做 ViewModel/模式转发与显隐。 | [查看](./components/sn_ship_stage_3d.gd.md) |
| `components/sn_ship_view.gd` | 船厂中央改装台：`EXTERIOR` 画程序化侧视占位；`CUTAWAY` 画授权纵剖图贴图（`assets/ui/shipyard/ship_section.png`）+ 每槽位一个 `SNSlotTarget` 贴片，贴图缺失时回退程序化剖面；预留可替换的 2.5D 渲染器接口。 | [查看](./components/sn_ship_view.gd.md) |
| `components/sn_ship_view.tscn` | 框架源文件：sn_ship_view.tscn | 本页 |
| `components/sn_slot_target.gd` | 纵剖图上的单个槽位贴片：显示槽位与已装模块，接收 `ship_parts` 拖放载荷，只校验来源与槽位类型。 | [查看](./components/sn_slot_target.gd.md) |
| `components/sn_slot_target.tscn` | 框架源文件：sn_slot_target.tscn | 本页 |
| `components/sn_sparkline.gd` | 市场价格历史迷你折线；只有两个以上真实样本才绘制。 | [查看](./components/sn_sparkline.gd.md) |
| `components/sn_sparkline.tscn` | 框架源文件：sn_sparkline.tscn | 本页 |
| `components/sn_stage_host.gd` | 通用 3D 舞台宿主（SubViewportContainer）：持有独占 SubViewport/World3D，加载并挂载一个 `LocationStage`，驱动 enter→bind 生命周期、舞台显隐与渲染停更，并转发 `portal_requested` / `fallback_requested`；同时是船厂 `SNShipView` 的渲染器后端。 | [查看](./components/sn_stage_host.gd.md) |
| `components/sn_story_card.gd` | 新手剧情 / 教学系统的全屏剧情卡（阶段 4.5）。深色遮罩 + 居中剧情面板： | [查看](./components/sn_story_card.gd.md) |
| `components/sn_story_objective.gd` | 新手剧情 / 教学系统的非阻塞目标条（阶段 4.5）：顶部居中的小面板，显示 | [查看](./components/sn_story_objective.gd.md) |
| `components/sn_supply_card.gd` | 单种补给品的决策卡：存量、可补上限、价格、港存、预计续航和购买操作。 | [查看](./components/sn_supply_card.gd.md) |
| `components/sn_supply_card.tscn` | 框架源文件：sn_supply_card.tscn | 本页 |
| `components/sn_task_tracker.gd` | HUD 任务追踪条（阶段 4.6 Phase A）——显示 `task.view.active_task` 的类别、 | [查看](./components/sn_task_tracker.gd.md) |
| `components/sn_voyage_confirm.gd` | 海图内的出航确认弹窗（阶段 4.3.4 / U7）。以半透明遮罩 + 居中面板覆盖海图， | [查看](./components/sn_voyage_confirm.gd.md) |
| `screens/flow/at_sea_screen.gd` | 航行演出页（海图系统阶段 3）：整幅海图 + 底部航程条。船只 icon 沿 | [查看](./screens/flow/at_sea_screen.gd.md) |
| `screens/flow/at_sea_screen.tscn` | 框架源文件：at_sea_screen.tscn | 本页 |
| `screens/flow/clue_log_screen.gd` | 线索列表页（阶段 4.4.4）。只读展示 `clue.list` 查询的输出：全部 active 线索 | [查看](./screens/flow/clue_log_screen.gd.md) |
| `screens/flow/clue_log_screen.tscn` | 框架源文件：clue_log_screen.tscn | 本页 |
| `screens/flow/event_screen.gd` | 航行事件流程场景：展示事件说明、当前资源和本次抽取的处理选项。 | [查看](./screens/flow/event_screen.gd.md) |
| `screens/flow/event_screen.tscn` | 框架源文件：event_screen.tscn | 本页 |
| `screens/flow/port_memory_screen.gd` | 港口记忆流程场景：只读展示上次到港时的市场和设施快照。 | [查看](./screens/flow/port_memory_screen.gd.md) |
| `screens/flow/port_memory_screen.tscn` | 框架源文件：port_memory_screen.tscn | 本页 |
| `screens/flow/sea_chart_screen.gd` | 全屏航海图页（海图系统阶段 2 入口集成，4.3.4 / U7 重构出航流程）： | [查看](./screens/flow/sea_chart_screen.gd.md) |
| `screens/flow/sea_chart_screen.tscn` | 框架源文件：sea_chart_screen.tscn | 本页 |
| `screens/flow/settlement_screen.gd` | 抵达结算页。展示委托收入 / 准时 / 延误、船况资源、交付明细与旅客受伤， | [查看](./screens/flow/settlement_screen.gd.md) |
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
| `screens/port/auto_trade_screen.gd` | Phase D4 自动贸易页：渲染 `auto_trade.view` 与可用策略，展示阶段、航程、 | [查看](./screens/port/auto_trade_screen.gd.md) |
| `screens/port/auto_trade_screen.tscn` | 框架源文件：auto_trade_screen.tscn | 本页 |
| `screens/port/base_screen.gd` | Phase D3 基地页：渲染 `base.view` 与 shell 提供的可用基地点/建筑/升级/工种/ | [查看](./screens/port/base_screen.gd.md) |
| `screens/port/base_screen.tscn` | 框架源文件：base_screen.tscn | 本页 |
| `screens/port/contracts_screen.gd` | 委托页面场景：按可接/进行中分组渲染主线与普通委托卡，并发出接取或规划出航意图。 | [查看](./screens/port/contracts_screen.gd.md) |
| `screens/port/contracts_screen.tscn` | 框架源文件：contracts_screen.tscn | 本页 |
| `screens/port/market_screen.gd` | 港口市场页面场景：展示行情、真实价格历史、持仓成本及买卖操作；作为泊位侧栏时按 620 px 窄列设计（纵向商品条目列表，替代旧九列表格），外层 PageScroll 负责竖向滚动。 | [查看](./screens/port/market_screen.gd.md) |
| `screens/port/market_screen.tscn` | 框架源文件：market_screen.tscn | 本页 |
| `screens/port/overview_screen.gd` | 港口总览页面场景：组合港口横幅、主线目标、通关清单、船只摘要、快捷操作、财务与航行记录；三种呈现由 Shell 控制——裸 3D 舞台（页面只留 spacer）、详细总览抽屉（原 2D 面板覆盖舞台）与 2D 回退总览。阶段 4.3 / U6 起不再渲染旧线稿海图。 | [查看](./screens/port/overview_screen.gd.md) |
| `screens/port/overview_screen.tscn` | 框架源文件：overview_screen.tscn | 本页 |
| `screens/port/shipyard_screen.gd` | 船厂页两种布局共用一页：正常态为「已有船舶卡片 / 实机渲染舞台 / 组件分类入口」，改装态为「贴图纵剖图 / 所选分类的槽位与操作 / 竖排分类页签（含杂项）」。规则仍来自 `shipyard.view`，页面不写 `GameState`。 | [查看](./screens/port/shipyard_screen.gd.md) |
| `screens/port/shipyard_screen.tscn` | 框架源文件：shipyard_screen.tscn | 本页 |
| `screens/port/supply_screen.gd` | 补给与维修页面场景：绑定 SupplyView，组合煤水决策卡、资源摘要与维修操作；作为泊位侧栏时按 620 px 窄列设计（卡片单列堆叠、badge 可换行），外层 PageScroll 负责竖向滚动。 | [查看](./screens/port/supply_screen.gd.md) |
| `screens/port/supply_screen.tscn` | 框架源文件：supply_screen.tscn | 本页 |
| `screens/port/tavern_screen.gd` | 酒馆页（阶段 4.5.4，替换原情报站页面）——上半部分保留物价情报矩阵与 | [查看](./screens/port/tavern_screen.gd.md) |
| `screens/port/tavern_screen.tscn` | 框架源文件：tavern_screen.tscn | 本页 |
| `shell/main.gd` | 可玩 UI 组合根：解析上下文、查询 ViewModel、执行命令、处理导航/转场，并把已迁移页面挂载到场景宿主；主界面采用「全窗 3D 港口舞台 + 紧凑顶部 chrome + 两侧设施招牌 + 底部状态条 + 详细总览抽屉」的 Bounty Train 式分层，2D 总览保留为回退/可访问性开关。自第七切片起总览/市场/补给三页共用同一座连续 3D 港区：页面切换只是平移镜头、把玩家的船开到对应泊位并换上右侧泊位面板，不重挂舞台、不过黑场；市场/补给页改为右侧 640 px 泊位面板，左侧保留舞台。 | [查看](./shell/main.gd.md) |
| `shell/main.tscn` | 框架源文件：main.tscn | 本页 |
| `showcase/ui_kit_showcase.gd` | 独立 UI Kit 展示与视觉冒烟场景，集中实例化全部可复用控件和状态。 | [查看](./showcase/ui_kit_showcase.gd.md) |
| `showcase/ui_kit_showcase.tscn` | 框架源文件：ui_kit_showcase.tscn | 本页 |
| `stages/location_stage.gd` | 2.5D 固定机位舞台契约基类：舞台自持相机/灯光/环境/水面/道具与 idle 动画，由 `SNStageHost` 驱动 enter→bind→exit 生命周期；只读已解析 ViewModel，不访问 GameState / QueryBus / CommandBus。 | [查看](./stages/location_stage.gd.md) |
| `stages/port_stage.gd` | 固定 3/4 长焦港口舞台，也是一座连续港区：`_ready` 一次建静态层（L0 暖色 sky + 双层水面 + 160 m 桩基码头 + L1 兜底 painted backdrop + L6 前景框 + L7 3 组蒸汽粒子 + 相机），`bind()` 只重建 `_content` 下的数据层：L1 banner 背板、L2 双深度带剪影（仅无 banner 且无 town kit）、L2b 港口街坊 town kit（按 size/density 28/47/63 件）、站前道具（每站 5/8/11 件）、L3 设施、L5 玩家船、L7 雾带；随后把设施 + 街坊 + 站前道具 + 玩家船静态合批。市场 / 港务 / 补给是同一港区里从左到右的三个相邻站位，切换页面只平移镜头并把玩家船开到对应泊位（`focus_station()`），世界不重建。全程序化 + 内容模组 GLB，无外部框架贴图。 | [查看](./stages/port_stage.gd.md) |
| `stages/port_stage.tscn` | 港口舞台场景：挂 `PortStage` 脚本并显式设置 `stage_id="port"`。 | 本页 |
| `stages/ship_rig_assembly.gd` | rig_kit 运行时装配规则（契约 `rig-kit@1` / `rig-sockets@1` 的代码实现）：在船体 GLB 里按标准名找 `SN_Socket_Mast/Yard/Sail_*` 空节点，把套件 Root 的 `SN_Mount` 精确对齐到 socket，按内容名单隐藏被替换的烘焙节点，并给出可复现的节点快照。 | [查看](./stages/ship_rig_assembly.gd.md) |
| `stages/ship_visual_assembler.gd` | `ShipVisualAssembler` —— 运行时把一条船拼成可见的整船：实例化船体 GLB，按船体 Root `SN_Socket_Mast/Yard/Sail_*` 挂 rig_kit 套件（并隐藏被替换的烘焙节点），再按 `SN_Socket_Weapon_*` 挂武器；返回装配根、可读报告与确定性快照，供船厂 / 港口 / 航行演出共用。 | [查看](./stages/ship_visual_assembler.gd.md) |
| `stages/ship_weapon_assembly.gd` | 武器装配运行时（契约 `weapon-assembly@2` / `hull-sockets@1` 的代码实现）：从船体 GLB 找 `SN_Socket_Weapon_*`、从武器 GLB 读 Root extras、按 `weapon_class == socket_class` 硬门禁配对，把武器 `SN_Mount` 对齐到 socket、按 `mount_scale` 缩放，并交出可操控的 `ShipWeaponMount`。 | [查看](./stages/ship_weapon_assembly.gd.md) |
| `stages/ship_weapon_mount.gd` | 一件「已装到船体安装点上的武器」的运行时句柄：持有 socket / 武器实例 / `SN_Mount`，按标准节点名暴露瞄准（yaw/pitch）、后坐（-X 平移）、炮口位置与净空复核，供战斗层、舞台层和 demo 使用。 | [查看](./stages/ship_weapon_mount.gd.md) |
| `stages/shipyard_stage.gd` | 船厂 EXTERIOR 固定 3/4 机位船体舞台（首个切片的迁移目标）：自建环境/灯光/水面/相机，按 ViewModel 的 `hull_model_path`（旧 `hull_tier` 路径仅 dev 回退）挂载船体 GLB（切片 5 起 `ship.visual` 命中时改由 `ShipVisualAssembler` 装配船体 + rig_kit + 武器），并在 `_process` 做升沉/横摇。 | [查看](./stages/shipyard_stage.gd.md) |
| `stages/shipyard_stage.tscn` | 船厂舞台场景：挂 `ShipyardStage` 脚本并显式设置 `stage_id="shipyard"`。 | 本页 |
| `stages/stage_kit.gd` | 固定机位 2.5D 舞台的公共构建器：程序化天空/颜色环境、无阴影方向光、近/远水面材质、船体泡沫环、世界空间 AABB 与长焦取景。 | [查看](./stages/stage_kit.gd.md) |

## 模块契约

- UI 只识别 Query/Command 与定义类型，不识别 core 内容。
- 公共视觉状态优先进入 Theme variation；业务页面只负责布局与数据绑定。
- 页面场景不得直接持有 AppContext；查询、命令、跨页导航、全局提示与音效属于 Shell。
- 2.5D 舞台只做表现层：资产路径由 ViewModel 解析后传入，舞台不读 GameState/QueryBus/CommandBus；同一时间只渲染一个 3D 舞台，隐藏即停更。
