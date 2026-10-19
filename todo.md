# Steam Navigator — TODO / 路线图

> 基线：Framework 0.1.0 / Core 1.0.0 / Mod API 1.0 / Content Schema 1.0
> 最近验证：Godot 4.7.2 headless，**162 个测试通过 / 0 失败**（含 9 个 seed 的完整通关回归、主界面接线冒烟、船厂改装 UI 契约、模块实例与部件损耗、密集界面横向排版与通报文案本地化守护、2.5D 舞台基础设施（LocationStage / SNStageHost 生命周期与回退 / ShipyardStage / PortStage 装配·替换·缩放·portal）、PortStage 场景填充访问器、港口街景 town kit（满配 29 / 无 town / 非法路径 / port.view 16 项端到端）、主界面紧凑 HUD + 两侧招牌 + 状态条 + 详细抽屉与 2D 回退、内容类型单一真源与 v2 模块分类一致性、save schema 1.x→2.0 迁移、CampaignState 分区、Content Schema 2.0 草案校验）；SNModMaker **33 个 Node 用例 + 1 个本地服务用例 + 16 个浏览器用例**通过；**Windows 导出包实机验收通过**（3D 船厂舞台 + `mods/`+`config/` 便携布局）；`node tools/gen_static_docs.mjs` 已重新生成静态文档。

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

来源：`docs/MVP反馈.md`（玩家试玩反馈 6 条）。契约与决策：[ITERATION_2_MVP_FEEDBACK.md](docs/design/ITERATION_2_MVP_FEEDBACK.md)

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

> 目标：主界面只保留「改装台 + 组件 HUD」，全部改装操作收进分类面板；旧的整页下方面板删除，但每条旧命令保留入口。设计说明：[SHIPYARD_UI_REFACTOR.md](docs/design/SHIPYARD_UI_REFACTOR.md)。

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
- [x] 文档：`docs/static` 的船厂页 / `sn_ship_view` / Shell / `shipyard_view` / 两个测试条目重写契约，并新增 [SHIPYARD_UI_REFACTOR.md](docs/design/SHIPYARD_UI_REFACTOR.md)、更新 UI_PROTOTYPE 与 ASSET_MAP
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

> 工作流与角色分工见 [docs/design/MODELING_WORKFLOW.md](docs/design/MODELING_WORKFLOW.md)，验收记录见 [docs/design/MODELING_ACCEPTANCE_2026-10-19.md](docs/design/MODELING_ACCEPTANCE_2026-10-19.md)，来源与运行时路径见 [docs/design/ASSET_MAP.md](docs/design/ASSET_MAP.md)。

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
- [x] 独立 Verifier 只读复核 R0→R2 三轮：R0 报的 5 处同法线共面 + 9 处悬空壳体、R1 报的 4 处共面 + 1 处被穹顶包住的隐藏几何全部清零，R2 判定 **pass**（仅剩 2 处完全被遮挡的微小共面记录在案）；报告见 [MODELING_ACCEPTANCE_2026-10-19.md](docs/design/MODELING_ACCEPTANCE_2026-10-19.md)
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
- [x] 独立 Verifier 只读复核 R0→R1 两轮：R0 的 8 类悬空/错位（桅顶饰、指挥塔、通风筒、甲板机械、小艇重合、桨叶脱毂、黄铜条/驾驶台、小间隙）全部清零，R1 判定 **pass**；R2 人工反馈（舰艏两个斜桁鞍座/绑扎块浮空）已加基座/艏柱座/锚吊架修复并复验仍 **pass**；报告见 [MODELING_ACCEPTANCE_2026-10-19.md](docs/design/MODELING_ACCEPTANCE_2026-10-19.md)
- [ ] Godot 引擎侧复核（导入已成功；待跑轴向/包围盒/材质校验）与 2.5D 舞台目标机位试装
- [ ] 如需转为战舰 / 第 5 种船体：接 Core 内容键 + manifest + 本地化 + 测试

## 3D 资产：小型明轮蒸汽船（SN_Paddle_Steamer）

