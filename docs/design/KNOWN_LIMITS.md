# 已知边界与暂缓项（Known Limits）

> 从 README 拆出的实现边界清单；判断某个需求是否已实现前先读这里，避免把“当前限制”当成 bug。

- 材料随船运输仍计入货舱容量；GDD 9.1 中“材料不占货舱容量”本轮只对未安装模块（transit）实现。
- 船厂仓库/运输 UI 为基础版：材料按固定 5 件批量存取，尚无数量步进或批量选择。
- 通关总结页为数据化总结，不含航线回放、成就与统计对比。
- 船厂改装态纵剖图是一张 2D 授权贴图；正常态已是真实 3D 船体舞台（固定机位、只做表现，不含环绕与场景热点），3D 船体资产缺失时回退程序化 2D 占位。贴图与当前可玩船型视觉也不完全一致（纵剖图 / 船卡为铁甲舰风格）。**主界面已是全窗 `PortStage` + 紧凑 HUD（含资源图标）+ 主题化两侧招牌 + 底部状态条 + 详细总览抽屉；港口街景 normal 47 件与 `port.diorama` 已接线，设施/街景/玩家船静态合批后实测 63/56 draw calls；剩余 2.5D 工作是港务/市场等独立舞台、出航/进港演出、质量档位/低配回退与 L2 LOD。**
- **运行时船体装配的边界**：帆索只对实测 1:1 吻合的船体做套件替换（PF 桅/桁、SF 桅），其余保留 GLB 内烘焙帆索，避免双层；kit 帆面尺寸与烘焙件不符，整桅帆重挂留待后续批次。D1 起 `weapons` 已是 active 2.0，战斗结算（`CombatOps`）用 `hull_data.weapon_sockets` + 武器内容解析玩家默认武器；但游戏内尚无武器购买 / 装配入口，`state.ship.weapon_loadout` 仍主要由预览注入 —— 视觉装配器与舞台透传已就绪，玩家 loadout UI 接上即可；截图工具注入的预览 loadout 只是装配证据。港口舞台会把玩家船烘进静态批次，合批后武器瞄准 / 后坐句柄失效（战斗层接入时需要不合批旁路）。详见 [SHIP_VISUAL_ASSEMBLY.md](docs/design/SHIP_VISUAL_ASSEMBLY.md) §9。
- **内容资产全部走模组**：船体/模块/道具模型与港口横幅随 `core` 模组发布（`dev_mods/core/assets/**` + manifest `model.*`/`banner.*` 键），发布包 PCK 已排除 `assets/models/*`；运行时由 `ContentAssetLoader` 读取模组内原始 `.glb`/`.png`。本体内只保留框架资源（代码、Theme/字体、UI 外壳图、音频、水面 shader/材质/贴图）。新增内容模型请放 `dev_mods/core/assets/models/<category>/` 后重新 `pack_core`，不要放回 `res://assets/models`。
- UI 是最小可用外壳，设施名称部分为中文硬编码；海图可按已访问港口打开上次在港的市场快照。
- 全屏航海图页已接入 Shell（M 键 / 导航「海图」/ 状态条「海图 ▶」/ 港口招牌；出航确认在页内弹窗），且 `run.start` 会生成与对局地图同 ID 的坐标空间孪生世界（`state.data["world_map"]`），海图在真实对局直接出图：起港已发现/访问/当前并揭示迷雾，抵达自动记录访问并揭示泊位与沿途迷雾。孪生世界的连通图是自身 MST 图，与抽象地图航线不完全一致（出航仍按抽象地图邻居可航行）；阶段 3 航行演出已把这些航线画出来（船只沿海图航线行进），但出航判定仍走抽象地图，二者的统一留待后续阶段。旧存档（无 `world_map`）海图显示无数据提示，按需重开新局。
- 存档已支持 save schema 1.x → 2.0 迁移（回填 campaign 元数据与分区，state/content schema 分离）；模块实例表 `ship.module_instances` 与 campaign 分区均由惰性 ensure 补齐；声明式 ID 别名迁移仍未实现，新字段继续通过惰性 ensure 补齐。
- 模块 condition 目前只影响失效标记与维修费用，尚未改变航速/容量等派生属性；统一 Module 迁移（definition_id 移入实例）与战斗期性能影响在后续阶段。
- **Content Schema 2.0 Phase B/C/D0–D5 已落地**：42 个 active 类型全部为 2.0（0 个 1.0 runtime；D1 新增 6 个战斗类型、D2 新增 4 个舰队类型、D3 新增 5 个基地类型、D4 新增 2 个自动贸易类型、D5 新增 5 个遗迹类型）；`CampaignFactory` 从 `start_profiles` / `world_profiles` / `map_configs` / `starting_scenarios` 装配战役并写入 `campaign.setup/content_versions`；`map_profiles` 已退役，`map_configs` 是唯一场景配置；D0 的 `data.sim`、D1 的 `data.combat` 与 D2 的 `data.fleet` 惰性持久化；编辑器草案为 `story_arcs` / `story_levels` / `combat_ai_profiles` 3 类（schema bundle 48 个）。**「运行时不加载」不是静默忽略**：未注册类型 / 版本不符仍按 mod error 拒绝，Core 必需包会让启动进入 `Degraded`。
- **剧情模式 S1 数据契约已落地**：新增 `schemas/v2/story_arc.schema.json` / `story_level.schema.json`（内嵌固定地图 `map.fixed`、共享 story_stage DSL、叙事 brief / beats / debrief、难度旋钮、checkpoint 重试、仅成就类奖励），`content_types.json` 把 `story_arcs` / `story_levels` 登记为 Schema 2.0 草案（capability `content.story.v1`，schema bundle 35 个）；SNModMaker / Content CLI 可编辑与校验（`draft_content` 警告、`story_pack_off_whitelist` 白名单、篇章 / 关卡语义），示例包见 `sdk/templates/story_pack_iron_tide/`；运行时加载链（S2）与后续 UI / 档案 / SNStoryMaker 仍在路线图中，草案见 [STORY_MODE.md](docs/design/STORY_MODE.md)。
- 无头退出时 Godot 会报告静态注册表/脚本的 ObjectDB 泄漏警告；测试退出码仍为 0，不影响运行。
