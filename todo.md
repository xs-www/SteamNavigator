# Steam Navigator — TODO / 路线图

> 基线：Framework 0.1.0 / Core 1.0.0 / Mod API 1.0 / Content Schema 1.0
> 最近验证：Godot 4.7.2 headless，**252 个测试通过 / 0 失败**（含 9 个 seed 的完整通关回归、主界面接线冒烟、船厂改装 UI 契约、模块实例与部件损耗、密集界面横向排版与通报文案本地化守护、2.5D 舞台基础设施、PortStage 场景填充与 town kit、连续港区三站位、主界面紧凑 HUD + 两侧招牌 + 状态条 + 详细抽屉与 2D 回退、**海图系统（世界生成器 18 / 迷雾系统 17 / 海图 UI 21 / 航行演出 19 / 入口集成·绕行自适应·真实对局孪生世界 +4）**、save schema 1.x→2.0 迁移、CampaignState 分区、Content Schema 2.0 草案校验）；**海图 UI 与航行演出均已做真实渲染视觉验收**（海图 4 张 + 演出 5 张 1440×900 截图，见 [NAUTICAL_CHART_SYSTEM.md §14/§15](docs/design/NAUTICAL_CHART_SYSTEM.md)）；SNModMaker **33 个 Node 用例 + 1 个本地服务用例 + 16 个浏览器用例**通过；**Windows 导出包实机验收通过**（3D 船厂舞台 + `mods/`+`config/` 便携布局）；`node tools/gen_static_docs.mjs` 已重新生成静态文档。

## 已完成

### 阶段 A：最小加载链

- [x] `Bootstrap` / `AppBootstrap` 启动链
- [x] Manifest 1.0 + JSON Schema 校验
- [x] 目录与 `.snavmod.zip` 扫描
- [x] SemVer 依赖解析、冲突、循环、致命/禁用分级
- [x] Core 完整性检查与注册表冻结
- [x] 一个商品 / 船 / 港口冒烟测试（实际已扩展为完整 Core）

### 阶段 B：领域接口

- [x] `CommandBus` 事务克隆提交
- [x] `QueryBus` 只读克隆
- [x] 领域事件总线
- [x] 命名确定性 RNG
- [x] 贸易、装配（购买安装）、出航预览、出航、事件选择
- [x] UI 不直接写 `GameState`
- [x] 七个独立界面：总览 / 市场 / 委托 / 船厂 / 补给 / 情报 / 出航
- [x] 启动主菜单：开始游戏 / 加载游戏 / 模组列表 / 设置 / 退出；右下角团队与版本
- [x] 设置持久化：默认 `config/config.json`，运行时写入 `user://config/config.json`
- [x] 补给界面：煤炭/淡水购买、剩余载重提示、维修报价
- [x] 点击已访问港口查看上次在港的货价与储备（港口记忆）
- [x] 任意港口收购所有普通货物；只允许买入本港商品表中的品种
- [x] 船上库存按加权平均成本记录并在市场/总览显示
- [x] 玩家单笔贸易价格影响阻尼为 35%，NPC 仍按完整供需重算
- [x] 煤炭/淡水作为补给商品，价格随港口库存和 NPC 商船流动浮动
- [x] 运行时扫描 `dist/mods`；松散 mod 覆盖同名 zip，core zip 构建产物自动忽略
- [x] 美术与交互原型：统一深青/黄铜视觉、图标族、主菜单、港口海图、信息页、反馈与独立抵达结算（本地 `.design/`）
- [x] Godot UI Kit：共享 Theme、语义按钮/面板/徽标/章节标题/资源存量条与独立展示场景
- [x] 资产落位：`assets/ui`、`assets/audio`、`assets/fonts`、Core 港口图；来源与路径见 `docs/design/ASSET_MAP.md`
- [x] 表现层第一轮：全屏主菜单背景、共享 Theme 顶栏/统计/导航、铁港港口横幅、两列委托卡、抵达结算页
- [x] 交易反馈：接入 `pickup_gold_00.wav`，买入/卖出/接委托/补给成功播放
- [x] 页面切换 TransitionLayer：旧页淡出后重建，新页淡入；数据刷新不转场
- [x] 新航程主按钮改用 `SNPrimaryButton`；章节标题改用语义 Label 变体
- [x] 高频决策页第一轮：补给 `SNSupplyCard`、委托固定结构/可接与进行中分区、市场真实价格历史与 `SNSparkline`
- [x] 海图重设计：三次贝塞尔航路、每港邻居组中心出港方向、经纬网/洋流/罗盘/图内图例、当前港脉冲与宽屏布局
- [ ] 高频决策页第二轮：市场数量步进/即时成本、持久 ScreenHost 与局部数据刷新（船厂槽位选择已随图 2/图 3 重构落地）
- [x] 情报页第二轮：`intel.view` 输出「商品 × 港口」矩阵（当前港实时市场，其余港快照 + 年龄），新增 `SNIntelTable`（`？`/`-` 规则、红降绿升百分比、未探索港整列）；main.gd 接线见 T4
- [x] 宽屏布局回归：设置、总览、市场、船厂与港口记忆的密集横向字段禁止智能折行为逐字竖排；市场/快照单元格保留最小列宽，情报矩阵随面板宽度展开
- [ ] 界面场景化重构：静态 `main.tscn` 外壳、独立海图、七个功能页、四个菜单页，以及港口记忆/抵达结算/航行中/事件/通关五个流程页均已完成；页面迁移完成，剩余工作是把当前整页重建升级为持久 `ScreenHost` 与局部刷新。

### 阶段 C：Core 内容（MVP 骨架）

- [x] 5 个港口原型 + 程序生成配置
- [x] 商品 / 材料 / 船体 / 锅炉 / 货舱 / 导航 / 安全 / 客舱
- [x] 三种锅炉策略
- [x] 工程师 / 领航员
- [x] 5 段主线 + 4 个普通委托模板
- [x] 2 类事件、事件选项池
- [x] 2 套初始构筑
- [x] 中英文本地化
- [x] 模块打造、材料运输与港口仓库
- [x] 普通委托池刷新与持有上限 UI
- [x] 第五委托完成后的通关判定与总结页

### 迭代 1：MVP 闭环（已完成）

- [x] `WarehouseOps`：每港独立仓库（模块/材料）、`ship.transit_modules` 随船运输（计重不占货舱）、旧存档惰性补齐
- [x] `CraftOps`：配方/工时/费用、仓库优先扣料、成品入当前港仓库
- [x] 命令：`ship.install_module(source=purchase|warehouse|transit, replace_module_id)`、`ship.uninstall_module`、`ship.craft_module`、`warehouse.{store,take}_{module,materials}`
- [x] 模块替换：单槽自动替换、货舱槽满替换/卸下，旧件写入当前港仓库；购买船体满耐久、旧件重装保留 min(当前,新上限)
- [x] 合同解锁：medium/large 船体与模块按主线奖励 `unlock_ids` 锁定，UI 显示解锁来源
- [x] 普通委托：`active_limit = max(1, 1+reputation/2)`；每次抵达按 `<port>:<arrival>:<voyages>` 命名流整池刷新
- [x] 统计：`GameState.record_income/record_expense` + 惰性 stats；市场/委托/工资/维修/情报/船厂/打造统一口径
- [x] 通关：`VictoryService` 主线全完成 + 造船厂内「大型船体 + 锅炉 + ≥1 货舱」→ 幂等颁奖；`victory.view` 与总结页（再来一局/继续游玩）
- [x] UI：船厂仓库/打造/随船运输/替换提示、委托持有上限与刷新提示、通关总结页、中英文案
- [x] 测试：74 个（新增仓库/打造 13、委托刷新 4、通关 5、完整通关 2 个用例覆盖 9 seed）

### 迭代 2：MVP 反馈优化（已完成）

来源：`docs/archive/MVP反馈.md`（玩家试玩反馈 6 条）。契约与决策：[ITERATION_2_MVP_FEEDBACK.md](docs/archive/ITERATION_2_MVP_FEEDBACK.md)

- [x] 反馈 1：tier1 模块改为「仅金币」配方（`materials: []` + `craft_cost`），`CraftOps.craftable()` 规则放宽；tier2/3 数值不变
- [x] 反馈 4：打造改为带工时的**订单**（`state.data.shipyard_orders` / `order_serial`，`CraftOps.ensure_orders/settle_orders`），下单不再推进时间、不再即时入库；新增 `port.wait`（1..240 小时，在港）+ 船厂/总览「在港等待 6/12/24 小时」按钮；出航抵达亦结算订单
- [x] 反馈 2：补给上限改为稳定物理上限（`capacity/baseline_capacity/cap_loss/headroom`），买一种补给只会压低另一种上限；`SNResourceMeter` 在 `loss_value > 0` 时用右端反向损失带表达上限损失（`loss_value <= 0` 仍走主题 ProgressBar）
- [x] 反馈 3：情报页改为「商品 × 港口」对比矩阵（`IntelViewQuery.columns/rows/cells` + `SNIntelTable`）：未探索港口保留整列（「未知港口」+「？」），`-` 表示该港不经营，趋势为红降/绿升百分比数字；`IntelService` 快照行新增 `trend_percent`
- [x] 反馈 5：顶部信息条常显当前港口（在航时为「在航 → 目的港」）与剩余载重/剩余货舱（`port.view.ship.free_weight/free_cargo_capacity`）
- [x] 反馈 6：总览常驻通关条件清单（主线 n/5 → 大型船体 → 锅炉 → ≥1 货舱 → 造船厂组装）与主线完成后的下一步提示，数据来自 `port.view.victory.conditions` 与 `contracts.main_done/main_total`；船厂页重构后不再重复该清单
- [x] 测试：新增 `test_craft_wait`（8）与 `test_ui_shell`（8，把真实外壳场景挂进场景树逐条验证反馈 2–6、密集界面横向排版，并守护通报文案替换与 `push_notice` 键的中英一致性），更新仓库/打造、补给、船体升级、情报用例；测试运行器改为在**首个渲染帧**执行，使 UI 套件能获得正常的 `_ready`/viewport 语义
- [x] 独立验证（T5，只读）发现的 3 处用户可见文案缺陷已修：`port.wait` 状态栏参数序、`ui.notice.craft_ordered` 英文模板序、「航行记录」裸模板；补齐 3 个缺失通报键（`discovered_port` / `run_started` / `no_contract_offer`），`arrived` 现在带上港口名
- [x] 文档：`docs/static` 与新代码同步（新增 `port_commands.gd` / `sn_intel_table.gd` / `test_ui_shell.gd` / `test_craft_wait.gd` 条目，更新受影响的契约描述）

### 船厂界面（图 2 / 图 3 布局重构，已完成）

> 目标：主界面只保留「改装台 + 组件 HUD」，全部改装操作收进分类面板；旧的整页下方面板删除，但每条旧命令保留入口。设计说明：[SHIPYARD_UI_REFACTOR.md](docs/archive/SHIPYARD_UI_REFACTOR.md)。

- [x] 正常态三列：左「已有船舶」贴图船卡（`assets/ui/shipyard/ship_thumb_ironclad.png`）+ 中间 `SNShipView(EXTERIOR)` 实机渲染占位 + 右「组件」六类入口（点击进入改装）
- [x] 改装态三列：左授权贴图纵剖图（`SNShipView(CUTAWAY)` + 每槽位一枚 `SNSlotTarget` 贴片 + 舱室引线）+ 中当前分类的槽位 / 装配 / 购买 / 打造紧凑操作卡（唯一纵向滚动区）+ 右竖排分类页签（船体 / 锅炉 / 货舱 / 导航 / 安全 / 客舱 / 杂项）
- [x] 删除旧的整页下方面板与构建函数：`_stage_row` / `_parts_hud` / `_victory_plan` / `_orders_panel` / `_warehouse_panel` / `_craft_panel` / `_build_purchase_panels`；`_body` 恒为三列
- [x] 命令迁移：打造订单 + 在港等待 + 仓库材料 / 仓库模块 →「杂项」；购买并安装 + 按配方打造 → 各模块分类；卸下 → 槽位卡；拖拽装配保留；通关清单只在总览页
- [x] `SNShipView` 贴图纵剖图：`SECTION_TEXTURE_PATH` + `has_section_texture()` / `section_texture_size()`，`_draw_section_texture()` 做 cover 裁切，贴图缺失回退程序化剖面；槽位行固定在 `h*0.60`（非货舱）/ `h*0.82`（货舱）
- [x] 槽位贴片与拖放：`SNSlotTarget` 只接受 `ship_parts` 载荷（仓库 / 随船、类型匹配、`can_install` 为真），发 `part_dropped` / `slot_activated`；购买候选与异类型部件被拒
- [x] `SNPartRow`：已装 / 仓库 / 随船 / 购买四种标签；仓库与随船且可装的行可拖，购买行点击即购买安装
- [x] Shell 记忆改装态 + 分类：`refit_mode_changed` / `refit_category_changed` → `_shipyard_refit` / `_shipyard_category`，`_shipyard_model()` 下发 `refit` / `category` / `ship.hull_name`；切页或命令重建后仍保持
- [x] 查询补字段：`shipyard.view` 的 `ship.modules[].effect` 供槽位卡显示效果行
- [x] 贴图资产：`assets/ui/shipyard/ship_section.png`（1792×1008）与 `ship_thumb_ironclad.png`（640×360），确定性生成器 `tools/art/gen_shipyard_textures.py`（`python tools/art/gen_shipyard_textures.py` 可重建；`--thumb-only` 只重导船卡）
- [x] 截图工具：`tools/ui_snapshot.gd` + `tools/capture_ui.ps1`（窗口 1440×900、bootstrap 与测试一致、模式/分类断言、120 s watchdog），产出 `shipyard_{normal,refit,refit_cargo,refit_misc}.png`
- [x] 本地化：新增 normal/refit 两态与分类页签中英键（`ui.label.ship_list`、`ui.label.components`、`ui.category.*`、`ui.hint.operations*`、`ui.tag.section_texture` 等）
- [x] 测试：`test_shipyard_refit` 扩到 8 例（正常态 / 改装态 / 分类与模式记忆 / 贴图契约 / 船卡缩略图 / 2.5D 渲染器替换 / 拖拽安装 / 旧面板移除）；`test_ui_shell` 改为通关只在总览、打造与等待经分类和「杂项」。本轮验收船厂 / UI 套件 105/105 全绿
- [x] 文档：`docs/static` 的船厂页 / `sn_ship_view` / Shell / `shipyard_view` / 两个测试条目重写契约，并新增 [SHIPYARD_UI_REFACTOR.md](docs/archive/SHIPYARD_UI_REFACTOR.md)、更新 UI_PROTOTYPE 与 ASSET_MAP
- [x] 2.5D 舞台接入：正常态中央已是真实 3D 船体舞台（`SNShipStage3D` → `SNStageHost` → `ShipyardStage`），改装态仍是 2D 纵剖图；`SNShipView.set_renderer()` 渲染器协议不变，第二切片把视口/机位/灯光/水面迁进通用宿主与舞台场景

