# CHANGELOG

> 只记录有意义的功能与变更，不写逐条流水账；实现细节见 git 历史。
> 发布约定：打 `v*` tag 前把 [todo.md](todo.md) 的 `Recently Completed` 按版本归并到这里，并从 todo 移除。

## [0.2.0-dev.4] — 2026-10-27

### Added

- 游玩数据上传（Telemetry，opt-in）：设置页新增「允许上传数据」开关（默认关），`TelemetryService` / `TelemetryUploader` 记录命令、契约白名单领域事件与 WARN+ 错误快照，写入 `user://telemetry/pending/` 后串行上传；退出时先 finalize、最多等 3 秒尝试上传，不阻塞退出；官网新增零依赖接收端 `website/server/telemetry.mjs`（校验 / 限流 / 180 天保留）+ nginx / compose / Dockerfile.telemetry 部署与测试。契约见 [TELEMETRY.md](docs/design/TELEMETRY.md)
- 可复用 UI 浮层场景化 P0：`SNInteractionHint` / `SNCarryGhost` / `SNVoyageConfirm` 从纯代码 `_build()` 升级为真 `.tscn` 骨架（静态结构 / 字号 / 间距 / 鼠标穿透进场景，脚本只做数据绑定、动态 `SNSkin` 色调与位置钳制），新增 [UI_SCENE_MIGRATION.md](docs/specs/UI_SCENE_MIGRATION.md) 说明边界、规则与 P0–P3 分批
- UI 图标图集按内容重切：新增 `tools/ui/slice_ui_icons.gd`（全透明行/列分格 + alpha 紧包围盒 + 居中 256×256），重切 30 张母版并重新生成 128×128 运行图标与 `check_*` 派生图标；`manifest.json` 记录精确内容包围盒、行带与未映射图标
- Core `icon.ui.*` 资源键（30 个）：30 枚 UI 图标复制进 Core 包并登记为内容资源键，内容 JSON / 事件 / 后续系统可直接 `information.texture: "icon.ui.nav_market"` 或 `AssetService.find_key("icon.ui.nav_market")`；测试逐字节守 Core 副本与运行图标同步
- 船厂武器分类装配 UX：右侧槽位卡显示玩家炮位名（左舷 1 号炮位 · 轻型等）与已装武器，左侧蓝图绘制已装 / 空槽贴片；仓库与购买行可拖到贴片或槽位卡安装 / 替换（class 匹配、命令仍走 `ship.install_weapon`）
- 市场「图标直接交易」：商品格角标改为**剩余库存**，跟随鼠标的光标幽灵显示已选 `×N` 与**预计消费**（单价 × 数量），点船舱 / 仓库落点即成交
- 海图单一世界 + 航线解锁：`world_map` 成为唯一世界与拓扑，任意两港可通航但航线需通过委托 / 剧情 / 酒馆购买海图解锁；航线未解锁时 `voyage.preview` / `voyage.start` / `clue.travel` 返回 `route_locked`
- Content Schema 2.0 Phase C–E 完成：实体合并（`modules` / `items` / `quests` 与 C4 类型改名升 2.0）、Phase D 系统切片（sim tick、combat、fleet、base、auto_trade、ruins）、Phase E 冻结 1.0；42 个 active 类型与 3 类草案全部 2.0，1.0 内容生成/读取已关闭并新增发布门禁 `tools/check_content_schema_v2.mjs`
- 基地 / 自动贸易 / 遗迹三套纵向切片：`data.base` 生产链、`data.trade` 自动买卖、`data.expedition` + `data.relics` 远征；对应命令、查询、tick 系统与最小页面

### Changed

