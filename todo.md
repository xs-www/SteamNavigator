# TODO

> 只保留最近 10–15 项已完成与尚未实现的目标；逐条实现细节见 git 历史。
> 发布约定：打 `v*` tag 前把 `Recently Completed` 里的条目按版本归并进 [CHANGELOG.md](CHANGELOG.md)（只写有意义的功能 / 变更），并从本文件移除。

## In Progress

- [ ] SNBattleSim 战术状态机工作台：人工浏览器验收（节点拖拽、转移表、状态机 CRUD、舰船挂载）后评估是否并入正式战斗
- [ ] 海图阶段 3 验收反馈 F1–F4：离港要"驶离"而不是平移；镜头俯角加大到竖直再拉升、云层后海图先铺满再回落；海图上的船必须沿航线移动，不能两点直线
- [x] SNBattleSim 模组交换与 Agent CLI：`mods/` 散装目录及 ZIP 导入、游戏约定 `.snavmod.zip` 导出、状态/FSM 契约、AND/OR 条件、状态拖放、空白拉线建状态和 Delete 删除
- [x] SNBattleSim 二轮易用性：Mod 蓝图舰体装配、五状态默认 FSM、工程目录持久化、目标高亮、全状态尝试开火与顶部入口分级

## Pending

### 近期
- [ ] 正式任务系统 Phase B：`quests` 内容类型 + `QuestService`（任务链、目标事件、前置 / 奖励、发布点、任务日志页）；契约见 [TASK_QUEST_SYSTEM.md](docs/design/TASK_QUEST_SYSTEM.md)

- [ ] 2.5D 舞台收尾：委托 / 情报页舞台化、事件触发的 3D 场景预加载、质量档位与低配回退、L2 LOD、第三方 `.glb` 白名单评审
- [ ] 高频决策页第二轮：市场数量步进 / 即时成本、持久 `ScreenHost` 与局部数据刷新
- [ ] 存档：声明式 ID 别名与数据迁移执行器；出航失败回滚的存档路径端到端测试
- [ ] SDK / 发布：模组管理 UI（启用 / 禁用 / 优先级）、发布签名与固定哈希校验
- [ ] 建模需求 Backlog：按 [MODELING_BACKLOG.md](docs/design/MODELING_BACKLOG.md) 的批次顺序推进（M0-3 船侧武器 socket、M0-4 `rig_kit` 均已完成；下一批建议：LOD1 基础套件（M0-5））
- [ ] 遗留清理：`SN_Ship_Prototype`（`model.ship.prototype` 遗留键）仍是旧纯色 `SN_*`，可随船体资产批次一起迁移或删除遗留键
- [ ] 3D 资产收尾：帆船 / 明轮 / 模块的 Godot 导入与目标机位验收、水面性能低配档位与第二港口变体
- [ ] 起重机三件新资产接入：`SN_Mega_Gantry` / `SN_Wooden_Mast_Crane` / `SN_Hand_Jib_Crane` 的 PortStage 槽位与目标机位复核（Core manifest 资源键与 `shared_materials` 贴图已接入）
- [ ] 模型素材库接入：kit 批次 1–3 的 26 件资产登记 Core `model.kit.*` / `model.weapon.*` 资源键，接 `ShipVisualAssembler` / 场景装配的 socket 装配与目标机位复核（目录见 `tools/modeling/kit_catalog.json`）
- [ ] Content Schema 2.0 迁移（分层）：Phase A 已落地；Phase B 实现契约已就绪（9 类类型 + CampaignFactory + 1.0→2.0 映射），待隔壁探索 4.1 提交后开工；之后 C 实体合并 → D 其余系统 → E 冻结 1.0。方案：[CONTENT_SCHEMA_V2_MIGRATION.md](docs/design/CONTENT_SCHEMA_V2_MIGRATION.md) / [WORLD_SCHEMA_V2_RUNTIME.md](docs/design/WORLD_SCHEMA_V2_RUNTIME.md)（待拍板 D2–D3、D7–D12）
- [ ] 3D 资产收尾：帆船 / 塔吊 / 明轮 / 模块的 Godot 导入与目标机位验收、塔吊参数化生成器、水面性能低配档位与第二港口变体

### 海图 / 探索