### 阶段 D：存档与兼容

- [x] 入港 / 出航前自动存档
- [x] 保存模组清单与版本
- [x] 保存/加载状态哈希一致
- [x] 缺失关键模组拒绝加载
- [ ] 声明式 ID 别名与数据迁移执行器
- [ ] 出航失败回滚的存档路径端到端测试

### 阶段 E：SDK 与第三方

- [x] `sdk/pack_mod.gd`
- [x] `sdk/validate.gd`
- [x] 模组模板
- [x] 第三方锅炉示例并通过公共注册表加载
- [x] 零依赖网页端模组制作器 `SNModMaker/`（表单、校验、本地化、资源、导入导出、ZIP、自动保存）
- [x] SNModMaker 实体约束编辑体验：ID 修改只预览多语言键，保存条目时原子迁移全部语言并删除旧键；名称/描述支持条目内多语言编辑与语言页跳转
- [x] SNModMaker 船只与模块子分页：船体 / 锅炉 / 货舱 / 导航 / 安全 / 客舱 / 岗位 / 策略直接切换
- [x] 标准实体视觉资源：可配置贴图与 GLB 模型资源键；使用主题化可搜索下拉框并按图片 / GLB 类型过滤；Schema、浏览器校验、资源白名单与导入导出同步支持
- [x] SNModMaker 船体模块配置区：锅炉 / 导航 / 安全固定一槽，货舱 / 客舱槽位按实体约束直接编辑且不与普通字段重复
- [x] 本体新版实体解析：`ContentDefinition` 保留 `information`，贴图 / GLB 键归一化为所属模组的 `asset://` URI；普通定义与 Patch 都校验资源存在性和扩展名
- [x] Core 新版实体字段：15 条船体 / 锅炉 / 商品 / 材料 / 港口定义接入贴图或 GLB；Core 包声明并携带 13 个资源，编辑器派生条目保留 `asset://core/...` 归属
- [x] SNModMaker 一键部署：导出并覆盖游戏 `mods/<id>.snavmod.zip`，清理同 ID 旧版本包；支持 `SNMODMAKER_GAME_MODS_DIR` 指向外部游戏安装目录
- [x] SNModMaker 部署目标默认指向发布包 `dist/build/<platform>/mods/`（优先已导出的平台目录），`SNMODMAKER_GAME_MODS_DIR` 仍可覆盖
- [x] SNModMaker 资源页 GLB 缩略图：内置 `js/glb.js` 解析 + `js/model_thumb.js` WebGL 单帧渲染，无第三方依赖；失败保留 GLB 占位
- [x] Content CLI（agent 无头工作流）：`SNModMaker/tools/content.mjs` 提供 types / describe / list / add / set / loc / rm / clone / validate / new 十个命令，按 Schema 保源增删改定义与本地化；`--json` 单一 JSON 对象 + 退出码 0/1/2，`--dry-run` 预览 diff，SHA-256 并发冲突保护，`--godot` 可调 `sdk/validate.gd`（需 `GODOT_BIN`）；保源编辑器在 `SNModMaker/tools/content_json.mjs`。用法见 [SNModMaker/README.md](SNModMaker/README.md)
- [x] SNModMaker 容器部署：`SNModMaker/Dockerfile` + 仓库根 `docker-compose.yml`（命名卷保存项目/导出/部署包，不挂载宿主机仓库、不写 `dev_mods/core`）；`SNMODMAKER_HOST` 支持容器内 `0.0.0.0`，宿主机只发布 `127.0.0.1:8099`，远程访问用 `tailscale serve --bg`（tailnet HTTPS，不用 funnel）
- [ ] 模组管理 UI（启用 / 禁用 / 优先级）
- [x] 发布链：GitHub Actions tag 发布 Windows/Linux + Core 包 + SHA256
- [x] 标准便携发布布局：exe 同级内置 `mods/`（core 包）与 `config/`；导出排除 `dev_mods` / `dev_scenes` / `framework/tests`；发布前用 `sdk/validate.gd` 校验 core 资产完整
- [ ] 发布签名与固定哈希校验

## 3D 资产：铁港码头道具

> 工作流与角色分工见 [docs/design/MODELING_WORKFLOW.md](docs/design/MODELING_WORKFLOW.md)，验收记录见 [docs/archive/MODELING_ACCEPTANCE_2026-10-19.md](docs/archive/MODELING_ACCEPTANCE_2026-10-19.md)，来源与运行时路径见 [docs/design/ASSET_MAP.md](docs/design/ASSET_MAP.md)。

- [x] 帆船 `SN_Ship_Prototype`（2608 tri）与塔吊 `SN_Harbor_Crane`（3420 tri）：建模、导出、Godot 导入
- [x] 铁港第一批 6 件道具（岸壁 / 护舷 / 系缆桩 / 木箱 / 木桶 / 矿堆）
- [x] 第一批 P0 整改：系缆桩改**十字桩头**并调尺寸 `0.62 × 0.62 × 0.70`（288 tri）、`SN_Ore` 改锈红铁矿色、Godot 导入与三段岸壁拼接验证通过（本批合计 1360 tri）
- [x] GLB 导入回归闸门 `tools/godot/verify_props.gd`：尺寸 / 轴向 / 材质 / 三角面，6 件全 PASS；改动资产后必须 `godot --headless --import` 再跑
- [x] 铁港第二批 6 件（煤气灯 / 跳板 / 抓斗 / 煤堆 / 爬梯 / 钢板堆）：1214 tri，已导出 6 个 `.glb` 并通过 Godot 导入验收（12 件全 PASS）
- [x] 铁港第三批 6 件（木料堆 / 麻袋堆 / 蒸汽管 / 缆绳卷 / 吊货网 / 托盘）：1024 tri，已导出 6 个 `.glb`；Godot 侧 18 件全 PASS
- [x] 铁港第四批 6 件（浮标 / 锚链堆 / 绞盘 / 手推车 / 碰垫 / 齿轮箱）：1452 tri，已导出 6 个 `.glb`；Godot 侧 24 件全 PASS
- [x] 铁港第五批 7 件（石阶 / 港口牌 / 港口钟 / 旗杆 / 煤溜槽 / 锅炉机组 / 龙骨墩）：1232 tri，已导出 7 个 `.glb`；Godot 侧 **31 件全 PASS**
- [x] 铁港道具 31 件 / 6282 三角面全部交付（工作台 103 对象 / 95 mesh / 8 材质）
- [x] 大型明轮蒸汽货轮 `SN_Paddle_Freighter`（46 对象 = 39 mesh + 7 empty / **12200 tri** / 6 材质 / 59.53 × 14.10 × 19.52 m，船体 LOA 55 m）：工单 `sn_paddle_freighter.json` + 参数化生成器 + 纯 Python 干跑 + Builder R1–R5 返工 + 独立 Verifier 全绿（15 对零交面、明轮 8 个旋转角 0 穿模、hull / 救生艇 / 侧封板镜像差 0、35 个闭合件水密、4 个单层曲面白名单）。已导出 `assets/models/ships/SN_Paddle_Freighter.glb`（639.5 KB / 46 节点 / 39 网格 / 12200 tri / 6 材质 doubleSided）与 `.design/ships/SN_Paddle_Freighter.blend`（`libraries.write` 独立快照）；工作台现 **149 对象**（103 + 46）
  - 明轮：14 桨叶 / 每侧 8 辐条 / 16 段双轮缘 + 内加强环 + 黄铜轮缘条 + 4 斜撑 + 轮毂法兰；轮罩 `-6°..186°` 半包箱板 + 中央观察窗 + 黄铜包边 / 铭牌（端封 r_in 2.75 让开轮扫掠、内板窗 2.30 让开蒸汽管）
  - [ ] 待办：Godot 侧导入验收（`godot --headless --import` + 轴向 / 包围盒 / 材质复核）与 PortStage 目标机位试装
- [ ] P1：补齐帆船与塔吊的 3/4、侧视、顶视截图；补塔吊参数化生成脚本
- [x] P1 ~~生成器脚本在被 gitignore 的 `.design/`~~：已全部迁到 `tools/modeling/generators/` 并纳入版本管理（`.blend` / GLB 备份 / 基线快照仍留本地）
- [ ] P1：补塔吊参数化生成脚本（`tools/modeling/generators/sn_harbor_crane_generator.py`）
- [ ] 道具进港口灰盒后，按目标机位复核尺度、朝向、材质与阴影

## 3D 资产：船舶模块（11 件）

> 覆盖 Core 里除船体外的全部模块实体：3 锅炉 / 3 货舱 / 2 导航 / 2 安全 / 1 客舱。本批只交付 Blender 工作台 + 独立 GLB，不接入 Core 内容键。工单 [sn_ship_modules_batch1.json](tools/modeling/briefs/sn_ship_modules_batch1.json)，流程同 [MODELING_WORKFLOW.md](docs/design/MODELING_WORKFLOW.md)。

- [x] 参数化生成器 `tools/modeling/generators/sn_ship_modules_generator.py`：11 件合计 **7016 tri**（预算 8300），全部由顶部参数表生成
- [x] 纯 Python 干跑 `dryrun_props.py`：tri / 包围盒（误差 ≤0.1 m）/ 边界边 / 非流形边 / 退化面 / 底面 z 全部通过
- [x] Blender 工作台 `SN_Ship_Modules` 集合：160 对象 / 145 mesh / 11 材质；网格健康四项全 0；原有 149 对象回归未变
- [x] 导出 11 个独立 GLB 到 `assets/models/modules/`，`verify_modules_glb.py` 11/11 PASS（单节点、尺寸、材质、轴向）
- [x] 验收截图归档：`docs/design/screenshots/ship_modules_batch1_{overview,boilers,cargo,nav_safety_cabin}.png`
- [x] 独立 Verifier 只读复核 R0→R2 三轮：R0 报的 5 处同法线共面 + 9 处悬空壳体、R1 报的 4 处共面 + 1 处被穹顶包住的隐藏几何全部清零，R2 判定 **pass**（仅剩 2 处完全被遮挡的微小共面记录在案）；报告见 [MODELING_ACCEPTANCE_2026-10-19.md](docs/archive/MODELING_ACCEPTANCE_2026-10-19.md)
- [ ] 接入 Core：每个模块实体 `information.model` 资源键 + manifest 声明 + 资源校验测试
- [ ] Godot 导入验收，并在船厂改装台 / 2.5D 舞台按 socket 试装

## 3D 资产：舷侧炮铁甲舰（SN_Ironclad）

> 纯展示资产（不接 Core 内容）：1860 年代舷侧炮铁甲舰，60 m 级、8830 tri。工单 [sn_ironclad_broadside.json](tools/modeling/briefs/sn_ironclad_broadside.json)，建模流程同 [MODELING_WORKFLOW.md](docs/design/MODELING_WORKFLOW.md)。

- [x] 参数化生成器 `tools/modeling/generators/sn_ironclad_generator.py`：17 站放样铁壳 + 撞角艏 + 2.2 m 英雄化装甲带 + 每舷 6 门英雄化舷侧炮（炮门 1.9×1.9 m / 炮管 Ø0.88→0.72 m）+ 中央炮房/指挥塔/双烟囱 + 三桅横桁收帆 + 甲板件，**8830 tri**（预算 12000；英雄化后 6 门/舷、炮门/炮管/装甲带放大，炮数减少抵消加粗）
- [x] 纯 Python 干跑 `dryrun_ironclad.py`：tri / 包围盒 60.14×18.00×28.64 / z -4.20..24.44 / 边界边 / 非流形边 / 退化面 / 孤立点 / 材质全部通过
- [x] 只读连通性检查 `check_ironclad_connectivity.py`（拆岛 + BVH 相交/最近距离）：551 岛、floating=0、loose=0
- [x] Blender 工作台 `SN_Ironclad_Prototype` 集合：161 对象 / 146 mesh / 11 材质；网格健康四项全 0；原有 160 对象回归未变
- [x] 导出 `assets/models/ships/SN_Ironclad.glb`（单节点 / 8 图元 / 8830 tri / 约 468 KB）+ `.design/ships/SN_Ironclad.blend` 快照；`verify_ironclad_glb.py` PASS；Godot 已生成 `.import`（PackedScene）
- [x] 截图归档：`docs/design/screenshots/ironclad_{three_quarter,broadside,bow,bow_closeup,guns_closeup,stage_ortho}.png`
- [x] 独立 Verifier 只读复核 R0→R1 两轮：R0 的 8 类悬空/错位（桅顶饰、指挥塔、通风筒、甲板机械、小艇重合、桨叶脱毂、黄铜条/驾驶台、小间隙）全部清零，R1 判定 **pass**；R2 人工反馈（舰艏两个斜桁鞍座/绑扎块浮空）已加基座/艏柱座/锚吊架修复并复验仍 **pass**；报告见 [MODELING_ACCEPTANCE_2026-10-19.md](docs/archive/MODELING_ACCEPTANCE_2026-10-19.md)
- [ ] Godot 引擎侧复核（导入已成功；待跑轴向/包围盒/材质校验）与 2.5D 舞台目标机位试装
- [ ] 如需转为战舰 / 第 5 种船体：接 Core 内容键 + manifest + 本地化 + 测试

## 3D 资产：小型明轮蒸汽船（SN_Paddle_Steamer）

> 参考澳大利亚国家博物馆的明轮蒸汽船 **PS Enterprise** 的 24 m 级小型明轮客船，纯展示资产（不接 Core）。**用户明确要求烟囱蒸汽不做几何，留给游戏内 VFX**。工单 [sn_ship_paddle_steamer.json](tools/modeling/briefs/sn_ship_paddle_steamer.json)，流程同 [MODELING_WORKFLOW.md](docs/design/MODELING_WORKFLOW.md)，验收记录见 [MODELING_ACCEPTANCE_2026-10-19.md](docs/archive/MODELING_ACCEPTANCE_2026-10-19.md) 第 10 节。

