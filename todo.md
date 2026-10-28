# TODO

> 只保留最近 10–15 项已完成与尚未实现的目标；逐条实现细节见 git 历史。
> 发布约定：打 `v*` tag 前把 `Recently Completed` 里的条目按版本归并进 [CHANGELOG.md](CHANGELOG.md)（只写有意义的功能 / 变更），并从本文件移除。

## In Progress

- [ ] 剧情模式：**数据契约 V2 + Schema 已冻结（2026-10-27）**，下一步实现（排除战斗集成）：V2 为完全数据驱动——手写陆地+航道、2D 叙事（文本/说话人/立绘/背景/音频/选项，无 3D 镜头）、关卡内嵌 `tasks[]` 复用 quest 状态机、页面/动作 available/locked(reason)/hidden 三态与阶段覆盖、触发器与效果白名单。契约见 [STORY_MODE_DATA_CONTRACT_V2.md](docs/specs/STORY_MODE_DATA_CONTRACT_V2.md)；按 **S2 加载链 → S4 运行时 → S5 UI → S3 首发 1 关 → S7 SNModMaker 剧情编辑**（含地图编辑器拆分）推进。V1 已被取代、无迁移。
- [ ] SNBattleSim 战术状态机工作台：人工浏览器验收（节点拖拽、转移表、状态机 CRUD、舰船挂载）后评估是否并入正式战斗；当前暂停，让位剧情模式

## Pending

### 近期
- [ ] UI 皮肤后续（V1 边界）：布旗 `flag_*` 接入导航/出航确认/港口识别（需布局改版，当前 44×36 图标导航与 172×42 侧牌放不下）；补齐 `nav_overview` / `nav_base` / `nav_trade` / `nav_ruins`、`shipyard_utility` / `shipyard_weapons`、`action_buy` / `sell` / `repair` / `wait`、`status_risk` 图标；多套皮肤运行时切换（Theme 动态重建，当前 Theme 绑定生成时的 skin 目录）；换肤后 960×540 文字/安全区复验与低动效模式。（2026-10-28 图标轮：HUD/导航/市场/委托/酒馆已接入 30 枚新图标并做文字精简；上述语义缺口仍待美术）
- [ ] 船体蓝图后续：武器成对（左右舷同型）的运行时命令与校验；舱位运行时槽位化（`mount_state` + state 2.1 迁移）；把 `apply_hull_blueprints.mjs --check` 接入发布/CI 门禁，GLB 或线稿参数变化时自动重算坐标
- [ ] 船厂改装页后续：俯视图恢复（当前只画侧视，`top` 系列 API 保留）需要先补每船 `blueprint_views.top` 的槽位锚点作者流程，并把 Core 4 船人工标定的 side 锚点接进编辑器拾取；港区 `shipyard` 站位接入真实干船坞 + 吊架（给 `port.view` / `facility_visuals.shipyard` 绑定 `SN_Dry_Dock.glb` + `SN_Shipyard_Gantry.glb`，当前是程序化 billboard）；3D 窗口按窗口宽度做机位微调，超宽屏下不要让船坞站位移到窗外
- [ ] Lua Modding SDK S1：按 [LUA_SDK_S0_API_CONTRACT.md](docs/design/LUA_SDK_S0_API_CONTRACT.md) / [LUA_SDK_S0_THREAT_MODEL.md](docs/design/LUA_SDK_S0_THREAT_MODEL.md) / [LUA_SDK_S0_TEST_MATRIX.md](docs/design/LUA_SDK_S0_TEST_MATRIX.md) 做独立 Lua Host PoC（VM 选型、中断/内存/库隔离证据、纵向样例），实验分支，禁止接入正式 ModLoader；S0 已完成
- [ ] 炮门舱段 port cassette：给明轮货轮 / 明轮客船 / 纵帆船（以及未来的船）提供“舷侧开口 + 暗腔 + 标准 `SN_Socket_GunPort` 接口”的适配模块，让 `SN_Weapon_CasemateGun` 能装到没有炮门的船上；同时解决空炮门的“暗腔”读感（当前是木制深色炮口板）
- [ ] 铁甲舰 `SN_Ironclad_LOD1.glb` 随空炮门 LOD0 重建（当前 LOD1 仍是带炮旧件；LOD 切换未接线，暂不影响运行时）
- [ ] 炮门 socket 内容镜像：`schemas/v2/hull.schema.json` 的 `hull_data` 新增可选 `gun_port_sockets` 数组并回填 Core `hulls.json`（供编辑器 / 装配器读内容，运行时仍以 GLB extras 为准）
- [ ] 正式任务系统后续切片：Quest 奖励 / effects（`spawn_contract` 等）、任务发布点（酒馆 / 港务告示牌）、任务日志页；`quests` 内容类型与 `QuestService` 已随 C3 落地，契约见 [TASK_QUEST_SYSTEM.md](docs/design/TASK_QUEST_SYSTEM.md)
- [ ] 势力 / 自由模式玩法：设计契约见 [FACTION_SYSTEM.md](docs/design/FACTION_SYSTEM.md)（Draft 0.1：名望与关系分离、6 港准入 + 通行许可证、港口 owner/特产/禁运/走私、委托发起方与关系条款、势力专属装备）；建议 P0 准入骨架 → P1 经济特色 → P2 条款与装备 → P3 自由模式内容/UI，待排期
- [ ] 战斗后续接线：D1 已交付 6 类战斗内容 + `CombatOps` / `CombatService` / `combat.resolve|view|log`；剩余「航行遭遇接入（voyage 风险 → 遭遇表）」「敌舰可视化 / `combat_kit` 接入 ShipVisualAssembler」「舰队编成与 2v2」三项切片。`weapons` / `damage_types` / `combat_abilities` / `enemy_archetypes` / `encounter_tables` / `loot_tables` 均已 active 2.0，Core 已带 5+4+4+4+2+2 条内容；契约见 [WEAPON_CONTENT_SCHEMA.md](docs/design/WEAPON_CONTENT_SCHEMA.md) 与 [COMBAT_ARCHITECTURE_REVIEW.md](docs/specs/COMBAT_ARCHITECTURE_REVIEW.md)