> 参考澳大利亚国家博物馆的明轮蒸汽船 **PS Enterprise** 的 24 m 级小型明轮客船，纯展示资产（不接 Core）。**用户明确要求烟囱蒸汽不做几何，留给游戏内 VFX**。工单 [sn_ship_paddle_steamer.json](tools/modeling/briefs/sn_ship_paddle_steamer.json)，流程同 [MODELING_WORKFLOW.md](docs/design/MODELING_WORKFLOW.md)，验收记录见 [MODELING_ACCEPTANCE_2026-10-19.md](docs/design/MODELING_ACCEPTANCE_2026-10-19.md) 第 10 节。

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
- [ ] 港务/市场/补给等独立舞台（当前市场/委托等仍是 2D 页面）
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
- [x] 模块实例化第一步：`ship.module_instances` + `module_serial`，实例 id/condition 随存档；`damage_module` 效果、锅炉过热接入、维修按部件计价、船厂状态徽标、顶部信息条/船卡/补给页可见；`capture_ui.ps1 -Damage` 可复现受损截图（见 [SHIP_MODULE_INSTANCES.md](docs/design/SHIP_MODULE_INSTANCES.md)）
- [x] 2.5D 首个切片：船厂正常态 3D 实机舞台（`SNShipStage3D` 按 hull_tier 选船、固定 3/4 机位、复用港口水面着色器，改装态保持纵剖图，资产缺失回退程序化占位）；截图见 [stage3d](docs/design/screenshots/stage3d/shipyard_normal.png)，方案见 [2.5D_STAGE_PLAN.md](docs/design/2.5D_STAGE_PLAN.md)
- [x] 2.5D 第二切片：`SNStageHost` + `LocationStage` 泛化、`ShipyardStage` 迁移、`PortStage` 骨架（设施/空槽/回退/玩家船）、独立预览与 9 个舞台测试；截图见 [port_stage_preview](docs/design/screenshots/port_stage/port_stage_preview.png) / [port_stage_sparse](docs/design/screenshots/port_stage/port_stage_sparse.png)
- [x] 2.5D 第三切片：总览页全窗 `PortStage` 背景层 + 2D 设施热点（相机投影 Ghost Button，点击进对应设施页）+ 俯瞰/返回切换 + 失败回退 2D；新增 `test_ui_shell` 用例与 `ui_snapshot --overview-stage` 截图；截图见 [overview_port_stage](docs/design/screenshots/overview_port_stage.png)
- [x] 2.5D 第四切片：PortStage 场景填充 L0–L2/L6/L7（程序化天空 + 太阳光晕、3 层 painted backdrop、双深度带 MultiMesh 剪影、左上角前景框、3 组蒸汽粒子 + 2–3 层雾带），新增 5 个只读访问器；预算 ≤120 draws / ≤60k tris、无新资产；截图见 [port_stage_preview](docs/design/screenshots/port_stage/port_stage_preview.png) / [port_stage_sparse](docs/design/screenshots/port_stage/port_stage_sparse.png)
- [x] 2.5D 第五切片：Bounty Train 式主界面（默认 3D 舞台、121 px 紧凑 HUD、左右设施招牌 + 出航招牌、60 px 底部状态条、详细总览抽屉、2D 回退）+ 港口街景 10 件 `SN_HT_*` + `port.diorama`/`town_visuals` 接线（16 项、旧存档回填）；截图见 [overview_port_stage](docs/design/screenshots/overview_port_stage.png) / [overview_detail](docs/design/screenshots/overview_detail.png)
- [ ] 阶段 0：Content Schema 2.0 系统类型、多战役存档、tick 模拟框架
- [ ] 阶段 1：广域海图与探索（区域 / 地点 / 迷雾 / 低细节远方模拟）
- [ ] 阶段 2：舰队组成与战斗（先自动结算，再评估战术层）；模块分类收敛为 boiler/cargo/utility/cabin/crew，导航与安全并入 utility；战斗契约边界见 [战斗系统架构评审](docs/design/COMBAT_ARCHITECTURE_REVIEW.md)
- [ ] 阶段 3：基地建设与生产链（接入舰队/战斗/贸易）
- [ ] 阶段 4：自动化贸易（航线、规则、风险与 tick 结算）
- [ ] 阶段 5：遗迹探索（程序化房间、远征、战利品）
- [ ] 阶段 6：整合、内容量、Mod API 2.0 / Content Schema 2.0 冻结与发布验收

### 当前下一步（按优先级，2026-10 对齐）