- [x] 参数化生成器 `tools/modeling/generators/sn_paddle_steamer_generator.py`：24 m 白漆内河船身 + 两舷 10 桨叶明轮 + 10 道格栅轮罩 + 前驾驶室（ENTERPRISE 文字铭牌）+ 后部雨棚游步甲板 + 黑烟囱 + 艏澳洲旗 + 艉弧形平台/舵，**11764 tri**（预算 12000）、8 材质（新增 `SN_White` / `SN_Flag_Blue` / `SN_Flag_White`）
- [x] 纯 Python 干跑 `dryrun_paddle_steamer.py`：35 对象 / 32 mesh / 3 empty、包围盒 **24.56 × 8.74 × 10.47 m**、z −1.32..9.15、边界/非流形/退化/孤立点全 0（Deck 与铭牌单层双面白名单）、左右镜像误差 0
- [x] Blender 工作台 `SN_Paddle_Steamer_Prototype` 集合：全场景 **196 对象**（161 既有 + 35 新增）；161 个既有对象名称/位置零漂移
- [x] 明轮安全与连通性：双舷各 8 个旋转角（0/45/…/315°）与轮罩/船体/明轮台 0 交面；524 个连通岛悬空 0，松接触 0.008–0.027 m（台阶、铭牌字母）
- [x] 独立 Verifier 只读 R0：**passed=true**，无阻断项；3 条非阻断视觉建议（轮罩下沿 / 雨棚体量 / 白色层次）
- [x] 按 Verifier P1 把轮罩下沿 z 0.55→**0.90**，明轮露出约 0.9 m；重跑场景验收 **passed** 并重渲 5 张截图
- [x] 导出 `assets/models/ships/SN_Paddle_Steamer.glb`（**35 节点 / 32 网格 / 11764 tri / 8 材质 doubleSided / 632.7 KB**）+ `.design/ships/SN_Paddle_Steamer.blend` 快照；`verify_paddle_steamer_glb.py` **GLB OK**
- [x] 截图归档：`docs/design/screenshots/paddle_steamer_{three_quarter,broadside,bow,stern_quarter,top}.png`
- [x] ~~烟囱蒸汽几何~~：按用户要求不建模，由游戏内粒子/VFX 负责；模型仅保留 `SN_PS_Steam_Pipes` 黄铜管路
- [ ] Godot 导入验收（本机 `GODOT_BIN` 未设置）与 2.5D 舞台目标机位试装（水线高度 / 朝向 / 明轮 Pivot 旋转）
- [ ] 可选：作为第 5 种船体 / 内河客运场景接入 Core 内容键 + manifest + 本地化 + 测试
- [ ] 非阻断视觉打磨：雨棚体量、白色层次与暗红压条对比（下一轮再定，不改当前工单）

## 3D 资产：1795 双桅纵帆船（SN_Schooner_Fame）

> 用户 2026-10-19 反馈「港口样片里的旧帆船太简陋」，给定 1795 年 Salem 名船 Fame 的绘画参考，要求做一艘「又帅气又好看」的 24 m 级双桅纵帆船替换旧浮船；明确要求**不要星条旗**。工单 [sn_schooner_fame.json](tools/modeling/briefs/sn_schooner_fame.json)，流程同 [MODELING_WORKFLOW.md](docs/design/MODELING_WORKFLOW.md)。

- [x] 人工门禁 1：新建 `SN_Schooner_Fame` 替换港口样片旧帆船；精度「风格化精修 ≈1.5–1.8 万 tri」；24 m 级、双桅纵帆、帆腹朝 −Y（Godot +Z 相机侧）
- [x] 人工门禁 2：**移除星条旗**，只保留主桅顶红白长旒（生成器不再装配 `SN_SF_Flag` / 旗杆段）
- [x] 参数化生成器 `tools/modeling/generators/sn_schooner_fame_generator.py`：18 站放样黑船身 + 赭黄上舷带 + 艉楼甲板；双桅后倾（Fore −2.5° / Main −3.2°，轴距 6.4 m）；前桅斜桁帆 + 方顶帆、主桅大斜桁帆 + 三角顶帆、两面艏三角帆；舷侧绳梯/支索/动索；艉廊 3 窗 + FAME 铭牌 + 双灯；甲板属具（舱口/绞盘/起锚机/舵轮/罗经柜/锚/钟/木桶/盘绳/fife rails/短梯/艏饰）；**13174 tri**（预算 18000）、12 材质
- [x] 纯 Python 干跑 `dryrun_schooner_fame.py`：29 mesh、12994 tri（+铭牌 180 = 13174）、包围盒 **33.44 × 6.88 × 26.82 m**、边界边仅在 6 个单层曲面白名单、非流形/退化/孤立点 0；新增 Pivot 世界变换 + 两桅轴距/后倾断言（修掉 R1 P0 的干跑盲区）
- [x] Builder R0→R4 + Verifier R0/R1 两轮：R0 抓出两桅世界坐标重合、rake 未生效（P0）；R1 修复后独立复核 **passed=true**，P2（艉柱与艉廊共面 20 mm、帆缝/索具细节、文档口径）已在 R4 收尾
- [x] 导出 `assets/models/ships/SN_Schooner_Fame.glb`（**32 节点 / 29 网格 / 13174 tri / 12 材质 doubleSided / 720.9 KB**，glTF Y-up，水线轴心 z=0，无星条旗）+ `.design/ships/SN_Schooner_Fame.blend` 快照；`verify_schooner_fame_glb.py` **GLB OK**
- [x] 截图归档：`docs/design/screenshots/schooner_fame_{three_quarter,broadside,bow_quarter,stern_quarter,top}.png`
- [x] 接入 `dev_scenes/harbor/harbor_diorama.tscn`：浮船实例换成 `SN_Schooner_Fame`，水面泡沫环 `boat_half_size` 9×4.1 → **13.2×3.9**；相机构图按 33.44 m 总长 / 26.82 m 总高复核
- [x] Godot 导入与场景验收：`godot --headless --import` 已生成 `SN_Schooner_Fame.glb.import`；`tools/godot/verify_harbor_diorama.gd` **21/21 PASS**（含新船实例、旧船移除、无星条旗、29 个网格、船体随波起伏）；`tools/godot/capture_harbor_diorama.gd` 已重截 `harbor_diorama_schooner.png` / `harbor_diorama_schooner_detail.png`
- [ ] 可选：后续加船内灯光/船尾灯夜景、或在港口样片里加第二艘同级帆船做尺度对比

## 可复用船体部件库（ship_parts，建模期复用）

> 用户提出“把一些部件抽离，做可替换/可复用的部件”；先做**建模期部件库**（不立即做运行时可换装 GLB）。契约见 [ship_parts/README.md](tools/modeling/generators/ship_parts/README.md)，流程见 [MODELING_WORKFLOW.md](docs/design/MODELING_WORKFLOW.md) 第 11.10 节。

- [x] 锁定重构前基线：纯 Python 逐对象 verts/faces/tris/material/parent digest + Blender 逐对象 local/world/polys digest
- [x] 抽出 `ship_parts/core.py`：`Part`、向量/基本体/放样/镜像工具、`PartSpec`、`tri_count`
- [x] 抽出 `ship_parts/deck.py`：舱口/天窗/绞盘/起锚机/舵轮/罗经柜/钟/木桶/盘绳/缆柱/水桶/fife rail/短梯（位置/甲板高由调用方传入）
- [x] 抽出 `ship_parts/bow.py`：艏斜桁/jibboom/艏饰（船体主色由调用方传入）
- [x] 抽出 `ship_parts/stern.py`：艉廊/3 艉窗/檐口/双艉灯
- [x] 抽出 `ship_parts/assembly.py`：`BuildConfig/PivotSpec` + 集合/材质/空物体/文字/report；bpy 只在函数内 import
- [x] 重构 `sn_schooner_fame_generator.py`：只保留船型参数、hull/桅帆/索具/锚架等船型相关几何与 `build_config()`；纯 Python 逐对象 digest **0 差异**，dryrun ALL OK（12994 tri / bbox 不变）
- [x] Builder 重建 + Blender 逐对象 world/local/polys digest 对比：32 对象 / 29 mesh / 3 empty / 13174 tri 全一致
- [ ] 抽出 `rig_kit`：桅杆/斜桁/帆面/索具参数化（按桅距、桅高、帆装配置复用）
- [ ] 用第二艘船型验证部件库复用（如 30 m 纵帆船 / 单桅纵帆船）
- [ ] 等 2.5D 舞台立项后再做运行时可替换：独立 GLB + `SN_Socket_*` + `parts_manifest.json` + `ShipVisualAssembler`

## 3D 港口样片：水面着色器试做（已完成一版）

> 目标只是"试试水"：在独立场景里验证水面观感、已有 GLB 资产的拼接与固定机位构图；不接入主流程。
> 运行与调参说明：[dev_scenes/harbor/README.md](dev_scenes/harbor/README.md)。

- [x] 独立场景 `dev_scenes/harbor/harbor_diorama.tscn`：岸壁 / 护舷 / 爬梯 / 系缆桩 / 煤气灯 / 塔吊 / 货堆 + **1795 双桅纵帆船 `SN_Schooner_Fame`**，全部复用 `assets/models` 的 GLB
- [x] 自写水面 shader `assets/shaders/water/harbor_water.gdshader`：顶点正弦波位移、双层滚动噪声法线、菲涅耳天空反射、太阳耀斑路径、岸线泡沫、船体椭圆泡沫、远水雾色淡出；兼容 GL Compatibility，不使用深度/屏幕纹理
- [x] 近水/远水双层材质：`FarWater` 下沉 3 m 只输出地平线雾色，遮住主水面网格边缘
- [x] `bobbing_boat.gd` 用与 shader 同源的波浪公式驱动升沉 / 纵摇 / 横摇，避免船与水各动各的
- [x] 黄昏逆光 + 仓库剪影 / 窗灯 + 煤气灯照明的固定 3/4 机位构图
- [x] 无头验收 `tools/godot/verify_harbor_diorama.gd`（场景加载 / shader 挂载 / 船体随波运动 / 未接入主场景）
- [x] 静态文档与截图归档：`docs/static/dev_scenes/`、`docs/design/screenshots/`
- [x] 升级为可接入的 `PortStage`：`StageHost`（`SNStageHost`）+ `SubViewport` + 固定机位已落地，港口骨架在 `framework/ui/stages/port_stage.gd`；总览页已以全窗背景层接入并叠加 2D 设施热点
- [x] 总览页主界面（Bounty Train 式：紧凑 HUD + 两侧招牌 + 底部状态条 + 详细总览抽屉）+ 场景填充 L0–L2/L6/L7 + 港口街景 kit 全部完成（见「2.5D 固定舞台」章节）
- [ ] 水面性能档位：细分 / 阴影 / 远水层的低配回退；960 宽窗口构图复核
- [ ] 港口变体：复用同一水面材质与资产 kit，做第二个港口的舞台
- [ ] 船与码头的交互细节：跳板/缆绳随船体浮动、灯池烘托与靠港阴影

## 下一阶段优先级

1. **风险与事件可读性**：预览风险来源 UI、事件结果解释、失败回滚提示。
2. **UI 体验**：按 `.design/` 原型完成设施本地化、构造对比、港口记忆的设施历史、船厂批量存取/替换选择器。
3. **平衡验证**：1000 种子地图硬约束、30–45 分钟单局、两种初始构筑胜率与再开率；将 `test_full_clear` 的 9 seed 扩展为统计型平衡探针。
4. **材料运输语义**：按 GDD 9.1 让造船材料也使用独立运输位（计重不占货舱），并补齐对应 UI 与测试。
5. **存档迁移**：声明式别名、模组版本变化、缺失可选模组。
6. **发布链**：导出预设、Core 包哈希、发布前契约测试。
7. **模组管理 UI**：启用 / 禁用 / 优先级。
8. **在港等待的随机流细化**：`NpcTraderSimulator` 的命名流键仍为 `npc_trade::<npc_id>`（同 seed + 同命令序列可复现，已由测试守护）；若要「等待时段/港口」参与派生，需把该文件纳入改动范围并补确定性用例。

## 2.5D 固定舞台（阶段 1 已启动）

> 设计已归档：[2.5D 固定舞台升级方案](docs/design/2.5D_STAGE_PLAN.md)。前六个切片（船厂 3D、通用舞台宿主 + 港口骨架、总览页接入、场景填充 L0–L2/L6/L7、Bounty Train 式主界面 HUD + 港口街景 kit/diorama、主界面美术收尾 + 街景密度 + 性能回收）已落地；剩余项列在下面。