- [ ] 阶段 5 事件化海洋：航行事件预生成与预加载、事件类型（敌对 / 环境 / 奖励 / 秘境）、3D 场景触发与决策、安全航行结算（含探索途中事件与耐久告急）
- [ ] 阶段 6 固定未知岛屿与基地建设：勘探、设施建造、公开港口
- [ ] 可选：航线表体积优化（path 抽稀 / 压缩，当前 38 条边 82 KB）
- [ ] 阶段 4 探索系统：`Clue` / `ClueService`、`explore_voyage.start`、搜索区判定与发现概率、资源告急与探索失败处理、线索可视化
- [ ] 阶段 5 事件化海洋：航行事件预生成与预加载、事件类型（敌对 / 环境 / 奖励 / 秘境）、3D 场景触发与决策、安全航行结算

### 正式版路线图

- [ ] 阶段 0：Content Schema 2.0 系统类型、多战役存档、tick 模拟框架
- [ ] 阶段 1：广域海图与探索运行时（v2 草案提升 active，接世界生成 / 战役 `world` 分区 / 区域低细节模拟）
- [ ] 阶段 2：舰队组成与战斗（先自动结算，再战术层）；模块 condition 进入派生属性；战斗内容 Schema 2.0（weapons / enemy_archetypes / encounter_tables / loot_tables）；SNBattleSim 规则并入
- [ ] 阶段 3：基地建设与生产链（接入舰队 / 战斗 / 贸易）
- [ ] 阶段 4：自动化贸易（航线、规则、风险与 tick 结算）
- [ ] 阶段 5：遗迹探索（程序化房间、远征、战利品）
- [ ] 阶段 6：整合、内容量、Mod API 2.0 / Content Schema 2.0 冻结与发布验收

