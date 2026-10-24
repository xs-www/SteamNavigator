# TODO

> 只保留最近 10–15 项已完成与尚未实现的目标；逐条实现细节见 git 历史。
> 发布约定：打 `v*` tag 前把 `Recently Completed` 里的条目按版本归并进 [CHANGELOG.md](CHANGELOG.md)（只写有意义的功能 / 变更），并从本文件移除。

## In Progress

- [ ] SNBattleSim 战术状态机工作台：人工浏览器验收（节点拖拽、转移表、状态机 CRUD、舰船挂载）后评估是否并入正式战斗

## Pending

### 近期
- [ ] UI 皮肤后续（V1 边界）：布旗 `flag_*` 接入导航/出航确认/港口识别（需布局改版，当前紧凑 64×36 导航与 172×42 侧牌放不下）；补齐 `nav_overview` / `nav_base` / `nav_trade` / `nav_ruins`、`shipyard_utility` / `shipyard_weapons`、`action_buy` / `sell` / `repair` / `wait`、`status_risk` 图标；多套皮肤运行时切换（Theme 动态重建，当前 Theme 绑定生成时的 skin 目录）；换肤后 960×540 文字/安全区复验与低动效模式
- [ ] 船体蓝图后续：武器成对（左右舷同型）的运行时命令与校验；舱位运行时槽位化（`mount_state` + state 2.1 迁移）；把 `apply_hull_blueprints.mjs --check` 接入发布/CI 门禁，GLB 或线稿参数变化时自动重算坐标
- [ ] 船厂改装页后续：港区 `shipyard` 站位接入真实干船坞 + 吊架（给 `port.view` / `facility_visuals.shipyard` 绑定 `SN_Dry_Dock.glb` + `SN_Shipyard_Gantry.glb`，当前是程序化 billboard）；3D 窗口按窗口宽度做机位微调，超宽屏下不要让船坞站位移到窗外
- [ ] Lua Modding SDK S1：按 [LUA_SDK_S0_API_CONTRACT.md](docs/design/LUA_SDK_S0_API_CONTRACT.md) / [LUA_SDK_S0_THREAT_MODEL.md](docs/design/LUA_SDK_S0_THREAT_MODEL.md) / [LUA_SDK_S0_TEST_MATRIX.md](docs/design/LUA_SDK_S0_TEST_MATRIX.md) 做独立 Lua Host PoC（VM 选型、中断/内存/库隔离证据、纵向样例），实验分支，禁止接入正式 ModLoader；S0 已完成
- [ ] 炮门舱段 port cassette：给明轮货轮 / 明轮客船 / 纵帆船（以及未来的船）提供“舷侧开口 + 暗腔 + 标准 `SN_Socket_GunPort` 接口”的适配模块，让 `SN_Weapon_CasemateGun` 能装到没有炮门的船上；同时解决空炮门的“暗腔”读感（当前是木制深色炮口板）
- [ ] 铁甲舰 `SN_Ironclad_LOD1.glb` 随空炮门 LOD0 重建（当前 LOD1 仍是带炮旧件；LOD 切换未接线，暂不影响运行时）
- [ ] 炮门 socket 内容镜像：`schemas/v2/hull.schema.json` 的 `hull_data` 新增可选 `gun_port_sockets` 数组并回填 Core `hulls.json`（供编辑器 / 装配器读内容，运行时仍以 GLB extras 为准）
- [ ] 剧情模式（Story Mode）：**S1 数据契约已交付**（`story_arcs` / `story_levels` Schema 2.0 草案 + 内嵌固定地图 + 只加剧情白名单 + 示例包 `sdk/templates/story_pack_iron_tide/`）；下一步 **S2 加载链**：剧情包按内容模组加载、白名单校验、注册，`story_mode.view` 列出篇章与关卡；之后 S3 首发 1 关内容 → S4 运行时（`data.story_mode` / `run.start story_level` / checkpoint 重试）→ S5 UI → S6 档案 → S7 `SNStoryMaker/`（Node Web，复用 SNModMaker 的 Schema / 校验 / 打包）。首发固定主角、每关独立、奖励不影响自由模式（成就延后）；草案见 [STORY_MODE.md](docs/design/STORY_MODE.md)
- [ ] 正式任务系统后续切片：Quest 奖励 / effects（`spawn_contract` 等）、任务发布点（酒馆 / 港务告示牌）、任务日志页；`quests` 内容类型与 `QuestService` 已随 C3 落地，契约见 [TASK_QUEST_SYSTEM.md](docs/design/TASK_QUEST_SYSTEM.md)
- [ ] 战斗后续接线：D1 已交付 6 类战斗内容 + `CombatOps` / `CombatService` / `combat.resolve|view|log`；剩余「航行遭遇接入（voyage 风险 → 遭遇表）」「敌舰可视化 / `combat_kit` 接入 ShipVisualAssembler」「舰队编成与 2v2」三项切片。`weapons` / `damage_types` / `combat_abilities` / `enemy_archetypes` / `encounter_tables` / `loot_tables` 均已 active 2.0，Core 已带 5+4+4+4+2+2 条内容；契约见 [WEAPON_CONTENT_SCHEMA.md](docs/design/WEAPON_CONTENT_SCHEMA.md) 与 [COMBAT_ARCHITECTURE_REVIEW.md](docs/specs/COMBAT_ARCHITECTURE_REVIEW.md)