- 顶部导航不再显示未发布的基地 / 贸易 / 遗迹入口（遗迹归航行探索玩法）；页面路由、场景与 `ui.nav.*` 文案保留，截图工具仍可直达内部页面
- 船厂模块拖放递完整 `ship_parts` 载荷（空槽安装与已装替换恢复），槽位页签 / 分类记忆与旧面板移除逻辑不变
- 市场行情格 meta 只保留单价 + 趋势，不再和角标重复；船舱 / 仓库格保持原「已选数量」角标
- `FrameworkInfo.CONTENT_SCHEMA` 与 `content_types.json.content_schema` 升为 `2.0`；SNModMaker / Content CLI 不再默认或写出 1.0，1.0 内容明确报「需要 2.0」/ `schema_version_frozen`；迁移与实体契约文档状态改为 **Finalized**
- 查询读作用域共享一次 GameState 克隆，`trade.buy` 381 → 309 ms、切海图 346 → 277 ms；运行时性能报告与网站 / 静态文档工具链落地

### Fixed

- 交互提示浮层宽度塌缩：`text_overrun_behavior` 在 Godot 4.7 让 Label 最小宽度只剩 1 px，面板缩成图标宽且文字只剩省略号；`show_at()` 改为按主题字体实测消息宽度（上限 520 px）
- 图标母版固定网格裁切把下一行图标顶端带进每张 PNG 底部、第 3 行逐格串图；改为按内容包围盒切片并居中
- 舞台站位切换在没有挂载船体时的过渡与港口演出接缝、退出 3D 舞台后的 teardown 顺序
- 遥测落地时按 hunk 分割提交导致 shell 的 `_init_telemetry()` 落在 return 之后、静态文档头位置错乱；已恢复

## [0.2.0-dev.3] — 2026-10-22

### Added

- 新手剧情 / 教学系统（4.5.1–4.5.6）：新开局默认五幕教学（获船 → 补给限购 / 海图首航 → 第二港市场往返 → 酒馆线索 / 保底探索 → 第三港船厂客舱 / 旅客），`data.story` 状态机 + Core JSON 剧情 / 文案 / 解锁、剧情卡与非阻塞目标条、功能门禁与跳过；补给并市、酒馆替换情报站、两港确定性价差、第三种货、1 人客舱与旅客主线 `main_03`；全量测试 0 failed
- 航海图阶段 4.3 体验修正：雾半径与双子世界尺寸内容化、线索失败保留可重试、逐级「调查」（20 金 / 6 h / 75%）、删除出航准备页并把出航确认移入海图、演出随船照亮与沿途迷雾落账、资源按航行小时连续读数
- 航海图阶段 4.4 线索扩展：`port_goods` 货物行情线索（冻结行情快照 + 分级披露 + 24/48/72 h 时效）、`clue.list` 查询与过期 sweep、在港等待 / 委托线索来源、`clue.travel`、线索列表页与回海图选中
- 任务追踪聚合 4.6 Phase A：只读 `task.view` 把剧情目标 / 待接主线 / 已接委托 / 普通委托聚合成统一 Task，委托拆成接取 / 备货 / 接客 / 前往 / 抵达交付步骤；HUD 任务条（剧情结束后接替目标条）+ 委托页任务面板
- Content Schema 2.0 迁移 Phase A（16 个运行时类型各自 `schema_version`、按类型校验与 Patch 再校验）+ Phase B 世界 / 战役运行时实现契约（9 类草案、CampaignFactory、1.0→2.0 映射、`content_versions`）
- 舰载武器内容 Schema 2.0 草案：`schemas/v2/weapon.schema.json`（战斗 / 装配 / 经济，15 项必填）+ `content_types.json` 登记 `weapons` 草案；`hull_data` 新增 `weapon_sockets` / `rig_sockets` 镜像并回填 Core 4 艘船（14 + 22）；SNModMaker 支持武器新建 / 编辑 / 校验 / 导出与船体安装点编辑
- 模型素材库批次 1–3（kit 30 件：武器套件 / 船体部件 / 机械 / 货物 / 码头 / 建筑 / 环境）+ 武器独立建模批次 1–2（8 件舰载武器）+ 武器装配规范 v2（`SN_Socket_Weapon` / `SN_Mount` / `SN_Pivot_*` / `SN_Recoil` / `SN_Muzzle`）
- 船体部件接口：船侧武器 socket M0-3（4 艘船 14 个）、`rig_kit` 帆索部件库 M0-4（12 件套件 + 3 艘船参数化 + 22 个帆索 socket）、LOD1 基础套件 M0-5（kit 26 + 船 4 = 30 个远景低模，19 850 / 88 026 tri = 22.6%）
- 船体运行时装配 `ShipVisualAssembler`：`ShipVisualPlan` 从 manifest / `rig_plan` / `weapon_loadout` 解析 hull + rig + weapon，按 socket 对齐套件 `SN_Mount`、按 class 挂武器（Modular 拒绝），接入船厂 3D 舞台 / 港口舞台 / 航行演出；旧 ViewModel 回退；新增 25 例装配测试
- 穿壳炮 casemate gun 模块化 M0-6：铁甲舰 12 门舷侧炮拆成独立模块 `SN_Weapon_CasemateGun`（108 tri，根 = 炮门平面中心、`port_pitch`），船体侧 12 个 `SN_Socket_GunPort_*`（`hull-gunports@1`）；铁甲舰重导为空炮门版（8 830 → 8 158 tri、26 节点），模块装回去与拆炮前炮管逐顶点重合