- [x] `StageHost` + `LocationStage` 泛化：`SNStageHost` 独占 `SubViewport`/`World3D`，驱动 enter→bind→exit，支持隐藏即停更、缺失场景 `fallback_requested`、`render_shrink` 低分辨率 3D
- [x] `ShipyardStage` 迁移：环境/灯光/水面/机位/船体 GLB 绑定/升沉从 `SNShipStage3D` 迁出；`SNShipStage3D` 保留 `SNShipView` renderer 契约
- [x] `PortStage` 骨架：L0 天空 + L1 banner 背板（缺失不放黑盒，改用暖霞渐变 + 双太阳光晕的程序化 painted backdrop，有 banner 时整体隐藏）+ L2 双深度带剪影（仅无 banner 时生成）+ L3 设施（billboard 默认 / `facility_visuals` GLB 替换 / 空槽货堆 filler）+ L5 玩家船随波 + L6 前景框 + L7 蒸汽/雾；薄甲板桩基栈桥（入水木桩/桩帽/横梁）取代实心码头箱体；`size` 0.9/1.0/1.15 缩放设施层；`facility_anchors()` / `facility_screen_anchor()` 供 2D 热点
- [x] 独立预览与截图：`dev_scenes/port_stage/`（preview / sparse 两份样例）+ `tools/godot/capture_port_stage.gd`（窗口 1440×900）；[完整港口](docs/design/screenshots/port_stage/port_stage_preview.png) / [稀疏港口](docs/design/screenshots/port_stage/port_stage_sparse.png)
- [x] 场景填充 L0–L2 / L6 / L7：L0 程序化暖色天空 + 太阳光晕；L1 无 banner 时 3 层 painted backdrop；L2 双深度带 MultiMesh 剪影（小/中/大 7/10/13 栋 + 2/2/3 吊机，仅无 banner，无发光窗）；L6 左上角 3 根前景构件（吊臂/钢缆/桅杆，不遮 HUD/热点）；L7 3 组蒸汽粒子 + 2–3 层雾带；预算 preview ≈114 draws / 17,954 tris、sparse ≈73 / 19,228，全程序化无新资产。原计划「5 张 banner 烘焙」因内容侧目前只有铁港 1 张 banner，改为程序化 painted backdrop（其余港口常规路径）
- [x] 测试：`test_stage_host.gd` 17 个同步用例（LocationStage 契约 / host 生命周期 / fallback / ShipyardStage / SNShipStage3D / PortStage 装配·替换·缩放·portal / 场景填充访问器 / town kit 满配·无 town·非法路径·port.view 端到端）
- [x] 主界面重构（第五切片，Bounty Train 式）：总览默认进入 3D 港口舞台；顶部 2 行 121 px 紧凑 chrome（品牌/状态/版本 + 港口·时间·金钱·声望 + 剩余载重/货舱/煤/水/耐久/受损 + 7 导航 + 2D 切换/诊断/刷新）；`_build_top_chrome()` 在所有 run 页面共用
- [x] 两侧招牌：按 `facility_screen_anchor()` 投影 x 分左右列、同列按 y 排序，172×42（左列「设施 ▶」/右列「◀ 设施」），右侧底部固定「出航 ▶」；safe 区避让 chrome 与状态条，resize 重排；点击仍走 `_on_port_hotspot` 映射
- [x] 底部状态条：60 px、仅总览显示，耐久/货舱/煤/水/受损/最新通告 + 详细总览/出航/等待 12h；显示时隐藏 footer 并加大页面底部预留
- [x] 详细总览抽屉：`_overview_detail` 默认 false，打开时用不透明 backdrop 覆盖舞台并渲染原 2D 面板（含 `_victory_plan`）；关闭/离开总览/失败回退自动复位
- [x] 2D 回退与测试：舞台加载失败回退 2D 并提示 `ui.error.port_stage_unavailable`；`test_ui_shell` 覆盖默认 3D + chrome ≤130 px、左右招牌数量/箭头/映射/resize、底部状态条按钮、抽屉开关、等待 12h、离开隐藏/返回恢复、2D 回退
- [x] 港口街景 10 件：`SN_HT_*` 建筑/围栏/工人/小船 6204 tri（预算 11500，244 objects / 223 mesh，既有对象 digest 不变）；`sn_harbor_town_generator.py` 参数化真源 + `export_town_glb.py` 导出 + 工单；Verifier R1 复验 passed
- [x] 街景接入：core manifest 新增 10 个 `model.prop.*`（资产 65→75）；五港 `diorama.kit/town`（16 项）+ `port_archetype.schema` 扩展；`port.view` 输出 diorama/town_visuals（旧存档按 archetype 回填）；`map_generator` 持久化 diorama；PortStage L2b 装配（满配 29 props / 建筑 blockout 回退 / town 存在时跳过 L2 剪影）
- [x] 截图：主界面 [overview_port_stage.png](docs/design/screenshots/overview_port_stage.png) / [详细总览](docs/design/screenshots/overview_detail.png) / [完整港口](docs/design/screenshots/port_stage/port_stage_preview.png) / [稀疏港口](docs/design/screenshots/port_stage/port_stage_sparse.png)
- [x] 第六切片·HUD 图标化：`_stat_chip()` 支持可选 `icon_key`，`_hud_icon()` 经 `AssetService.find_key("icon.money/coal/water")` 从任一内容包裸键解析并缓存，缺资产回退纯文字；金币/煤炭/淡水出现在顶部 chrome 与底部状态条
- [x] 第六切片·主题化招牌：[sn_harbor_sign.gd](framework/ui/components/sn_harbor_sign.gd) 自绘木板/木纹/铁框/黄铜铆钉 + 设施徽记 + 指向场景的箭头 + 悬停黄铜光晕；Button 语义/text/tooltip 保留；172×42 招牌在 1440×900 与 960×540 窗口均完整可见（canvas_items 缩放）
- [x] 第六切片·街景密度：`port.size`/`port.diorama.density` 确定性分档（small→sparse 28、medium→normal 47、large→busy 63）；新增市场摊/吊车/麻袋堆/钢板堆/矿堆/托盘/跳板/系缆桩/绞盘/浮标 10 类 slot（全部复用已声明资产）；5 个 archetype 的 `diorama.town` 与 schema 的 `diorama.density` 同步
- [x] 第六切片·静态与船体合批：facilities/town 程序化 box → 共享单位立方体 MultiMesh，其余按材质签名烘焙成每材质 1 个 ArrayMesh；玩家船在泡沫 AABB 后按 ship-local 刚性合批，动画/骨骼/粒子/透明/法线贴图整船安全回退；实测 **preview 63 / sparse 56 draw calls（37,280 / 29,738 tris）**，`batch_stats()` 暴露前后计数
- [x] 第六切片·无 banner 程序化远景：山脊/远城塔楼/屋脊+烟囱 3 层低对比剪影合并为 1 个 MultiMesh，有 banner 时隐藏；旧斜置 sky card 改固定 260 m camera-facing，修掉右侧远景截断
- [x] 第六切片·测试与工具：`test_stage_host` 增至 24 例（密度/可选 slot/静态合批/无 town 合批/远景层/船体合批与泡沫 AABB/非刚性回退），`test_ui_shell` 覆盖 HUD 图标与招牌组件/紧凑尺寸 helper，全量 **162 passed / 0 failed**；新增 [measure_port_stage.gd](tools/godot/measure_port_stage.gd) 窗口实测工具（真实 draw calls/分层 surface/合批统计，headless 降级）
- [x] 第六切片·截图：主界面 1440×900 + 960×540 + 详细总览 + 完整/稀疏港口（见 [overview_port_stage.png](docs/design/screenshots/overview_port_stage.png) / [overview_port_stage_960.png](docs/design/screenshots/overview_port_stage_960.png) / [overview_detail.png](docs/design/screenshots/overview_detail.png)）
- [x] 第七切片·连续港区三站位：码头 54→160 m、广场 120→250 m，`STATIONS`（market -30 / harbor 0 / supply +30）定义各站位镜头 pose、泊位与道具组；`exchange`/`supply` 设施搬到对应站位；`focus_station()` / `advance_station()` 在 0.6 s 内平移镜头并把玩家船（先转艏、24 m/s 沿岸）开到新泊位，港口/街坊/设施/合批层不重建，泡沫环随船移动
- [x] 第七切片·画幅层跟随与站前道具：镜头平移时天空/远景/banner/前景框/雾带按偏移平移保持构图、L2 剪影半速视差；`STATION_PROPS` 每站 5/8/11 件（复用 town kit 已解析路径，`station_prop_count()` 单独计数）
- [x] 第七切片·主界面接线与泊位面板：`STAGE_SCREENS`（overview→harbor / market→market / supply→supply）让三页共用同一 `PortStage` 实例；market/supply 页改为右侧 640 px `DockPanel` + 左侧露出 3D 街景，站位间导航不播黑场淡出；市场页九列表改 620 px 纵向条目、补给页煤水卡改单列堆叠（最坏内容宽 574 px）
- [x] 第七切片·测试/工具/截图：`test_stage_host` 增至 30 例（新增站位相邻顺序/镜头与泊位移动/立即聚焦幂等/过渡中重定向/重绑保持站位/站前道具密度），`test_ui_shell` 改写总览用例覆盖共用舞台/泊位面板/镜头到位/离页隐藏，全量 **167 passed / 0 failed**；`capture_port_stage.gd` 扩到 5 张站位截图、`measure_port_stage.gd` 增加三站位实测、`ui_snapshot.gd` 增加 `--station-shots`；截图 [市场站位](docs/design/screenshots/market_station.png) / [补给站位](docs/design/screenshots/supply_station.png) / [市场 960×540](docs/design/screenshots/market_station_960.png) / [market 镜头](docs/design/screenshots/port_stage/port_stage_market.png)
- [ ] 委托 / 情报页舞台化（当前仍为 2D 页面）
- [ ] 离港拉高 → 2D 海图 → 进港降落演出（可跳过、事件暂停）
- [ ] 目的港舞台预加载、质量档位与低配回退、第三方 `.glb` 白名单评审
- [ ] L2 LOD 与远景 `visibility_range`

## GDD 验收对照（MVP）

| 验收项 | 状态 | 备注 |
| --- | --- | --- |
| 4–5 港口、不可达/无分支防护 | 完成 | 30 种子测试；建议扩到 1000 |
| 五段主线 | 完成 | 1–5 可接取并完成；第 5 段后进入通关判定 |
| 三种锅炉策略影响耗时/煤水/风险 | 完成 | 预览与结算均使用 |
| 重量影响速度 | 完成 | 分段线性速度系数；transit 模块计重 |
| 2–3 艘 NPC 商船推动市场 | 完成 | 抵达时推进，情报只给区间 |
| 情报快照保留 / 时间戳 / 过期 | 部分 | 快照与时间戳完成；过期仅显示年龄 |
| 船体与五类模块购买/打造/运输/入库/安装/替换 | 完成 | 购买/打造/仓库/transit/替换/卸下全链路；仓储 UI 为基础版 |
| 客舱、岗位、贷款、维修、声誉、自动存档 | 完成 | 贷款自动偿还已接入委托收入 |
| 第五委托后解锁大型船并通关 | 完成 | 大型船体+锅炉+≥1 货舱在造船厂触发通关总结页 |
| 同 seed / 命令序列结果一致 | 完成 | 测试覆盖开局、RNG 隔离与委托刷新 |
| 存档哈希一致 | 完成 | 数字规范化到 1e-9；新字段惰性补齐 |
| Framework 无具体 `core:*` ID | 完成 | 有测试守护 |
| 第三方内容走同一注册接口 | 完成 | 示例锅炉测试 |
| 完整通关回归 | 完成 | `test_full_clear` 覆盖 9 个 seed，航次 ≤16 |
| 试玩反馈 1–6 落地 | 完成 | 迭代 2：tier1 仅金币、补给反向损失带、情报对比矩阵、打造订单 + 在港等待、信息条剩余舱容、通关引导；`test_ui_shell` 逐条守护 |

## 正式版方向：持久模拟经营（已确认）

> 定位：一个战役 = 一份持久存档，世界随机开局后固定；多舰队、基地、自动贸易与遗迹都活在同一存档里。详见 [架构方向](docs/design/PERSISTENT_CAMPAIGN_ARCHITECTURE.md) 与 [路线图](docs/design/FULL_GAME_ROADMAP.md)。

- [x] 产品决策：持久模拟经营战役 + 随机开局，失败不静默删档
- [x] 实体契约 v2 草案 + `content_types.json` v1（含 16 个 active 类型、v2 模块分类与正式版 planned 系统，框架一致性测试守护）
- [x] `content_types.json` 生成链：`tools/gen_content_types.mjs` → 框架 `ContentTypes.gd` + 编辑器 `content-types.js`；Godot/Node 测试与 `--check` 门禁
- [x] 存档 Schema 2.0：新档写 save_schema/state_schema 2.0，`SaveMigrations` 支持 1.x → 2.0 并回填 campaign 元数据；旧档可加载且不自动改写
- [x] Content Schema 2.0 草案：`schemas/v2/common` + start/world/region/site/route，`draft_schemas` 登记且保持 planned，SchemaValidator 有效/无效样本测试
- [x] Content Schema 2.0 世界探索家族补齐：`weather_profile` / `faction` / `discovery` 草案，登记 `draft_schemas` 并补有效/无效样本测试
- [x] `CampaignState` 分区骨架：`campaign.world` / `codex` / `factions` 惰性补齐，探索进度只追加 ID，`set_faction_reputation` 夹取，随存档往返；新局标记 `world.generated` 与起始港
- [x] 模块实例化第一步：`ship.module_instances` + `module_serial`，实例 id/condition 随存档；`damage_module` 效果、锅炉过热接入、维修按部件计价、船厂状态徽标、顶部信息条/船卡/补给页可见；`capture_ui.ps1 -Damage` 可复现受损截图（见 [SHIP_MODULE_INSTANCES.md](docs/archive/SHIP_MODULE_INSTANCES.md)）
- [x] 2.5D 首个切片：船厂正常态 3D 实机舞台（`SNShipStage3D` 按 hull_tier 选船、固定 3/4 机位、复用港口水面着色器，改装态保持纵剖图，资产缺失回退程序化占位）；截图见 [stage3d](docs/design/screenshots/stage3d/shipyard_normal.png)，方案见 [2.5D_STAGE_PLAN.md](docs/design/2.5D_STAGE_PLAN.md)
- [x] 2.5D 第二切片：`SNStageHost` + `LocationStage` 泛化、`ShipyardStage` 迁移、`PortStage` 骨架（设施/空槽/回退/玩家船）、独立预览与 9 个舞台测试；截图见 [port_stage_preview](docs/design/screenshots/port_stage/port_stage_preview.png) / [port_stage_sparse](docs/design/screenshots/port_stage/port_stage_sparse.png)
- [x] 2.5D 第三切片：总览页全窗 `PortStage` 背景层 + 2D 设施热点（相机投影 Ghost Button，点击进对应设施页）+ 俯瞰/返回切换 + 失败回退 2D；新增 `test_ui_shell` 用例与 `ui_snapshot --overview-stage` 截图；截图见 [overview_port_stage](docs/design/screenshots/overview_port_stage.png)
- [x] 2.5D 第四切片：PortStage 场景填充 L0–L2/L6/L7（程序化天空 + 太阳光晕、3 层 painted backdrop、双深度带 MultiMesh 剪影、左上角前景框、3 组蒸汽粒子 + 2–3 层雾带），新增 5 个只读访问器；预算 ≤120 draws / ≤60k tris、无新资产；截图见 [port_stage_preview](docs/design/screenshots/port_stage/port_stage_preview.png) / [port_stage_sparse](docs/design/screenshots/port_stage/port_stage_sparse.png)
- [x] 2.5D 第五切片：Bounty Train 式主界面（默认 3D 舞台、121 px 紧凑 HUD、左右设施招牌 + 出航招牌、60 px 底部状态条、详细总览抽屉、2D 回退）+ 港口街景 10 件 `SN_HT_*` + `port.diorama`/`town_visuals` 接线（16 项、旧存档回填）；截图见 [overview_port_stage](docs/design/screenshots/overview_port_stage.png) / [overview_detail](docs/design/screenshots/overview_detail.png)
- [ ] 阶段 0：Content Schema 2.0 系统类型、多战役存档、tick 模拟框架
- [ ] 阶段 1：广域海图与探索（区域 / 地点 / 迷雾 / 低细节远方模拟）
- [ ] 阶段 2：舰队组成与战斗（先自动结算，再评估战术层）；模块分类收敛为 boiler/cargo/utility/cabin/crew，导航与安全并入 utility；战斗契约边界见 [战斗系统架构评审](docs/design/COMBAT_ARCHITECTURE_REVIEW.md)
  - [x] 建立独立 `SNBattleSim` 2D 规则试验台第一版：固定大/中/小船体、多武器、视野与最后已知位置追击、直射/炮击/侧弦齐射、货船护航、自定义武器及配置导入导出；战场使用无限坐标、全舰取景镜头、低机动船舶运动、阵营观察视角、航速/视野配平、所选舰逐武器射界、逐挂载武器装填倒计时、带脱离迟滞的逐舰可编辑战术状态机、战场事件 HUD 与实时舰船状态面板（未接入 Godot/战役存档）