- [ ] 2.5D 舞台收尾：委托 / 情报页舞台化、事件触发的 3D 场景预加载、质量档位与低配回退、L2 LOD、第三方 `.glb` 白名单评审
- [ ] 高频决策页第二轮：市场数量步进 / 即时成本、持久 `ScreenHost` 与局部数据刷新
- [ ] 存档：声明式 ID 别名与数据迁移执行器；出航失败回滚的存档路径端到端测试
- [ ] SDK / 发布：模组管理 UI（启用 / 禁用 / 优先级）、发布签名与固定哈希校验
- [ ] 建模需求 Backlog：按 [MODELING_BACKLOG.md](docs/design/MODELING_BACKLOG.md) 的批次顺序推进（M0 系列全部收口；**M1-1 architecture_kit 扩展 6 件 + M1-2 base_kit 生产建筑 5 件 + M2-1 combat_kit 敌舰 4 艘（3 类敌人）已完成**；下一批建议 M1-3 `interior_kit` 切面内景（切面约定已定：开放面 +X / 8×6×3.6 m 内景盒 / Camera_Fixed 接口），或 M0 系列运行时接线（LOD 切换 / 质量档位 / M2-5）；批次 4–5 / 敌舰的 LOD1 与运行时舞台接入均留后续）
- [ ] 遗留清理：`SN_Ship_Prototype`（`model.ship.prototype` 遗留键）仍是旧纯色 `SN_*`，可随船体资产批次一起迁移或删除遗留键
- [ ] 3D 资产收尾：帆船 / 明轮 / 模块的 Godot 导入与目标机位验收、水面性能低配档位与第二港口变体
- [ ] 起重机三件新资产接入：`SN_Mega_Gantry` / `SN_Wooden_Mast_Crane` / `SN_Hand_Jib_Crane` 的 PortStage 槽位与目标机位复核（Core manifest 资源键与 `shared_materials` 贴图已接入）
- [ ] 模型素材库接入：kit 批次 1–5 其余 33 件资产登记 Core `model.kit.*` 资源键（武器 4 件已以 `model.weapon.*` 登记，帆索 12 件以 `model.rig.*`、船体部件 4 件以 `model.ship_part.*` 登记；批次 4 新增 6 件可围合建筑件、批次 5 新增 5 件基地生产建筑），接 `ShipVisualAssembler` / 基地舞台 / PortStage 的 socket 装配与目标机位复核（目录见 `tools/modeling/kit_catalog.json`）

### 海图 / 探索

- [ ] 阶段 5 事件化海洋：航行事件预生成与预加载、事件类型（敌对 / 环境 / 奖励 / 秘境）、3D 场景触发与决策、安全航行结算（含探索途中事件与耐久告急）
- [ ] 阶段 6 固定未知岛屿与基地建设：勘探、设施建造、公开港口
- [ ] 可选：航线表体积优化（path 抽稀 / 压缩，当前 38 条边 82 KB）

### 正式版路线图

- [ ] 阶段 0：多战役存档（Content Schema 2.0 已 Finalized、tick 框架 D0 ✅、combat D1 ✅；多战役存档与其余系统待做）
- [ ] 阶段 1：广域海图与探索运行时（v2 草案提升 active，接世界生成 / 战役 `world` 分区 / 区域低细节模拟）
- [ ] 阶段 2：舰队组成与战斗（D1 已交付自动结算 + 6 类战斗内容；D2 已交付舰队 4 类 + `fleet.*` / `data.fleet`；待航行遭遇接线、敌舰可视化、舰队参与 2v2 与跨区调度；SNBattleSim 规则并入）
- [ ] 阶段 3：基地建设与生产链（接入舰队 / 战斗 / 贸易）
- [ ] 阶段 4：自动化贸易（航线、规则、风险与 tick 结算）
- [ ] 阶段 5：遗迹探索（程序化房间、远征、战利品）
- [ ] 阶段 6：整合、内容量、Mod API 2.0 与发布验收（Content Schema 2.0 已冻结）

