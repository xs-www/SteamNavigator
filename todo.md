# Steam Navigator — TODO / 路线图

> 基线：Framework 0.1.0 / Core 1.0.0 / Mod API 1.0 / Content Schema 1.0
> 最近验证：Godot 4.7.2 headless，**100 个测试通过 / 0 失败**（含 9 个 seed 的完整通关回归、主界面接线冒烟、船厂改装 UI 契约、密集界面横向排版与通报文案本地化守护）；SNModMaker 28 个 Node 用例通过（浏览器冒烟需本地 Chrome 环境）；`node tools/gen_static_docs.mjs` 已重新生成静态文档。

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
- [ ] 高频决策页第二轮：市场数量步进/即时成本、船厂槽位选择、持久 ScreenHost 与局部数据刷新
- [x] 情报页第二轮：`intel.view` 输出「商品 × 港口」矩阵（当前港实时市场，其余港快照 + 年龄），新增 `SNIntelTable`（`？`/`-` 规则、红降绿升百分比、未探索港整列）；main.gd 接线见 T4
- [x] 宽屏布局回归：设置、总览、市场与船厂的密集横向字段禁止智能折行为逐字竖排；市场单元格保留最小列宽，情报矩阵随面板宽度展开
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
- [x] 反馈 6：总览与船厂常驻通关条件清单（主线 n/5 → 大型船体 → 锅炉 → ≥1 货舱 → 造船厂组装）与主线完成后的下一步提示，数据来自 `port.view.victory.conditions` 与 `contracts.main_done/main_total`
- [x] 测试：新增 `test_craft_wait`（8）与 `test_ui_shell`（8，把真实外壳场景挂进场景树逐条验证反馈 2–6、密集界面横向排版，并守护通报文案替换与 `push_notice` 键的中英一致性），更新仓库/打造、补给、船体升级、情报用例；测试运行器改为在**首个渲染帧**执行，使 UI 套件能获得正常的 `_ready`/viewport 语义
- [x] 独立验证（T5，只读）发现的 3 处用户可见文案缺陷已修：`port.wait` 状态栏参数序、`ui.notice.craft_ordered` 英文模板序、「航行记录」裸模板；补齐 3 个缺失通报键（`discovered_port` / `run_started` / `no_contract_offer`），`arrived` 现在带上港口名
- [x] 文档：`docs/static` 与新代码同步（新增 `port_commands.gd` / `sn_intel_table.gd` / `test_ui_shell.gd` / `test_craft_wait.gd` 条目，更新受影响的契约描述）

### 船厂改装界面（已完成）

> 目标：船厂从「列表 + 按钮」升级为可交互的中央改装台；本迭代只做 2D 占位渲染与可拖拽槽位，2.5D 舞台留接口。同时覆盖「高频决策页第二轮」里的船厂槽位选择部分（市场数量步进与持久 `ScreenHost` 仍未做）。

- [x] `SNShipView` 中央改装台：船体侧视占位渲染 ↔ 纵剖图切换；纵剖图每槽位一枚 `SNSlotTarget` 贴片，槽位由当前船体反推（船体/锅炉/导航/安全各 1、客舱看 `cabin_slots`、货舱按 `cargo_slots`）
- [x] `SNSlotTarget`：只接受 `ship_parts` 拖放载荷（仓库/随船、类型匹配、`can_install` 为真），发 `part_dropped` / `slot_activated`；购买候选与异类型部件被拒
- [x] `SNPartRow` 部件 HUD：已装 / 仓库 / 随船 / 购买四种标签；仓库与随船且可装的行可拖，购买行点击即购买安装
- [x] `ShipyardScreen` 重排：中央舞台 + 右侧 372 px 按槽位分组的 HUD + 改装开关；拖放映射 `ship.install_module(replace_module_id)`，保留订单/仓库/打造/购买/通关清单面板
- [x] Shell：`_shipyard_refit` 记忆改装态，`shipyard_model.refit` 下发页面；切页或命令重建后仍保持纵剖图
- [x] 本地化：新增 refit / stage / slot / tag / hint 中英键（`ui.label.refit`、`ui.label.slot_*`、`ui.tag.*`、`ui.hint.drag_*` 等）
- [x] 2.5D 接口：`SNShipView.set_renderer(node)` / `has_renderer()` + 渲染器协议 `ship_view_update(model)` / `ship_view_set_mode(mode)` / `ship_view_highlight(slot_ids)`；传 `null` 恢复内置占位
- [x] 测试：新增 `test_shipyard_refit`（3）——槽位数与模式持久、渲染器替换钩子、仓库模块拖拽安装并离开仓库；测试总数 97 → 100
- [x] 截图：`docs/design/screenshots/shipyard_refit_exterior.png` / `shipyard_refit_cutaway.png`
- [x] 文档：`docs/static` 新增 `sn_ship_view.gd` / `sn_slot_target.gd` / `sn_part_row.gd` / `test_shipyard_refit.gd` 条目，并刷新船厂页 / Shell / 测试运行器契约

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
- [ ] 模组管理 UI（启用 / 禁用 / 优先级）
- [x] 发布链：GitHub Actions tag 发布 Windows/Linux + Core 包 + SHA256
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