- [ ] 阶段 3：基地建设与生产链（接入舰队/战斗/贸易）
- [ ] 阶段 4：自动化贸易（航线、规则、风险与 tick 结算）
- [ ] 阶段 5：遗迹探索（程序化房间、远征、战利品）
- [ ] 阶段 6：整合、内容量、Mod API 2.0 / Content Schema 2.0 冻结与发布验收

## 航海图系统（Nautical Chart System，设计冻结 v1.0，待实施）

> 正式版核心系统：坐标空间世界、三重迷雾、渐进式探索、事件化海洋。取代 MVP 时期的抽象图模型（`MapGenerator` 4-5 港口全连接图），作为正式版海图的唯一真源。设计文档：[NAUTICAL_CHART_SYSTEM.md](docs/design/NAUTICAL_CHART_SYSTEM.md)。

### 阶段 0：数据模型与生成器

- [x] `WorldMap` / `Landmass` / `Port` 数据结构（坐标空间，港口锚定在陆地海岸线上）
  - `framework/domain/world/landmass.gd`: 陆地多边形，4种原型（大陆/大岛/小岛/环礁），支持面积/质心/边界框/海岸线采样
  - `framework/domain/world/world_port.gd`: 港口实体，包含位置/区域/设施/出航角度，保留MVP字段兼容性
  - `framework/domain/world/region.gd`: 行政区域（沿岸/远洋），包含陆地ID列表
  - `framework/domain/world/world_map.gd`: 世界地图容器，支持序列化/反序列化
- [x] 程序化陆地生成器（continent / large_island / small_island / atoll，相干谐波剖面 + Douglas-Peucker）
  - `framework/domain/world/land_generator.gd`: 半径剖面 = base + Σ aᵢ·sin(fᵢ·θ+φᵢ)，相位每岛只抽一次 → 平滑海岸线；生成后按 0.3 单位容差简化
  - 早期实现是逐顶点 `randf()`（白噪声）+ 每顶点随机正弦相位，海岸线呈锯齿星形；已改为相干噪声（注释里长期写的 "Perlin/Simplex" 当时并不存在）
  - 默认配置：400×400世界，11个陆地（1大陆+3大岛+4小岛+3环礁）
- [x] 港口锚定算法（海岸线采样 + 最小间距约束）
  - `framework/domain/world/world_generator.gd`: `_place_ports_on_coastlines()` 在海岸线上采样，保证15单位最小间距
  - 默认13个港口，支持重试机制（20次尝试调整位置）
- [x] 连通关系预计算（绕开陆地的航线图，**稀疏但连通**）
  - `route_calculator.gd`: `build_connectivity_graph()` 最小生成树（Prim）+ 每港 2 条最近邻捷径；13 港实测 38 条边（原为全连接 78 条，海图画成不可读的毛球）
  - 绕陆走"沿岸外扩环 / 外切点"的有界递归（`_detour`，深度 ≤3），无 A*、无网格；每条发出的曲线都过 `_path_is_clear` 校验
  - 端点附近 `END_GRAZE_TOLERANCE = 8` 单位内的擦岸算靠泊（港口就在海岸线上），不算穿陆
- [x] 贝塞尔航线生成（出航角 + 陆上绕行）
  - `route_calculator.gd`: `compute_departure_angles()` 取邻居质心方向；若指向本岛内陆则回退为背离本岛质心方向
  - `_create_bezier_path()` 生成三次贝塞尔曲线，20段细分；控制臂按 0.3→0.18→0.09→0 逐档收紧直到曲线不穿陆
- [x] 同 seed 可复现性测试（`RngService` 命名流）
  - `framework/tests/cases/test_world_generator.gd`: 12个测试用例
  - `test_same_seed_produces_identical_world()`: 同seed两次生成完全一致
  - `test_different_seeds_produce_different_worlds()`: 不同seed产生不同世界
- [x] 15-20 港口合理分布验证
  - `WorldGenerator.MIN_PORTS = 15` / `MAX_PORTS = 20` 为冻结常量，`_validate_world` 缺省按此校验；港口不足直接判生成失败（`too few ports: N < 15`），不再静默返回小图
  - 正式 profile 走 `WorldGenerator.formal_profile(definition)`：把内容层 `map_profiles` 定义（`port_count_range` / `archetypes` / `port_name_keys` / `required_facility_tags`）展开成 5 区域、11 块陆地（1 大陆 + 5 大岛 + 3 小岛 + 2 环礁）与 `FORMAL_PORT_SLOTS` 港口槽位（起始大陆 6 港、大岛 2–3 港、小岛/环礁各 1 港）
  - 生成失败改为回传最后一次尝试的真实原因（`too few ports: 11 < 15`），不再吞成「failed after 60 attempts」
  - 测试夹具从 13 港提到 18 港（`test_world_generator.gd` / `test_sea_chart.gd`），断言改用 `WorldGenerator.MIN_PORTS/MAX_PORTS` 而非字面量 `>=10`
  - `test_world_below_port_floor_is_rejected` 锁死「10 港必须被拒」；`test_formal_profile_matches_design_bounds` 锁死「15–20 港 profile 能真的生成 15 港、全部锚定海岸线、陆地占比 < 45%」
  - 锚定到海岸线（距离<2单位）、最小间距15单位、必需设施（船厂/情报站）在起点2条边内、所有港口从起点可达
  - 边界：可玩 MVP 地图仍走 `MapGenerator` 的 4–5 港分支网络；15–20 港坐标空间世界的真实对局接入属于阶段 3 之后
- [x] `WorldOps` 替代旧 `MapOps`
  - `framework/domain/world/world_ops.gd`: 世界地图查询和变更接口，保持GameState兼容性

### 阶段 1：迷雾网格

- [x] `FogGrid` 数据结构（`cell_size = min_vision_radius / 4`）
- [x] 三重状态机（black / explored / visible）
- [x] 沿岸 vs 海洋不同规则：沿岸格子经过后永久保留灰雾，海洋格子离开后直接变回黑雾
- [x] 港口揭示（路灯花效应，半径 R 内永久清除战争迷雾）
- [x] 迷雾 shader（格子 alpha 插值平滑过渡，避免棋盘格感）
- [x] 陆地轮廓渲染（剪影优先，纯色多边形）
- [x] 迷雾单元测试（状态转换、沿岸规则、港口揭示）

### 阶段 2：海图 UI

- [x] `SNSeaChartView` 连续可缩放 2D 视图（滚轮缩放、拖拽平移、`Esc`/`+`/`-` 键盘控制）
  - `framework/ui/components/sn_sea_chart_view.gd`：使用 `_draw()` 在世界坐标上绘制水面、陆地多边形（已探索/未探索双色调）、贝塞尔航线、港口图标（当前/已访问/已发现三态 + 脉冲/选中高亮）、降采样迷雾网格（BLACK/EXPLORED 分色、VISIBLE 跳过）、船只标记、罗盘、图例与缩放指示
  - 世界↔屏幕线性变换：`world_to_screen / screen_to_world`，缩放以鼠标位置为不动点，半径按 `sqrt(_zoom)` 缩放
  - 发出 `port_clicked(port_id)` 与 `port_hovered(port_id)` 信号，不执行导航或查询
- [x] 信息层级（港口/陆地/船只按发现等级显示）
  - 港口只在 `discovered=true` 时显示；航线只在两端都已发现时显示，`explored=true` 表示两端都已访问
  - 陆地多边形在迷雾未探索时使用暗色，已探索时使用亮色（fill + outline）
  - 在航时显示船只菱形标记（带脉冲）
- [x] 右侧 Panel（目的地基础信息 + 预计时间/消耗/风险）
  - `framework/ui/components/sn_sea_chart_panel.gd`：展示港口名、原型、区域、设施列表、航线信息（距离 / **预计时间** / **煤水预计消耗（需求 / 存量）** / **风险** / 是否已探索）与「启航」按钮
  - 风险等级按阈值分四档（low/medium/high/extreme），文案与颜色走本地化；风险未知时显示「无法评估」而不是「无风险」
  - 补给不足时给一行提示，但不在面板拦截出航（阻断仍由出航页的 `voyage.preview` 决定）
  - 发出 `voyage_requested(port_id)`，由 Shell 路由到 `voyage.start`
- [x] 查询层 `sea_chart.view`（已注册在 `QueryRegistry`）
  - `framework/application/queries/sea_chart_view.gd`：输出世界边界、陆地多边形、按发现等级分类的港口、已知航线、降采样迷雾网格（步长 `max(w,h)/80`）、船只位置
  - 只读查询，不修改 `GameState`；`has_run=false` 或 `world_map` 为空时返回结构化空结果
  - **航程预估**：每条航线附 `travel_hours` / `arrival_hours` / `speed` / `supplies` / `risk_level` / `strategy_id` / `distance_source`，由 `framework/domain/voyage/voyage_estimator.gd` 结合船速、锅炉策略、载重系数与航行规则推导
  - 公式与 `VoyageCalculator.preview` 完全一致（直接复用其 `weight_speed_factor` / `PASSENGER_WATER_RATE` / `risk_label` 与 0.01–0.7 风险钳位），面板与出航页不会给出两个数字
  - 抽象地图航线距离优先（`distance_source="voyage"`）；孪生世界 MST 图上没有对应抽象边时退回海图距离，`risk_level = -1` 表示未知
- [x] 海图 UI 单元测试（13 个用例 → 21 个）
  - `framework/tests/cases/test_sea_chart.gd`：覆盖查询结构、世界边界匹配、陆地数量、当前港标记、航线生成、迷雾降采样、港口位置合理性、空上下文、JSON 序列化往返、同 seed 复现、异 seed 差异、发现计数、原型名称合法
  - 新增 `test_sea_chart_routes_carry_voyage_estimates`：真实 `run.start` 后逐条航线断言预估存在，并把海图时长/风险与 `voyage.preview` 逐项对齐（容差 0.05 h / 0.02）；无抽象边的航线必须报 `-1` 未知风险
  - 新增 `test_sea_chart_panel_renders_voyage_estimates`：面板真实挂树后断言「预计时间 / 预计消耗 / 煤炭 / 风险档」文字出现，未知风险渲染为「无法评估」
- [x] 附带修复：Phase 1 迷雾系统的 4 处编译问题（`fog_grid.gd` 类型推断、`fog_ops.gd` `GameState.has()` → `state.data.has()`）
- [x] 真实渲染视觉验收（此前只有无头测试，海图从未被画出来过）
  - 独立预览场景 `dev_scenes/sea_chart/`（`fresh` / `bare` / `explored` / `voyage` 四个变体，`explored` 会真实回放一圈沿岸航行产生永久灰雾）
  - 截图工具 `tools/godot/capture_sea_chart.gd`（窗口 1440×900，先写 tmp 再原子提交、纯色画面判失败、90 s 看门狗）
  - 产出 [fresh](docs/design/screenshots/sea_chart/sea_chart_fresh.png) / [bare](docs/design/screenshots/sea_chart/sea_chart_bare.png) / [explored](docs/design/screenshots/sea_chart/sea_chart_explored.png) / [voyage](docs/design/screenshots/sea_chart/sea_chart_voyage.png)
  - 预览世界按验收口径生成 **15 港**（`WorldGenerator.MIN_PORTS..MAX_PORTS`），不再是手搓的 13 港；`bare` 截图可直接数出 15 个港口
  - 预览跑一次真实 `RunFactory.create_run`，只替换坐标 `world_map`：`voyage` 截图右侧面板显示的是**真实**距离 / 预计时间 / 煤水预计消耗 / 风险档（与 `voyage.preview` 同源），不是摆拍数值
- [x] 视觉验收带出的缺陷一并修掉（详见 [设计文档 §14.1](docs/design/NAUTICAL_CHART_SYSTEM.md)）
  - 海岸线：逐顶点白噪声（"锯齿星形"）→ 相干谐波剖面，相位每岛只抽一次；`simplify_polygon()` 投入使用
  - 迷雾：每格纯色矩形 → 每格 1 texel 的 RGBA 纹理 + 线性过滤（平滑且 1 次绘制）
  - 连通图：13 港完全图 78 条线 → 最小生成树 + 每港 2 条最近邻（38 条），连通且可读
  - 航线穿陆：出航角可指向内陆 + 绕岛循环振荡 + 曲线从未校验 → 出航角背离陆地回退、沿岸环行/外切点有界递归、曲线落地前包围盒剪枝校验
  - 沿岸带：`COASTAL_CELLS = 2` 格（原 2.0 世界单位 < 雾格）；已探索判定改为海岸采样 ≥25%
  - 面板/预览裸键：查询补 `archetype_name_key` / `region_name_key`，设施走 `ui.facility.*`，预览用 Core 真实原型 ID
  - 交互：`select_port()` 不再把视图跳位（居中拆为 `center_on_port()`）
  - 回归：`test_world_generator` 新增「航线不得穿陆」「连通图稀疏且连通」2 个用例
- [x] 测试收紧（按只读验收意见，把"比名字弱"的断言补实）
  - 航线穿陆：41 点索引采样 → **逐段精确几何**（`Geometry2D.segment_intersects_segment` + 多点在内检测），容差直接引用 `RouteCalculator.END_GRAZE_TOLERANCE`（原 12.0 比实现 8.0 松，等于没测）
  - 连通图：不只数边数，改为 `WorldOps.bfs_distances()` **真断言连通**；稀疏阈值 `complete/2`（n² 缩放、13 港只差 1 条就过）→ `3n` 上界
  - 迷雾沿岸带：新增 `test_coastal_band_is_two_cells_wide`，断言 1.5 格内必为海岸、3.5 格外必不是（原用例在旧语义下也能过，等于没测出"按格数而不是世界单位"）
  - 海图查询：新增 `archetype_name_key` / `region_name_key` 用例——**当场抓出 `world.region.*` 在全项目没有本地化条目**（面板会显示裸键，预览里被我自己的 workaround 遮住了），已补框架中英默认文案
  - 出航刻度：把弧度→方向抽成 `SNSeaChartView.exit_direction()` 可测接缝，新增用例锁死"90 不得当 90 度处理"
  - 布局前居中：`center_on_port()` 在控件无尺寸时改为排队、首次取景后应用，并加用例
- [x] 航线预计算（消除海图开页卡顿）
  - `WorldMap.edges[]`（world schema **1.1**）：每条连通边在生成期算好 `{from, to, distance, path}`，扁平 `[x0,y0,…]` + 2 位小数存储
  - `WorldGenerator._build_route_edges()` 是唯一写入方；`sea_chart.view` / `WorldOps.route_between` 只读，缺 `edges` 的旧存档回退现场计算
  - 实测：13 港 38 边，查询 **558 ms → 12 ms**（46×）；生成期一次性 +336 ms；`world_map` JSON 112 KB（其中航线 82 KB）
  - 新增用例：航线表完整性/双向往查/存档往返、查询确实读表（用 sentinel 路径证明不重算）、无 `edges` 的旧世界仍能出图