## Recently Completed

- UI 外部贴图皮肤管线 V1（2026-10-24）：UI 从 Godot 内置绘制/StyleBoxFlat 全面切换为外部贴图控件。新增 `tools/ui/build_ui_skin.gd`（两份母版图集 → `assets/ui/skin/sn_v1/`：41 个九宫格 style、30 枚 128px 图标、6 个固定配件、派生仪表/铭牌/滚动条/复选框/焦点环 + `skin.json`）与 `tools/ui/build_ui_theme.gd`（skin.json → 纹理化 Theme，含按钮 6 变体、面板 10 变体、Badge 4、进度 3、输入/复选/滚动条/Tab/Tooltip/Popup），`tools/build_ui_skin.ps1 -Check` 作为母版一致性门禁；新增 `framework/ui/skin/sn_skin.gd`（SNSkin）作为程序化 UI 的唯一素材访问层。Shell 顶栏/HUD/导航/侧牌/底栏、8 个港口页、7 个流程页、4 个菜单页与 story 组件全部移除 `StyleBoxFlat.new()` 与十六进制业务色（Theme 0 flat、全局业务脚本 0 flat），接入 HUD/导航/侧牌/船厂分类/行动/状态图标；市场账册与委托/结算/线索用 Parchment 纸面、船厂保留 Blueprint 底板与 Glass 操作坞、HUD 用半透明钢框（TopChrome 实测 113px ≤130、状态条 50px）。换同名同尺寸贴图即整体换肤，流程见 `docs/design/UI_SKIN_PIPELINE.md`。验证：Godot 全量 **652/652**（新增 `test_ui_skin` 9 例含无 Flat/无 hex 守门）、`build_ui_skin -Check` 通过、`capture_ui -AllScreens` 两分辨率各 26 张、静态文档 `--check` 通过。

- 船厂改装页重做（2026-10-23）：改装态改为画在连续港区 3D 舞台上的工作台——`PortStage` 新增 `shipyard` 站位（干船坞/吊架设施锚点 x 14.5，镜头与目标西移 7.5 m 对准中间 3D 窗口，玩家船泊位 (14.5,0,9)），`STAGE_SCREENS` 增加 `shipyard→shipyard` 且只在 `_shipyard_refit` 时显示（正常态仍用面板内 3D 船体舞台）。页面不再有整页不透明背景：左蓝图板 / 中 3D 窗口 / 右 `SNGlassPanel` 半透明操作坞；操作坞含舰船数据卡（船名 + 重量 / 耐久 / 货舱 / 客舱 / 武器 / 剩余货舱）、七项分类、`装配 / 购买 / 打造` 三个独立页签（杂项无页签），装配页高亮可安装槽位并保留拖放安装；移除「改装蓝图 / 蓝图线稿 / 贴图剖面 / 实机渲染」等测试向文案与蓝图上方金币/耐久/重量摘要行；顶栏品牌位改为当前港口名。验证：Godot 全量 **643/643**（新增 3 例）、`ui_snapshot --tabs` / `capture_ui -Tabs` 截图、静态文档 `--check` 通过。

- 船厂改装蓝图底板（2026-10-23）：把 `docs/design/ui_controls_v1/blueprint_panel/` 的九宫格底板落地为 Theme variation `SNBlueprintPanel`（`StyleBoxTexture` + 派生运行纹理 `assets/ui/shipyard/blueprint_panel.png`：取图区域 1682×598 的 0.5 倍，九宫格 56/54、安全区 66/62）；改装态有 `blueprint_views` 时整列换底板，`SNShipView.set_blueprint_backdrop(true)` 让舞台不再自绘深色底 / 视图框 / 槽位坞条；母版留在 docs 不改，导入参数与多尺寸验收（1440×900 / 960×540 / 1280×1024 / 1920×1080 / 2560×1080）回写 layout.json 与 README；新增 `test_refit_blueprint_board_uses_the_nine_slice_panel`，船厂改装套件 11/11。

- Godot 导入隔离（2026-10-23）：新增 `SNModMaker/.gdignore`、`.agents/.gdignore`、`release/.gdignore`，阻止 Godot 扫描网页编辑器工作区（`mods/`、`exports/`）、Agent worktree 与发布暂存；清理 `SNModMaker` 下 294 个生成的 `.import`。`godot --headless --editor --quit` 扫描日志中 `SNModMaker` / `shared_materials` / `glTF` 报错均为 0，`docs/`、`dist/`、`.design/` 原有 ignore 保持不变。