## 3D 港口样片：水面着色器试做（已完成一版）

> 目标只是"试试水"：在独立场景里验证水面观感、已有 GLB 资产的拼接与固定机位构图；不接入主流程。
> 运行与调参说明：[dev_scenes/harbor/README.md](dev_scenes/harbor/README.md)。

- [x] 独立场景 `dev_scenes/harbor/harbor_diorama.tscn`：岸壁 / 护舷 / 爬梯 / 系缆桩 / 煤气灯 / 塔吊 / 货堆 + 帆船，全部复用 `assets/models` 的 GLB
- [x] 自写水面 shader `assets/shaders/water/harbor_water.gdshader`：顶点正弦波位移、双层滚动噪声法线、菲涅耳天空反射、太阳耀斑路径、岸线泡沫、船体椭圆泡沫、远水雾色淡出；兼容 GL Compatibility，不使用深度/屏幕纹理
- [x] 近水/远水双层材质：`FarWater` 下沉 3 m 只输出地平线雾色，遮住主水面网格边缘
- [x] `bobbing_boat.gd` 用与 shader 同源的波浪公式驱动升沉 / 纵摇 / 横摇，避免船与水各动各的
- [x] 黄昏逆光 + 仓库剪影 / 窗灯 + 煤气灯照明的固定 3/4 机位构图
- [x] 无头验收 `tools/godot/verify_harbor_diorama.gd`（场景加载 / shader 挂载 / 船体随波运动 / 未接入主场景）
- [x] 静态文档与截图归档：`docs/static/dev_scenes/`、`docs/design/screenshots/`
- [ ] 升级为可接入的 `PortStage`：`StageHost` + `SubViewport` 透明合成、固定机位与 2D HUD 叠加
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

## 暂缓：2.5D 固定舞台

> 等玩法闭环、存档与回归测试稳定，且 3D 船只/港口/模块资产达到最低量后再启动。设计已归档：[2.5D 固定舞台升级方案](docs/design/2.5D_STAGE_PLAN.md)。

- [ ] `StageHost` + `PortStage`（固定机位、有限环绕、2D HUD 叠加）
- [ ] `MarketStage` / `ShipyardStage`（固定机位、场景热点、无读条切换）
- [ ] 离港拉高 → 2D 海图 → 进港降落演出（可跳过、事件暂停）
- [ ] 目的港舞台预加载与 3D 资产缺失时的 2D 回退
- [ ] 质量档位、低配回退与第三方 `.glb` 白名单评审

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

## 维护约定

- 改代码后同步更新 `docs/static/` 对应文件与 `docs/static/manifest.json`。
- 数值改动先改 Core JSON，不在框架里写死。
- 新增命令/查询必须经 `FrameworkApi` 注册，并补测试。
- 新增内容类型需要同时补 Schema、注册表映射、跨引用检查与文档；随后运行 `node SNModMaker/tools/sync-schemas.mjs` 与 `node SNModMaker/tools/sync-core-index.mjs`，并跑 `node SNModMaker/tests/run-tests.js`。