### Changed

- 旧资产 UV 迁移 B：11 件船模块 + 4 艘可玩船 + 旧小镇剩余 5 件补 `UVMap`、切 10 种 `SN_Tex_*` 共享贴图、重导 21 个 GLB；几何逐位不变（55 256 tri / 118 网格）
- 静态代码文档生成器升级为 v3：源码 `@static-doc` / sidecar 为唯一真源，项目配置声明模块与跳过规则，`--check` 保持新鲜度门禁
- 设计截图继续作为本地生成物（不入库）；文档按 Active / Finalized / Archived 分层维护

### Fixed

- 炮门框 / 深色炮口板 / 上翻门盖贴合 17 站放样壳面（边缘间隙 0.241 m → 0；三角面不变）
- 新手剧情补给引导改为跟踪真实煤舱（目标条显示「8/10，还差 2」，不再要求玩家自己换算）
- 海图幽灵按钮 hover 稳定、头部详情可收缩、航线距离标签；SNModMaker 草案内容禁止覆盖发布包（G8）与 story `flow_id` 假阳性

## [0.2.0-dev.2] — 2026-10-21

### Added

- 航海图系统正式版阶段 0–3：坐标空间世界生成、三重迷雾、海图 UI、航线预计算、真实对局孪生世界、航行演出（3D 离港 / 入港 + 云层转场 + 海图航行 + 事件中断）
- 航海图系统阶段 4.1 探索：线索（抵达传闻 / 购买情报 + 分级与海图可视化）、`explore.start` / `explore.settle` 探索航次、搜索区判定与发现概率、失败漂流、发现后解锁港口与迷雾揭示、探索结算；数值配置在 `map_profiles` 的 `exploration` 块
- 航海图系统阶段 4.2 资源告急：航程 50% 处停下让玩家选「继续探索 / 掉头返航」（跳过演出不能替玩家决策）；掉头经 `force_arrival()` 直接播入港；探索入港复用普通抵达的到港服务（委托 / 市场记忆 / NPC / 债务 / 委托刷新 / 统计 / 自动存档）
- 铁港建筑套件批次 A / B / C：5 栋 LOD1、外部共享贴图、三栋新原型（Boiler House / Workshop Row / Brick Tenement）、SN_Paddle_Steamer 视觉精修
- 港口起重机四件套：塔吊参数化重建（`SN_Harbor_Crane`）、大型龙门吊（`SN_Mega_Gantry`）、木制桅杆起重机（`SN_Wooden_Mast_Crane`）、手摇悬臂吊（`SN_Hand_Jib_Crane`），共用 `crane_kit` 生成器
- 共享贴图材质系统：10 张 512² 无缝 `SN_Tex_*` 贴图 + 世界空间盒式 UV，导出 GLB 时贴图外部化并与 Core 同步，四台起重机已切换（旧纯色 `SN_*` 材质待迁）
- SNBattleSim：独立 2D 舰队战斗规则试验台（固定船体、多武器、视野与战争迷雾、货船护航、自定义武器；`mods/` 散装目录与 ZIP 交换、Agent CLI、状态机契约与默认五状态 FSM）
- 设计文档按生命周期分层：`docs/design/`（Active）、`docs/specs/`（Finalized）、`docs/archive/`（Archived）及顶层索引