## Recently Completed
- [x] 船体运行时装配 `ShipVisualAssembler`（2026-10-22）：`ShipVisualPlan` 从 Core manifest（`model.ship.*` / `model.rig.*` / `model.weapon.*`）+ `hulls.json.data.rig_plan` + `ship.weapon_loadout` 解析出 hull / rig / weapon 路径；`ShipVisualAssembler` 实例化船体后按 `SN_Socket_Mast/Yard/Sail_*` 对齐套件 `SN_Mount` 并隐藏被替换的烘焙节点，按 `SN_Socket_Weapon_*` 挂武器（class 硬门禁、`Modular` 拒绝）；rig 全有或全无回退原船、武器逐件跳过、旧 ViewModel 走原 `hull_model_path`/`hull_tier` 回退；节点命名稳定 + 量化快照确定性。接入船厂 3D 舞台、港口舞台（含静态合批）与航行演出（离港/入港共用入口）；移植 `weapon-assembly-demo` 的武器运行时层（14 例）。新增装配测试 11 例、全量 402 passed，截图 8 张 `docs/design/screenshots/ship_assembly/`。设计 [SHIP_VISUAL_ASSEMBLY.md](docs/design/SHIP_VISUAL_ASSEMBLY.md)
- [x] 船体帆索部件库 M0-4 `rig_kit`（2026-10-22）：新增参数化部件库 `rig_kit.py`（桅杆 / 横桁 / 斜桁 / 帆杠 / 艏斜桁 / 帆面 / 索具）与 **12 件独立 `SN_Rig_*` 套件**（**3,774 tri / 7,050 预算**，`assets/models/rig/` + Core 副本）；PF / SF / IC 三艘船的帆索改由同一份部件库生成，**逐对象几何 digest 0 差异**（PF 12,200 / IC 8,830 tri、mesh 数不变；SF 纯帆索基线 28 对象 / 12,994 tri，整船含既有 `SN_SF_Nameplate` 为 29 / 13,174）；3 艘船新增 **22 个** `SN_Socket_Mast/Yard/Sail_*` 空节点（PF 6 / SF 7 / IC 9，零几何），GLB 节点 PF 50→56 / SF 35→42 / IC 5→14；GLB 12/12 + 船舶 4/4 + 批次 B 21 files 0 failures + Godot 新增 3 例。契约 [RIG_KIT_CONTRACT.md](docs/design/RIG_KIT_CONTRACT.md)、目录 [rig_kit_catalog.json](tools/modeling/rig_kit_catalog.json)、验收 [RIG_KIT_ACCEPTANCE.md](docs/archive/RIG_KIT_ACCEPTANCE.md)
- [x] 船侧武器安装点 M0-3（2026-10-22）：4 艘可玩船（明轮货轮 / 明轮客船 / 纵帆船 / 铁甲舰）各就地补 2–4 个 `SN_Socket_Weapon*` 空节点，共 **14 个**（class 混编 Side / Light / Medium / Heavy），**零几何改动**（45,968 tri / mesh 数不变）；BLEND 前缀名 → GLB 标准名归一化，节点 extras 写 `socket_class / clearance_r / clearance_x / clearance_y / clearance_h / mount_scale / socket_index`，Root 写 `weapon_sockets` 列表；GLB 4/4 自检 + 批次 B 21 files 0 failures + Godot 资产/socket 测试 11/11。脚本 `sn_ship_weapon_sockets.py` / `glb_ship_sockets.py` / `export_ship_weapon_sockets_glb.py` / `verify_ship_weapon_sockets_glb.py`，契约 [WEAPON_SOCKET_CONTRACT.md](docs/design/WEAPON_SOCKET_CONTRACT.md)，验收 [SHIP_WEAPON_SOCKETS_ACCEPTANCE.md](docs/archive/SHIP_WEAPON_SOCKETS_ACCEPTANCE.md)
- [x] 旧资产 UV 迁移 B（2026-10-22）：船模块 12 GLB（含 `modules/SN_Boiler_Unit` 占位副本）+ 4 艘可玩船 + 旧小镇剩余 5 件补 UV、切 10 种 `SN_Tex_*` 共享贴图、重导 GLB；**55,256 tri / 118 网格与迁移前逐件一致**（多节点船体用根节点局部空间 UV），21/21 GLB 自检 + Godot 21 件 / 24 个共享贴图实例 / 0 失败。旧小镇 5 栋建筑此前已由建筑套件升级为 `SN_Town_*`；`SN_Ship_Prototype` 遗留键除外。脚本 `sn_legacy_uv_migration.py`（`migrate_all_b`）/ `dryrun_legacy_uv_b.py` / `export_legacy_uv_b_glb.py` / `verify_legacy_uv_b_glb.py`，验收 [LEGACY_UV_MIGRATION_B_ACCEPTANCE.md](docs/archive/LEGACY_UV_MIGRATION_B_ACCEPTANCE.md)
- [x] 任务追踪聚合 4.6 Phase A（2026-10-22）：只读 `task.view` 聚合剧情目标 / 待接主线 / 已接主线与普通委托；委托步骤推导（接取 / 备货 / 接客 / 前往 / 抵达交付，燃料按煤舱、自备货物按船上数量、普通货箱接取即装船）；HUD 任务追踪条（剧情结束后自动接替目标条）+ 委托页任务面板；任务不复制状态；测试 +5，截图 `task_tracker_hud.png` / `task_tracker_contracts.png`
- [x] 新手剧情补给引导修正（2026-10-22）：关闭海图后的「煤舱补到 10」目标改为跟踪真实煤舱（进入阶段 8/10，购买时 `counter_from: stock`），目标条显示「8/10，还差 2」，不再要求玩家自己算要买多少；新增 `tutorial_supply_remaining.png` 截图
- [x] 阶段 4.5 新手剧情 / 教学系统（4.5.1–4.5.6，2026-10-22）：新开局默认五幕教学（获船→补给限购 / 海图首航→第二港市场与回运→酒馆线索 / 保底探索→第三港船厂客舱 / 旅客），剧情接管 `main_01..main_03` 并在第三段后交还沙盒；`data.story` 状态机 + Core JSON 剧情 / 文案 / 解锁、剧情卡 + 非阻塞目标条、功能门禁、跳过保底；补给并市、酒馆替换情报站、两港价差、第三种货、两根线索、保底探索、船厂按 `unlocked_modules` 过滤、1 人客舱与旅客主线全部落地；全量测试 0 failed，截图见 [STORY_TUTORIAL.md](docs/design/STORY_TUTORIAL.md)。
- [x] 新手剧情 4.5.5 · 船厂 / 客舱 / 旅客（2026-10-22）：新增 `core:cabin/small_cabin`（1 人，120 金 / 8 重量）；`StoryService.module_filter` + `shipyard.view` 在剧情期间按 `unlocked_modules` 过滤购买 / 打造 / 仓库候选；第三港由 Core 补 `shipyard` 并用 `upgrade_hull` 换成带客舱位的中型船体；`refit_unload` 卸货舱 → `refit_cabin` 装客舱 → 自动接 `main_03` 1 名旅客委托（清空货箱、主线链推进 `main_04`）→ `story_complete` 解锁全部；`ContractOps.attach` 不再用空货箱校验货舱容量；截图 `tutorial_shipyard_cabin.png` / `tutorial_shipyard_refit.png` / `tutorial_passenger_contract.png`
- [x] 新手剧情 4.5.4 · 酒馆 / 线索 / 保底探索（2026-10-22）：情报站页替换为酒馆页（设施 / feature `intel`→`tavern`，旧存档归一兼容）；`tavern.view` 合并物价情报 + 港口线索列表，酒馆可购买 / 调查线索；Core `grant_clue` / `set_market_price_bias` / `guarantee_explore_success` 效果 + 两根剧情线索（L1 → 同港 L3）；起始港与邻港纺织品 / 香料确定性价差且双向交易；第三种货木材解锁；`explore.settle` 对剧情 L3 线索无视 `outcome_roll` 直接成功（消费 flag，跳过不设保底），发现第三港并进入 `third_port` 占位阶段；测试 369 例，截图 `tutorial_tavern*.png` / `tutorial_market_third_good.png` / `tutorial_clue_list.png`
- [x] Content Schema 2.0 迁移 Phase B 实现契约（2026-10-21）：[WORLD_SCHEMA_V2_RUNTIME.md](docs/design/WORLD_SCHEMA_V2_RUNTIME.md) —— 8 类草案提升 + 新增 `map_configs`、9 类跨引用/完整性规则、CampaignFactory 流水线与状态形状、1.0→2.0 字段映射（含探索 `exploration` 原样迁移）、存档 `content_versions`、编辑器/CLI/G8 语义变化、B0–B6 落地顺序与 DoD
- [x] 编辑器导出守卫（G8，2026-10-21）：`Store.draftContentFiles()` 识别草案内容；含草案的项目禁用「导出并覆盖到发布包 mods/」，ZIP / exports/ / 目录导出二次确认并提示游戏运行时不加载（避免玩家拿到 Degraded 启动）
- [x] Content Schema 2.0 迁移 Phase A · 按类型版本解耦（2026-10-21）：16 个运行时类型各自声明 `schema_version`（1.0）、生成 `ContentTypes.SCHEMA_VERSIONS`、`ContentCompiler` 按类型校验并让 Patch 再校验走目标类型版本、新增 `test_content_versions` 6 例；编辑器/CLI 统一读类型 `schemaVersion`，1.0 行为不变
- [x] SNModMaker / Content CLI 适配 Content Schema 2.0 草案（2026-10-21）：`content_types.json.draft_types` 单一真源、8 类草案类型可编辑 / 校验 / 导出（`schema_version: "2.0"`）、v2 跨文件 `$ref` 与 `schema_version_mismatch` / `draft_content` / `capability_undeclared` 告警，运行时仍只加载 1.0
- [x] 设计文档按生命周期整理：`docs/design/`（Active）/ `docs/specs/`（Finalized）/ `docs/archive/`（Archived）+ 顶层索引（2026-10-21）
- [x] SNBattleSim 独立 2D 舰队战斗规则试验台（固定船体、多武器、视野、护航、自定义武器）
- [x] 铁港建筑套件批次 A/B/C：LOD1、外部共享贴图、三栋新原型、明轮蒸汽船视觉精修
- [x] 海图阶段 3 航行演出：3D 离港 / 入港、云层转场、海图航行、事件中断与恢复
- [x] 海图阶段 2：海图 UI、入口集成（`M` 键 / 导航 / 出航页）、航线预计算与绕行自适应
- [x] 海图阶段 0–1：坐标空间世界生成、三重迷雾、真实对局孪生世界
- [x] 2.5D 阶段 1 前七切片：船厂 3D 舞台、通用 StageHost、PortStage、主界面 HUD / 招牌 / 合批、连续港区三站位
- [x] 内容资产全部随 `core` 模组加载（共享外部贴图 + 松散 / ZIP / 发布包三条路径实测）
- [x] 静态文档迁移到源码 `@static-doc` / sidecar，生成器带 `--check`
- [x] 模块实例与部件损耗、战役分区、Content Schema 2.0 草案与存档 1.x→2.0 迁移
- [x] 迭代 2 MVP 反馈优化（打造订单与在港等待、补给比例条、情报对比表）
- [x] 迭代 1 MVP 闭环（仓库 / 打造订单 / 委托刷新 / 通关判定）
- [x] 船厂界面重构（图 2 / 图 3 三列布局、拖拽安装、分类记忆）
- [x] SNModMaker 原生工作区 + Content CLI + 容器部署；Windows 导出包实机验收
- [x] MVP 骨架：模组加载 / 依赖 / Schema / 注册表冻结 + 命令-查询总线（0.1.0-dev.2 初版）