- 素材页命名与分选（SNModMaker，2026-10-23）：明确内容引用资源键、`manifest.assets` 映射相对路径；资源键与存储路径改为按导入路径生成（`blueprints/ship_a/side.png` → `icon.blueprints.ship_a.side`），同名自动 `_2` 后缀，新增「导入文件夹」保留上层目录；素材页加入搜索、类型筛选（图片/模型/音频/其他）、按键/路径/大小/类型排序、引用次数提示；修改资源键会自动迁移内容里的裸键与 `asset://` 引用；Core 8 张蓝图文件改名带模型名（`<GLB>.side.png`），重建 manifest/core-index；Node 单测 64/64。

- 船体蓝图线稿与双视图（2026-10-23）：4 艘 Core 船入库 8 张 side/top 裁切线稿（manifest 资源键 + hull `blueprint_views`）；新增 `tools/modeling/blueprint/apply_hull_blueprints.mjs`，用生成器 metadata 的正交相机把 14 个武器 socket 的 `position` 投影成 `blueprint`（`--check` 可做门禁）；SNModMaker 新增工作区资产只读 API 与编辑器惰性 hydrate，Core 线稿可直接预览；船厂改装态同屏绘制侧视/俯视，并按每视图线稿等比矩形映射武器框（无 `blueprint_views` 的船体回退通用纵剖图）。

- 船体蓝图槽位编辑器（SNModMaker，2026-10-23）：新增 `js/blueprint_editor.js` + 全屏 Modal 子界面；在绑定的 `blueprint_views.side/top` 线稿上用鼠标拖动舱位 / 模块位 / 武器位标记，自动计算归一化 uv 并写回 `blueprint_position` / `blueprint`，复用现有撤销、校验与自动保存；hull 表单新增线稿资源选择、舱位与模块位数组、四分量坐标输入；`hull.schema.json` 新增可选 `base_cargo_capacity` / `blueprint_views` / `compartments[]` / `module_slots[]` / `weapon_sockets[].pair`，`blueprint` 改为可选覆盖；Node 单测 62/62。

- 船体武器槽位蓝图坐标（2026-10-23）：`weapon_sockets[].blueprint` 新增归一化 `side` / `top` Vector2 契约，Core 四艘船的 14 个槽位完成标注；`shipyard.view` 投影坐标，Godot 船厂改装蓝图绘制槽位框，并在武器分类与候选卡悬停时高亮对应槽位。

- Blender 工业蓝图线稿生成器 MVP（2026-10-23）：新增独立 `tools/modeling/blueprint/` 工具，支持 `.blend` / `.glb`、侧视/俯视/轴测正交取景、Freestyle 三档细节、透明 2048 RGBA 渲染后按 Alpha 自动裁切、确定性相机/尺寸/裁切元数据，以及逐模型 Blender 进程隔离的目录批处理；真实 `SN_Paddle_Freighter.glb` 三视图与可复现 `.blend`/`.glb` 冒烟、损坏单件不中断批次均通过。

- 核心机制补全 Phase 1（2026-10-23）：模块 condition 实际影响锅炉输出、utility 修正、货舱/客舱容量与 modifiers；船厂新增舰载武器购买/仓库/装配/卸下与持久 loadout，武器计重、hull 重配自动回仓；玩家空槽不再获得默认武器；损伤→性能下降→维修报价/扣款→性能恢复回归与船厂 UI 回归落地。设计见 [CORE_MECHANICS_PHASE1.md](docs/design/CORE_MECHANICS_PHASE1.md)，全量 639/639。

- Content Schema 2.0 Phase E（2026-10-23，**Finalized**）：`FrameworkInfo.CONTENT_SCHEMA` / `content_types.json.content_schema` 升 2.0；运行时 `ContentCompiler` 对 1.0 envelope 报「needs 2.0」，SNModMaker / Content CLI fallback 全部 2.0 且 1.0 内容报 `schema_version_frozen`；新增发布门禁 `node tools/check_content_schema_v2.mjs`；迁移/实体契约文档状态 Finalized；636/636 Godot、Node 60、CLI 64、SDK `status: ok`。

> 新完成项先记在这里，打 `v*` tag 前按版本归并进 [CHANGELOG.md](CHANGELOG.md) 并移除。

- 测试运行器并行化（2026-10-23）：`tools/test.ps1` 默认按逻辑核数（2–8）拆多个 Godot 进程并行跑套件并聚合结果与退出码；分片成员用上一轮 `.godot/test_suite_timings.json` 的套件耗时做 LPT 负载均衡（首次按声明顺序、之后自调优），另支持 `-Shards` / `-Summary` / `-Suite` / `-NoImport` 与首次资源导入；`test_runner.gd` 新增 `--list` / `--suites=` / `--shard=i/n` / `--timings=` 与 `[SUITE]` 逐套件汇总（`Tests:` 行保持兼容）；`WorldGenerator.generate` 对 `ports` 定义数已低于 `min_ports` 的不可满足 profile 直接 fail-fast，不再空转 60 次整世界生成（单个用例 65s → ~0.1s）。验证（当时快照）：全量 **605/605**，墙钟 **481s → 106s**（约 4.5×）。

