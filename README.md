# Steam Navigator（蒸汽航海）MVP — Framework + Core Mod

《蒸汽航海》是一款**蒸汽朋克**背景的航海贸易模拟游戏。本仓库是 MVP 的 Godot 4.x 原型：游戏本体只提供通用框架；官方内容（港口、商品、船体、锅炉、委托、事件等）通过 **`core` 内容模组**加载，走与第三方模组完全相同的发现、校验、注册和冻结流程。

- 设计文档：[MVP GDD v1.0](docs/specs/蒸汽航海_MVP_GDD_V1.0.md)
- 架构文档：[框架 + 模组 v1.0](docs/specs/蒸汽航海_项目架构方案_框架与模组_V1.0.md)
- 正式版方向：[持久模拟经营战役](docs/specs/PERSISTENT_CAMPAIGN_ARCHITECTURE.md)
- 正式版路线图：[从 MVP 到持久模拟经营](docs/design/FULL_GAME_ROADMAP.md)
- 实体契约 v2：[content_types 与 Schema 2.0 契约](docs/design/ENTITY_CONTRACT_V2.md)
- 武器内容 Schema 2.0 草案：[WEAPON_CONTENT_SCHEMA.md](docs/design/WEAPON_CONTENT_SCHEMA.md)
- Content Schema 2.0 迁移落地方案：[分层迁移与切片计划](docs/design/CONTENT_SCHEMA_V2_MIGRATION.md)
- 世界与战役运行时实现契约（Phase B）：[WORLD_SCHEMA_V2_RUNTIME.md](docs/design/WORLD_SCHEMA_V2_RUNTIME.md)
- 模块实例与部件损耗：[SHIP_MODULE_INSTANCES.md](docs/specs/SHIP_MODULE_INSTANCES.md)
- 战斗架构采纳边界：[战斗系统架构评审](docs/specs/COMBAT_ARCHITECTURE_REVIEW.md)
- 迭代 1 实现契约：[MVP 闭环](docs/specs/ITERATION_1_MVP_LOOP.md)
- 迭代 2 实现契约：[MVP 反馈优化](docs/specs/ITERATION_2_MVP_FEEDBACK.md)
- 设计文档生命周期（Active / Finalized / Archived）：[docs/README.md](docs/README.md) — 已定稿生效契约见 [docs/specs/](docs/specs/README.md)，历史归档见 [docs/archive/](docs/archive/README.md)
- 静态代码文档：[docs/static/README.md](docs/static/README.md)
- 探索系统（阶段 4）实现契约：[docs/design/EXPLORATION_SYSTEM.md](docs/design/EXPLORATION_SYSTEM.md)
- 新手剧情 / 教学系统（阶段 4.5）实现契约：[docs/design/STORY_TUTORIAL.md](docs/design/STORY_TUTORIAL.md)
- 剧情模式设计草案（只加剧情的模组数据包 + 固定地图 + 任务线 + `SNStoryMaker` 编辑器）：[docs/design/STORY_MODE.md](docs/design/STORY_MODE.md)
- 任务追踪与任务系统设计：[docs/design/TASK_QUEST_SYSTEM.md](docs/design/TASK_QUEST_SYSTEM.md)（Phase A `task.view` 已实现；Phase B 正式 Quest 待实现）
- 美术/音频资产映射：[docs/design/ASSET_MAP.md](docs/design/ASSET_MAP.md)
- 物品建模半工作流（派发给子代理）：[docs/design/MODELING_WORKFLOW.md](docs/design/MODELING_WORKFLOW.md)
- UI 原型与落地说明：[docs/design/UI_PROTOTYPE.md](docs/design/UI_PROTOTYPE.md)
- 船厂界面（图 2 / 图 3 布局重构）：[docs/specs/SHIPYARD_UI_REFACTOR.md](docs/specs/SHIPYARD_UI_REFACTOR.md)
- 2.5D 固定舞台升级方案（阶段 1 前七个切片已落地：船厂 3D + 通用舞台宿主 + 港口骨架 + 场景填充 + Bounty Train 式主界面 + 街景密度/合批/程序化远景 + 连续港区相邻站位）：[docs/design/2.5D_STAGE_PLAN.md](docs/design/2.5D_STAGE_PLAN.md)
- 高频决策页面重构指南：[docs/specs/HIGH_FREQUENCY_UI_REFACTOR_GUIDE.md](docs/specs/HIGH_FREQUENCY_UI_REFACTOR_GUIDE.md)
- 任务与路线图：[todo.md](todo.md)
- 变更日志（按版本的功能 / 变更）：[CHANGELOG.md](CHANGELOG.md)

## 当前状态

基础框架与首个可玩纵切片已跑通：

