# TODO

> 只保留最近 10–15 项已完成与尚未实现的目标；逐条实现细节见 git 历史。
> 发布约定：打 `v*` tag 前把 `Recently Completed` 里的条目按版本归并进 [CHANGELOG.md](CHANGELOG.md)（只写有意义的功能 / 变更），并从本文件移除。

## In Progress

- [ ] SNBattleSim 战术状态机工作台：人工浏览器验收（节点拖拽、转移表、状态机 CRUD、舰船挂载）后评估是否并入正式战斗
- [ ] 海图阶段 3 验收反馈 F1–F4：离港要"驶离"而不是平移；镜头俯角加大到竖直再拉升、云层后海图先铺满再回落；海图上的船必须沿航线移动，不能两点直线

## Pending

### 近期
- [ ] 炮门舱段 port cassette：给明轮货轮 / 明轮客船 / 纵帆船（以及未来的船）提供“舷侧开口 + 暗腔 + 标准 `SN_Socket_GunPort` 接口”的适配模块，让 `SN_Weapon_CasemateGun` 能装到没有炮门的船上；同时解决空炮门的“暗腔”读感（当前是木制深色炮口板）
- [ ] 铁甲舰 `SN_Ironclad_LOD1.glb` 随空炮门 LOD0 重建（当前 LOD1 仍是带炮旧件；LOD 切换未接线，暂不影响运行时）
- [ ] 炮门 socket 内容镜像：`schemas/v2/hull.schema.json` 的 `hull_data` 新增可选 `gun_port_sockets` 数组并回填 Core `hulls.json`（供编辑器 / 装配器读内容，运行时仍以 GLB extras 为准）
- [ ] 剧情模式（Story Mode）：**S1 数据契约已交付**（`story_arcs` / `story_levels` Schema 2.0 草案 + 内嵌固定地图 + 只加剧情白名单 + 示例包 `sdk/templates/story_pack_iron_tide/`）；下一步 **S2 加载链**：剧情包按内容模组加载、白名单校验、注册，`story_mode.view` 列出篇章与关卡；之后 S3 首发 1 关内容 → S4 运行时（`data.story_mode` / `run.start story_level` / checkpoint 重试）→ S5 UI → S6 档案 → S7 `SNStoryMaker/`（Node Web，复用 SNModMaker 的 Schema / 校验 / 打包）。首发固定主角、每关独立、奖励不影响自由模式（成就延后）；草案见 [STORY_MODE.md](docs/design/STORY_MODE.md)
- [ ] 正式任务系统 Phase B：`quests` 内容类型 + `QuestService`（任务链、目标事件、前置 / 奖励、发布点、任务日志页）；契约见 [TASK_QUEST_SYSTEM.md](docs/design/TASK_QUEST_SYSTEM.md)
- [ ] 战斗内容 Schema 2.0 其余类型：`damage_types` / `enemy_archetypes` / `encounter_tables` / `loot_tables`（`weapons` 草案已落地，见 [WEAPON_CONTENT_SCHEMA.md](docs/design/WEAPON_CONTENT_SCHEMA.md)）；保持 `planned`，先补 Schema + 有效/无效样本
- [ ] 武器内容接入运行时：`weapons` 进 runtime types / 注册表，`ShipVisualAssembler` 改读内容 + GLB 节点（船体 socket 镜像转正），SNBattleSim 的 `kind` 行为与命中/齐射/冷却规则并入战斗结算；同时补齐 `yaw_limit_deg` / `mount_pad_*`、统一 socket 索引与 `mast_key` 口径。**类型提升前不要把 2.0 `weapons` 写进 Core**（运行时会按 mod error 拒绝，Core 必需包 → `Degraded`）；当前 5 件模拟器武器落在编辑器「舰载武器包」模板