- Lua Modding SDK S0（2026-10-23）：三份契约文档落地——[API 契约](docs/design/LUA_SDK_S0_API_CONTRACT.md) 全量盘点 Query 19 / Command 42 / Event 53 并给出 20 条候选 API 与版本/能力/错误协议（含 Manifest Schema v2 演进、`script.*` 能力前缀分流、脚本错误码）；[威胁模型](docs/design/LUA_SDK_S0_THREAT_MODEL.md) 44 威胁 / 28 不变量 / 22 差距 / 9 条发布阻断项；[测试矩阵](docs/design/LUA_SDK_S0_TEST_MATRIX.md) L0–L3 分级与双向覆盖、L0 门禁 G0-1..G0-8。结论：现有 Manifest 为封闭 schema + 扫描器白名单，脚本支持需 v2 Schema；42 个 Command 不得按总线名直接暴露。未改运行时代码。

- Content Schema 2.0 Phase D5（2026-10-23）：ruins 5 类 active 2.0（`ruin_archetypes` / `room_templates` / `expedition_events` / `hazard_tables` / `relics`，content.ruins.v1）；Core 5 个内容文件（2 遗迹 / 4 房间 / 3 事件 / 2 危险表 / 3 遗物）；`RuinOps` / `ExpeditionService` / `expedition.start|enter|choose|retreat` + `expedition.view`，`data.expedition` 临时远征与 `data.relics` 永久遗物、确定性房间/危险/事件/奖励；SDK `example_ruins`、最小遗迹页。**42 类 active 全部 2.0（41 定义 + patch）**、schema bundle 48（2 顶层 + 46 v2）、编辑器 45（42 runtime + 3 draft）、Core 41 内容文件 / 154 定义。验证：Godot **635/635**、Node **60/60**、CLI **64/64**、SDK `status: ok`。
- Content Schema 2.0 Phase D4（2026-10-23）：auto_trade 2 类 active 2.0（`trade_policies` / `automation_rules`，content.trade.v1）；Core 2 个内容文件（2 策略 / 5 规则）；`AutoTradeOps` / `AutoTradeService` / `AutoTradeSystem` / `auto_trade.start|stop|set_policy|pause|resume` + `auto_trade.view`，`data.trade` 惰性持久、tick 买卖/风险/规则与最小页面；SDK `example_trade`。**37 类 active 全部 2.0（36 定义 + patch）**、schema bundle 43（2 顶层 + 41 v2）、编辑器 40（37 runtime + 3 draft）、Core 36 内容文件 / 140 定义。验证（当时快照）：Godot **618/618**、Node **60/60**、CLI **64/64**、SDK `status: ok`。
- Content Schema 2.0 Phase D3（2026-10-23）：base 5 类 active 2.0（`base_sites` / `buildings` / `building_upgrades` / `production_recipes` / `worker_roles`，content.base.v1）；Core 5 个内容文件（2 站点 / 5 建筑 / 5 升级 / 3 配方 / 3 工人工种）；`BaseOps` / `BaseService` / `BaseProductionSystem` / `base.claim|build|upgrade|deposit|withdraw|hire_worker|assign_worker|start_production` + `base.view`，`data.base` 惰性持久、tick 生产与欠费停工；SDK `example_base`、最小基地页。**35 类 active 全部 2.0（34 定义 + patch）**、schema bundle 41（2 顶层 + 39 v2）、编辑器 38（35 runtime + 3 draft）、Core 34 内容文件 / 133 定义。验证（当时快照）：Godot **605/605**、Node **60/60**、CLI **64/64**、SDK `status: ok`。
- Content Schema 2.0 Phase D2（2026-10-23）：fleet 4 类 active 2.0（`ship_archetypes` / `captains` / `formations` / `fleet_doctrines`，content.fleet.v1）；Core 4 个舰队内容文件（4 船型 / 3 舰长 / 2 编队 / 2 战术）；`FleetOps` / `FleetService` / `fleet.assign_captain|set_formation|set_doctrine|add_ship|remove_ship` + `fleet.view`，`data.fleet` 惰性持久；SDK `example_fleet`。**30 类 active 全部 2.0（29 定义 + patch）**、schema bundle 36（2 顶层 + 34 v2）、编辑器 33（30 runtime + 3 draft）、Core 29 内容文件 / 115 定义。验证（当时快照）：Godot **590/590**、Node **60/60**、CLI **64/64**、SDK `status: ok`。
- Content Schema 2.0 Phase D0/D1（2026-10-23）：D0 确定性模拟时钟（`sim.pause` / `resume` / `set_speed` / `advance` + `sim.view`，`data.sim`，1 游戏小时固定步长，`sim.tick` 事件）；D1 combat（`weapons` 提升 active + `damage_types` / `combat_abilities` / `enemy_archetypes` / `encounter_tables` / `loot_tables` 5 类，共 6 个战斗类型；Core 6 个战斗内容文件；`CombatOps` / `CombatService` / `combat.resolve|view|log`）。**（当时快照）26 类 active 全部 2.0（25 定义 + patch）**、schema bundle 31（2 顶层 + 29 v2）、编辑器 28（26 runtime + 2 draft）、Core 25 内容文件。验证：Godot **566/566**、Node **58/58**、CLI **63/63**、SDK `status: ok`。
- Content Schema 2.0 Phase C · C4（Phase C 完成，全类型 2.0）：`port_archetypes → port_templates`、`starting_builds → starting_scenarios`、`roles → crew_roles`、`strategies → boiler_strategies`、`events → voyage_events`；`map_profiles` 退役（`map_configs` 取代）；`contracts` / `patches` 升 2.0，删除 1.0 回退路径（RunFactory / ContentRefs / 存档 resolver）。**20 个 active 类型全部 2.0（19 定义 + patch）**；schema bundle 26（2 顶层 + 24 v2）、编辑器 23（20 runtime + 3 draft）、Core 19 内容文件。验证：Godot **527/527**、Node **58/58**、CLI **63/63**、SDK `status: ok`。
- Content Schema 2.0 Phase C · C3（委托/任务解耦）：新增 `quests` active 2.0（kind story/guide/system、stages/objectives 复用剧情 DSL、tracking/prerequisites；无运输 payload）；core `quests.json` 2 条；新增 `QuestOps`/`QuestService` 与 `data.quests` 持久实例（惰性 ensure），委托 `accept_offer`/教程主线挂接生成追踪实例、完成关闭；`task.view` 增加 `kind:"quest"` 聚合（contract 实例不重复渲染），Shell 转发 `cmd:*`/`ui:*` 给 quest.observe；`content.quests.v1` capability 与 `quest.start|complete|observe` 命令。验证：Godot **525/525**、Node **55/55**、CLI **62/62**、SDK `status: ok`。
- README 瘦身（2026-10-22）：根 README 从 323 行压到 115 行、SNModMaker README 从 479 行压到 63 行；详细进度拆到 `docs/design/PROJECT_STATUS.md`、Core 内容基线拆到 `docs/design/CORE_CONTENT.md`、实现边界拆到 `docs/design/KNOWN_LIMITS.md`，SNModMaker 使用/开发细节拆到 `SNModMaker/docs/{USER_GUIDE,DEVELOPMENT}.md`；README 改为「按需读取」索引。