### Changed

- 内容资产（模型 / 贴图 / 港口横幅）全部随 `core` 模组加载，共享外部贴图按 URI 复用同一 `Texture2D`
- 静态代码文档迁移到源码 `@static-doc` 注释与 sidecar，生成器支持 `--check` 新鲜度校验
- 航线表预计算进 `WorldMap.edges`（world schema 1.1）；绕行档位按岛屿尺寸自适应
- 设计截图改为本地生成物，不再入库

### Fixed

- 海图视觉验收修正：连贯海岸线、迷雾纹理过滤、稀疏航线、避陆航线
- 海图阶段 3 实机验收反馈 F1–F4：离港改为"先转艏驶离"（入港镜像，接缝朝向一致）、镜头俯角升到 83° 并拉升；云层后海图由近景拉远、入港前推近；航行页海图铺满整屏；船只沿世界航线表按弧长行进（不再两点直线 / 不受迷雾过滤影响）
- `SN_HT_Warehouse_Short` 檐口顶皮与墙线对齐（−3.543 cm → 0.000 cm）

## [0.2.0-dev.1] — 2026-10-20

### Added

- 2.5D 连续港区：市场 / 港务 / 补给三站位共享同一 `PortStage`，切页只平移镜头并驶靠泊位
- 通用舞台宿主（`SNStageHost` / `LocationStage`）与 `PortStage` 场景填充（天空、banner、剪影、蒸汽、雾带）
- Bounty Train 式主界面：紧凑 HUD、资源图标、设施招牌、底部状态条、详细总览抽屉
- 港口街景 town kit（10 件 `SN_HT_*` 建筑 / 工人 / 小船与 `diorama` / `town_visuals`）
- 船厂正常态 3D 实机舞台；港口设施锚点 6 件模型
- SNModMaker 原生工作区、Content CLI 无头增删改与容器部署
- 静态代码文档索引与发布流水线（tag 触发 Windows / Linux 开发版）

### Changed

- 内容模型与横幅改为随 `core` 模组加载
- 模块实例、战役分区与 Content Schema 2.0 草案；存档 1.x → 2.0 迁移
- 铁港道具改为参数化生成器产出的 31 件 GLB

### Fixed

- 连续港区过渡中重定向从当前相机续 pan；960×540 窄窗口布局与静态合批

## [0.1.0-dev.7] — 2026-10-19

### Added

- 船厂改装台（图 2 / 图 3 三列布局、纵剖图拖拽安装、分类记忆）
- 3D 港口样片：自定义水面着色器、浮船、码头道具与固定机位
- 明轮货轮（SN_Paddle_Freighter）

### Changed

- 迭代 2 MVP 反馈优化：打造订单与在港等待、补给比例条、情报对比表
- 界面场景化重构：静态外壳 + 独立功能页 / 流程页

## [0.1.0-dev.6] — 2026-10-19

### Added

- 航海图重设计：三次贝塞尔航路、每港唯一出港方向、经纬网、洋流、罗盘、图例与当前港光晕

## [0.1.0-dev.5] — 2026-10-19

### Added

- 高频决策页第一轮：补给卡（存量 / 续航 / 花费）、委托五区卡片、市场真实价格历史与迷你折线

## [0.1.0-dev.4] — 2026-10-19

### Changed

- UI 复核修正：页面淡入淡出过渡、分组标题主题化

## [0.1.0-dev.3] — 2026-10-19

### Added

- 蒸汽朋克主题 UI 应用到主菜单与港口页面

### Changed

- 统一 UI / 音频资产路径

## [0.1.0-dev.2] — 2026-10-19

### Added

- 初版 MVP：模组扫描 / 依赖解析 / Schema 校验 / 注册表冻结，命令-查询总线与领域事件
- 市场、航行、委托、船厂、补给、债务与声誉闭环；确定性开局与存档
- 主菜单（开始 / 加载 / 模组 / 设置 / 退出）与设置持久化
- 零依赖网页端模组制作器（SNModMaker）
- 静态代码索引与 tag 触发的开发版发布