- [ ] 2.5D 舞台收尾：委托 / 情报页舞台化、事件触发的 3D 场景预加载、质量档位与低配回退、L2 LOD、第三方 `.glb` 白名单评审
- [ ] 高频决策页第二轮：市场数量步进 / 即时成本、持久 `ScreenHost` 与局部数据刷新
- [ ] 存档：声明式 ID 别名与数据迁移执行器；出航失败回滚的存档路径端到端测试
- [ ] SDK / 发布：模组管理 UI（启用 / 禁用 / 优先级）、发布签名与固定哈希校验
- [ ] 建模需求 Backlog：按 [MODELING_BACKLOG.md](docs/design/MODELING_BACKLOG.md) 的批次顺序推进（M0 系列全部收口；**M1-1 architecture_kit 扩展 6 件 + M1-2 base_kit 生产建筑 5 件 + M2-1 combat_kit 敌舰 4 艘（3 类敌人）已完成**；下一批建议 M1-3 `interior_kit` 切面内景（切面约定已定：开放面 +X / 8×6×3.6 m 内景盒 / Camera_Fixed 接口），或 M0 系列运行时接线（LOD 切换 / 质量档位 / M2-5）；批次 4–5 / 敌舰的 LOD1 与运行时舞台接入均留后续）
- [ ] 遗留清理：`SN_Ship_Prototype`（`model.ship.prototype` 遗留键）仍是旧纯色 `SN_*`，可随船体资产批次一起迁移或删除遗留键
- [ ] 3D 资产收尾：帆船 / 明轮 / 模块的 Godot 导入与目标机位验收、水面性能低配档位与第二港口变体
- [ ] 起重机三件新资产接入：`SN_Mega_Gantry` / `SN_Wooden_Mast_Crane` / `SN_Hand_Jib_Crane` 的 PortStage 槽位与目标机位复核（Core manifest 资源键与 `shared_materials` 贴图已接入）
- [ ] 模型素材库接入：kit 批次 1–5 其余 33 件资产登记 Core `model.kit.*` 资源键（武器 4 件已以 `model.weapon.*` 登记，帆索 12 件以 `model.rig.*`、船体部件 4 件以 `model.ship_part.*` 登记；批次 4 新增 6 件可围合建筑件、批次 5 新增 5 件基地生产建筑），接 `ShipVisualAssembler` / 基地舞台 / PortStage 的 socket 装配与目标机位复核（目录见 `tools/modeling/kit_catalog.json`）
- [ ] Content Schema 2.0 迁移（分层）：Phase A + Phase B（B0–B6）+ **Phase C · C1–C3 已完成**（C1：5 类模块→`modules` 2.0 + `hulls` 2.0；C2：goods+materials→`items` 2.0（`crafting_material`）；C3：`quests` 2.0 + 持久 `data.quests` + QuestService，委托接取生成追踪实例；active 21、编辑器 24（21 runtime + 3 draft））。下一步 **C4 残留类型 2.0 化**（port_archetypes/map_profiles/starting_builds/events/roles/strategies/patches/contracts），之后 D 其余系统 → E 冻结 1.0。开发期不保留旧档/旧模型兼容。方案：[CONTENT_SCHEMA_V2_MIGRATION.md](docs/design/CONTENT_SCHEMA_V2_MIGRATION.md) / [WORLD_SCHEMA_V2_RUNTIME.md](docs/design/WORLD_SCHEMA_V2_RUNTIME.md)

### 海图 / 探索

- [ ] 阶段 5 事件化海洋：航行事件预生成与预加载、事件类型（敌对 / 环境 / 奖励 / 秘境）、3D 场景触发与决策、安全航行结算（含探索途中事件与耐久告急）
- [ ] 阶段 6 固定未知岛屿与基地建设：勘探、设施建造、公开港口
- [ ] 可选：航线表体积优化（path 抽稀 / 压缩，当前 38 条边 82 KB）

### 正式版路线图

- [ ] 阶段 0：Content Schema 2.0 系统类型、多战役存档、tick 模拟框架
- [ ] 阶段 1：广域海图与探索运行时（v2 草案提升 active，接世界生成 / 战役 `world` 分区 / 区域低细节模拟）
- [ ] 阶段 2：舰队组成与战斗（先自动结算，再战术层）；模块 condition 进入派生属性；战斗内容 Schema 2.0（`weapons` 草案、船体 socket 镜像与编辑器支持已完成；**`combat_kit` 敌舰 4 艘 / 3 类敌人资产 + 16 武器 socket + 8 炮门 socket 已交付**，待接 `ShipVisualAssembler` 武器挂载与遭遇表；`enemy_archetypes` / `encounter_tables` / `loot_tables` 待做）；SNBattleSim 规则并入
- [ ] 阶段 3：基地建设与生产链（接入舰队 / 战斗 / 贸易）
- [ ] 阶段 4：自动化贸易（航线、规则、风险与 tick 结算）
- [ ] 阶段 5：遗迹探索（程序化房间、远征、战利品）
- [ ] 阶段 6：整合、内容量、Mod API 2.0 / Content Schema 2.0 冻结与发布验收