- SN SDK Schema 2.0 兼容（2026-10-22）：`sdk/validate.gd` 新增 `--mode=runtime|draft`（默认 runtime 保持旧调用兼容；runtime 显式拒绝未激活草案并输出结构化 `inactive_content_type`，draft 对草案 / 混合模组做静态 Schema 校验）；`sdk/pack_mod.gd --release` 打包前跑真实 runtime 校验、草案或 error 时拒绝且 `.snavmod.zip` 结构不变；新增 `sdk/validation_core.gd` 共享实现（扫描根去重，`--mod-root=dev_mods/core` 不再重复加载 core），类型 / 版本只读 `content_types.json`；示例补 1.0 `example_roles_1_0`、混合 `example_mixed_roles_items` 与草案模板 `draft_weapons_pack`；新增 `framework/tests/cases/test_sdk_validation.gd`（11 用例）并更新 release workflow 的 runtime / draft / 发布拦截门禁。验证：SDK 套件 11/11、Godot 全量 507/507、`gen_content_types --check` 全绿（`docs/static` 待 Lead 统一生成）。

- 建模 M2-1 `combat_kit` 敌舰（批次 9）：4 艘敌舰 = **3 类敌人**（Light ×2 / Medium / Heavy），海盗单桅 `SN_Enemy_Pirate_Sloop` / 武装商船 `SN_Enemy_Merchant_Armed` / 铁甲舰变体 `SN_Enemy_Ironclad_Raider` / 小型炮艇 `SN_Enemy_Gunboat`，**31,324 / 32,400 tri**、55 mesh（GLB 节点合计 86）+ **16 武器 socket + 8 炮门 socket**、9 张共享贴图（无新增，新增 `assets/models/combat/` 类别目录 + Core 副本）。复用现有船体站表放样 + `rig_kit` / `ship_parts`，**不烘炮**（甲板 socket `hull-sockets@1`、炮门 socket `hull-gunports@1`，复用 `SN_Weapon_CasemateGun`）；4/4 GLB 自检 ALL OK、独立 Verifier 只读验收 0 failures、Godot 用例守护（4 GLB 加载 / tri 锁定 / socket 契约）；预览 8 单件 + 1 lineup。运行时武器挂载与敌人内容 Schema 留后续。

