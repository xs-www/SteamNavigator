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
- [ ] 高频决策页第二轮：持久 `ScreenHost` 与局部数据刷新（市场数量步进 / 即时成本已由「图标直接交易」取代）
- [ ] 市场 V2：从「中间 3D 港区窗口」推进到 3D 船内交互（左侧背包退化为船体货舱热点，复用 `market_item` / `cargo_item` 拖拽载荷）；补给（煤 / 水）也改图标直接交互；商品分类筛选 / 分组；买卖音效与拖拽动效；用正式美术替换 10 张 SVG 占位图标（保持 `icon.item.*` 同名同尺寸即可）。（2026-10-26：市场商品「拿起 / 放下」与交互处浮出提示已落地；剩余补给图标直接交互、分类筛选、买卖音效与正式美术）
- [ ] 可复用浮层视觉重排（等 UI 素材到位）：`SNCarryGhost` 当前是「图标 + 名称 / ×N / 预计消费 / 拿起提示」四行紧凑布局，偏功能化，用户反馈观感一般、留待素材到位再改。重排方向：更大图标、名称与数量同行、金额用徽标 / 右对齐、把「点船舱 / 仓库落点放下」这类长提示迁到 `SNInteractionHint` 做一次性提示；同时把运行时 tint 收进 Theme 变体（`SNCarryGhostPanel` / `SNHintSuccessPanel` / `SNHintErrorPanel`）让编辑器所见即运行时。改动范围仍只是 `.tscn` + `_ensure_refs()` 路径 + 结构断言，契约见 [UI_SCENE_MIGRATION.md](docs/specs/UI_SCENE_MIGRATION.md)。
- [ ] 存档：声明式 ID 别名与数据迁移执行器；出航失败回滚的存档路径端到端测试
- [ ] SDK / 发布：模组管理 UI（启用 / 禁用 / 优先级）、发布签名与固定哈希校验
- [ ] 建模需求 Backlog：按 [MODELING_BACKLOG.md](docs/design/MODELING_BACKLOG.md) 的批次顺序推进（M0 系列全部收口；**M1-1 architecture_kit 扩展 6 件 + M1-2 base_kit 生产建筑 5 件 + M2-1 combat_kit 敌舰 4 艘（3 类敌人）已完成**；下一批建议 M1-3 `interior_kit` 切面内景（切面约定已定：开放面 +X / 8×6×3.6 m 内景盒 / Camera_Fixed 接口），或 M0 系列运行时接线（LOD 切换 / 质量档位 / M2-5）；批次 4–5 / 敌舰的 LOD1 与运行时舞台接入均留后续）
- [ ] 遗留清理：`SN_Ship_Prototype`（`model.ship.prototype` 遗留键）仍是旧纯色 `SN_*`，可随船体资产批次一起迁移或删除遗留键
- [ ] 3D 资产收尾：帆船 / 明轮 / 模块的 Godot 导入与目标机位验收、水面性能低配档位与第二港口变体
- [ ] 起重机三件新资产接入：`SN_Mega_Gantry` / `SN_Wooden_Mast_Crane` / `SN_Hand_Jib_Crane` 的 PortStage 槽位与目标机位复核（Core manifest 资源键与 `shared_materials` 贴图已接入）
- [ ] 模型素材库接入：kit 批次 1–5 其余 33 件资产登记 Core `model.kit.*` 资源键（武器 4 件已以 `model.weapon.*` 登记，帆索 12 件以 `model.rig.*`、船体部件 4 件以 `model.ship_part.*` 登记；批次 4 新增 6 件可围合建筑件、批次 5 新增 5 件基地生产建筑），接 `ShipVisualAssembler` / 基地舞台 / PortStage 的 socket 装配与目标机位复核（目录见 `tools/modeling/kit_catalog.json`）

- [ ] 门面港（terminal）预算收尾：给 `SN_Grand_Harbour_Terminal` 出 LOD1 或按门面模式重设 60k tri 预算（当前门面四站位 83.5k tris，terminal 自身 59,450）；60 m 级 freight / ironclad 在 0.75 缩放下水平投影略出左缘，按船体长度自适应缩放
- [ ] 剧情引导后续：focus 遮罩覆盖更多引导阶段（depart_brief 需玩家在海图选目的港 + 确认，单目标遮罩会锁死，需多目标/步骤式引导）；航行演出 2–9 s 压缩导致抵达结算在启航后 4–6 s 出现，观感需复核
- [ ] 委托后续：`accept_offer` 命令层拒绝未发现目的地的实例（本轮只做视图过滤，UI 无路径提交隐藏实例）；结算页无期限交付的「准时」徽标文案适配

### 运行时性能 / 闪退（2026-10-24 取证，见 [RUNTIME_PERF_REPORT.md](docs/design/RUNTIME_PERF_REPORT.md)）