## Recently Completed

> 新完成项先记在这里，打 `v*` tag 前按版本归并进 [CHANGELOG.md](CHANGELOG.md) 并移除。

- Content Schema 2.0 Phase C · C3（委托/任务解耦）：新增 `quests` active 2.0（kind story/guide/system、stages/objectives 复用剧情 DSL、tracking/prerequisites；无运输 payload）；core `quests.json` 2 条；新增 `QuestOps`/`QuestService` 与 `data.quests` 持久实例（惰性 ensure），委托 `accept_offer`/教程主线挂接生成追踪实例、完成关闭；`task.view` 增加 `kind:"quest"` 聚合（contract 实例不重复渲染），Shell 转发 `cmd:*`/`ui:*` 给 quest.observe；`content.quests.v1` capability 与 `quest.start|complete|observe` 命令。验证：Godot **518/518**、Node **54/54**、CLI **62/62**、SDK `status: ok`。
- README 瘦身（2026-10-22）：根 README 从 323 行压到 115 行、SNModMaker README 从 479 行压到 63 行；详细进度拆到 `docs/design/PROJECT_STATUS.md`、Core 内容基线拆到 `docs/design/CORE_CONTENT.md`、实现边界拆到 `docs/design/KNOWN_LIMITS.md`，SNModMaker 使用/开发细节拆到 `SNModMaker/docs/{USER_GUIDE,DEVELOPMENT}.md`；README 改为「按需读取」索引。

- SN SDK Schema 2.0 兼容（2026-10-22）：`sdk/validate.gd` 新增 `--mode=runtime|draft`（默认 runtime 保持旧调用兼容；runtime 显式拒绝未激活草案并输出结构化 `inactive_content_type`，draft 对草案 / 混合模组做静态 Schema 校验）；`sdk/pack_mod.gd --release` 打包前跑真实 runtime 校验、草案或 error 时拒绝且 `.snavmod.zip` 结构不变；新增 `sdk/validation_core.gd` 共享实现（扫描根去重，`--mod-root=dev_mods/core` 不再重复加载 core），类型 / 版本只读 `content_types.json`；示例补 1.0 `example_roles_1_0`、混合 `example_mixed_roles_items` 与草案模板 `draft_weapons_pack`；新增 `framework/tests/cases/test_sdk_validation.gd`（11 用例）并更新 release workflow 的 runtime / draft / 发布拦截门禁。验证：SDK 套件 11/11、Godot 全量 507/507、`gen_content_types --check` 全绿（`docs/static` 待 Lead 统一生成）。

- 建模 M2-1 `combat_kit` 敌舰（批次 9）：4 艘敌舰 = **3 类敌人**（Light ×2 / Medium / Heavy），海盗单桅 `SN_Enemy_Pirate_Sloop` / 武装商船 `SN_Enemy_Merchant_Armed` / 铁甲舰变体 `SN_Enemy_Ironclad_Raider` / 小型炮艇 `SN_Enemy_Gunboat`，**31,324 / 32,400 tri**、55 mesh（GLB 节点合计 86）+ **16 武器 socket + 8 炮门 socket**、9 张共享贴图（无新增，新增 `assets/models/combat/` 类别目录 + Core 副本）。复用现有船体站表放样 + `rig_kit` / `ship_parts`，**不烘炮**（甲板 socket `hull-sockets@1`、炮门 socket `hull-gunports@1`，复用 `SN_Weapon_CasemateGun`）；4/4 GLB 自检 ALL OK、独立 Verifier 只读验收 0 failures、Godot 用例守护（4 GLB 加载 / tri 锁定 / socket 契约）；预览 8 单件 + 1 lineup。运行时武器挂载与敌人内容 Schema 留后续。

- UI 视觉基准 V1：图二确认为约束性的 `SN Visual Baseline V1`，图一保留为非生产承诺的 `UI Kit Concept V1`；生产视觉收敛为黄铜钢板、羊皮纸、蓝图、布旗四个材质族，并冻结基础尺寸、九宫格、安全文字区、字体、颜色、交互状态、动效与边框治理。见 [UI_VISUAL_BASELINE.md](docs/design/UI_VISUAL_BASELINE.md) / [UI_FOUNDATION_SPEC_V1.md](docs/design/UI_FOUNDATION_SPEC_V1.md)。

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