- UI 视觉基准 V1：图二确认为约束性的 `SN Visual Baseline V1`，图一保留为非生产承诺的 `UI Kit Concept V1`；生产视觉收敛为黄铜钢板、羊皮纸、蓝图、布旗四个材质族，并冻结基础尺寸、九宫格、安全文字区、字体、颜色、交互状态、动效与边框治理。见 [UI_VISUAL_BASELINE.md](docs/design/UI_VISUAL_BASELINE.md) / [UI_FOUNDATION_SPEC_V1.md](docs/design/UI_FOUNDATION_SPEC_V1.md)。

- UI 页面视觉原型 V1：按统一顶部资源带与布旗导航，完成总览/HUD、市场、委托、船厂、补给、酒馆/情报、海图/出航确认、抵达/航程结算 8 张 16:9 高保真原型；保持四材质族与状态语义，明确原型不等于生产切图。见 [UI_SCREEN_PROTOTYPES_V1.md](docs/design/UI_SCREEN_PROTOTYPES_V1.md)。

- SNModMaker / SNBattleSim Windows 一键启动：两个子目录新增可双击的 `start.bat`，自动检测 Node.js；缺失时优先用 winget 安装最新 LTS，并以 nodejs.org 官方 MSI 作为回退，随后启动本地服务并打开浏览器。

- 剧情模式 S1（数据契约）：新增 `schemas/v2/story_arc.schema.json` / `story_level.schema.json`（固定地图内嵌 `map.fixed`、叙事 brief/beats/debrief、难度旋钮、checkpoint、仅成就类奖励；阶段复用 `v2/common.schema.json#/$defs/story_stage`）；`content_types.json` 登记 3 类草案（weapons + 2 类剧情，`content.story.v1`，bundle 31 个 Schema）；SNModMaker `catalog.js` 补剧情标签 / 默认值 / 枚举，`validate.js` 加故事包白名单（`story_pack_off_whitelist`）与篇章 / 关卡语义（主角未知、缺 checkpoint、beats 指向未知阶段、固定地图断连、fail 默认不在 allow 等）；`sdk/templates/story_pack_iron_tide/` 1 篇章 + 2 关卡 + 中英文本示例（CLI validate 0 error / 2 个预期 draft warning）；Node 53+60 用例、Godot 全量通过。