- 模组扫描（目录 / ZIP）、Manifest 校验、SemVer 依赖解析、冲突与循环检测、注册表冻结。
- JSON Schema 子集校验（含本地 `$ref`）、跨引用校验、Core 完整性检查、显式 Patch；新版实体 `information.texture/model` 会解析进注册表并校验资源类型。
- 命名随机流、确定性开局、市场 NPC 模拟、情报快照、借贷、声望、自动存档。
- 命令 / 查询总线（事务克隆提交、领域事件、只读 ViewModel）。
- 可玩的程序生成海图：点击已访问港口查看上次在港货价/储备、贸易、补给、维修、造船厂购买/打造/仓库/替换模块、委托接取、出航预览、风险事件、抵达结算与通关总结。
- 市场规则：任意港口都收购所有普通货物；只有本港商品表列出的品种可以直接买入。库存按加权平均成本记录并显示；玩家单笔交易只把价格推向新均衡的 35%，避免过度敏感。
- 煤炭与淡水作为补给商品进入港口市场，价格随港口库存和 NPC 商船流动浮动；在补给页按当前市场价买入。
- 5 段主线委托链（自动接第 1 段，后续以 offer 形式接取）、4 个普通委托模板。
- **迭代 1 · MVP 闭环**：船厂支持购买/打造/仓库/替换/卸下/随船运输模块；每港独立仓库，旧件入当前港仓库；普通委托池在每次抵达后整池刷新并按声誉限制持有上限；完成主线 05 后在造船厂组装「大型船体 + 锅炉 + ≥1 货舱」触发通关总结页（构筑、航次、准时率、事故、收入/支出/利润、债务、耐久）。
- 启动主菜单：开始游戏 / 加载游戏 / 模组 / 设置 / 退出游戏；右下角显示开发团队与版本。
- 设置持久化：编辑器内默认读 `config/config.json`、写入 `user://config/config.json`；发布包优先以 exe 同级的 `config/config.json` 作为可编辑配置，目录不可写时回退到 `user://config/config.json`。
- 最小 UI：开局构筑选择，以及总览、市场（含补给区块）、委托、船厂、酒馆五个独立界面 + 全屏海图页；共享蒸汽朋克 Theme、全屏主菜单背景、铁港横幅、两列委托卡、顶部导航、页面淡入淡出与抵达结算页。阶段 4.3 起出航准备页删除，出航确认移入海图弹窗；4.5.3 起补给页并入市场；4.5.4 起情报站页面由酒馆页替换。
- 交易反馈：买入/卖出、接取委托、购买补给成功后播放金币音效；右下角固定开发团队与版本。
- 高频决策页第一轮：补给卡（存量/可补上限/续航/补满花费）、委托固定五区卡片与可接/进行中分区、市场真实价格历史与迷你折线。
- 海图重设计：三次贝塞尔曲线航路、每港从邻居组中心计算的唯一出港方向、经纬网、洋流、罗盘、图内图例、当前港脉冲光晕与更宽的图表布局。
- **探索系统（海图阶段 4.1 / 4.2 / 4.3）**：`Clue` / `ClueService`（抵达传闻按概率生成、有情报站的港口花钱购买）、线索分级与海图可视化（level 2 参照港方向箭头 / level 3 虚线圆 / level 4 `？港名？`）与右侧线索面板（来源、等级、八方位、航程区间、预计煤水风险、可出航性）；`explore.start` 把航线画到搜索区、海图显示金色计划航线 + `?` 虚线预测线，抵达时 Shell 自动 `explore.settle`：发现 → 解锁港口 + 迷雾揭示 + 入港，失败 → 漂流到最近已知港（扣耐久 / 煤水 / 时间）；结算页新增探索结果区块。**4.2**：航程 50% 处遇「资源告急」停下，玩家选「继续探索 / 掉头返航」（跳过演出不能替玩家决策）；掉头立即结算半程返航并直接播入港，继续则走完自动结算；探索入港与普通抵达复用同一套到港服务（委托 / 市场记忆 / NPC / 债务 / 委托刷新 / 统计 / 自动存档）。**4.3 体验修正（8 条）**：雾半径改为「世界短边 × Core 比例」且双子世界尺寸内容化；线索获得固定 1 级、在港可逐级「调查」（1→2→3→4，消耗字段预留 0）；**探索失败不再消耗线索**（保留 active、记 `attempts`，可立即再次出航）；演出中船周连续照亮并在抵达 / 掉头时持久化沿途迷雾；普通航线只在选中港口时显示；删除详细总览旧海图；删除出航准备页，出航确认（预估 + 锅炉策略，默认上次）移入海图弹窗；资源在演出中按航行时间连续读数、出发只扣工资、抵达 / 漂流 / 掉头按实际小时一次性落账。领域字段/命令/数值契约见 [EXPLORATION_SYSTEM.md](docs/design/EXPLORATION_SYSTEM.md)，数值在 `map_profiles` 的 `exploration` 块。预览：[海图线索](docs/design/screenshots/exploration/exploration_chart_clues.png) / [逐级调查](docs/design/screenshots/exploration/exploration_chart_investigate.png) / [出航确认弹窗](docs/design/screenshots/exploration/exploration_depart_confirm.png) / [探索航行](docs/design/screenshots/exploration/exploration_chart_route.png) / [资源告急](docs/design/screenshots/exploration/exploration_resource_alert.png) / [掉头结算](docs/design/screenshots/exploration/exploration_turned_back.png) / [发现结算](docs/design/screenshots/exploration/exploration_result_found.png) / [失败结算（线索保留）](docs/design/screenshots/exploration/exploration_result_failed.png)。**4.4 线索扩展（4.4.1–4.4.5 全部实现）**：`Clue` 增加 `type` / `target_goods_id` / `goods_snapshot` / `expires_at` / `unlock_source`（旧存档惰性 normalize，不改 schema_version）；新增 `port_goods` 货物行情线索（已发现港口 + 货物，行情快照冻结、分级披露港口名 → 参考价区间 → 库存/供需 → 精确买卖价，按来源 24/48/72h 到期）；命令路径 `sweep_expired` 把过期线索移入 `data.clues.expired` 历史并释放线索上限；`sea_chart.view.clues` 与新增 `clue.list` 查询输出类型 / 剩余时效 / 可调查 / 可出航字段（仍不泄露 target_port_id / credibility / 真实 search_zone）；在港等待按档位复利抽线索、完成委托按概率解锁线索；货物线索面板显示行情与时效，「前往该港」走统一确认弹窗 → `clue.travel`（目标港在领域层解析）后进入普通航行演出；调查消耗落地（每次 20 金 + 在港 6 小时 + 75% 成功率，失败照扣成本但不升级、可再试）；海图顶栏新增「线索列表」独立页（active 线索卡片 + 过期折叠历史，点击回海图并选中）。预览：[货物行情线索](docs/design/screenshots/exploration/clue_goods_lead.png) / [前往行情港口确认](docs/design/screenshots/exploration/clue_goods_depart.png) / [调查成本](docs/design/screenshots/exploration/clue_investigate_cost.png) / [调查结果](docs/design/screenshots/exploration/clue_investigate_result.png) / [线索列表](docs/design/screenshots/exploration/clue_log.png)。数值在 Core `map_profiles.exploration`（含 Schema）。契约与分片见 [EXPLORATION_SYSTEM.md §11](docs/design/EXPLORATION_SYSTEM.md)。
- **迭代 2 · MVP 反馈优化**（试玩反馈）：tier1 部件改为「仅金币」打造（不消耗材料）；打造变成带工时的**订单**，并新增 `port.wait`「在港等待」让时间流动可感知；补给比例条改用稳定物理上限，上限被另一项占用时用右端反向损失带表示；情报页合并为「商品 × 港口」对比表（未探索港口保留整列并显示「未知港口」+「？」，趋势为红降/绿升数字）；顶部信息条常显当前港口与剩余载重/剩余货舱；总览常驻通关条件清单，主线完成后提示下一步（船厂页改为组件分类入口，不再重复清单）。
- **船厂界面（图 2 / 图 3 布局）**：正常态三列——左「已有船舶」贴图船卡、中心 3D 实机舞台、右「组件」六类入口；点击分类进入改装态，三列变为——左授权贴图纵剖图（`assets/ui/shipyard/ship_section.png`，每槽位一枚可拖放贴片，不再是运行时多边形拼接）、中间所选分类的槽位 / 装配 / 购买 / 打造操作卡、右竖排分类页签（船体 / 锅炉 / 货舱 / 导航 / 安全 / 客舱 / 杂项）。旧的整页下方面板（打造订单 / 港口仓库 / 配方 / 可购买模块 / 通关清单）全部删除，命令迁入分类与「杂项」页签，通关清单只在总览；改装态与分类由 Shell 记忆，切页或命令重建后保持；3D 资产缺失时回退程序化占位。预览：[正常态](docs/design/screenshots/stage3d/shipyard_normal.png) / [改装态](docs/design/screenshots/shipyard_refit.png) / [货舱分类](docs/design/screenshots/shipyard_refit_cargo.png) / [杂项](docs/design/screenshots/shipyard_refit_misc.png)；布局、删除面板与命令迁移表见 [SHIPYARD_UI_REFACTOR.md](docs/specs/SHIPYARD_UI_REFACTOR.md)。
- **船厂 3D 实机舞台（2.5D 首个切片）**：正常态中央由 [SNShipStage3D](framework/ui/components/sn_ship_stage_3d.gd) 渲染真实船体 GLB（按 `hull_tier` 选船）、固定 3/4 机位、海面与灯光；复用港口水面着色器（船体泡沫环跟随包围盒），改装态隐藏 3D 切回纵剖图。顶部导航、槽位、拖拽与所有 2D 页面不变；没有船体 GLB 时自动保留程序化占位。预览：[船厂 3D 舞台](docs/design/screenshots/stage3d/shipyard_normal.png)，方案见 [2.5D_STAGE_PLAN.md](docs/design/2.5D_STAGE_PLAN.md#L11)。
- **2.5D 舞台第二切片（通用宿主 + 港口骨架 + 场景填充）**：`SNShipStage3D` 重写为 [SNStageHost](framework/ui/components/sn_stage_host.gd) 适配器，宿主独占 SubViewport/World3D 并驱动 [LocationStage](framework/ui/stages/location_stage.gd) 的 `enter → bind → exit` 生命周期（隐藏即停更、缺失场景回退 2D、单舞台）；船厂环境/灯光/水面/机位/升沉迁入 [ShipyardStage](framework/ui/stages/shipyard_stage.gd)，公共构建器为 [StageKit](framework/ui/stages/stage_kit.gd)。新增 [PortStage](framework/ui/stages/port_stage.gd)：按 `port.facilities` 装配设施（有 `facility_visuals` GLB 则替换，否则程序化 billboard；缺席设施只放货堆 filler、不生成热点），L0 暖色程序化天空/L1 banner 背板（缺失不放黑盒：暖霞渐变 + 双太阳光晕的程序化 painted backdrop）/L2 双深度带确定性剪影（仅无 banner，小/中/大 7/10/13 栋 + 2/2/3 吊机，MultiMesh 批量）/L5 玩家船随波，另加 L6 左上角前景框与 L7 3 组蒸汽粒子 + 2–3 层雾带（全程序化、无新资产；目前仅铁港有 banner，其余港口走 painted backdrop）；码头为薄甲板桩基栈桥（入水木桩/桩帽/横梁），并按 `port.size` 0.9/1.0/1.15 缩放设施层；`facility_anchors()`/`facility_screen_anchor()` 供 2D 热点使用。**第五切片再接入 10 件港口街景 `SN_HT_*`（L2b town kit：5 建筑 + 围栏/工人/装饰/小船，town 存在时跳过 L2 剪影）。**独立预览场景 `dev_scenes/port_stage/` + 窗口截图脚本 `tools/godot/capture_port_stage.gd` 已跑通。预览：[完整港口](docs/design/screenshots/port_stage/port_stage_preview.png) / [稀疏港口](docs/design/screenshots/port_stage/port_stage_sparse.png)，方案见 [2.5D_STAGE_PLAN.md](docs/design/2.5D_STAGE_PLAN.md#L11)。
- **2.5D 舞台第三切片（总览页接入 + 2D 热点）**：总览页可在「俯瞰港口 / 返回总览」间切换：`PortStage` 作为全窗 3D 背景层挂在 `Background` 之上、UI 之下，顶部 HUD/导航不变；设施热点由 `facility_anchors()` → `facility_screen_anchor()` 相机投影生成（第五切片升级为两侧固定招牌）；舞台加载失败置本会话回退并提示 `ui.error.port_stage_unavailable`。
- **2.5D 第五切片（Bounty Train 式主界面 + 港口街景）**：总览默认进入全窗 3D 港口舞台；顶部压缩为 2 行 121 px 紧凑 chrome（header / 资源 / 导航信息全部保留），设施入口改为左右两列「招牌」按钮（按投影 x 分列、箭头指向场景，右侧底部常驻「海图」），底部 60 px 船舶/港口状态条（耐久/货舱/煤/水/受损/最新通告 + 详细总览/海图/等待 12h），「详细总览」抽屉默认关闭、打开时用原 2D 面板（含通关清单）覆盖舞台，2D 回退仍可用；港口街景 10 件 `SN_HT_*` 建筑/工人/小船经 `port.diorama.town`（16 项 `town_visuals`，旧存档按 archetype 回填）接入。预览：[主界面](docs/design/screenshots/overview_port_stage.png) / [详细总览](docs/design/screenshots/overview_detail.png)。
- **2.5D 第六切片（主界面美术收尾 + 街景密度 + 性能回收）**：HUD 资源 chip 接入可选内容图标（`icon.money/coal/water` 经 `AssetService.find_key()` 按裸键解析，缺资产自动回退纯文字）；设施招牌改为自绘木牌/铁框/黄铜铆钉 + 设施专属徽记 + 指向场景的箭头 + 悬停黄铜光晕（[sn_harbor_sign.gd](framework/ui/components/sn_harbor_sign.gd)）；工程使用 `canvas_items + expand`，960×540 窗口映射为缩放后的 1600×900 逻辑画布，两行 HUD 与 172×42 招牌完整保留、不裁切；港口街景 normal 密度 29→47 件（市场摊/吊车/货堆/托盘/跳板/系缆桩/绞盘/浮标等，按 `port.size` 与 `port.diorama.density` 确定性增减，sparse 28 / busy 63）；设施与街景、玩家船体全部静态合并（按材质/共享盒体批处理，透明/Shader/骨骼动画自动回退），实测 **preview 63 / sparse 56 draw calls**（原 284 / 255；37k tris ≤60k；铁港建筑套件升级后为 preview **71** / sparse **64**，见下方批次 A），无 banner 港口新增 3 层程序化远景（山脊/远城塔楼/屋脊烟囱，1 个 MultiMesh）。预览：[主界面 1440](docs/design/screenshots/overview_port_stage.png) / [主界面 960×540](docs/design/screenshots/overview_port_stage_960.png) / [详细总览](docs/design/screenshots/overview_detail.png) / [完整港口](docs/design/screenshots/port_stage/port_stage_preview.png) / [无 banner 稀疏港口](docs/design/screenshots/port_stage/port_stage_sparse.png)，细节见 [2.5D_STAGE_PLAN.md](docs/design/2.5D_STAGE_PLAN.md#L11)。
- **模块实例与部件损耗**：每个已装模块有稳定实例 id 与 0–1 状态；`damage_module` 效果可损坏指定槽位（锅炉过热事件已接入），港口维修按「船体缺失 + 部件损耗」点数计价并恢复全部实例。界面可见：顶部信息条「部件 1 · 50%」chip、船卡「受损部件」行、船厂槽位卡「状态 NN%」徽标、补给页「含部件损耗」报价；旧存档缺实例表按满状态补齐。预览：[受损船卡](docs/design/screenshots/module_condition/shipyard_normal_damaged.png) / [状态徽标](docs/design/screenshots/module_condition/shipyard_refit_damaged.png) / [维修报价](docs/design/screenshots/module_condition/supply_damaged.png)，说明见 [SHIP_MODULE_INSTANCES.md](docs/specs/SHIP_MODULE_INSTANCES.md)。
- **2.5D 第七切片（连续港区 + 港务/市场/补给相邻站位）**：港口不再按页换场景，而是一座连续港区——160 m 桩基码头从左到右排着市场、港务、补给三个相邻站位（`STATIONS` 的 center/camera/target/ship 明确站位构图与泊位），站前道具各 5/8/11 件；切换市场/补给页时同一个 `PortStage` 实例不重建，镜头在 0.6 s 内沿码头平移、玩家船先转艏再以 24 m/s 沿岸航到新泊位，镜头的朝向层（天空/远景/招牌/雾）随平移保持构图，L2 剪影保留一半视差；市场/补给页改为右侧 640 px 泊位面板，左侧继续露出 3D 街景，页面切换不播放黑场淡出。位置见 [port_stage.gd](framework/ui/stages/port_stage.gd)（`focus_station()` / `advance_station()` / `STATION_PROPS`）与 [main.gd](framework/ui/shell/main.gd)（`STAGE_SCREENS` / `_focus_stage_station()` / `_mount_dock_panel()`）。预览：[市场站位](docs/design/screenshots/market_station.png) / [补给站位](docs/design/screenshots/supply_station.png) / [市场站位 960×540](docs/design/screenshots/market_station_960.png)，细节见 [2.5D_STAGE_PLAN.md](docs/design/2.5D_STAGE_PLAN.md#L11)。
- **海图系统阶段 2 收尾（入口集成 + 绕行自适应 + 真实对局接入）**：全屏航海图页 [sea_chart_screen.tscn](framework/ui/screens/flow/sea_chart_screen.tscn) 接入 Shell——顶部导航「海图」按钮、`M` 键开关（`Esc` 返回来源页 / 关闭弹窗）、总览底部状态条「海图 ▶」与港口右下固定「海图」招牌；打开时预选当前港，图上点击港口/线索联动右侧面板，面板「启航 / 循线索出航」打开统一确认弹窗（预估 + 锅炉策略切换，默认上次选择），确认后才发 `voyage.start` / `explore.start`（阶段 4.3.4 起出航准备页删除）。[RunFactory](framework/domain/contracts/run_factory.gd) 在开局时生成与对局地图同 `port_0..N` ID 的**坐标空间孪生世界**（每港一岛、共享原型/名称）写入 `state.data["world_map"]`，海图在真实对局直接出图：起港发现/访问/当前 + 迷雾灯塔揭示（`_initialize_world_fog`），抵达时 [VoyageService](framework/domain/voyage/voyage_service.gd) 经 `WorldOps.mark_visited` + `FogOps.reveal_arrival` 同步访问与泊位揭示；旧存档无 `world_map` 时全部 no-op、海图显示无数据提示。[RouteCalculator](framework/domain/world/route_calculator.gd) 绕行外扩档位按岛屿尺寸自适应（半长轴 ×1/2/3，上限仍为 14 单位档），小礁石不再把航线拽出 42 单位。
- **海图系统阶段 3 · 航行演出（3D 离港/入港 + 云层转场 + 海图航行）**：[VoyagePresentation](framework/domain/voyage/voyage_presentation.gd) 是纯状态机（11 相位 / 5 里程碑，逐帧 `tick()`），`voyage.start` 仍一次性结算航行，演出层只决定"什么时候把哪个画面推给玩家"，因此旧存档、`at_sea` 语义与 9 seed 通关回归全部不受影响。演出顺序：**3D 离港（船先原地转艏朝出海方向再驶离泊位、镜头俯角爬到 83° 并拉升到 165 m）** → 云层盖住高位镜头 → 海图航行（海图由近景 ×2.8 随云散拉远到铺满整窗的稳态取景）→ 事件（云层落下、决策后回海图）→ 云层盖住海图（取景反向推近）→ **3D 入港（目的港从海上高位出现，镜头下降、船驶入泊位并转回驻泊朝向）** → 抵达结算。[PortStage](framework/ui/stages/port_stage.gd) 的 `begin_departure()` / `begin_arrival()` / `advance_voyage()` 承载 3D 两个 beat（与状态机共用 beat 长度，有测试守护）；[SNCloudVeil](framework/ui/components/sn_cloud_veil.gd) 做「盖住 → 换页 → 散开」；[AtSeaScreen](framework/ui/screens/flow/at_sea_screen.gd) 是海图航行页：**全窗**海图（挂在 `FullscreenLayer`，cover 取景铺满、航线包围盒保底）+ 船只 icon 按**弧长**沿 **`WorldMap.edges` 的真实航线**行进（Shell 的 `_presentation_route_path()` 提供，不受迷雾过滤影响；`SNSeaChartView.set_ship_pose()` 逐帧覆盖位置 + 航线切线艏向，船形 icon 始终朝移动方向，不重绑 ViewModel）+ 底部航程条（起终港 / 进度 / `航程 X 小时 / Y 小时` / 时间倍率 / 跳过演出）。**接缝不变量**：3D 船停在海门 `SEA_HANDOFF` 的那一刻，海图船标记从 `handoff_progress`（默认 0 = 出发港图标）开始，两边是同一个地理位置，`test_chart_ship_starts_where_the_stage_ship_vanished` 锁死。航程压缩到 2–9 s，事件落在 50% 处停下等玩家决策（跳过演出不会替玩家做决定）。演出期间隐藏导航、顶栏显示「在航 → 目的港」。预览：[离港转艏](docs/design/screenshots/voyage_presentation/voyage_departure_turn.png) / [3D 离港](docs/design/screenshots/voyage_presentation/voyage_departure_3d.png) / [高位镜头](docs/design/screenshots/voyage_presentation/voyage_departure_high.png) / [出航云层](docs/design/screenshots/voyage_presentation/voyage_departure_clouds.png) / [海图近景](docs/design/screenshots/voyage_presentation/voyage_chart_near.png) / [海图稳态](docs/design/screenshots/voyage_presentation/voyage_chart_steady.png) / [海图航行](docs/design/screenshots/voyage_presentation/voyage_at_sea.png) / [3D 入港](docs/design/screenshots/voyage_presentation/voyage_arrival_3d.png) / [抵达结算](docs/design/screenshots/voyage_presentation/voyage_arrival.png)，细节与阶段 3 验收反馈 F1–F4 修复记录见 [NAUTICAL_CHART_SYSTEM.md §8/§15](docs/design/NAUTICAL_CHART_SYSTEM.md)。
- **新手剧情 / 教学系统（阶段 4.5 已实现，4.5.1–4.5.6）**：新开局默认进入剧情（Shell 的「开始新航行」显式传 `tutorial=true`，领域 `run.start` 本身保持默认 false，测试 / 旧入口不弹；教程新航程页隐藏构筑选择并使用默认教学船）。`data.story` 惰性 ensure（不改 `schema_version`，旧存档视为已看完、功能全开）；新增查询 `story.view` 与命令 `story.advance` / `story.skip` / `story.observe`（经 FrameworkApi 注册），Shell 把成功命令与 UI 事件转成 `cmd:*` / `ui:*` 观测，按 Core JSON 的阶段事件 / 计数 / 阈值推进；剧情文本 / 步骤 / 解锁全部来自 Core `map_profiles.data.story`（Schema 同步），框架只认 feature 键（overview / supply / chart / market / contracts / clues / tavern / shipyard）。UI：全屏剧情卡（标题 + 多段正文 + 继续 / 跳过教程 + 跳过确认）、非阻塞目标条、导航 / 港口招牌 / `M` / 状态条海图入口按解锁过滤；跳过教程会解锁全部功能并揭示主委托目的港，保证不卡死。**4.5.2 开局幕**：获船叙事 → 补给 4 煤 2 水 → 补给受限（`lock_actions: supply.buy`，卡片显示原因）→ 海图解禁 → 关闭海图恢复补给 → 买够 10 煤 → 海图出航（默认极速）→ 抵达第二港；第一主线由 Core story `grant_tutorial_contract` 以 `main_01` 模板生成「燃料舱交付 10 煤」实例（`provider: fuel`，出航前校验、完成扣煤舱），`set_ship_fuel` 把开场煤舱压到 4，`tutorial_express` 限时保证标准迟到 / 极速准时。**4.5.3 并市 + 第二主线**：补给页删除，煤 / 水并入市场页「补给（煤 / 水）」区块（复用 `supply.buy_*`，旧 `supply` 入口 / 存档重定向市场）；市场贸易货物按 story `unlocked_items` 过滤（Act 0 为 0 条，第二港开放纺织品 / 香料）；第二主线用 `grant_tutorial_contract`（main_02 模板、`provider: player`、`destination: home`）交付 6 件纺织品，剧情目标买 8 件、回港卖剩余 2 件，新增事件 `match` 条件。**4.5.4 酒馆 / 线索 / 保底探索**：情报站页面被酒馆页替换（设施 / feature `intel`→`tavern`，旧存档的 `intel` 设施与页面归一兼容）；酒馆同时提供物价情报矩阵与港口线索列表（购买 / 调查），页面由 `tavern.view` 合并 `IntelViewQuery` + `ClueListViewQuery.clue_rows`。酒馆开业自动给第一条 L1 线索（离当前港最近的未发现港，记入 `story_target_port_id`），并用 Core `set_market_price_bias` 把纺织品 / 香料在起始港与其它港的价格拉开（库存归位、打开双向交易，保证教学来回可盈利）；刷新物价情报后解锁第三种货（木材）；跑一个来回后自动给同目标港的 L3 第二条线索并设置 `guaranteed_explore_clue_id`，`explore.settle` 对该线索无视 `outcome_roll` 直接成功（成功即消费 flag，跳过教程不会设置），发现第三港后进入 `third_port` 占位阶段并解锁船厂，旅客主线留给 4.5.5。**4.5.5 船厂 / 客舱 / 旅客**：新增 1 人小型客舱 `core:cabin/small_cabin`（120 金 / 8 重量 / `passenger_capacity = 1`）；第三港由 Core story 补上 `shipyard` 设施并用 `upgrade_hull` 换成带客舱位的中型船体（旧船进当前港仓库），`unlock_modules` 让 `shipyard.view` 在剧情期间只露出该客舱（购买 / 打造 / 仓库安装候选都过滤，当前已装模块仍可卸下）；`refit_unload` 卸货舱（match `cargo_modules`）→ `refit_cabin` 装小型客舱 → 自动接第三主线旅客（沿用 `main_03` 段，清空货箱改为 1 名旅客，完成时主线链推进 `main_04`）→ `story_complete` 解锁全部功能并交还沙盒。`ContractOps.attach` 不再用空货箱校验货舱容量，客运委托可正常接取。预览：[开局剧情卡](docs/design/screenshots/story/tutorial_card.png) / [非阻塞目标条](docs/design/screenshots/story/tutorial_objective.png) / [补给受限](docs/design/screenshots/story/tutorial_supply_hold.png) / [补给还差 2](docs/design/screenshots/story/tutorial_supply_remaining.png) / [首航默认极速](docs/design/screenshots/story/tutorial_depart_fast.png) / [市场补给区块](docs/design/screenshots/story/tutorial_market_supply.png) / [第二港市场](docs/design/screenshots/story/tutorial_market_goods.png) / [酒馆物价情报](docs/design/screenshots/story/tutorial_tavern.png) / [酒馆港口线索](docs/design/screenshots/story/tutorial_tavern_clues.png) / [第三种货市场](docs/design/screenshots/story/tutorial_market_third_good.png) / [L1 + L3 线索列表](docs/design/screenshots/story/tutorial_clue_list.png) / [第三港船厂客舱](docs/design/screenshots/story/tutorial_shipyard_cabin.png) / [卸货舱装客舱](docs/design/screenshots/story/tutorial_shipyard_refit.png) / [第三主线旅客](docs/design/screenshots/story/tutorial_passenger_contract.png)。契约与分片见 [STORY_TUTORIAL.md](docs/design/STORY_TUTORIAL.md)。

- 无头测试套件：**497 个测试全部通过**（含 ZIP 打包加载、30 个种子的地图硬约束、保存哈希一致性、save schema 1.x→2.0 迁移、Content Schema 2.0 草案校验、CampaignState 分区、模块实例与部件损耗、显式 Patch 冲突、港口记忆、补给与库存成本、仓库存取/打造订单/在港等待/替换、委托刷新、通报文案本地化、密集界面横向排版、通关判定、船厂界面（三列布局、纵剖图贴图契约、槽位与分类记忆、2.5D 渲染器替换钩子、拖拽安装、旧面板移除、状态徽标）、2.5D 舞台基础设施（LocationStage / SNStageHost 生命周期与回退 / ShipyardStage / PortStage 装配、替换、缩放与 portal）、PortStage 场景填充访问器、港口街景 town kit（满配 47 / 无 town 5+5 / 非法路径回退 / port.view 26 项端到端 / 密度随 size 与 `diorama.density` 缩放）、连续港区三站位（相邻顺序 / 聚焦后镜头与船泊位 / 立即聚焦与幂等 / 过渡中重定向 / 重绑保持站位 / 站前道具密度）、静态层与玩家船刚性合批（含动画/骨骼/透明安全回退）、无 banner 程序化远景层、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 960×540 + 底部状态条 + 详细总览抽屉与 2D 回退、市场/补给泊位面板与共用舞台接线、主界面接线冒烟、内容类型单一真源与 v2 模块分类守护、建筑 GLB 外部共享贴图（5 栋跨建筑同一 Texture2D 实例 / 旧格式回退 / 缺失失败缓存 / ZIP 挂载共享）、海图入口集成（chrome/M/出航页入口、真实对局数据绑定与启航路由）、真实对局孪生世界（run.start 生成同 ID 坐标世界 / 起港发现访问出雾 / 首航同步目的港）、航线绕行尺寸自适应（小岛收档/大陆保档/绕行不穿陆）、航行演出（状态机 15 例 / Shell 集成 8 例：出航云层→海图、船只推进、抵达结算、跳过、事件中断后恢复）、海图演出验收反馈 F1–F4（先转艏后航行与接缝艏向 / handoff hold / 镜头高度与俯角单调 / 海图 cover 铺满 + 航线保底 + 小世界 ×9 不受手动缩放上限 / 入港推近接线 / 船沿世界航线 141 点、任意进度离线 < 1 单位 / 船形 icon 按切线朝向）、探索系统 4.1/4.2/4.3/4.4（线索等级/来源/可信度与目标筛选、查询裁剪不泄露目标港、购买线索门禁、`explore.start` 只扣工资与状态形状、`settle` 成功解锁+迷雾+线索 resolved、失败漂流+耐久煤水扣减+**线索保留与可再次出航**、`turn_back` 线索保留、存档 round-trip；UI 线索几何/命中/未知终点/面板/整页接线、真实领域成功与失败两条 E2E、`clue.buy` 入口；4.2 资源告急继续/掉头两条 E2E、force_arrival、到港服务复用与自动存档；4.3 雾半径/世界尺寸内容化、失败重试、逐级调查与查询裁剪、航线仅在选中港口显示、详细总览无旧海图、统一出航确认弹窗与两处入口、演出随船照亮与沿途迷雾落账、连续消耗读数与按小时结算/事件延误计费；4.4 货物行情线索冻结/分级裁剪/时效 sweep、`clue.list`、等待与委托来源、`clue.travel`、调查 20 金 / 6h / 75% 与失败重试、线索列表页与回海图选中；4.5.1 新手剧情框架：教程局初始化 / 功能门禁 / 剧情卡继续与跳过 / 主委托目的港揭示 / 旧存档全开 / 存档往返；4.5.2 开局幕：补给限购拦截与卡片提示、海图打开 / 关闭推进、燃料舱运煤教学委托与出航前货物校验、标准迟到 / 极速准时、教程新航程页隐藏构筑；4.5.3 并市与第二主线：补给区块进市场、导航 / 招牌删除与旧入口重定向、市场商品按 unlocked_items 过滤（Act 0 0 条 / 第二港 2 条）、main_02 玩家自备纺织品回运与匹配事件条件；4.5.4 酒馆与线索：tavern 替换 intel 设施 / 页面与旧存档兼容、酒馆自动 L1 线索、两港价差与双向交易、第三种货、第二条 L3 线索、保底探索成功与 flag 消费、跳过不设保底；4.5.5 船厂与旅客：小型客舱内容、船厂按 unlocked_modules 过滤、第三港补船厂 / 换船体、卸货舱 / 装客舱、main_03 旅客委托与教学完成；4.6A 任务追踪：task.view 聚合（剧情 / 待接主线 / 已接委托）、委托步骤推导、HUD 任务条与委托页任务面板；剧情模式 S1：`story_arcs` / `story_levels` Schema 2.0 草案校验、故事包白名单、篇章 / 关卡语义、固定地图连通性与示例剧情包；Content Schema 2.0 Phase B：`CampaignFactory` 世界装配、`start_profile` / `campaign.view`、跨引用与 Core 完整性、`content_versions` 存档迁移；资产侧：船侧武器 socket 14 个空节点 / rig_kit 12 件套件 + 22 个帆索 socket / 旧资产 UV 迁移 B 55,256 tri 几何不变；LOD1 基础套件 / casemate 炮门 / weapons Schema 2.0 草案；船体运行时装配（ShipVisualPlan 内容驱动 rig_kit 1:1 替换与烘焙节点隐藏、武器 class 门禁、缺 socket 与缺套件回退、确定性快照、船厂与港口舞台接线与合批）），以及 9 个 seed 的完整通关回归）。
- **任务追踪聚合（阶段 4.6 Phase A）**：新增只读查询 `task.view`，把剧情当前目标、待接主线、已接主线 / 普通委托聚合成统一 Task，并把委托拆成「接取 / 备货 / 接客 / 前往 / 抵达交付」步骤（燃料委托按煤舱、玩家自备货物按船上数量、普通委托货箱接取即装船）。剧情目标仍优先显示；剧情结束后 HUD 自动切到主线 / 委托任务条，委托页顶部新增完整「任务追踪」面板（完成打勾、当前高亮、剩余时限）。任务不复制状态，全部由 `story.view` / `contracts` 派生。预览：[HUD 任务追踪](docs/design/screenshots/task/task_tracker_hud.png) / [委托页任务面板](docs/design/screenshots/task/task_tracker_contracts.png)。设计：[TASK_QUEST_SYSTEM.md](docs/design/TASK_QUEST_SYSTEM.md)。
- **旧资产 UV 迁移 B（船模块 / 4 艘船 / 旧小镇，2026-10-22）**：船模块 12 GLB（含 `modules/SN_Boiler_Unit` 占位副本）+ 4 艘可玩船 + 旧小镇剩余 5 件道具补 UV（单 mesh 用局部空间、多节点船体用根节点局部空间）、切 10 个 `SN_Tex_*` 共享贴图材质并重导 GLB。**几何逐位不变：55 256 tri（modules 7 492 / ships 45 968 / town 1 796）、118 网格与迁移前逐件一致**；21/21 GLB 自检、Godot 运行时 21 件 / 24 个共享 `Texture2D` 实例 / 0 失败；旧小镇 5 栋建筑此前已由建筑套件升级为 `SN_Town_*`，`SN_Ship_Prototype` 遗留键除外。验收见 [LEGACY_UV_MIGRATION_B_ACCEPTANCE.md](docs/archive/LEGACY_UV_MIGRATION_B_ACCEPTANCE.md)。
- **船侧武器安装点 M0-3（4 艘可玩船，2026-10-22）**：`SN_Paddle_Freighter` / `SN_Paddle_Steamer` / `SN_Schooner_Fame` / `SN_Ironclad` 各就地补 2–4 个 `SN_Socket_Weapon*` 空节点（合计 **14 个**，class 混编 Side / Light / Medium / Heavy），**零几何改动**（45,968 tri / mesh 数不变）；BLEND 内带资产前缀、GLB 导出后归一化为标准名，节点 extras 写 `socket_class / clearance_r / clearance_x / clearance_y / clearance_h / mount_scale / socket_index`，Root 写 `weapon_sockets` 列表；GLB 4/4 自检 + 批次 B 21 files 0 failures + Godot 资产/socket 测试 11/11。契约 [WEAPON_SOCKET_CONTRACT.md](docs/design/WEAPON_SOCKET_CONTRACT.md)，验收 [SHIP_WEAPON_SOCKETS_ACCEPTANCE.md](docs/archive/SHIP_WEAPON_SOCKETS_ACCEPTANCE.md)。
- **穿壳炮 casemate gun 模块化（2026-10-22）**：铁甲舰舷侧 12 门炮拆成独立模块 `SN_Weapon_CasemateGun`（**108 tri / 7 节点 / 3 材质**，根 = 炮门平面中心、`port_pitch` 装配、炮管与炮口箍可见、炮尾/双耳轴藏进门内 0.95 m），船体侧新增 **12 个 `SN_Socket_GunPort_*`**（`hull-gunports@1`，原点 = 炮门平面中心、`+X` = 炮膛轴线；门内实测纵深 4.245–8.000 m、舷外 8.0 m）并把 `SN_Ironclad.glb` 重导为**空炮门版**（8 830 → **8 158 tri**、26 节点；炮门框 / 深色炮口板 / 上翻门盖保留）。模块装到 12 个炮门与拆炮前的烘焙炮管**逐顶点重合（误差 0）**，删炮管后网格健康全 0、原有 4 武器 + 9 帆索 socket 与共享贴图 / UV 全部不变。工具 `sn_casemate_gun_generator.py` / `dryrun_casemate_gun.py` / `sn_ship_gun_ports.py` / `glb_gun_ports.py` / `apply_casemate_assets.py` / `export_casemate_glb.py` / `verify_casemate_glb.py` / `render_casemate_preview.py`，契约 [WEAPON_SOCKET_CONTRACT.md §9](docs/design/WEAPON_SOCKET_CONTRACT.md)，验收 [CASEMATE_GUN_ACCEPTANCE.md](docs/archive/CASEMATE_GUN_ACCEPTANCE.md)。运行时装配器已接入甲板武器 socket（ShipVisualAssembler，见 [SHIP_VISUAL_ASSEMBLY.md](docs/design/SHIP_VISUAL_ASSEMBLY.md)）；炮门 gun-port socket 的运行时装配尚未接入；其它 3 艘船需「炮门舱段」才能挂穿壳炮。
- **船体帆索部件库 M0-4 `rig_kit`（12 件套件 + 3 艘船参数化，2026-10-22）**：新增 `tools/modeling/generators/rig_kit.py`（桅杆 / 横桁 / 斜桁 / 帆杠 / 艏斜桁 / 帆面 / 索具的参数化部件库）与 **12 件独立 `SN_Rig_*` GLB**（**3,774 tri / 7,050 预算**，`assets/models/rig/` + Core 副本 + 共享贴图）；`SN_Paddle_Freighter` / `SN_Schooner_Fame` / `SN_Ironclad` 的帆索改由同一份部件库生成，**逐对象顶点/面 digest 与重构前完全一致**（12,200 / 8,830 tri、mesh 数不变；SF 纯帆索基线 28 对象 / 12,994 tri，整船场景含既有 `SN_SF_Nameplate` 为 29 / 13,174）；3 艘船新增 **22 个** `SN_Socket_Mast/Yard/Sail_*` 空节点（PF 6 / SF 7 / IC 9，零几何），GLB 节点 PF 50→56 / SF 35→42 / IC 5→14，Root 写 `rig_sockets` 列表；GLB 12/12 + 船舶 4/4 + 批次 B 21 files 0 failures。契约 [RIG_KIT_CONTRACT.md](docs/design/RIG_KIT_CONTRACT.md)，机器目录 [rig_kit_catalog.json](tools/modeling/rig_kit_catalog.json)，验收 [RIG_KIT_ACCEPTANCE.md](docs/archive/RIG_KIT_ACCEPTANCE.md)。
- **舰载武器内容 Schema 2.0 草案 + 船体安装点镜像（2026-10-22）**：新增 `schemas/v2/weapon.schema.json`（战斗 10 项对齐 SNBattleSim、装配对齐 `weapon-assembly@2`、经济对齐 `module_common`，15 项必填），`content_types.json` 把 `weapons` 登记为 draft type（capability `content.combat.v1`，仍在 `planned`）；`hull.schema.json` 的 hull_data 新增可选 `weapon_sockets` / `rig_sockets` 镜像，Core 回填 4 艘船 **14 个武器 socket + 22 个帆索 socket**；Core manifest 新增 **12 个 `model.weapon.*`（8 件完整武器 + 4 件 kit 部件）、12 个 `model.rig.*`、4 个 `model.ship_part.*`** 资产键（运行时由 ShipVisualAssembler 引用，供编辑器选择与装配层共用）；SNModMaker 可新建 / 编辑 / 校验 / 导出 weapons（`schema_version: "2.0"`），船体表单可编辑安装点，修复 story `flow_id` 假阳性后 Core 导入 0 error。契约 [WEAPON_CONTENT_SCHEMA.md](docs/design/WEAPON_CONTENT_SCHEMA.md)。
- **船体运行时装配 `ShipVisualAssembler`（2026-10-22）**：新增 `framework/services/ship_visual_plan.gd`（把 hull 定义 / `hulls.json.data.rig_plan` / `weapon_loadout` 解析成物理路径，资源键全部走 Core manifest 的 `model.ship.*` / `model.rig.*` / `model.weapon.*`）、`framework/ui/stages/ship_visual_assembler.gd`、`ship_rig_assembly.gd`，并从 `weapon-assembly-demo` 分支移植武器运行时层（`ship_weapon_assembly.gd` / `ship_weapon_mount.gd`，14 例回归）。装配顺序：实例化船体 GLB → 按船体 Root `SN_Socket_Mast/Yard/Sail_*` 把 `SN_Rig_*` 套件的 `SN_Mount` 对齐 socket → 按内容 `hide_nodes` 隐藏被替换的烘焙节点 → 按 `SN_Socket_Weapon_*` 挂武器（class 硬门禁）。Core 只对实测 1:1 吻合的船体做帆索替换（纵帆船 2 桅、明轮货轮 2 桅 + 2 桁；客船 / 铁甲舰保留烘焙帆索），rig 失败整体回退原船、武器逐件跳过，旧存档无 `visual` 字段时仍走原 `hull_model_path`/`hull_tier` 回退链。接入船厂 3D 舞台、港口舞台（含静态合批）与航行演出（离港 / 入港共用同一入口）。预览：[船厂 · 纵帆船](docs/design/screenshots/ship_assembly/shipyard_schooner.png) / [船厂 · 明轮货轮](docs/design/screenshots/ship_assembly/shipyard_freighter.png) / [港口停泊](docs/design/screenshots/ship_assembly/port_moored.png) / [航行离港](docs/design/screenshots/ship_assembly/voyage_departure.png) / [航行入港](docs/design/screenshots/ship_assembly/voyage_arrival.png)，设计与回退矩阵见 [SHIP_VISUAL_ASSEMBLY.md](docs/design/SHIP_VISUAL_ASSEMBLY.md)。
- **2.5D 城镇建筑升级 · 批次 A（5 栋 LOD1 + 共享贴图 + 檐口修复）**：5 栋铁港建筑（长仓库 / 短仓库 / 港务办公楼 / 货棚 / 酒馆）交付 LOD1：**6 564 tri**（LOD0 的 21.85%，逐栋 ≤35%），LOD1↔LOD0 包围盒逐轴 0.000 m、轴心落地、网格健康全 0；`Warehouse_Short` LOD0 檐口顶皮与墙线 **−3.543 cm → 0.000 cm**（仅 8 个屋面顶点）。10 个建筑 GLB 改为「GLB + 外部共享贴图」：11 张 `iron_harbor_shared` PNG 与手写 trim tile 逐字节一致，`ContentAssetLoader` 按 URI 共享 `Texture2D`，PortStage 舞台分析面 **91→73**、draw calls preview **89→71**（≤75 目标）、静态批次 59→41；5 栋模型+纹理 **4.17 MB**（≤4.5 MB），松散 / `.snavmod.zip` / 发布包三路径实测。LOD1 仅交付资产（未接运行时切换，`model.prop.*_lod1` 已登记）。验收见 [IRON_HARBOR_ARCHITECTURE_BATCH_A.md](docs/archive/IRON_HARBOR_ARCHITECTURE_BATCH_A.md)，分项见 [LOD1 构建](docs/archive/IRON_HARBOR_ARCHITECTURE_LOD1_BUILD.md) / [独立验收](docs/archive/IRON_HARBOR_ARCHITECTURE_LOD1_VERIFY.md) / [共享贴图](docs/archive/IRON_HARBOR_ARCHITECTURE_SHARED_TEXTURES.md)。截图：[LOD1 全栋对比](docs/design/screenshots/iron_harbor_architecture/SN_HT_Warehouse_Long_LOD1_vs_LOD0_street_3q_1280x800.png) / [PortStage LOD0 1440×900](docs/design/screenshots/iron_harbor_architecture/SN_HT_Warehouse_Long_LOD0_port_stage_1440x900.png) / [LOD1 960×540](docs/design/screenshots/iron_harbor_architecture/SN_HT_Warehouse_Long_LOD1_port_stage_960x540.png)。
- **LOD1 基础套件 M0-5（kit 26 + 4 艘可玩船 + 铁港建筑收口，2026-10-22）**：kit 26 件 + 4 艘可玩船各补远景低模 **30 件**（LOD1 由 LOD0 就地派生：`Decimate(collapse)` + ≤20 tri 小件保留 + 单 mesh 合并 + 包围盒逐轴钉死 + 盒式 UV 重投影），**19 850 / 88 026 tri = 22.6 %**（kit 10 824 / 42 058 = 25.7 % ≤35 %、船 9 026 / 45 968 = 19.6 % ≤30 %；铁甲舰 LOD0 同日 casemate 批次 −672 tri，船组合计现为 45 296 / 87 354，LOD1 资产未变）；LOD0↔LOD1 世界包围盒逐轴 **0.000 m**，30/30 单根节点 / 单 mesh / 每个图元带 UV / 外部共享贴图（175 个 image 引用 → 11 张 PNG，与授权 tile 逐字节一致，8 类 `shared_materials` 未新增贴图）；安装于 `assets/models/<category>/SN_*_LOD1.glb` + `dev_mods/core/assets/models/<category>/` 副本，船 **4 个 `model.ship.*_lod1` manifest 键**、kit 26 件登记 `kit_catalog.json` v1.3 的逐件 `lod1` 块（kit 同 LOD0 不进 manifest）；铁港建筑 8 栋 × (LOD0 + LOD1) = 16 个 GLB 此前已交付。LOD1 不保留 socket / pivot（远景不参与装配），**运行时 LOD 切换未接线**；Godot 运行时探针 **30 件 / 67 个共享贴图实例 / 0 失败**，全量无头测试 **391 passed / 0 failed**（新增 `test_lod1_assets.gd` 3 例）。预览：[kit lineup](docs/design/screenshots/lod1/LOD1_lineup_weapons_1440x620.png) / [铁甲舰 LOD0 vs LOD1](docs/design/screenshots/lod1/SN_Ironclad_LOD0_vs_LOD1_three_quarter_1024x640.png)；验收 [LOD1_BASE_KIT_ACCEPTANCE.md](docs/archive/LOD1_BASE_KIT_ACCEPTANCE.md)。
- **base_kit 生产建筑 M1-2（批次 5：基地生产链 5 件，2026-10-22）**：新增 `SN_Base_Sawmill` / `Smelter` / `Foundry` / `Stockyard` / `Defense_Tower`，**15 948 / 19 000 tri**、42 mesh、37 socket、84 节点、159 图元，**5/5 GLB 自检 ALL OK**；全部地面件 zmin=0、4 m 网格，生产链接口齐备（锯木厂 `Drive_Shaft`/`Log_Input`/`Timber_Output`，冶炼炉 `Coal_Input`/`Ore_Input`/`Molten_Out`/`Chimney`，铸造车间 `Door_Front`/`Hoist`/`Molten_In`/`Pour_Point`，堆场 `Gate_In`/`Hoist`/`Scale`/`Storage`，防御塔 `Weapon_Mount`/`Searchlight`/`Flag`/`Magazine`/`Ladder_Foot`）；材质沿用 11 张共享贴图（无新增，新增 `assets/models/base/` 类别目录）；独立 Verifier 只读验收 0 failures；Godot 运行时用例 2 例、全量 headless **456 / 456**；`kit_catalog.json` v1.5（37 件 / 70 590 tri、4 条生产链配方）。3 轮 Builder 返工修掉浇包悬空/互穿、探照灯悬空、梯子无过桥、Foundry 正立面被墙吞没（射线级复核）。目录见 [KIT_ASSET_LIBRARY.md §13](docs/design/KIT_ASSET_LIBRARY.md)，预览 [lineup](docs/design/screenshots/kits/kit_base_lineup.png) / [生产链基地](docs/design/screenshots/kits/kit_base_assembly.png)。
- **`combat_kit` 敌舰 M2-1（批次 9：4 艘 = 3 类敌人，2026-10-22）**：新增 `SN_Enemy_Pirate_Sloop`（Light，8 678 tri）/ `SN_Enemy_Merchant_Armed`（Medium，11 746）/ `SN_Enemy_Ironclad_Raider`（Heavy，7 440，含 8 个空炮门）/ `SN_Enemy_Gunboat`（Light，3 460），**合计 31 324 / 32 400 tri**、55 mesh（GLB 节点合计 **86**）、**16 个 `SN_Socket_Weapon_*` + 8 个 `SN_Socket_GunPort_*`**；复用现有船体骨架（站表放样 + `rig_kit` / `ship_parts`），**不烘炮**：甲板炮位按 `hull-sockets@1`、铁甲舰炮门按 `hull-gunports@1` 给空节点并复用 `SN_Weapon_CasemateGun`。材质沿用 9 张共享贴图（无新增，新增 `assets/models/combat/` 类别目录 + Core 副本）；**4/4 GLB 自检 ALL OK**、独立 Verifier 只读验收 0 failures、Godot 用例守护（GLB 加载 / tri 锁定 / socket 契约）；机器目录 `tools/modeling/combat_kit_catalog.json`。预览 [lineup](docs/design/screenshots/combat/combat_lineup.png)，契约 [WEAPON_SOCKET_CONTRACT.md §11](docs/design/WEAPON_SOCKET_CONTRACT.md)，验收 [COMBAT_KIT_ACCEPTANCE.md](docs/archive/COMBAT_KIT_ACCEPTANCE.md)。运行时武器挂载 / 敌人内容 Schema / LOD1 留后续。
- **architecture_kit 扩展 M1-1（批次 4：可围合基地 6 件，2026-10-22）**：新增 `SN_Arch_Perimeter_Wall` / `Gate` / `Road` / `Loading_Platform` / `Warehouse_Variant` / `Workshop_Annex`，**12 584 / 16 800 tri**、39 mesh、37 socket、82 节点、117 图元，**6/6 GLB 自检 ALL OK**；全部地面件 zmin=0、4 m 网格 `Module_Next/Prev` 平铺，可把批次 3 的 4 栋建筑围成基地；大门门扇净间隙 0.05、吊闸不碰门顶，装卸平台月台面 1.25 m + 5 级楼梯 + 外挑吊货梁，仓库变体 14 级外楼梯上 3.48 m 上层侧门，工坊扩建 `Drive_Shaft` 接工坊 + 送煤槽/烟囱。材质沿用 11 张共享贴图（无新增）；独立 Verifier 只读验收 **0 failures**；Godot 运行时用例 2 例、全量 headless **425 / 425**；`kit_catalog.json` v1.4（32 件 / 54 642 tri、4 条基地装配配方）。目录见 [KIT_ASSET_LIBRARY.md §12](docs/design/KIT_ASSET_LIBRARY.md)，预览 [lineup](docs/design/screenshots/kits/kit_architecture_extension_lineup.png) / [基地拼装](docs/design/screenshots/kits/kit_architecture_extension_assembly.png)。
- **旧资产 UV 迁移 A（31 件铁港道具 + 6 件港口设施，2026-10-22）**：按 backlog M0-1 给 37 件旧纯色资产补 `UVMap`（局部空间盒式投影，24 188 UV loops）、把 9 个旧 `SN_*` 材质切换为 9 个 `SN_Tex_*` 共享贴图材质、重导 GLB（`images[].uri = shared_materials/<texture>.png` + Core 副本）。**几何逐位不变：11 278 tri（props 6 282 / port 4 996）与迁移前逐件一致**；37/37 GLB 自检、Godot 运行时 37 件 / 14 个共享 `Texture2D` 实例 / 0 失败，旧纯色材质从港区退场。脚本 / 映射 / 验收见 [LEGACY_UV_MIGRATION_A_ACCEPTANCE.md](docs/archive/LEGACY_UV_MIGRATION_A_ACCEPTANCE.md)。
- **3D 港口样片（独立场景）**：`dev_scenes/harbor/` 复用 `assets/models` 的 1795 双桅纵帆船 `SN_Schooner_Fame`（黑船身 + 赭黄腰线 + 双桅斜桁帆，用户要求无星条旗） / 塔吊 / 码头道具搭一个固定机位小港口，自写 Godot 水面着色器（顶点波浪 + 噪声法线 + 菲涅耳天空反射 + 太阳耀斑 + 岸线/船体泡沫 + 远水雾色），船体随与着色器同源的波浪起伏。**不接入主场景**，仅供水面观感与构图验证；说明见 [dev_scenes/harbor/README.md](dev_scenes/harbor/README.md)，预览见 [港口样片截图](docs/design/screenshots/harbor_diorama_schooner.png) 与 [纵帆船近景](docs/design/screenshots/harbor_diorama_schooner_detail.png)。
- SDK：模组打包、无头校验、模组模板与一个第三方锅炉示例。
- [SNModMaker](SNModMaker/README.md)：零依赖网页端模组制作器，可视化编辑、校验并打包 `.snavmod.zip`；实体资源使用主题化可搜索选择器，船体可在独立模块区配置槽位；已适配 Content Schema 2.0（**20 类运行时类型 + 3 类草案**：7 类 1.0 与 12 类 2.0；模块已合并为 `modules`（`v2_category`）、`hulls` 升 2.0、goods/materials 合并为 `items`（`crafting_material`），9 类世界/战役类型由运行时加载，`weapons` 与剧情 `story_arcs` / `story_levels` 仍为草案、运行时暂不加载），新建模组可选「**舰载武器包**」模板
- [SNBattleSim](SNBattleSim/README.md)：独立 2D 舰队战斗规则试验台，验证固定三船体、多武器、视野、炮击、货船护航和自定义武器。

尚未完成、但已留出扩展位置的内容见 [todo.md](todo.md)。

## 环境要求

- Godot **4.4+**（本仓库在 **4.7.2 stable** 上验证）。
- 无需 C# / .NET；纯 GDScript。
- 无头测试与 SDK 工具不依赖编辑器 UI。

## 快速开始

1. 用 Godot 打开仓库根目录（包含 `project.godot`）。
2. 按 **F5** 运行。主场景为 `framework/ui/shell/main.tscn`。
3. 选择初始构筑（低耗稳健型 / 高速冒险型）和可选种子，开始新航程。

开发模式下，Core 从 `res://dev_mods/core/` 松散目录加载；同时扫描 `res://dist/mods`，方便直接放入第三方 `.snavmod.zip`。同 ID 时松散目录优先，`dist/mods` 里的 core 构建产物会被自动忽略。发布模式不扫描 `res://dev_mods`（它也不会被导出进 PCK），只扫描可执行文件旁的 `mods/` 与 `user://mods/`。

### 运行测试

```powershell
# 设置 Godot 可执行文件路径，或把 godot 加入 PATH
$env:GODOT_BIN = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
pwsh ./tools/test.ps1

# 等价命令
godot --headless --path . --script res://framework/tests/test_runner.gd
```

测试输出形如：

```text
[PASS] test_mod_loading::test_core_loads_cleanly
...
Tests: 100 passed, 0 failed, 100 total
```

### 打包 Core 模组

```powershell
pwsh ./tools/pack_core.ps1
# 或
godot --headless --path . --script res://sdk/pack_mod.gd -- --source=dev_mods/core --out=dist/mods
```

产物：`dist/mods/core-1.0.0.snavmod.zip`（包内路径为 `mods/core/...`）。

### 开发版发布

推送 `v*` tag 会触发 `.github/workflows/release.yml`：跑测试、导出 Windows/Linux、打包 Core、生成 SHA256，并创建 GitHub Release。带 `-dev.` 的 tag 自动标记为预发布。

发布前先在本地把 [todo.md](todo.md) 中 `Recently Completed` 的条目归并进 [CHANGELOG.md](CHANGELOG.md)（只写有意义的功能 / 变更），再从 todo 移除，然后打 tag。

```powershell
git tag -a v0.2.0-dev.1 -m "Steam Navigator v0.2.0-dev.1"
git push origin v0.2.0-dev.1
```

发布资产：`SteamNavigator-<tag>-windows.zip`、`SteamNavigator-<tag>-linux.zip`、`core-1.0.0.snavmod.zip`、`SHA256SUMS.txt`。

发布包是标准便携布局，解压后保持同一层目录：

```text
SteamNavigator/
  SteamNavigator.exe            # Linux 为 SteamNavigator.x86_64
  mods/
    core-1.0.0.snavmod.zip      # 官方内容包，启动必需
  config/
    config.json                 # 可编辑的默认设置
```

- 发布标签会先运行 `sdk/validate.gd` 校验松散 core；manifest 声明的资产（贴图 / GLB）不完整时直接阻止发布。
- `core-1.0.0.snavmod.zip` 也作为独立资产提供，方便第三方或手动替换；直接使用发布包时无需另外下载。
- [SNModMaker](SNModMaker/README.md) 的「导出并覆盖到发布包 mods/」默认就写入 `dist/build/<platform>/mods/`，本地导出的发布包可直接接收编辑器部署的模组。
- 发布版 exe 不再内嵌 `dev_mods/`，内容只从 `mods/` 读取，因此不会再出现「核心包半导出」导致的启动失败。

本地导出需要安装 Godot 4.7.2 导出模板；预设名为 `Windows Desktop` 和 `Linux/X11`。

### 校验第三方模组

```powershell
godot --headless --path . --script res://sdk/validate.gd -- --mod-root=sdk/examples/example_boilers
```

## 架构概览

```text
Presentation  framework/ui
      ↓ Query / Command
Application   framework/application（总线、用例、命令、查询）
      ↓
Domain        framework/domain（航行、市场、委托、船只、地图、事件、债务）
      ↓
Content API   framework/modding（定义、注册表、Schema、Patch）
      ↓
Mod Runtime   framework/modding（扫描、依赖、挂载、编译）
      ↓
Infrastructure framework/services（文件、存档、日志、RNG、本地化、资源）
```

启动链路（见 `framework/bootstrap/bootstrap.gd` 与 `framework/modding/mod_loader.gd`）：

```text
AppBootstrap._ready
  → Bootstrap.run
    → AppContext（服务/总线）
    → ModScanner.scan       扫描 dev_mods / user://mods_dev / user://mods
    → DependencyResolver    校验 API、依赖、冲突、循环，生成确定性顺序
    → mount resource packs  ProjectSettings.load_resource_pack(path, false)
    → ContentCompiler       JSON → Schema → 注册 → 显式 Patch
    → CrossReferenceValidator + CoreCompletenessChecker
    → RegistryHub.freeze_all
    → FrameworkApi.register 命令 / 查询
    → 主场景
```

Core 加载失败时，主场景仍可进入诊断界面，但不会开始游戏。

### 关键不变量

- **官方内容也是模组**：`framework/` 中不存在具体 `core:*` 内容 ID（有测试守护）。
- **注册表冻结后不可变**：运行态数量、库存、耐久只存在于 `GameState`。
- **命令事务**：`CommandBus` 在 `GameState` 深拷贝上执行，成功才提交并发布领域事件。
- **查询只读**：`QueryBus` 给查询处理器一个临时克隆，防止查询意外修改状态。
- **命名随机流**：`RngService` 按（基础种子、流名、上下文键）派生，新增视觉随机不会影响市场或事故。
- **存档确定性**：数字在规范化 JSON 中量化到 1e-9，保存/加载前后状态哈希一致。
- **模组安全**：内容模组只能提交 JSON / 图片 / 音频 / 单文件 GLB 模型；拒绝脚本、动态库、场景、路径穿越与 `res://framework/**` 覆盖。

## 目录结构

```text
project.godot                  Godot 项目入口
content_types.json             内容类型单一真源（框架 / 编辑器 / Schema / SDK 契约）
framework/
  bootstrap/                   启动、AppContext、启动报告、自动清理
  modding/                     模组扫描、Manifest、依赖、Schema、编译、注册表
  application/                 Command / Query / Event 总线，用例，命令与查询
  domain/                      voyage / economy / contracts / ship / map / events / debt / run(通关)
  services/                    RNG、时钟、日志、本地化、资源、存档
  state/                       GameState（纯数据、可克隆、可哈希）
  ui/                          最小可玩外壳（2.5D 固定舞台子系统在 framework/ui/stages/）
  tests/                       无头测试运行器与测试用例（数量见上方「当前状态」）
  localization/                框架 UI 文案（zh_CN / en）
  assets/                      缺失资源占位符
schemas/                       Manifest 与各类内容的 JSON Schema
config/                        默认 UI 设置（config.json）
sdk/                           打包、校验、模组模板、第三方示例
.github/workflows/            GitHub Actions：tag 触发的开发版发布
SNModMaker/                    零依赖网页端模组制作器（原生 HTML/CSS/JS）
assets/                        运行时 UI、音频与字体资产；船厂纵剖图 / 船卡贴图在 assets/ui/shipyard/，水面 shader / 材质 / 噪声纹理在 assets/{shaders,materials,textures}/water
dev_scenes/harbor/             独立 3D 港口样片（不接入主流程；水面着色器与浮船试做）
dev_scenes/port_stage/         独立 PortStage 预览场景（不接入主流程；两套样例 ViewModel）
dev_mods/core/                 官方 MVP 内容（松散的开发态 mod；建筑 GLB + `assets/models/props/iron_harbor_shared/` 共享贴图）
dist/mods/                     本地 mod 包（.snavmod.zip）与 core 构建产物；运行时扫描
docs/                          GDD、架构方案、静态代码文档
tools/                         PowerShell 辅助脚本、UI 截图工具与建模生成器
```

## 内容与数值（Core v1.0.0）

- 5 个港口原型：铁港、香料港、自由镇、渔村、玻璃港。
- 每局生成 4–5 个港口的连通分支网络；造船厂与情报站保证在起点 2 条边内。
- 7 种普通商品（含委托货箱）+ 2 种补给商品（煤炭/淡水）+ 3 种专用造船材料。
- 4 个船体（小型/中型/大型）、3 个锅炉、3 个货舱、2 个导航、2 个安全、1 个固定客舱。
- 六类模块都带打造配方：tier1 为**仅金币**配方（`materials: []` + `craft_cost` + `craft_time_hours`，反馈 1），tier≥2 额外消耗材料与 `craft_cost`；两个造船厂港口限量出售精密齿轮。
- 经济 / 标准 / 极速三种锅炉策略；工程师 / 领航员岗位。
- 5 段主线 + 4 种普通委托；2 类事件（锅炉过热、偶遇商船）。
- 2 套初始构筑：低耗稳健型、高速冒险型。
- 15 条 Core 实体已配置新版 `information.texture/model`：船体、锅炉、商品、造船材料与铁港可直接解析对应贴图或 GLB 模型。
- 所有数值均为数据驱动，位于 `dev_mods/core/content/*.json`。

## 模组制作

除了手写 JSON 与 SDK 脚本，也可以使用 [SNModMaker](SNModMaker/README.md)（零依赖网页端）：

```powershell
node SNModMaker/tools/serve.mjs
# 打开 http://127.0.0.1:8099/
```

它从 `schemas/` 读取同一套约束，支持 20 类运行时类型（19 类内容 + 显式补丁，其中 12 类为 Content Schema 2.0）与 3 类 Schema 2.0 草案（`weapons` + 剧情 `story_arcs` / `story_levels`）、本地化与资源编辑，可导入现有目录 / ZIP，并导出 `mods/<id>/` 结构的 `.snavmod.zip`。新建模组时可选起始模板：「舰载武器包」会一次生成 5 件战斗模拟器武器（战斗数值对齐 SNBattleSim、装配字段来自 GLB extras、模型引用 Core 的 `asset://core/model.weapon.*`，`schema_version: "2.0"`），只写入编辑器项目、不写入 Core。内容类型清单来自 `content_types.json`：修改后运行 `node tools/gen_content_types.mjs` 重新生成框架常量与编辑器目录（`--check` 可检查是否过期）。实体 ID 修改时只实时预览新多语言键，点击「保存条目」后才原子迁移全部语言文本；船只与模块类型可在页面子分页间直接切换。每个实体还可引用贴图与单文件 GLB 模型资源；本体解析器会将这些键归一化为 `asset://<mod>/<key>` 并拒绝缺失或格式不匹配的资源；资源页会对 GLB 生成自动取景缩略图（内置解析 + WebGL，不引入第三方库）。使用本地服务时，项目会同时写入 `SNModMaker/mods/`，普通导出写入 `SNModMaker/exports/`；「导出并覆盖到发布包 mods/」默认写入 `dist/build/<platform>/mods/<id>.snavmod.zip`（可用 `SNMODMAKER_GAME_MODS_DIR` 指向其他游戏目录或开发态 `dist/mods`）。

最小结构：

```text
<mod_id>/
├── manifest.json
├── content/*.json
├── localization/zh_CN.json
└── assets/...
```

- ID 必须为 `<mod_id>:<type>/<local_id>`，且命名空间必须是自己的 `mod_id`。
- 内容文件外壳：

```json
{
  "schema_version": "1.0",
  "content_type": "goods",
  "definitions": [{ "id": "...", "name_key": "...", "enabled": true, "data": {} }]
}
```

- 修改其他模组的定义必须使用显式 `patches` 文件；同路径冲突会阻止启动，不会静默决定胜负。
- 详见 `sdk/templates/mod_template/`、`sdk/examples/example_boilers/` 与 `schemas/`。

## 本地化

- 框架 UI：`framework/localization/{zh_CN,en}.json`。
- Core 内容：`dev_mods/core/localization/{zh_CN,en}.json`。
- 默认 `zh_CN`，缺失键回退到 `en`，再回退到键名本身。

## 已知边界

- 材料随船运输仍计入货舱容量；GDD 9.1 中“材料不占货舱容量”本轮只对未安装模块（transit）实现。
- 船厂仓库/运输 UI 为基础版：材料按固定 5 件批量存取，尚无数量步进或批量选择。
- 通关总结页为数据化总结，不含航线回放、成就与统计对比。
- 船厂改装态纵剖图是一张 2D 授权贴图；正常态已是真实 3D 船体舞台（固定机位、只做表现，不含环绕与场景热点），3D 船体资产缺失时回退程序化 2D 占位。贴图与当前可玩船型视觉也不完全一致（纵剖图 / 船卡为铁甲舰风格）。**主界面已是全窗 `PortStage` + 紧凑 HUD（含资源图标）+ 主题化两侧招牌 + 底部状态条 + 详细总览抽屉；港口街景 normal 47 件与 `port.diorama` 已接线，设施/街景/玩家船静态合批后实测 63/56 draw calls；剩余 2.5D 工作是港务/市场等独立舞台、出航/进港演出、质量档位/低配回退与 L2 LOD。**
- **运行时船体装配的边界**：帆索只对实测 1:1 吻合的船体做套件替换（PF 桅/桁、SF 桅），其余保留 GLB 内烘焙帆索，避免双层；kit 帆面尺寸与烘焙件不符，整桅帆重挂留待后续批次。武器 content type 仍是 Schema 2.0 草案、`state.ship` 尚无已装武器，因此游戏内 `weapon_loadout` 当前为空 —— 装配器 / 舞台透传已就绪，武器内容落地后直接接上；截图工具注入的预览 loadout 只是装配证据。港口舞台会把玩家船烘进静态批次，合批后武器瞄准 / 后坐句柄失效（战斗层接入时需要不合批旁路）。详见 [SHIP_VISUAL_ASSEMBLY.md](docs/design/SHIP_VISUAL_ASSEMBLY.md) §9。
- **内容资产全部走模组**：船体/模块/道具模型与港口横幅随 `core` 模组发布（`dev_mods/core/assets/**` + manifest `model.*`/`banner.*` 键），发布包 PCK 已排除 `assets/models/*`；运行时由 `ContentAssetLoader` 读取模组内原始 `.glb`/`.png`。本体内只保留框架资源（代码、Theme/字体、UI 外壳图、音频、水面 shader/材质/贴图）。新增内容模型请放 `dev_mods/core/assets/models/<category>/` 后重新 `pack_core`，不要放回 `res://assets/models`。
- UI 是最小可用外壳，设施名称部分为中文硬编码；海图可按已访问港口打开上次在港的市场快照。
- 全屏航海图页已接入 Shell（M 键 / 导航「海图」/ 状态条「海图 ▶」/ 港口招牌；出航确认在页内弹窗），且 `run.start` 会生成与对局地图同 ID 的坐标空间孪生世界（`state.data["world_map"]`），海图在真实对局直接出图：起港已发现/访问/当前并揭示迷雾，抵达自动记录访问并揭示泊位与沿途迷雾。孪生世界的连通图是自身 MST 图，与抽象地图航线不完全一致（出航仍按抽象地图邻居可航行）；阶段 3 航行演出已把这些航线画出来（船只沿海图航线行进），但出航判定仍走抽象地图，二者的统一留待后续阶段。旧存档（无 `world_map`）海图显示无数据提示，按需重开新局。
- 存档已支持 save schema 1.x → 2.0 迁移（回填 campaign 元数据与分区，state/content schema 分离）；模块实例表 `ship.module_instances` 与 campaign 分区均由惰性 ensure 补齐；声明式 ID 别名迁移仍未实现，新字段继续通过惰性 ensure 补齐。
- 模块 condition 目前只影响失效标记与维修费用，尚未改变航速/容量等派生属性；统一 Module 迁移（definition_id 移入实例）与战斗期性能影响在后续阶段。
- **Content Schema 2.0 Phase B 已落地**：8 类世界/战役类型（world_profiles / regions / sites / route_templates / weather_profiles / factions / discoveries / start_profiles）与新增 `map_configs` 已提升 active，运行时按类型版本加载 1.0/2.0 内容；`run.start` 支持可选 `start_profile`，由 `CampaignFactory` 装配区域/地点/航路/阵营/图鉴并写入 `campaign.setup/content_versions`；`map_configs` 的 31 键 exploration 与 story 从 1.0 `map_profile` 原样迁移；旧档继续按 `map_profile` 读取，`weapons` / `story_arcs` / `story_levels` 仍是编辑器草案。**「运行时不加载」不是静默忽略**：未注册类型 / 版本不符仍按 mod error 拒绝，Core 必需包会让启动进入 `Degraded`。
- **剧情模式 S1 数据契约已落地**：新增 `schemas/v2/story_arc.schema.json` / `story_level.schema.json`（内嵌固定地图 `map.fixed`、共享 story_stage DSL、叙事 brief / beats / debrief、难度旋钮、checkpoint 重试、仅成就类奖励），`content_types.json` 把 `story_arcs` / `story_levels` 登记为 Schema 2.0 草案（capability `content.story.v1`，schema bundle 31 个）；SNModMaker / Content CLI 可编辑与校验（`draft_content` 警告、`story_pack_off_whitelist` 白名单、篇章 / 关卡语义），示例包见 `sdk/templates/story_pack_iron_tide/`；运行时加载链（S2）与后续 UI / 档案 / SNStoryMaker 仍在路线图中，草案见 [STORY_MODE.md](docs/design/STORY_MODE.md)。
- 无头退出时 Godot 会报告静态注册表/脚本的 ObjectDB 泄漏警告；测试退出码仍为 0，不影响运行。

## 文档与协作

- 静态代码文档按“文件镜像 + 模块索引”组织，生成信息见 `docs/static/README.md`。
- 重要源码在文件头用 `@static-doc` 注释维护职责/契约；不能写注释的格式使用 `docs/static_headers/<源码路径>.md`，格式见 [静态文档注释约定](docs/static_headers/README.md)。
- 每轮代码改动后运行 `node tools/gen_static_docs.mjs`，提交前用 `node tools/gen_static_docs.mjs --check` 检查生成物没有过期。
- 设计问题优先回到 GDD / 架构文档确认，不用“通过测试”替代需求判断。