> 新完成项先记在这里，打 `v*` tag 前按版本归并进 [CHANGELOG.md](CHANGELOG.md) 并移除。

- [x] 新手剧情阶段 4.5.3 并市 + 第二主线（全套 363 例通过）：补给页删除、煤 / 水并入市场「补给（煤 / 水）」区块（复用 `supply.buy_*`，导航 / 招牌移除，旧 `supply` 入口与存档重定向市场）；市场贸易货物按 story `unlocked_items` 过滤（Act 0 0 条，第二港开放纺织品 / 香料）；第二主线 `grant_tutorial_contract`（main_02、`provider: player`、`destination: home`）交付 6 件纺织品，剧情目标买 8 件、回港卖剩余 2 件；新增事件 `match` 条件与非确认阶段收卡。截图 [市场补给区块](docs/design/screenshots/story/tutorial_market_supply.png) / [第二港市场](docs/design/screenshots/story/tutorial_market_goods.png)。契约见 [STORY_TUTORIAL.md §9](docs/design/STORY_TUTORIAL.md)。
- [x] 新手剧情阶段 4.5.2 开局幕（全套 354 例通过）：教程新航程页隐藏构筑选择、默认教学船；获船叙事 → 补给 4 煤 2 水 → 补给受限（`lock_actions: supply.buy`，卡片显示原因、命令层拦截）→ 海图解禁 → 关闭海图恢复补给 → 买够 10 煤 → 海图出航默认极速；第一主线由 Core story `grant_tutorial_contract` 以 `main_01` 模板生成「燃料舱交付 10 煤」实例（`provider: fuel`、出航前校验、完成扣煤舱），`set_ship_fuel` 把开场煤舱压到 4，`tutorial_express` 保证标准迟到 / 极速准时；非教程局主线与 9 seed 通关回归不变。窗口截图 [补给受限](docs/design/screenshots/story/tutorial_supply_hold.png) / [首航默认极速](docs/design/screenshots/story/tutorial_depart_fast.png)。契约见 [STORY_TUTORIAL.md §9](docs/design/STORY_TUTORIAL.md)。
- [x] 新手剧情阶段 4.5.1 框架 + 门禁 + 剧情卡（全套 352 例通过）：`GameState.ensure_story` / `StoryService` 状态机（Core `map_profiles.story` 阶段表、事件计数、功能 / 商品 / 模块解锁、`discover_contract_destination` 效果）；`story.view` / `story.advance` / `story.skip` / `story.observe`（FrameworkApi 注册，Shell 转发 `cmd:*` / `ui:*`）；全屏剧情卡（继续 / 跳过 + 跳过确认）、非阻塞目标条、导航 / 港口招牌 / `M` / 状态条海图入口按 Feature 门禁；`run.start tutorial=true`（Shell 新局传 true）；旧存档惰性 ensure 全开；跳过保底解锁并揭示主委托目的港；窗口截图 [剧情卡](docs/design/screenshots/story/tutorial_card.png) / [目标条](docs/design/screenshots/story/tutorial_objective.png)。契约见 [STORY_TUTORIAL.md §9](docs/design/STORY_TUTORIAL.md)。
- [x] 武器装配规范 v2（可拼接武器系统）：8 件舰载武器 + kit 的 Cannon/GunCarriage/Turret/Pedestal + 甲板 socket 统一为 `SN_Socket_Weapon` / `SN_Mount` / `SN_Pivot_Yaw` / `SN_Pivot_Pitch` / `SN_Recoil` / `SN_Muzzle`；BLEND 内前缀唯一、GLB 导出后归一化标准名；13 件重建并重导，weapon/kit GLB 自检 16/16 通过。契约 [WEAPON_SOCKET_CONTRACT.md](docs/design/WEAPON_SOCKET_CONTRACT.md)，工单 [weapon_assembly_v2.json](tools/modeling/briefs/weapon_assembly_v2.json)。
- [x] 海图阶段 4.4 线索扩展（5 片全部实现，全套 338 例通过）：`port_goods` 货物行情线索（已发现港口 + 货物 + 冻结行情快照，分级披露港口名 → 参考价区间 → 库存供需 → 精确买卖价）；`expires_at` 时效（传闻 24 / 等待 48 / 情报 72 / 委托 72 游戏小时）与命令路径 sweep，过期进 `data.clues.expired` 历史并释放线索上限；新增 `clue.list` 只读查询与 `sea_chart.view` 类型 / 时效 / 可出航字段（仍不泄露 target_port_id / credibility / 真实 search_zone）；在港等待按档位复利、完成委托按概率解锁线索；货物线索「前往该港」走统一确认弹窗 → `clue.travel` 普通航线；调查消耗落地（20 金 + 在港 6h + 75% 成功率，失败照扣成本但不升级、可再试）；海图顶栏「线索列表」独立页（active 卡片 + 过期折叠 + 点击回海图选中）。旧存档惰性 normalize、不改 schema_version。契约与验收截图见 [EXPLORATION_SYSTEM.md §11](docs/design/EXPLORATION_SYSTEM.md)。
- [x] 海图阶段 4.3 探索体验修正（5 片全部实现，全套 325 例通过）：雾半径改为 `min(世界短边) × Core 比例` 且双子世界尺寸内容化；线索获得固定 1 级 + 在港逐级 `clue.investigate`（1→4，消耗字段预留 0）；探索失败不消耗线索（记 `attempts`，可立即再次出航）；演出随船照亮 + 抵达/掉头沿途迷雾持久化；普通航线仅在选中港口时显示；删除详细总览旧海图；删除出航准备页、出航确认（预估 + 锅炉策略，默认上次）移入海图弹窗；资源演出连续读数、出发只扣工资、结算按实际航行小时一次落账。契约与实现台账见 [EXPLORATION_SYSTEM.md §10](docs/design/EXPLORATION_SYSTEM.md)，截图见 [exploration/](docs/design/screenshots/exploration/)。
- [x] 武器独立建模批次 1：5 件舰载武器（`SN_Weapon_DeckGun` / `HeavyCannon` / `Mortar` / `Repeater` / `Broadside`），9,704 tri、共享贴图、Yaw/Pitch Pivot、GLB + Core 资产副本 + 单件/lineup 预览；纯资产交付，未登记 manifest、未接战斗逻辑。工单 [sn_weapon_batch1.json](tools/modeling/briefs/sn_weapon_batch1.json)，验收 [WEAPON_BATCH1_ACCEPTANCE.md](docs/archive/WEAPON_BATCH1_ACCEPTANCE.md)，映射 [ASSET_MAP.md](docs/design/ASSET_MAP.md#3d-舰载武器五件套2026-10-21)。
- [x] 武器独立建模批次 2：舰载弩炮 / 载人箭塔 / 蒸汽鱼叉发射器，7,292 tri；首次显式导出 `Mount` + `Anchor_1..4` 空节点与 Root `extras`（mount_class / pivot_profile / base_footprint / envelope / swept_radius），并给出不规则形态的 socket 契约。工单 [sn_weapon_batch2.json](tools/modeling/briefs/sn_weapon_batch2.json)，契约 [WEAPON_SOCKET_CONTRACT.md](docs/design/WEAPON_SOCKET_CONTRACT.md)，验收 [WEAPON_BATCH2_ACCEPTANCE.md](docs/archive/WEAPON_BATCH2_ACCEPTANCE.md)。
- [x] 模型素材库批次 1 · weapon_kit（P0）：火炮炮管总成 / 四轮炮架 / 装甲回转炮塔 / 武器基座 4 件，合计 6,256 tri；建立 `Mount + Trunnion_L/R + Yaw/Pitch + Collar` 拼装接口，火炮根 = 耳轴轴心、炮架耳轴座 z=0.62 与之对齐。工单 [sn_kit_batch1.json](tools/modeling/briefs/sn_kit_batch1.json)，契约 [KIT_ASSET_LIBRARY.md](docs/design/KIT_ASSET_LIBRARY.md)，目录 [kit_catalog.json](tools/modeling/kit_catalog.json)，验收 [KIT_BATCH1_ACCEPTANCE.md](docs/archive/KIT_BATCH1_ACCEPTANCE.md)。
- [x] 模型素材库批次 1 · ship_parts（P0）：8.4×6.0 m 甲板模块（5 个 Socket_*）/ 桅杆总成（桅顶瞭望台）/ 蒸汽烟囱 / 双开货舱盖 4 件，合计 5,708 tri；甲板作为母模块承载桅杆 / 烟囱 / 货舱盖 / 炮塔 / 基座的拼装演示；共享贴图 `SN_Tex_*`、UV 完整、GLB 外部贴图 URI 与 Core 副本已落盘。
- [x] 模型素材库批次 2 · machinery_kit（P1）：齿轮组（开式机架 + 24/14/12 齿三级传动）/ 卷扬机（绳鼓 + 棘轮 + 曲柄 + 吊钩）/ 卧式蒸汽动力装置（汽缸 + 飞轮 + 阀箱 + 蒸汽管），合计 6,056 tri；提供 `Shaft_In/Out`、`Drum_Pivot`、`Steam_In` 等功率链接口。工单 [sn_kit_batch2.json](tools/modeling/briefs/sn_kit_batch2.json)，契约 [KIT_ASSET_LIBRARY.md §9](docs/design/KIT_ASSET_LIBRARY.md)，验收 [KIT_BATCH2_ACCEPTANCE.md](docs/archive/KIT_BATCH2_ACCEPTANCE.md)。
- [x] 模型素材库批次 2 · cargo_kit（P1）：货箱（可堆叠）/ 轮式煤斗（新增 `SN_Tex_Coal` 碎煤贴图）/ 卧式铆接储罐 / 木托盘 4 件，合计 3,396 tri；`Stack_Top`、`Fill_Top`、`Outlet` 等接口与 `kit_catalog.json` 已登记。
- [x] 模型素材库批次 2 · dock_kit（P1）：8.4×4.2 m 石砌码头结构 / 8×2.6 m 木栈桥（桩到水下 −1.30）/ 双柱系缆设施 3 件，合计 4,228 tri；`Module_Next/Prev` 沿 X 平铺、`Socket_Mooring/Jetty` 拼装，装配演示见 `kit_assembly_dock.png`。
- [x] 模型素材库批次 3 · architecture_kit（P2）：仓库（装卸雨棚/滑门/吊货梁）/ 工坊（采光顶 + 外墙飞轮 `Drive_Shaft`）/ 酒馆（门廊 + 阳台 + 悬挑招牌）/ 厂房（锯齿采光顶 + 双烟囱 + 外置吊车梁），合计 10,604 tri；按 4 m 网格 `Module_Next/Prev` 平铺，建筑街区装配见 `kit_assembly_town.png`。工单 [sn_kit_batch3.json](tools/modeling/briefs/sn_kit_batch3.json)。
- [x] 模型素材库批次 3 · environment_kit（P2）：礁石（宽平礁顶 + 4.6 m 石砌灯塔基台）/ 沉船残骸（横倾 13°、断桅穿龙骨、压舱石贴底）/ 灯塔（石塔 + 环廊 + 灯室 + 穹顶）/ 航标浮标，合计 5,810 tri；礁石 Top 承灯塔、残骸/浮标根在水线，海岸装配见 `kit_assembly_coast.png`。
- [x] 模型素材库批次 3 工具链与文档：`kit_batch3_generator.py` / `dryrun_kit_batch3.py` / `export_kit_batch3_glb.py` / `verify_kit_batch3_glb.py` / `render_kit_batch3_preview.py`；`kit_catalog.json` 合并三批（26 件 / 42,058 tri / 13 配方）；契约 [KIT_ASSET_LIBRARY.md §10](docs/design/KIT_ASSET_LIBRARY.md)，验收 [KIT_BATCH3_ACCEPTANCE.md](docs/archive/KIT_BATCH3_ACCEPTANCE.md)。