- Content Schema 2.0 Phase B · B0：执行契约刷新到 [Draft 2](docs/design/WORLD_SCHEMA_V2_RUNTIME.md)（按 4.1–4.5 的 `map_profile` 现状补 31 键 `exploration`、`twin_world_size`、`story`、15 处生产读取点，新增 D13 教程 story 归属）；同步迁移方案状态；重新同步 SNModMaker 嵌入式 schema bundle（Node 恢复 50/50）。基线证据：Godot 419/419、`gen_content_types --check`、`gen_static_docs --check`、SDK core 校验全绿。
- Content Schema 2.0 Phase B · B1：8 类草案提升 active + 新增 `map_configs`；`schemas/v2/map_config.schema.json`（31 键 exploration、`twin_world_size`、`story`）+ `world_profiles.edge_density` + `start_profiles.map_config`；`ContentTypes` 16 → 25、编辑器 TYPES 26 项（草案只剩 weapons）、schema bundle 29 个；编辑器 catalog 增加 `map_configs` 默认值；框架 `test_content_versions` / `test_schema_v2_drafts` 与 SNModMaker/CLI 测试同步改写。
- Content Schema 2.0 Phase B · B2：`CrossReferenceValidator` 9 个 Phase B `_check_*` + `ref_inactive_type`（计划类型激活后自动升级硬校验）+ faction 自指 / map_config archetype 组合规则；`CoreCompletenessChecker` Phase B 规则（Core presence gate，B4 落盘自动开启）；`FrameworkInfo.CAPABILITIES` 增加 `content.world.v1` / `content.campaign.v1`；新增 `test_world_schema_refs`（16 例）与 `test_world_completeness`（13 例）。
- Content Schema 2.0 Phase B · B3：`CampaignFactory`（MapGenerationSpec + region/site/route/faction/discovery 装配器）消费 `start_profiles`；`run.start` 可选 `start_profile`、`campaign.view`；`ContentRefs.map_config()` 解析器 + 12 处运行时 resolver 切换（含 story/exploration/clue，D13 教程 v2 打通）；`initialize_markets` 抽公共；`game_state` 补 `campaign.setup` / `world.regions/sites` / faction 字段惰性默认；新增 `test_campaign_assembly`（10 例）与 `test_campaign_start`（6 例）。
- Content Schema 2.0 Phase B · B4：Core 新增 9 个 v2 内容文件（world_profiles 1 / map_configs 1 / regions 5 / sites 6 / route_templates 3 / weather_profiles 2 / factions 3 / discoveries 7 / start_profiles 2）；`exploration` 31 键与 `story` 20 stages 原样迁入 `map_configs`（deepEqual）；本地化各 +62 键；manifest content 24 / capabilities 4；`core-index.js` 同步（82 definitions）。SDK validate `status: ok`。
- Content Schema 2.0 Phase B · B5：`SaveMigrations.prepare_for_save()` 保存时快照 `ContentTypes.SCHEMA_VERSIONS`（1.0 新 run 创建即写）；加载 `_ensure_content_versions()` 对旧档推断 `starting_builds/map_profiles → 1.0`、按注册表补齐并写 `content_versions inferred`；已记录版本不一致只写 `content version drift` warning，不阻塞加载/不重排世界；`test_save_migration` 8 例 + `test_save_load` hash 往返全绿。
- Content Schema 2.0 Phase B · B6（收尾）：编辑器 `capability_undeclared` 改为按 `schemaVersion = 2.0` 判定并按 capability 去重、`draft_content` 只对草案；G8 导出守卫改为 `runtimeSupportsFile/unsupportedContentFiles`（草案/未知类型/版本不符拦截，提升类型可部署）；CLI `types` 标 `[runtime 2.0]`、`describe` 显示运行时 2.0、`new --draft` 接受剩余草案；release workflow 加入 SNModMaker + Content CLI 两个 Node 门禁。验证：Node 50/50、CLI 58/58、Godot 472/472、生成器 `--check` 全绿。
- Content Schema 2.0 Phase C · C1：5 类模块（boilers/cargo/navigation/safety/cabins）合并为 `modules` 2.0（`data.v2_category` = boiler/cargo/utility/cabin；utility 按 `module.navigation`/`module.safety` tags 路由），hulls 升 2.0；core `modules.json` 12 条 + `hulls.json` 4 条，旧 ID 统一 `core:module/*`；新增 `ModuleOps` 与船厂分类 UI、完整性按 category、SDK example 改 modules；无旧类型/别名。验证：Godot **491/491**、Node **53/53**、CLI **61/61**、SDK core `status: ok`。
- Content Schema 2.0 Phase C · C2：goods + materials 合并为 `items` 2.0（`data.crafting_material` 标志，字段并集），core `items.json` 12 条 `core:item/*`，全量引用/`item.core.*` 本地化/编辑器/CLI/SDK template/运行时统一到 `ContentTypes.ITEM`；新增 `test_item_categories`，修掉截图脚本旧 ID 与模板 capability。验证：Godot **508/508**、Node **53/53**、CLI **61/61**、SDK `status: ok`。
- 建模 M1-1 architecture_kit 扩展（批次 4）：6 件可围合建筑件（围墙段 / 大门 / 道路 / 装卸平台 / 仓库变体 / 工坊扩建），**12,584 / 16,800 tri**、39 mesh / 37 socket / 82 节点 / 117 图元、11 张共享贴图（无新增）；6/6 GLB 自检 ALL OK、独立 Verifier 只读验收 0 failures、Godot 运行时用例 2 例；`kit_catalog.json` v1.4（32 件 / 54,642 tri、4 条基地装配配方）；预览 12 单件 + 3 张拼装。接入类工作（PortStage / 基地舞台）与 LOD1 留后续。
- 建模 M1-2 base_kit 生产建筑（批次 5）：5 件（锯木厂 / 冶炼炉 / 铸造车间 / 仓库堆场 / 防御塔），**15,948 / 19,000 tri**、42 mesh / 37 socket / 84 节点 / 159 图元、11 张共享贴图（无新增，新增 `assets/models/base/` 类别目录）；5/5 GLB 自检 ALL OK、独立 Verifier 只读验收、Godot 运行时用例 2 例；`kit_catalog.json` v1.5（37 件 / 70,590 tri、4 条生产链配方）；预览 10 单件 + 3 张拼装。3 轮 Builder 返工修掉浇包悬空/互穿、探照灯悬空、梯子无过桥、Foundry 正立面被墙吞没（射线复核）；接入类工作（基地舞台 / PortStage）与 LOD1 留后续。
