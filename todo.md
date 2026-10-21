# TODO

> 只保留最近 10–15 项已完成与尚未实现的目标；逐条实现细节见 git 历史。
> 发布约定：打 `v*` tag 前把 `Recently Completed` 里的条目按版本归并进 [CHANGELOG.md](CHANGELOG.md)（只写有意义的功能 / 变更），并从本文件移除。

## In Progress

- [ ] SNBattleSim 战术状态机工作台：人工浏览器验收（节点拖拽、转移表、状态机 CRUD、舰船挂载）后评估是否并入正式战斗
- [ ] 海图阶段 4.4 线索扩展（4.4.1–4.4.3 已实现，4.4.4–4.4.5 进行中）：`port_goods` 货物行情线索（已发现港口 + 货物 + 冻结行情 + 分级披露）、`expires_at` 时效与过期历史、`clue.list` 只读查询、旧存档惰性 normalize、在港等待 / 完成委托解锁来源、货物线索「前往该港」（`clue.travel` + 统一确认弹窗 + 普通航行演出）、调查消耗落地（20 金 / 6h / 75%，失败可再试）；下一步线索列表页、截图/文档收尾。契约见 [EXPLORATION_SYSTEM.md §11](docs/design/EXPLORATION_SYSTEM.md)

## Pending

### 近期

- [ ] 2.5D 舞台收尾：委托 / 情报页舞台化、事件触发的 3D 场景预加载、质量档位与低配回退、L2 LOD、第三方 `.glb` 白名单评审
- [ ] 高频决策页第二轮：市场数量步进 / 即时成本、持久 `ScreenHost` 与局部数据刷新
- [ ] 存档：声明式 ID 别名与数据迁移执行器；出航失败回滚的存档路径端到端测试
- [ ] SDK / 发布：模组管理 UI（启用 / 禁用 / 优先级）、发布签名与固定哈希校验
- [ ] 3D 资产收尾：帆船 / 明轮 / 模块的 Godot 导入与目标机位验收、水面性能低配档位与第二港口变体
- [ ] 起重机三件新资产接入：`SN_Mega_Gantry` / `SN_Wooden_Mast_Crane` / `SN_Hand_Jib_Crane` 的 PortStage 槽位与目标机位复核（Core manifest 资源键与 `shared_materials` 贴图已接入）
- [ ] 旧资产 UV 迁移：31 件铁港道具 / 6 件港口设施 / 11 件模块 / 4 艘船补 UV 并切换 `SN_Tex_*` 共享贴图材质（新资产已默认贴图；旧纯色 `SN_*` 逐批退役）
- [ ] 船体部件库 `rig_kit`（桅杆 / 斜桁 / 帆面 / 索具参数化）与运行时可替换部件（`SN_Socket_*` + `parts_manifest.json` + `ShipVisualAssembler`）

### 海图 / 探索

- [ ] 阶段 4.4 线索扩展：`port_goods` 货物类线索与 `expires_at` 时效、在港等待 / 完成委托解锁线索、线索列表页、调查消耗数值落地（4.4.1 已完成，见 In Progress）
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

> 新完成项先记在这里，打 `v*` tag 前按版本归并进 [CHANGELOG.md](CHANGELOG.md) 并移除。

- [x] 海图阶段 4.3 探索体验修正（5 片全部实现，全套 325 例通过）：雾半径改为 `min(世界短边) × Core 比例` 且双子世界尺寸内容化；线索获得固定 1 级 + 在港逐级 `clue.investigate`（1→4，消耗字段预留 0）；探索失败不消耗线索（记 `attempts`，可立即再次出航）；演出随船照亮 + 抵达/掉头沿途迷雾持久化；普通航线仅在选中港口时显示；删除详细总览旧海图；删除出航准备页、出航确认（预估 + 锅炉策略，默认上次）移入海图弹窗；资源演出连续读数、出发只扣工资、结算按实际航行小时一次落账。契约与实现台账见 [EXPLORATION_SYSTEM.md §10](docs/design/EXPLORATION_SYSTEM.md)，截图见 [exploration/](docs/design/screenshots/exploration/)。
- [x] 武器独立建模批次 1：5 件舰载武器（`SN_Weapon_DeckGun` / `HeavyCannon` / `Mortar` / `Repeater` / `Broadside`），9,704 tri、共享贴图、Yaw/Pitch Pivot、GLB + Core 资产副本 + 单件/lineup 预览；纯资产交付，未登记 manifest、未接战斗逻辑。工单 [sn_weapon_batch1.json](tools/modeling/briefs/sn_weapon_batch1.json)，验收 [WEAPON_BATCH1_ACCEPTANCE.md](docs/archive/WEAPON_BATCH1_ACCEPTANCE.md)，映射 [ASSET_MAP.md](docs/design/ASSET_MAP.md#3d-舰载武器五件套2026-10-21)。
