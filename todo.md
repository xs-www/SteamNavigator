# TODO

> 只保留最近 10–15 项已完成与尚未实现的目标；逐条实现细节见 git 历史。
> 发布约定：打 `v*` tag 前把 `Recently Completed` 里的条目按版本归并进 [CHANGELOG.md](CHANGELOG.md)（只写有意义的功能 / 变更），并从本文件移除。

## In Progress

- [ ] SNBattleSim 战术状态机工作台：人工浏览器验收（节点拖拽、转移表、状态机 CRUD、舰船挂载）后评估是否并入正式战斗
- [x] SNBattleSim 模组交换与 Agent CLI：`mods/` 散装目录及 ZIP 导入、游戏约定 `.snavmod.zip` 导出、状态/FSM 契约、AND/OR 条件、状态拖放、空白拉线建状态和 Delete 删除
- [x] SNBattleSim 二轮易用性：Mod 蓝图舰体装配、五状态默认 FSM、工程目录持久化、目标高亮、全状态尝试开火与顶部入口分级

## Pending

### 近期

- [ ] 2.5D 舞台收尾：委托 / 情报页舞台化、事件触发的 3D 场景预加载、质量档位与低配回退、L2 LOD、第三方 `.glb` 白名单评审
- [ ] 高频决策页第二轮：市场数量步进 / 即时成本、持久 `ScreenHost` 与局部数据刷新
- [ ] 存档：声明式 ID 别名与数据迁移执行器；出航失败回滚的存档路径端到端测试
- [ ] SDK / 发布：模组管理 UI（启用 / 禁用 / 优先级）、发布签名与固定哈希校验
- [ ] 3D 资产收尾：帆船 / 明轮 / 模块的 Godot 导入与目标机位验收、水面性能低配档位与第二港口变体
- [ ] 起重机三件新资产接入：`SN_Mega_Gantry` / `SN_Wooden_Mast_Crane` / `SN_Hand_Jib_Crane` 的 Core manifest 资源键、PortStage 槽位与目标机位复核（塔吊已沿用既有键并更新 GLB）
- [ ] 船体部件库 `rig_kit`（桅杆 / 斜桁 / 帆面 / 索具参数化）与运行时可替换部件（`SN_Socket_*` + `parts_manifest.json` + `ShipVisualAssembler`）

### 海图 / 探索

- [ ] 阶段 4.3 线索体验：`port_goods` 货物类线索与 `expires_at` 时效、在港等待 / 完成委托解锁线索、线索列表页
- [ ] 阶段 5 事件化海洋：航行事件预生成与预加载、事件类型（敌对 / 环境 / 奖励 / 秘境）、3D 场景触发与决策、安全航行结算（含探索途中事件与耐久告急）
- [ ] 阶段 6 固定未知岛屿与基地建设：勘探、设施建造、公开港口
- [ ] 可选：航线表体积优化（path 抽稀 / 压缩，当前 38 条边 82 KB）

### 正式版路线图

- [ ] 阶段 0：Content Schema 2.0 系统类型、多战役存档、tick 模拟框架
- [ ] 阶段 1：广域海图与探索运行时（v2 草案提升 active，接世界生成 / 战役 `world` 分区 / 区域低细节模拟）
- [ ] 阶段 2：舰队组成与战斗（先自动结算，再战术层）；模块 condition 进入派生属性；战斗内容 Schema 2.0（weapons / enemy_archetypes / encounter_tables / loot_tables）；SNBattleSim 规则并入
- [ ] 阶段 3：基地建设与生产链（接入舰队 / 战斗 / 贸易）
- [ ] 阶段 4：自动化贸易（航线、规则、风险与 tick 结算）
- [ ] 阶段 5：遗迹探索（程序化房间、远征、战利品）
- [ ] 阶段 6：整合、内容量、Mod API 2.0 / Content Schema 2.0 冻结与发布验收

## Recently Completed

- [x] 港口起重机四件套（2026-10-21）：补全塔吊参数化生成器并重建（`SN_Harbor_Crane` 3912 tri / 33 节点，Core 副本同步）+ 新增大型龙门吊 `SN_Mega_Gantry`（9420 tri / 39.6×14.8×29.65 m，台车齿轮传动 / 40 m 桁架桥 / 双卷扬机械房 / 吊装集装箱）、木制桅杆起重机 `SN_Wooden_Mast_Crane`（1932 tri / 14.77×7×14.25 m）、手摇悬臂吊 `SN_Hand_Jib_Crane`（896 tri / 4.6×1.7×5.17 m）；共用 `crane_kit.py`，干跑 / 导出 / GLB 世界空间自检 / Godot 导入验收 4/4 PASS；工单 `sn_crane_batch1.json`，记录见 `docs/design/MODELING_WORKFLOW.md` §11.11
- [x] 海图阶段 4.2（2026-10-21）：资源告急决策（航程 50% 停下，继续 / 掉头；跳过不能替玩家决策）、`VoyagePresentation.force_arrival()` 直接入港、`explore.decide` 幂等与错误码、探索入港复用普通抵达的到港服务（委托 / 市场记忆 / NPC / 债务 / 委托刷新 / 统计 / 自动存档）、告警状态进 `sea_chart.view`、窗口截图与 308 例全量回归
- [x] 海图阶段 4.1 探索系统（2026-10-21）：`ClueService`（抵达传闻 + 购买情报）、线索分级与海图可视化（方向箭头 / 虚线圆 / `？港名？`）、`explore.start`/`settle`/`decide`、搜索区判定与发现概率、失败漂流、发现后解锁港口与迷雾揭示、探索演出与结算；契约与截图见 `docs/design/EXPLORATION_SYSTEM.md`
- [x] 海图阶段 3 实机验收反馈 F1–F4（2026-10-21）：离港先转艏再驶离（入港镜像 + 接缝朝向一致）；镜头俯角爬到 83° 并拉升到 165 m；云层后海图由近景（×2.8）拉远到稳态、入港前反向推近；航行页海图改全窗 cover 取景并铺满（小世界 ×9 不受手动缩放上限约束）；演出航线改由 `WorldMap.edges` 提供，船沿真实航线按弧长行进
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