- [ ] 航线表体积优化（可选）：38 条边占 82 KB，正式版可对 path 做 0.5 单位抽稀或改用二进制/压缩，当前保留全精度以免高倍缩放时折线感
- [x] 入口集成与 Shell 接线（M 键 / 顶部导航「海图」/ 出航页「打开海图 (M)」）
  - 新页面 `framework/ui/screens/flow/sea_chart_screen.tscn`（`SeaChartScreen`）：左侧 `SNSeaChartView` 铺满 + 右侧 `SNSeaChartPanel`（320 px），打开时预选当前港；面板「启航」冒泡为 `voyage_requested(port_id)`，Shell 路由到出航页预选目的港（锅炉策略仍在出航页确认后才发 `voyage.start`）
  - Shell：`Esc` 关闭返回来源页，`M` 全局开关（仅在 `has_run` 且非在航、无通关弹窗时生效），顶部导航行追加「海图」按钮（海图打开时高亮），新开/读档重置返回页记忆
  - 面板绑定港口/航线数据、图表点击选中与启航冒泡均有用例；Shell 集成用例同时覆盖「无 `world_map` 时显示无数据提示」与「注入世界后的完整数据路径」
  - 边界：该条为历史记录——真实对局接入已由下方「真实对局接入（孪生世界）」完成，海图页不再显示无数据提示
- [x] 真实对局接入（孪生世界）：`RunFactory.create_run` 在抽象地图生成后用 `_coordinate_world_profile()` 生成**坐标空间孪生世界**写进 `state.data["world_map"]`——每港一岛、第 i 港落第 i 岛，与对局地图共享 `port_0..N` ID、原型与名称，海图查询、发现状态与迷雾天然对齐；起港灯塔揭示（`_initialize_world_fog`：海岸带标记 + 港口揭示 + 船视）；抵达时 `VoyageService` 经 `WorldOps.mark_visited` + `FogOps.reveal_arrival` 同步访问/发现与泊位迷雾（旧存档无 `world_map` 时全部为 no-op，海图仍显示无数据提示）；孪生世界生成失败只降级海图、不失败开局。已知边界：孪生世界连通图为自身 MST 图，与抽象地图航线不完全一致（出航仍按抽象地图邻居），阶段 3 航行演出统一
  - 测试：`test_run_pipeline::test_run_maps_a_chart_twin_world`（真实 run.start 直接喂 `sea_chart.view`：ID/原型镜像、起港发现+访问+当前+出雾、首航后目的港访问+出雾）；`test_ui_shell` 海图集成用例改为钉住"真实对局出图、无数据提示不再出现"
- [x] 航程预估进查询层（阶段 2 验收补齐）：世界表只存几何量，`travel_hours` / `risk_level` / 煤水消耗由 `VoyageEstimator` 在查询时推导
  - `framework/domain/voyage/voyage_estimator.gd`：`estimate()` 只做只读投影，常量与钳位直接引用 `VoyageCalculator`，不复制第二套公式
  - `sea_chart.view` 每条航线输出 `travel_hours` / `arrival_hours` / `speed` / `supplies`（需求/存量/余量/是否够）/ `risk_level` / `risk_label` / `risk_source` / `distance_source` / `strategy_id`
  - 风险来源与 `_risk_breakdown` 逐项对齐（基础风险 + 策略 + 超载 + 低耐久 + 设备船员），跨页数值一致性由用例锁死
- [ ] 线索可视化（箭头/虚线圆圈/`？港口名？`，按 §7.2 分级）——阶段 4 探索系统落地后接入
- [x] 航线绕行按岛屿尺寸自适应（`RouteCalculator._detour_clearances`）：外扩档位 = 岛屿半长轴 ×1/2/3，下限 `COAST_CLEARANCE * 0.5`、上限 `COAST_CLEARANCE`；小礁石不再把航线拽出 42 单位，大陆保持原档位；每个候选仍过 `_path_is_clear` 校验，新增档位缩放与绕行不穿陆用例
- [x] ~~海图查询每条边都重算贝塞尔~~ 已由「航线预计算」覆盖：`WorldMap.edges[].path` 即生成期算好的贝塞尔折线，`sea_chart.view` 与 `WorldOps.route_between` 均只读表；仅缺 `edges` 的旧存档回退现场计算（此条为该工作完成前的过时记录）

### 阶段 3：航行演出状态机

> **实机验收反馈（2026-10-21）：F1–F4 待修，先记录不开工**，见本小节末尾
> 「阶段 3 实机验收反馈」——离港平移、镜头俯角/海图缩放、海图太小、船没沿航线。

- [x] 状态机实现（InPort → OpenSeaChart → VoyagePlanned → Departure → AtSea → Arrived）
  - `framework/domain/voyage/voyage_presentation.gd`（`VoyagePresentation`，纯模型）：10 个相位（`VOYAGE_PLANNED / DEPARTURE_3D / DEPARTURE_VEIL / AT_SEA / EVENT_APPROACH / EVENT_WAIT / EVENT_RESUME / ARRIVAL_APPROACH / ARRIVAL_HARBOR / DONE`）+ 5 个里程碑（`DEPARTED / AT_SEA_STARTED / EVENT_READY / ARRIVAL_READY / DONE`），逐帧 `tick()` 推进，云层与航程进度都在模型里算
  - 不碰 `GameState`：`voyage.start` 仍一次性结算航行，演出层只决定"什么时候把哪个画面推给玩家"，旧存档 / 9 seed 通关回归 / `at_sea` 语义全部不变
  - `skip()` 不替玩家做事件决策：未处理的事件仍会被推到玩家面前
- [x] 3D 镜头升降（离港：船驶离 + 镜头上升；入港：镜头下降 + 船驶入）
  - `framework/ui/stages/port_stage.gd` 新增 `begin_departure()` / `begin_arrival()` / `advance_voyage()` / `reset_voyage()` / `skip` 相关访问器：船从泊位驶向 `SEA_HANDOFF`（港外海面）时镜头升到 `DEPART_CAMERA` 高位广角；入港反过来从高位下降到站位机位，并把船停回泊位。beats 由 Shell 逐帧步进（`_process` 在 beat 期间让位给 `advance_voyage`，不双倍速），测试/截图工具可同步驱动
  - 状态机与 3D 动画共用 beat 长度（`VoyagePresentation.DEPARTURE_3D_SECONDS == PortStage.VOYAGE_BEAT_SECONDS`，有测试守护），云层不会在镜头还在动时盖下
  - **接缝不变量**：3D 船停在 `SEA_HANDOFF` 的那一刻，海图船标记从 `VoyagePresentation.handoff_progress`（默认 0 = 出发港图标）开始 —— 3D 船正是从这个港口驶出去的，两边是同一个地理位置。`test_chart_ship_starts_where_the_stage_ship_vanished` 用真实 Shell 断言 3D 船确实停在 `SEA_HANDOFF`、且海图接管第一帧的船标记坐标等于出发港在航线上的起点
  - 演出期间 3D 舞台被强制挂在港务站位（不依赖 `STAGE_SCREENS` 页面）；离港用出发港的 `port.view`（命令前缓存 `_presentation_origin_view`），入港用抵达后的目的港
- [x] 云层转场（3D 港口 → 云层 → 2D 海图 → 云层 → 3D 目的港）
  - `framework/ui/components/sn_cloud_veil.gd`（`SNCloudVeil`）：程序化软边云团（运行时生成 128×128 smoothstep alpha 贴图 + 三档深浅 + 穿越漂移），只渲染 `cover`，不做时序
  - 出航 / 事件 / 抵达三处都是"盖住 → 换页 → 散开"；`cover` 由状态机逐帧驱动
- [x] 船舶 icon 沿贝塞尔路径移动（`Route.bezier_path`）
  - `SNSeaChartView.set_ship_position()` 逐帧覆盖船只坐标（不重绑整个 ViewModel，避免每帧重建迷雾纹理与取景）
  - `VoyagePresentation.sample_polyline()` 按**弧长**取点，曲线密集段不会走得比稀疏段慢；缺对应航线时退回起终港直线，船不会停在原地
- [x] 时间加速流逝
  - 整段航程压缩到 2–9 s（`SECONDS_PER_GAME_HOUR = 0.35` + 上下限），`hours_per_second` 即航程条上的倍率（实测 `×2.9`）；游戏时间本身已由 `voyage.start` 推进
  - 航程条显示起终港 / 进度 / `航程 X 小时 / Y 小时` / 时间倍率 / 「跳过演出」
- [x] 事件触发（云层下降 → 事件决策 → 回到海图）
  - 事件落在航程 `DEFAULT_EVENT_PROGRESS`（50%）处，演出停在 `EVENT_WAIT` 等玩家选择；选完云层重新盖住再交还海图，不会把事件页硬切回海图
  - 演出期间顶栏与"当前港"高亮都按出发港显示（`在航 → 目的港`），不提前剧透抵达
- [x] 航行演出单元测试
  - `framework/tests/cases/test_voyage_presentation.gd`：13 例（压缩窗口、3D 离港先于云层、出航交还、进度=压缩时间、事件中断与恢复、入港收尾、跳过不跳过事件、决策点跳过无效、快照字段、弧长采样、扁平路径还原、云层 clamp、beat 长度一致性）
  - `framework/tests/cases/test_voyage_flow.gd`：6 例，真实 Shell + 真实命令（3D 离港 + 云层 → 海图、3D 交接点不变量、船只推进、抵达结算、跳过、事件中断后恢复），事件用例用确定种子真实抽到事件，不伪造航行状态
  - `framework/tests/cases/test_stage_host.gd` 新增 2 例：离港 beat 结束时船正好停在 `SEA_HANDOFF` 且镜头升到 `DEPART_CAMERA`；入港 beat 结束时船回到泊位、镜头回到站位机位
- [ ] 事件触发的 3D 场景预加载与云层下降（当前事件页仍是 2D 页面，只有 2D 云层转场）
- [x] 视觉验收：`tools/godot/capture_voyage_presentation.gd` + [5 张 1440×900 截图](docs/design/screenshots/voyage_presentation/)（3D 离港 / 出航云层 / 海图航行 / 3D 入港 / 抵达结算），见 [设计文档 §15](docs/design/NAUTICAL_CHART_SYSTEM.md)

#### 阶段 3 实机验收反馈（2026-10-21，**待修，尚未开工**）

人工在实机演出里看到的 4 个问题，按验收顺序记录。每条都写了现状与验收口径，
修的时候逐条对照，不要用"看起来更顺了"替代口径。

- [ ] **F1 · 离港是"平移"不是"驶离"**
  - 现象：船离开泊位时像在轨道上横移，船艏一直朝着原泊位方向，没有转向出海。
  - 现状：`PortStage.advance_voyage()` 只对 `_ship_x/_ship_z` 做 lerp，`_ship_yaw` 始终是
    泊位 yaw（`_ship_moor_yaw`，20°）；而离港方向是 +Z，船体因此横着"滑"出去。
  - 验收口径：出航前先把船艏转到出海方向（+Z 对应 `PI/2`，用现有 `SHIP_TURN_SPEED` 或
    beat 内插值），船体沿艏向航行；入港反向（先是出海朝向，接近泊位时转回 `_ship_moor_yaw`）。
    截图里应能看到船头朝外、尾流在后方，而不是侧舷对着前方。

- [ ] **F2 · 镜头应是"俯角加大到竖直 + 拉升"，云层后海图由最大缩到合适尺寸**
  - 期望：离港镜头俯角不断加大直到接近竖直，同时拉升；云层盖住后，海图**从放大的近景
    逐渐缩小**（模拟镜头还在继续上升，"天旋地转"到看得见整片海）。入港完全镜像：
    先缩小到近景 → 云层 → 3D 镜头从竖直高位逐渐放下俯角。
  - 现状：`advance_voyage()` 把相机 position/target/fov 各自线性插值到固定的
    `DEPART_CAMERA` / `DEPART_CAMERA_TARGET`，俯角没有刻意做到竖直；海图接管时是一次
    性 fit 到位，没有"由近到远"的缩放过程。
  - 验收口径：离港末帧镜头几乎垂直向下（pitch ≥ 80°）且高度达到峰值；海图第一帧的
    缩放明显大于最终值，随后在固定时长内（建议与出航 veil 同时长）缩到稳态；
    入港为逆过程（近景 → 拉远 → 云层 → 3D 下降）。

- [ ] **F3 · 海图太小，最高位时应铺满整屏**
  - 现象：海图只占中间一块方形，四周大片暗色留白，看不出"大海广阔"。
  - 现状：`AtSeaScreen` 里的 `SNSeaChartView` 挂在 `PageScroll/RootBox` 下，高度被滚动
    容器限制；`_fit_to_view()` 永远把 400×400 世界整体放进控件（还留 60 px 边距），
    16:9 窗口下必然出现左右大留白。
  - 验收口径：航行页的海图铺满可用窗口（不进滚动容器或被撑满），最高位时视野裁掉
    世界边界以外的空白、整屏都是海面与已探索内容；缩放下限仍保留（不能因为铺满而
    裁掉正在走的航线与起终港）。

- [ ] **F4 · 海图上船是"两点直线"，不是沿航线**（真 bug，优先级最高）
  - 现象：船在实际航线之外沿起终港直线插值移动。
  - 根因（已定位）：`AtSeaScreen._route_path()` 从 `sea_chart.view` 的 `routes` 里找这段
    航线，但该查询**只输出两端都已发现**的航线；出发时目的港还没发现，于是找不到，
    退回 `[origin, destination]` 两点直线。
  - 修复方向：航线数据由 Shell 从坐标世界直接取（`WorldMap.edges` 的路点表 /
    `WorldOps.route_between`），通过 `bind()` 的 `positions` 之外再传一个 `route_path`
    给航行页；只有世界表里确实没有这条边时才退回直线。注意**不要**为此把海图查询的
    战争迷雾规则放宽（未发现的航线仍不应画在图上）。
  - 验收口径：`at_sea.get_ship_world_position()` 在任意进度都落在该航线的折线上
    （逐点最小距离 < 1 世界单位），并在进度 0/1 时等于起终港坐标；新增用例锁死
    "直线不是航线"的情况（目的港未发现时依然沿曲线走）。

### 阶段 4：探索系统

- [ ] `Clue` 数据结构与 `ClueService`（港口位置/港口货物两类）
- [ ] 线索分级与海图可视化（存在/方向/距离/名称，渐进披露）
- [ ] `explore_voyage.start(clue_id)` 命令
- [ ] 搜索区判定与发现概率（按 `credibility` + 命名流）
- [ ] 资源告急事件（资源消耗 50% 时触发，可选择继续/掉头）
- [ ] 探索失败处理（消耗大量物资+耐久，漂到最近港口，允许未知港口直接发现）
- [ ] 线索调查方式（花金币/花时间/完成委托）
- [ ] 探索系统单元测试（发现/未发现/掉头/漂流）