- [ ] 2.5D 舞台收尾：委托 / 情报页舞台化、事件触发的 3D 场景预加载、质量档位与低配回退、L2 LOD、第三方 `.glb` 白名单评审
- [ ] 高频决策页第二轮：持久 `ScreenHost` 与局部数据刷新（市场数量步进 / 即时成本已由「图标直接交易」取代）
- [ ] 市场 V2：从「中间 3D 港区窗口」推进到 3D 船内交互（左侧背包退化为船体货舱热点，复用 `market_item` / `cargo_item` 拖拽载荷）；补给（煤 / 水）也改图标直接交互；商品分类筛选 / 分组；买卖音效与拖拽动效；用正式美术替换剩余 8 张 SVG 占位图标（保持 `icon.item.*` 同名同尺寸即可）。（2026-10-26：市场商品「拿起 / 放下」与交互处浮出提示已落地；2026-10-28 图标轮：煤 / 水 / 锅炉钢板 / 委托货箱改用 `icon.ui.*` 新批次，市场文字精简、**只显示可买货物**（卖出不受影响）；剩余补给图标直接交互、分类筛选、买卖音效、8 张商品图）
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

- 图标轮 + UI 收尾（2026-10-28）：30 枚皮肤图标接入 HUD / 导航 / 市场 / 委托 / 酒馆；HUD chip 改「图标 + 数值」（字段名进 tooltip，`_stat_chip` 单行化）、导航为「图标 + 本地化页名」（64×36、`nav_screen` meta，剧情引导/测试按 meta 解析）；第二轮反馈移除与顶部完全重复的底部状态条与详细总览抽屉（等待 / 航行记录 / 详细总览留在 2D 总览页，3D 主视图隐藏页脚）；市场只显示可买货物（卖出仍走整块面板落点）；市场账册摘要改单行 icon chip、删长说明与商品分类副标题、补给卡字段名进 tooltip；委托卡 4 字段与报酬行图标化、删重复「截止」行与声望 badge；酒馆删纯说明段落。内容侧煤 / 水 / 锅炉钢板 / 委托货箱 4 个商品改用 `icon.ui.*`，早期 `icon.coal` / `icon.money` / `icon.water` PNG 与 2 个被替换 SVG 退役（Core 资产键 179→174）。验证：Godot 全量 735/735、`check_content_schema_v2`、SNModMaker 65/65、`gen_static_docs --check`；截图 `docs/design/screenshots/skin/1440x900/*`。

- 船厂改装界面第二轮反馈（2026-10-28）：改装蓝图只保留侧视图，普通槽位按 Core hull `module_slots` / `compartments` 的 `blueprint_position.side`（`shipyard.view.ship.slot_anchors`）画圆点，槽位方框移到侧视图下方的标注带并用点线连到圆点（`SNShipView` 新增 `slot_anchor_rects()` / `slot_chip_rects()` / `chip_band_rect()` / `slot_leader_lines()` / `set_module_chips_visible()` / `set_weapon_patches_visible()`）；操作坞拆「部件改装 / 武器装配」两个模式，常规分类 6 项 3×2 等宽对齐、武器模式独立炮位/仓库/购买（无打造页签）；4 艘 Core 船补侧视槽位坐标并同步 `SNModMaker/js/core-index.js`。新增 `test_shipyard_blueprint` 8 例 + `test_shipyard_refit` 模式分离用例；验证 `check_content_schema_v2`、SNModMaker 65/65、截图 `_check5/shipyard_refit*.png`。