- [x] **P0 退出崩溃兜底（已落地 2026-10-24，需随引擎升级移除）**：`auto_accept_quit=false` + `NOTIFICATION_WM_CLOSE_REQUEST` → `_graceful_quit()` → `_prepare_quit()`（卸舞台 / 释放 SubViewport / 清页面树 / `ContentAssetLoader.clear_cache()` / `FrameworkRuntime.shutdown()` / `force_sync()`）。**应用层清理不足以避免引擎 GLES3 teardown 崩溃**，故对「本会话渲染过 3D 且非编辑器构建」补 `OS.kill()` 兜底；实测「进 3D 舞台 → 点 X」WER 不再新增（4→4）。**待引擎升级后移除 `_had_3d_stage` 兜底并复测**
- [x] **P0 交互重建降本 · 阶段 1（已落地 2026-10-24）**：`_port_name()` 按 run seed 缓存（13.5 → 0 ms/次）、`QueryBus.begin_read_scope()` 让整页重建共用一次 GameState 克隆（`CommandBus` 提交后失效）、`trade.buy` **381 → 309 ms**、切海图 **346 → 277 ms**；新增 3 条守门测试（查询快照语义 / 港口名缓存 / 退出清理），Godot 全量 668/668
- [ ] **P0 交互重建降本 · 阶段 2**（目标 `trade.buy` <100 ms）：`_rebuild_ui` 局部增量刷新（市场/船厂只刷新变化区块、chrome/状态条/侧牌/故事层不重建）、演出相位切换预建页（消除单帧 489 ms 毛刺）、`story.observe` / `quest.observe` 合并或按事件兴趣短路、autosave 改后台线程 / 分帧写盘（当前 167 ms 同步冻结）
- [ ] **P1 画质档位 + 自动低配**：设置页暴露「画质 高/中/低 + 垂直同步 + 帧率上限」；低档 = `SNStageHost.render_shrink=2` + 关 4× MSAA + 关雾带/粒子（`render_shrink` 目前从未被赋值；设置页当前只有语言/自动存档）
- [ ] **P1 3D 舞台 MSAA 可配置**：`sn_stage_host.gd:194` 的硬编码 `Viewport.MSAA_4X` 改为档位驱动；`--msaa=0` 可确定省约 40 MB 显存
- [ ] **P1 内容贴图去重**：`ContentAssetLoader` 按内容哈希缓存（或打包时合并 `models/<category>/shared_materials/`），发布 zip 里 114 条引用路径 → 27 张唯一内容，省约 121 MB 显存与解码时间
- [ ] **P2 发布 zip 冷启动**：HEAD 内容包 37 MB 的 mod 加载 1.7 s（首挂 3.2 s，dev.3 仅 0.2 s）；按入口页懒读 + 预生成内容索引
- [ ] **P2 首访页面预加载**：切页前空闲帧预解析 GLB（当前首访 hitch 12–56 ms）；修 `port_stage.gd:3500 _add_beam` 的 `looking_at` 共线 warning（每次舞台构建 82 条）
- [ ] **P2 弱机复现**：拿反馈者日志/显卡型号，确认「低帧率」是弱 GPU 填充率还是 vsync 掉半；本机强机无法复现

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

- 已按版本归并到 [CHANGELOG.md](CHANGELOG.md)（最新 [0.2.0-dev.4]）；后续完成项继续记录在本节。

- 官网版本数据自动同步（2026-10-27）：用户反馈「官网最新游戏版本不是从 GitHub 自动获取」。①**生成器**：新增 `website/tools/build-release-data.mjs`，调 GitHub Releases API（可选 `GITHUB_TOKEN` 提高限流）生成 `website/assets/data/release-data.js`（`latest` / `stable` / 平台直链 / 字节数 / 日期，使用 `browser_download_url`）；网络失败保留上一次生成文件，`--check` 校验数据是否落后、`--strict` 才失败。②**前端**：新增 `website/assets/js/release.js`，下载页 / 开发日志页用 `data-release` / `data-release-link` 属性自动填充版本号、发布日期、大小、下载与校验链接；首页仍不出现版本，静态文案仅作无 JS fallback。③**自动时机**：`website/tools/ci.ps1` 构建镜像前自动刷新（`-SkipReleaseData` 可跳过），新增 `.github/workflows/website-release-data.yml` 在 Release 发布后自动生成并提交数据文件。④**验证**：`node --test website/tests/release-data.test.mjs` 5/5；`--check` 对真实 GitHub 数据通过；Chrome headless 渲染确认下载页 Linux 大小由静态 62 MB 变为 GitHub 实际 61 MB、开发日志页日期由 10-24 变为 Release 日期 10-22（证明 JS 已消费生成数据）；`gen_static_docs --check` 全绿。契约见 [WEBSITE.md](docs/design/WEBSITE.md) §2/§7。