### 阶段 5：事件化海洋

- [ ] 航行事件预生成（出航前全部确定，命名流 + seed 可复现）
- [ ] 事件预加载机制（出航前生成事件遇见时间表 + 预加载场景）
- [ ] 事件类型实现（敌对/环境/奖励/随机岛屿秘境/安全航行）
- [ ] 事件触发与决策（云层下降 → 3D 场景 → 选择 → 回到 2D 海图）
- [ ] 安全航行与消耗结算（物资/时间/耐久）
- [ ] 事件系统单元测试（预生成一致性、事件触发、决策结果）

### 阶段 6：固定未知岛屿与基地建设（中后期）

- [ ] `FixedUnknownIsland` 数据结构（真实地图实体，勘探后才发现资源）
- [ ] 勘探机制（抵达后触发勘探事件，发现资源列表）
- [ ] 基地建设系统（建造设施、产能、存储）
- [ ] 公开港口建立（把岛屿变成新港口，接入贸易网络）
- [ ] 设施建造（码头/仓库/生产设施/防御设施）
- [ ] 基地建设单元测试（勘探/建造/产能/贸易接入）

### 验收标准（阶段 0-3 的 MVP 切片）

- 同 seed 生成的世界布局一致
- 15-20 港口合理分布在陆地海岸线上
- 迷雾三态视觉清晰（黑雾/灰雾/可见）
- 沿岸格子被经过后永久保留灰雾
- 海洋格子离开后变回黑雾
- 港口发现时路灯花效应正确清除周围战争迷雾
- 航线为贝塞尔曲线，每港口有唯一出航角度
- 航行演出完整：3D → 云层 → 2D → 事件 → 2D → 云层 → 3D
- 海图 UI 连续可缩放，信息层级正确
- 右侧 Panel 显示目的地基础信息与预计信息
- 168+ 测试通过（新增海图系统测试）

### 未决定的事项（留给后续迭代）

- 陆地轮廓视觉风格升级（剪影 → 手绘风格）
- 随机岛屿秘境的漂移规则
- 多人港口区域（一个岛屿上多个港口）的可行性
- 海图视觉风格统一（羊皮纸古地图 / 蓝图 / 蒸汽朋克铜版画）
- 探索航行的演出细节（云层颜色/氛围）
- 漂流到未知港口时的设施限制（维修/补给/交易）

### 当前下一步（按优先级，2026-10 对齐）

- [x] **P0 提交当前批次**：已拆 4 个 commit（`f8d8c29` 框架/模块实例、`480a440` 3D 舞台/UI、`35abfbf` 资产/建模、`3cf61fe` SNModMaker/发布/文档）；船体与 core 资产已入库，工作区清空。
- [x] **P1 导出实测**：Windows 导出包（114 MB，embed PCK）启动正常，`mods/core-1.0.0.snavmod.zip` + `config/config.json` 布局生效；导出包内确认包含 `SNShipStage3D`、船体 GLB、`ship_modules` 与 `harbor_water`；导出包实机进入船厂 3D 舞台通过（1440×900）。1280×720 / 960×540 用同一构建在编辑器窗口验收通过（movie writer 固定输出 1440×900 画布，不能当窗口截图用）。截图见 [export](docs/design/screenshots/export/)。
- [x] **P1 `StageHost` + `LocationStage` 泛化**：`SNStageHost` 独占 SubViewport/World3D，驱动 `LocationStage` 的 `enter → bind → exit`，支持舞台显隐/隐藏即停更/缺失场景回退；`SNShipStage3D` 已重写为宿主适配器，环境/灯光/水面/机位/升沉迁入 `ShipyardStage`，公共构建器在 `StageKit`。
- [x] **P1 `PortStage` 骨架**：按 `facilities` 装配设施（已实现 `facility_visuals` GLB 替换 + 程序化 billboard 兜底 + 空槽货堆 filler）；L0 天空/L1 banner 背板/L2 确定性岸线剪影/L5 玩家船已跑通；6 件锚点模型（[PORT_FACILITIES_PLAN.md](tools/modeling/briefs/PORT_FACILITIES_PLAN.md)，GLB 在 `assets/models/port/`）已接线。预览：[完整港口](docs/design/screenshots/port_stage/port_stage_preview.png) / [稀疏港口](docs/design/screenshots/port_stage/port_stage_sparse.png)。
- [x] **P1 总览页接入 `PortStage`**：全窗背景层 + 失败回退 2D + 切页隐藏/返回恢复已完成；第五切片进一步改为 Bounty Train 式主界面（紧凑 chrome、左右招牌、底部状态条、详细抽屉），并完成 `port.diorama` / 街景 town kit 接线。剩余：独立舞台与演出。
- [x] **P1 港口舞台验收**：主界面默认全窗 3D 舞台 + 紧凑 HUD + 两侧招牌 + 底部状态条 + 详细抽屉，2D HUD 不变；不同 `facilities` 的港口出现/缺少对应设施；资产缺失时回退 2D 背景（`test_ui_shell` 真实外壳用例守护，162 测试全绿）。
- [x] **P1 主界面美术收尾与性能回收（第六切片）**：HUD 资源图标（`AssetService.find_key` 裸键）、自绘木牌招牌 + 设施徽记 + 悬停光晕；街景 normal 47 件（size/density 分档）；设施/街景/玩家船静态合批把实测 draw calls 从 284/255 降到 **63/56**（37k/30k tris）；无 banner 港口 3 层程序化远景；新增 measure 工具与 7 个舞台用例，全量 162 tests 绿。截图：[主界面 1440](docs/design/screenshots/overview_port_stage.png) / [主界面 960×540](docs/design/screenshots/overview_port_stage_960.png) / [详细总览](docs/design/screenshots/overview_detail.png)。
- [x] **P1 连续港区 + 港务/市场/补给相邻站位（第七切片）**：码头 160 m、广场 250 m，`STATIONS` 把 market(-30)/harbor(0)/supply(+30) 排成相邻站位；`focus_station()`/`advance_station()` 只平移镜头 + 把船开到新泊位（0.6 s 镜头、转艏 + 24 m/s 航行），港口/街坊/设施/合批层不重建，画幅层跟随、L2 半速视差；`STAGE_SCREENS` 让 overview/market/supply 共用同一 `PortStage` 实例，market/supply 改成右侧 640 px 泊位面板 + 左侧露出 3D 街景且切页无黑场；`test_stage_host` 30 例、`test_ui_shell` 覆盖共用舞台/面板/镜头到位，全量 **168 tests 绿**。截图：[市场站位](docs/design/screenshots/market_station.png) / [补给站位](docs/design/screenshots/supply_station.png) / [市场 960×540](docs/design/screenshots/market_station_960.png) / [market 镜头](docs/design/screenshots/port_stage/port_stage_market.png)。
- [ ] **剩余 2.5D 舞台工作**：委托/情报页舞台化、离港/进港演出与目的港舞台预加载、质量档位与低配回退、L2 LOD、第三方 `.glb` 白名单评审。
- [x] **铁港城镇建筑视觉升级 · 第一阶段 + R1**：`SN_HT_Warehouse_Long` LOD0 灰模 R1（7 436 tri / 20×9×11 m / 6 材质槽 / 网格健康全 0），已临时装配进 PortStage 并出 1440×900 与 960×540 实机截图（stage tri 37 280→43 584 证明新模型入场景），旧 GLB 已还原；见 [IRON_HARBOR_ARCHITECTURE_PHASE1.md](docs/archive/IRON_HARBOR_ARCHITECTURE_PHASE1.md)。
- [x] **铁港城镇建筑视觉升级 · M1 材质轮**：`warehouse_long` 槽位 yaw −90→−106 / pos z −34→−33 让装卸门长立面正对固定机位（立面 +38%、两扇装卸门 +36%/+34%、山墙吊梁仍可见、足迹仍在广场内）；共享 2K trim sheet（16 cell）+ 每材质 512² 平铺贴图 + 盒投影 UV（0 tri 增加）；内容 GLB 已换成带贴图版本并重新 import，1440×900 与 960×540 实机截图已出；见 [IRON_HARBOR_ARCHITECTURE_M1.md](docs/archive/IRON_HARBOR_ARCHITECTURE_M1.md)。**等待"是否扩展整批"决定**。
- [x] **铁港建筑套件 · 第二批（其余 4 栋 drop-in）**：SN_HT_Warehouse_Short 3 788 tri / SN_HT_Harbor_Office 10 336 tri / SN_HT_Cargo_Shed 3 356 tri / SN_HT_Tavern 5 116 tri，尺寸与旧占位资产一致、网格健康全 0、同一套 6 材质槽 + 共享 trim sheet（每栋换 cell）、主立面在本地 +X 正对固定机位；实机 stage tri 53 908 → 73 228（增量 19 320 = Σ新 22 596 − Σ旧 3 276）、4 个旧占位资产零改动且各有备份。见 [IRON_HARBOR_ARCHITECTURE_BATCH2.md](docs/archive/IRON_HARBOR_ARCHITECTURE_BATCH2.md)。LOD1 与共享外部贴图已由批次 A 完成；剩余 3 个新原型（批次 B）。
- [x] **铁港建筑套件 · 批次 A（LOD1 + 共享贴图 + Warehouse_Short 檐口修复）**：5 栋 LOD1 共 **6 564 tri**（LOD0 的 21.85%，上限 10 508；逐栋 1 584 / 1 060 / 1 896 / 776 / 1 248），LOD1 与 LOD0 bbox 逐轴 0.000 m、轴心落地、网格健康全 0；`SN_HT_Warehouse_Short` 檐口顶皮@墙线 **−3.543 cm → 0.000 cm**（仅 8 个屋面顶点变化）；10 个 GLB 改为 **GLB + 外部共享贴图**（11 张 `iron_harbor_shared/*.png` 与手写 tile 逐字节一致，`ContentAssetLoader` 按 URI 共享 `Texture2D`），PortStage 舞台分析面 **91→73**、draw calls preview **89→71**（≤75 目标），5 栋模型+纹理 **4.17 MB**（≤4.5 MB）；松散 / `.snavmod.zip` / 发布包三条加载路径实测。见 [IRON_HARBOR_ARCHITECTURE_BATCH_A.md](docs/archive/IRON_HARBOR_ARCHITECTURE_BATCH_A.md)、LOD1 构建/独立验收/共享贴图三份报告。剩余：批次 B（3 个新原型）。
- [ ] **P2 模块 condition 进入派生属性**：受损锅炉/导航/安全/货舱/客舱按 condition 降低速度、载重、风险修正与容量，补回归测试与 UI 提示（战斗前置）。
- [ ] **P2 战斗内容 Schema 2.0 草案**：`weapons` / `enemy_archetypes` / `encounter_tables` / `loot_tables`，仍保持 planned，配套有效/无效样本测试。
- [ ] **P3 世界探索运行时**：把 v2 草案提升 active，接世界生成、战役 `world` 分区、海图迷雾与区域低细节模拟（阶段 1 的主线）。

## 港口设施锚点第一批（2026-10-20，模型已交付）

> 2.5D 港口舞台的设施可辨认锚点，6 件合计 4996 tri（预算 10500）。工单 [sn_port_facilities_batch1.json](tools/modeling/briefs/sn_port_facilities_batch1.json)，规划 [PORT_FACILITIES_PLAN.md](tools/modeling/briefs/PORT_FACILITIES_PLAN.md)，资产登记 [ASSET_MAP.md](docs/design/ASSET_MAP.md)。

- [x] Lead 写参数化生成器 `sn_port_facilities_generator.py`（ITEMS 参数表 + 6 个 build_*；纯几何可离线干跑），纯 Python 干跑 `dryrun_props.py` ALL OK（尺寸误差 0、tri 4996、边界/非流形 0）
- [x] Builder 六轮迭代（每轮只重建本集合 6 件）：布局冲突（y=60 与 `SN_Ship_Modules` 互穿）→ 整排移到空闲 y=75；告示板纸面翻到 -Y + 绕 X 后仰；龙门吊横梁接腿 / 爬梯踏棍外移出腿体；干船坞龙骨墩改骑滑道轨 + 删不可见死几何；市场侧梁收进帆布下；水箱收口环改 SN_Metal
- [x] 独立 Verifier 只读验收通过：命名/集合/轴心/尺寸（误差 0.000，龙门吊 Y +0.014 来自爬梯外凸）/预算/材质（7 种调色板 + 新增 SN_Iron）/网格健康全 0/剔除 6 件后回归 digest 命中（基线 228 对象）/6 件视觉可辨
- [x] 归档：`assets/models/port/` 6 个 GLB（42.6/17.4/67.9/59.0/59.6/30.5 KB，单节点、doubleSided）+ `.design/port/SN_<Name>.blend` 6 个源快照 + `.design/port/report.json`；`verify_port_glb.py` 6/6 PASS；预览截图 `docs/design/screenshots/port_facilities_batch1_*.png`
- [x] 工作台 `.design/SN_Asset_Workbench.blend` 保存（234 对象 / 213 mesh / 19 材质，`SN_Port_Facilities` 集合在 y=75）
- [x] 已接入：`PortStage.facility_visuals`（`StageHost` 泛化已完成）；ViewModel 传入已解析 GLB 路径时按设施替换这 6 个锚点，路径缺失/非法时回退程序化 billboard，默认仍是 billboard 占位。预览见 [完整港口](docs/design/screenshots/port_stage/port_stage_preview.png)。
- [ ] 备注：acceptance“信号塔最高剪影”与本批尺寸表矛盾（塔 8.5 m < 龙门吊 10.0 m），按尺寸表实现并在工单 `delivery_notes` 记录

## 铁港建筑套件 · 第一阶段样板 + R1（2026-10-20，PortStage 实机截图已出，等待扩展决定）

> 工单 [sn_iron_harbor_architecture_kit_v1.json](tools/modeling/briefs/sn_iron_harbor_architecture_kit_v1.json)，报告 [IRON_HARBOR_ARCHITECTURE_PHASE1.md](docs/archive/IRON_HARBOR_ARCHITECTURE_PHASE1.md)。只做 `SN_HT_Warehouse_Long` 的 LOD0 灰模；R1 GLB 仅临时装配截图，已还原旧资产；不贴图、不改运行时代码。