- [x] **P0 提交当前批次**：已拆 4 个 commit（`f8d8c29` 框架/模块实例、`480a440` 3D 舞台/UI、`35abfbf` 资产/建模、`3cf61fe` SNModMaker/发布/文档）；船体与 core 资产已入库，工作区清空。
- [x] **P1 导出实测**：Windows 导出包（114 MB，embed PCK）启动正常，`mods/core-1.0.0.snavmod.zip` + `config/config.json` 布局生效；导出包内确认包含 `SNShipStage3D`、船体 GLB、`ship_modules` 与 `harbor_water`；导出包实机进入船厂 3D 舞台通过（1440×900）。1280×720 / 960×540 用同一构建在编辑器窗口验收通过（movie writer 固定输出 1440×900 画布，不能当窗口截图用）。截图见 [export](docs/design/screenshots/export/)。
- [x] **P1 `StageHost` + `LocationStage` 泛化**：`SNStageHost` 独占 SubViewport/World3D，驱动 `LocationStage` 的 `enter → bind → exit`，支持舞台显隐/隐藏即停更/缺失场景回退；`SNShipStage3D` 已重写为宿主适配器，环境/灯光/水面/机位/升沉迁入 `ShipyardStage`，公共构建器在 `StageKit`。
- [x] **P1 `PortStage` 骨架**：按 `facilities` 装配设施（已实现 `facility_visuals` GLB 替换 + 程序化 billboard 兜底 + 空槽货堆 filler）；L0 天空/L1 banner 背板/L2 确定性岸线剪影/L5 玩家船已跑通；6 件锚点模型（[PORT_FACILITIES_PLAN.md](tools/modeling/briefs/PORT_FACILITIES_PLAN.md)，GLB 在 `assets/models/port/`）已接线。预览：[完整港口](docs/design/screenshots/port_stage/port_stage_preview.png) / [稀疏港口](docs/design/screenshots/port_stage/port_stage_sparse.png)。
- [x] **P1 总览页接入 `PortStage`**：全窗背景层 + 失败回退 2D + 切页隐藏/返回恢复已完成；第五切片进一步改为 Bounty Train 式主界面（紧凑 chrome、左右招牌、底部状态条、详细抽屉），并完成 `port.diorama` / 街景 town kit 接线。剩余：独立舞台与演出。
- [x] **P1 港口舞台验收**：主界面默认全窗 3D 舞台 + 紧凑 HUD + 两侧招牌 + 底部状态条 + 详细抽屉，2D HUD 不变；不同 `facilities` 的港口出现/缺少对应设施；资产缺失时回退 2D 背景（`test_ui_shell` 真实外壳用例守护，162 测试全绿）。
- [x] **P1 主界面美术收尾与性能回收（第六切片）**：HUD 资源图标（`AssetService.find_key` 裸键）、自绘木牌招牌 + 设施徽记 + 悬停光晕；街景 normal 47 件（size/density 分档）；设施/街景/玩家船静态合批把实测 draw calls 从 284/255 降到 **63/56**（37k/30k tris）；无 banner 港口 3 层程序化远景；新增 measure 工具与 7 个舞台用例，全量 162 tests 绿。截图：[主界面 1440](docs/design/screenshots/overview_port_stage.png) / [主界面 960×540](docs/design/screenshots/overview_port_stage_960.png) / [详细总览](docs/design/screenshots/overview_detail.png)。
- [ ] **剩余 2.5D 舞台工作**：港务/市场/补给等独立舞台、离港/进港演出与目的港舞台预加载、质量档位与低配回退、L2 LOD、第三方 `.glb` 白名单评审。
- [ ] **铁港城镇建筑视觉升级**：按 `tools/modeling/briefs/sn_iron_harbor_architecture_kit_v1.json` 重建近中景建筑；先用 `SN_HT_Warehouse_Long` 灰模过固定机位门禁，再完成共享模块、2K trim sheet、5 个原位升级资产、3 个新增原型与 LOD1。
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

## 维护约定

- 改代码后同步更新 `docs/static/` 对应文件与 `docs/static/manifest.json`。
- 数值改动先改 Core JSON，不在框架里写死。
- 新增命令/查询必须经 `FrameworkApi` 注册，并补测试。
- 新增内容类型需要同时补 Schema、注册表映射、跨引用检查与文档；随后运行 `node SNModMaker/tools/sync-schemas.mjs` 与 `node SNModMaker/tools/sync-core-index.mjs`，并跑 `node SNModMaker/tests/run-tests.js`。
- 新增或修改内容（商品 / 船体 / 委托 / 事件等）优先用 `node SNModMaker/tools/content.mjs` 的 `add` / `set` / `clone` / `loc`，不要手改 JSON 后再靠编辑器重排格式。