- 教程强制引导 P0 修复（2026-10-28）：玩家反馈「框与按钮根本不在一个地方」。`SNFocusOverlay` 新增 `focus_target(control, text)` + 逐帧 `refresh_target()` 自愈，Shell 页面重建后补两次 deferred 重解析；遮罩改挂到目标条之上（提示不再被压字）、三处共享 `SNSkin.style()` 改克隆、提示板按字体实测高度 + 24 px 内边距；1440×900 / 960×540 实测 hole=target（0 误差）、FocusHint 484×30；新增 `test_story_ui` 回归，重截 `docs/design/screenshots/story/tutorial_objective.png`。

- 剧情模式数据契约 V1 冻结（2026-10-27）：Schema 边界（`story_arcs` / `story_levels` 与 common 的 4 个 story `$defs`）、固定港口市场改 `{item, stock, price}[]`、世界坐标 / ID / 键长上限、起点双字段一致性、固定地图自环 / 重复航道 / 重复市场商品、包级 capability / 单篇章 / 关卡归属、`intel → tavern` 设施键，全部落进 Schema 与 `SNModMaker/js/validate.js`；新增 `tools/check_story_schema_freeze.mjs` + `schemas/v2/story_schema_freeze.json` 冻结门禁，契约文档见 [STORY_MODE_DATA_CONTRACT_V1.md](docs/specs/STORY_MODE_DATA_CONTRACT_V1.md)。验证：`content.mjs validate` 示例包 0 error / 2 draft warning、SNModMaker 65/65、Content CLI 64/64、`check_story_schema_freeze --check` 通过。

- 官网发布日期时区修正（2026-10-27）：用户反馈 `v0.2.0-dev.4` 在网站显示 10-26，按其当地时间（悉尼 UTC+11）应为 10-27。根因：`tools/build-release-data.mjs` 直接用 `published_at.slice(0, 10)` 截 UTC 日期（`2026-10-26T22:18:39Z`）。修复：`date` 改为按站点时区（默认 `Asia/Shanghai`，`SN_RELEASE_TIME_ZONE` / `--time-zone` 覆盖）计算并输出 `date_time_zone`；`release.js` 把 `published_at` 按访客本地时区格式化为 `YYYY-MM-DD`，解析失败回退 `date`；更新 `?v=` 缓存标识与 `WEBSITE.md` §2。验证：release-data 6/6（含 UTC 日界、UTC / 悉尼时区用例）、site-api 6/6；重新生成数据 `date=2026-10-27`。

- 官网运行时版本自动更新（2026-10-27）：用户要求「每次发布后网站能自动更新最新版本」。①新增只读内容 API `website/server/site_api.mjs`（容器 8092，`Dockerfile.site-api` + compose `site-api` + nginx `/api/site/` 反代），服务端用 `GITHUB_TOKEN` 可选地调 GitHub Releases API，内存缓存默认 5 分钟、同进程刷新去重，失败降级旧缓存 → 镜像内 `release-data.js` → 503。②前端 `assets/js/release.js` 改为「静态数据立即渲染 + `/api/site/release` 异步刷新」，发版后无需重新部署网站即可在 ≤5 分钟显示新版本。③缓存：`release-data.js` 单独 `no-cache`；API `public, max-age=60, stale-while-revalidate=600`。④发布链路：`release.yml` 发布后直接同步静态数据（`GITHUB_TOKEN` 创建的 Release 不会再触发独立 workflow）；`ci.ps1` 修 Windows PowerShell 5.1 把 docker stderr 当错误的问题，部署 `website + site-api` 后校验 `/api/site/release`。验证：site-api 6/6、release-data 5/5、website 全量 34/34；实际部署后线上 `dev.4`、页面版本/日期/大小已更新。

- 官网版本数据自动同步（2026-10-27）：用户反馈「官网最新游戏版本不是从 GitHub 自动获取」。①**生成器**：新增 `website/tools/build-release-data.mjs`，调 GitHub Releases API（可选 `GITHUB_TOKEN` 提高限流）生成 `website/assets/data/release-data.js`（`latest` / `stable` / 平台直链 / 字节数 / 日期，使用 `browser_download_url`）；网络失败保留上一次生成文件，`--check` 校验数据是否落后、`--strict` 才失败。②**前端**：新增 `website/assets/js/release.js`，下载页 / 开发日志页用 `data-release` / `data-release-link` 属性自动填充版本号、发布日期、大小、下载与校验链接；首页仍不出现版本，静态文案仅作无 JS fallback。③**自动时机**：`website/tools/ci.ps1` 构建镜像前自动刷新（`-SkipReleaseData` 可跳过），新增 `.github/workflows/website-release-data.yml` 在 Release 发布后自动生成并提交数据文件。④**验证**：`node --test website/tests/release-data.test.mjs` 5/5；`--check` 对真实 GitHub 数据通过；Chrome headless 渲染确认下载页 Linux 大小由静态 62 MB 变为 GitHub 实际 61 MB、开发日志页日期由 10-24 变为 Release 日期 10-22（证明 JS 已消费生成数据）；`gen_static_docs --check` 全绿。契约见 [WEBSITE.md](docs/design/WEBSITE.md) §2/§7。