- [x] 生成器 `tools/modeling/generators/sn_iron_harbor_architecture_kit_generator.py`：纯 Python 几何（可 `dryrun_props.py` 干跑）+ Blender 内 `build_all()/report()`，在 `SN_Iron_Harbor_Architecture` 建单 mesh 对象 `SN_HT_Warehouse_Long_LOD0`
- [x] 几何与健康（R1）：**7 436 tri / 4 486 顶点**、20.000×9.000×11.000 m、轴心底面中心、zmin 0、6 材质槽、孤立点/退化面/非流形边/边界边全 0；真实凹口 窗 0.16 / 装卸门 0.28（门扇 0.16）/ 人门·服务门 0.26（门扇 0.20），墙厚 0.46 m；同向共面只剩隐藏接缝（无外露 z-fighting）
- [x] R1 细化：双高门双滑轨 + 3 吊架 + 每扇 2 滚轮 + 石/铁门槛 + 3.10×0.30 m 铁短平台；山墙吊梁加牛腿/双滑轮组/梁端板/斜拉杆；4 段檐沟接 4 落水管雨水斗；侧墙 4 窗 + 3 壁柱；石基压到 0.58 m 并收窄到 19.56×8.56（去托盘感）；檐口顶面抬到 7.53，与屋面底皮只留 0.02 m 阴影缝（消檐口黑边）
- [x] 朝向决策：town 槽位 yaw −90° 使固定机位只能看到本地 +X 山墙与 +Y 长墙（旧资产把门窗放 −Y，机位里不可见），故主立面改到 +Y、背面放 −Y；**整批 drop-in 需统一**
- [x] 预览渲染器 `render_iron_harbor_architecture_preview.py`：固定机位（eye(50,186,26.1)/target(-22,140,10.1)/41.9856 mm，与 Godot 30° vfov 等价）+ 960×540 + 居中复查 + 街道低机位 + 正交正视 + 屋顶，6 张到 `docs/design/screenshots/iron_harbor_architecture/`
- [x] **PortStage 实机门禁**：`export_iron_harbor_architecture_glb.py` 临时替换内容 GLB（旧资产备份 + R1 候选在 `.design/buildings/iron_harbor/`）→ `godot --import` 刷新导入缓存 → `tools/godot/capture_port_stage_res.gd -- 1440 900 / 960 540` → 还原旧 GLB 并重新 import；证据 stage tri 37 280→43 584、draw_meshes 88→94；截图 `docs/design/screenshots/iron_harbor_architecture/SN_HT_Warehouse_Long_LOD0_port_stage_{1440x900,960x540}.png`
- [x] 回归：245 对象 = 244 旧 + 1 新；旧 `SN_HT_Warehouse_Long`（1 132 tri / 8 槽 / `(-48,110,0)` / 可见性）未动；内容 GLB 已恢复为旧资产（SHA-256 与备份一致）
- [x] ~~其余 4 栋 drop-in~~ 已完成（见上方第二批条目）；**批次 A 已补完 LOD1（≤35%）与共享外部贴图（draw_meshes 91→73）**；剩：3 个新原型（Boiler_House / Workshop_Row / Brick_Tenement）、1K 污渍遮罩通道 / UV2

## 铁港建筑套件 · M1 材质轮（2026-10-20，PortStage 实机截图已出，等待扩展决定）

> 报告 [IRON_HARBOR_ARCHITECTURE_M1.md](docs/archive/IRON_HARBOR_ARCHITECTURE_M1.md)；材质源 [iron_harbor_trim_sheet_2048.spec.json](docs/design/textures/iron_harbor/iron_harbor_trim_sheet_2048.spec.json)。几何冻结不动（仍 7 436 tri / 20×9×11 m）。

- [x] 朝向/位置：`framework/ui/stages/port_stage.gd` `TOWN_SLOTS.warehouse_long` → `pos(-30, 1.9, -33) yaw -106`；主立面法线↔机位轴 52.2°→35.9°，立面投影 +38.2%、装卸门 +36.4%/+33.7%，门 100% 无遮挡，山墙吊梁仍可见；足迹 x −37.08…−22.92 / z −43.85…−22.15（广场内）、与岸吊间隙 0.92 m
- [x] trim sheet 生成器 `tools/art/gen_iron_harbor_trim_sheet.py`（numpy+Pillow，确定性，PNG-8 ≤96 色）：4×4×512 px、2.0 m/cell=256 px/m、16 cell（6 主用 + 10 变体/预留）；自检 mean 误差 ≤±0.5/255、接缝率 0.26–1.18、两跑字节一致；产出 2048² 图集 3.68 MB + `tiles/` 16×512² 合计 2.66 MB
- [x] 共享材质模块 `tools/modeling/generators/sn_iron_harbor_materials.py`：6 材质槽→6 cell（brick_wall / plaster_light / wood_plank_weathered / iron_dark / stone_base_dirty / glass_dark）、REPEAT 平铺、盒投影 UV（u/v = world/2.0，屋面 v=Y、门扇 v=Z）、`verify_object()` 自检
- [x] 生成器接线：`build_all()` 建完对象后应用材质+UV，`report()` 增加 textures 段与 `uv_loops_complete / geometry_unchanged_by_uv / all_images_bound / texture_slots_6` 四项检查；贴图缺失时自动退回灰阶占位
- [x] 证据：Blender 8 视图（新增装卸门近景 / 墙脚近景）+ 实机 `SN_HT_Warehouse_Long_LOD0_port_stage_{1440x900,960x540}.png`；`capture_port_stage_res.gd` 新增 `[asset]` 行自证 surfaces=6 tris=7436 uv_surfaces=6 textured_surfaces=6 + 6×512² 贴图；GLB 1 473 876 B（内嵌 6 PNG，合计 1 020 426 B，sha256 `1b6d995f…`）
- [x] 卫生：Godot 把内嵌贴图解包到 GLB 同级目录，已 `.gitignore`（构建产物）；手写源在 `docs/design/textures/iron_harbor/tiles/`；旧 GLB 备份 sha256 仍 `2576e3db…`
- [ ] 待决定：扩展整批 / 内容 GLB 是否正式保留带贴图版本（当前已装）/ 污渍强度与「1K 污渍遮罩」通道（建议先试顶点色）/ 是否给屋面开第 7 个材质槽用上 `roof_sheet` 瓦楞铁

## 铁港建筑套件 · 批次 A（2026-10-20，LOD1 + 共享贴图 + 檐口修复）

> 需求 [MODELING_REQUIREMENTS_NEXT_BATCH.md](docs/archive/MODELING_REQUIREMENTS_NEXT_BATCH.md) §5 / §8 / §9；验收 [IRON_HARBOR_ARCHITECTURE_BATCH_A.md](docs/archive/IRON_HARBOR_ARCHITECTURE_BATCH_A.md)，LOD1 构建 [IRON_HARBOR_ARCHITECTURE_LOD1_BUILD.md](docs/archive/IRON_HARBOR_ARCHITECTURE_LOD1_BUILD.md)，独立验收 [IRON_HARBOR_ARCHITECTURE_LOD1_VERIFY.md](docs/archive/IRON_HARBOR_ARCHITECTURE_LOD1_VERIFY.md)，共享贴图 [IRON_HARBOR_ARCHITECTURE_SHARED_TEXTURES.md](docs/archive/IRON_HARBOR_ARCHITECTURE_SHARED_TEXTURES.md)。

- [x] Builder：新增 `sn_iron_harbor_architecture_lod1_generator.py`（纯 Python 参数化真源，5 栋 LOD1 合计 6 564 tri / 21.85%，逐栋 ≤35%；LOD0↔LOD1 bbox 逐轴 0.000、轴心落地、健康全 0、材质 6 槽 + 共享 cells/UV）；`sn_iron_harbor_warehouse_short_generator.py` 仅改 `_roof_section()`，顶皮@墙线 −3.543 cm→0.000 cm（tri/verts/bbox/轴心/主立面/材质不变）；30 张 1280×800 LOD1/对比预览；全场景 245 个非目标对象 digest 零改动。
- [x] 独立 Verifier（只读）：t0/t1 dump 独立复算，LOD1 5/5 门禁 PASS、剪影 IoU 0.99+、§5.1 保留项全通过、檐口 0.0000 m、LOD0 4 栋逐字节一致 / Short 仅 8 顶点、非目标 0 modified；报告无 FAIL。
- [x] 导出与结构检查：Blender 逐件按栋重写 cells 后导出 10 个 GLB（LOD0 5 + LOD1 5，根节点归零、tri 与验收表 10/10 相等），`glb_shared_textures.py` 把内嵌贴图外部化为 11 张共享 PNG 并压缩 BIN；`verify_iron_harbor_architecture_lod_glb.py` 10/10 PASS（结构/材质槽/URI/bbox/总量）。
- [x] 运行时接线：10 个 GLB 装入 `dev_mods/core/assets/models/props/`（LOD1 为 `SN_HT_<Name>_LOD1.glb`），manifest 新增 5 个 `model.prop.*_lod1` 键（75→80）；`ContentAssetLoader` 共享贴图 + 5 例无头测试（216 tests 全绿）；`measure_port_stage.gd -- --core-zip` 扩展。
- [x] 实测：draw_meshes（舞台分析面）91→73（≤75），渲染器 draw calls preview 89→71 / sparse 82→64，batches 59→41；5 栋模型+纹理 4.17 MB（GLB 2.28 MB + PNG 1.88 MB），LOD1 组合 6 564 tri（≤20 000）；松散 / ZIP / 发布包三路径均实测（发布 exe 启动 `content=51 status=ok`）。
- [x] 截图：PortStage 固定机位 LOD0/LOD1 1440×900 + 960×540（`docs/design/screenshots/iron_harbor_architecture/`），LOD1 临时入舞台 tri 73 228→49 760、draw calls 不变（合批按材质）。
- [ ] 待人工视觉门禁确认（§10）：1440×900 / 960×540 轮廓与入口可读、LOD1 无明显塌陷、性能收益是否抵过资产格式复杂度；确认后再进入批次 B。
- [ ] 移除构建卫生：`dev_mods/core/assets/models/props/SN_HT_*.png`（Godot 从内嵌 GLB 解包的旧构建产物）已清理，后续由 .gitignore + 导出流程守护。

## 铁港建筑套件 · 批次 B（2026-10-20，三栋新原型 + 两港组合）

> 需求 §6；验收 [IRON_HARBOR_ARCHITECTURE_BATCH_B.md](docs/archive/IRON_HARBOR_ARCHITECTURE_BATCH_B.md)；LOD0 构建/验收 [PROTOTYPES_LOD0_BUILD](docs/archive/IRON_HARBOR_ARCHITECTURE_PROTOTYPES_LOD0_BUILD.md) / [PROTOTYPES_LOD0_VERIFY](docs/archive/IRON_HARBOR_ARCHITECTURE_PROTOTYPES_LOD0_VERIFY.md)。

- [x] Boiler_House 7 388 tri / 12×10×12、Workshop_Row 7 312 / 18×7×8.5、Brick_Tenement 9 376 / 10×8×12；LOD1 2 536 / 2 444 / 2 704（≤2 800/2 800/4 900 且 ≤35%）；LOD0↔LOD1 bbox 0.000、健康全 0、§6 必须项 3/3 PASS。
- [x] 导出 + 共享贴图（新增 1 张 `brick_wall_soot`，共 12 张、2.03 MB）；manifest 80→86；iron_harbor=WR+BH、spice_port=WR+BT，其余三港旧 5 栋。
- [x] 两组 5 栋组合 + 旧 5 栋对照 1440/960；combo_a 75 376 tri/72 draws、combo_b 72 144/71 draws（松散与 ZIP 一致）。
- [ ] 待人工视觉门禁（组合轮廓可辨、无穿插遮挡）；待 verifier task-10 终验。
- [ ] 外部阻塞：并发海图工作流修复后重跑完整测试套件与 release 导出/启动（批次 B 相关测试子集 49/49 已全绿）。

## SN_Paddle_Steamer 视觉精修 · 批次 C（2026-10-20）

> 需求 §7；报告 [PADDLE_STEAMER_VISUAL_POLISH_C.md](docs/archive/PADDLE_STEAMER_VISUAL_POLISH_C.md)；独立验收 [PADDLE_STEAMER_VISUAL_POLISH_C_VERIFY.md](docs/archive/PADDLE_STEAMER_VISUAL_POLISH_C_VERIFY.md)。

- [x] 雨棚减重（投影 63.72→41.34 m2，占游步甲板 71.4→46.3%，薄边 0.14→0.07）、明度层级（0.870/0.680/0.300）、暗红压条加粗（0.055→0.075 等）。
- [x] 不变量：tri 11764、尺寸 24.56x8.74x10.47、水线轴心、35 对象层级、旗/铭牌/明轮安全；共享材质 SN_Wood_Deck/SN_Flag_White 已恢复原值，非目标 226 对象 digest 不变；verify 26/26。
- [x] 导出 core 内容 GLB（633.3 KB，sha `cefec2b7aa2d`）+ framework 镜像；工作台/船体快照；Godot 船厂 1440/960 与 PortStage 重拍；完整测试 231 passed；静态文档 --check 通过。
- [x] 人工视觉门禁（A/B/C）：通过（2026-10-21，用户确认截图：三项精修可读、其它资产零变化、实机无黑材质）。

## 文档归档（2026-10-21）

- [x] 设计文档整理：已完成开发的设计 / 实施契约 / 验收报告共 26 篇迁入 [`docs/archive/`](docs/archive/README.md)（MVP 设计基线、迭代 1/2、UI 重构、铁港建筑套件阶段 1→批次 B、建模验收与下一批需求、批次 C）；`docs/design/` 仅保留现行方案 / 路线图 / 工作流 / 资产映射 / 契约与原型说明。
- [x] 引用同步：README、todo、各设计文档与 tools 工单内的相对链接已改为新路径；`docs/static/` 未重组，仅按生成器重跑同步 manifest 哈希与 1 个硬编码的「迭代 1 契约」链接。

## 维护约定

- 改代码时在源码头维护 `@static-doc`（无注释格式用 `docs/static_headers/` sidecar），运行 `node tools/gen_static_docs.mjs`，并用 `--check` 守护 `docs/static/` 与 manifest 新鲜度；旧 `FILE_DOCS` 仅作迁移兼容。
- 数值改动先改 Core JSON，不在框架里写死。
- 新增命令/查询必须经 `FrameworkApi` 注册，并补测试。
- 新增内容类型需要同时补 Schema、注册表映射、跨引用检查与文档；随后运行 `node SNModMaker/tools/sync-schemas.mjs` 与 `node SNModMaker/tools/sync-core-index.mjs`，并跑 `node SNModMaker/tests/run-tests.js`。
- 新增或修改内容（商品 / 船体 / 委托 / 事件等）优先用 `node SNModMaker/tools/content.mjs` 的 `add` / `set` / `clone` / `loc`，不要手改 JSON 后再靠编辑器重排格式。
