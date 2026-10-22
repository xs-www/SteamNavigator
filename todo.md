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
- [ ] 炮门 socket 内容镜像：`hull.schema.json` 的 `hull_data` 新增可选 `gun_port_sockets` 数组并回填 Core `hulls.json`（供编辑器 / 装配器读内容，运行时仍以 GLB extras 为准）
- [ ] 正式任务系统 Phase B：`quests` 内容类型 + `QuestService`（任务链、目标事件、前置 / 奖励、发布点、任务日志页）；契约见 [TASK_QUEST_SYSTEM.md](docs/design/TASK_QUEST_SYSTEM.md)
- [ ] 战斗内容 Schema 2.0 其余类型：`damage_types` / `enemy_archetypes` / `encounter_tables` / `loot_tables`（`weapons` 草案已落地，见 [WEAPON_CONTENT_SCHEMA.md](docs/design/WEAPON_CONTENT_SCHEMA.md)）；保持 `planned`，先补 Schema + 有效/无效样本
- [ ] 武器内容接入运行时：`weapons` 进 runtime types / 注册表，`ShipVisualAssembler` 改读内容 + GLB 节点（船体 socket 镜像转正），SNBattleSim 的 `kind` 行为与命中/齐射/冷却规则并入战斗结算；同时补齐 `yaw_limit_deg` / `mount_pad_*`、统一 socket 索引与 `mast_key` 口径。**类型提升前不要把 2.0 `weapons` 写进 Core**（运行时会按 mod error 拒绝，Core 必需包 → `Degraded`）；当前 5 件模拟器武器落在编辑器「舰载武器包」模板

- [ ] 2.5D 舞台收尾：委托 / 情报页舞台化、事件触发的 3D 场景预加载、质量档位与低配回退、L2 LOD、第三方 `.glb` 白名单评审
- [ ] 高频决策页第二轮：市场数量步进 / 即时成本、持久 `ScreenHost` 与局部数据刷新
- [ ] 存档：声明式 ID 别名与数据迁移执行器；出航失败回滚的存档路径端到端测试
- [ ] SDK / 发布：模组管理 UI（启用 / 禁用 / 优先级）、发布签名与固定哈希校验
- [ ] 建模需求 Backlog：按 [MODELING_BACKLOG.md](docs/design/MODELING_BACKLOG.md) 的批次顺序推进（M0-3 船侧武器 socket、M0-4 `rig_kit`、M0-5 LOD1 基础套件、casemate 穿壳炮模块化均已完成，M0 系列收口；下一批建议：port cassette 或 M2-1 `combat_kit` 敌舰，或 M1-1 / M1-2 / M1-3 基地 / 内景；LOD1 运行时切换与质量档位待接线，LOD2 见 M2-5）
- [ ] 遗留清理：`SN_Ship_Prototype`（`model.ship.prototype` 遗留键）仍是旧纯色 `SN_*`，可随船体资产批次一起迁移或删除遗留键
- [ ] 3D 资产收尾：帆船 / 明轮 / 模块的 Godot 导入与目标机位验收、水面性能低配档位与第二港口变体
- [ ] 起重机三件新资产接入：`SN_Mega_Gantry` / `SN_Wooden_Mast_Crane` / `SN_Hand_Jib_Crane` 的 PortStage 槽位与目标机位复核（Core manifest 资源键与 `shared_materials` 贴图已接入）
- [ ] 模型素材库接入：kit 批次 1–3 其余 22 件资产登记 Core `model.kit.*` 资源键（武器 4 件已以 `model.weapon.*` 登记，帆索 12 件以 `model.rig.*`、船体部件 4 件以 `model.ship_part.*` 登记），接 `ShipVisualAssembler` / 场景装配的 socket 装配与目标机位复核（目录见 `tools/modeling/kit_catalog.json`）
- [ ] Content Schema 2.0 迁移（分层）：Phase A 已落地；Phase B 实现契约已就绪（9 类类型 + CampaignFactory + 1.0→2.0 映射），待隔壁探索 4.1 提交后开工；之后 C 实体合并 → D 其余系统 → E 冻结 1.0。方案：[CONTENT_SCHEMA_V2_MIGRATION.md](docs/design/CONTENT_SCHEMA_V2_MIGRATION.md) / [WORLD_SCHEMA_V2_RUNTIME.md](docs/design/WORLD_SCHEMA_V2_RUNTIME.md)（待拍板 D2–D3、D7–D12）

### 海图 / 探索

- [ ] 阶段 5 事件化海洋：航行事件预生成与预加载、事件类型（敌对 / 环境 / 奖励 / 秘境）、3D 场景触发与决策、安全航行结算（含探索途中事件与耐久告急）
- [ ] 阶段 6 固定未知岛屿与基地建设：勘探、设施建造、公开港口
- [ ] 可选：航线表体积优化（path 抽稀 / 压缩，当前 38 条边 82 KB）

### 正式版路线图

- [ ] 阶段 0：Content Schema 2.0 系统类型、多战役存档、tick 模拟框架
- [ ] 阶段 1：广域海图与探索运行时（v2 草案提升 active，接世界生成 / 战役 `world` 分区 / 区域低细节模拟）
- [ ] 阶段 2：舰队组成与战斗（先自动结算，再战术层）；模块 condition 进入派生属性；战斗内容 Schema 2.0（`weapons` 草案、船体 socket 镜像与编辑器支持已完成，见 [WEAPON_CONTENT_SCHEMA.md](docs/design/WEAPON_CONTENT_SCHEMA.md)；`enemy_archetypes` / `encounter_tables` / `loot_tables` 待做）；SNBattleSim 规则并入
- [ ] 阶段 3：基地建设与生产链（接入舰队 / 战斗 / 贸易）
- [ ] 阶段 4：自动化贸易（航线、规则、风险与 tick 结算）
- [ ] 阶段 5：遗迹探索（程序化房间、远征、战利品）
- [ ] 阶段 6：整合、内容量、Mod API 2.0 / Content Schema 2.0 冻结与发布验收

## Recently Completed

> 新完成项先记在这里，打 `v*` tag 前按版本归并进 [CHANGELOG.md](CHANGELOG.md) 并移除。
