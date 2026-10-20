# 正式版架构方向：持久模拟经营战役

> 状态：方向确认（2026-10-19），待拆分为 ADR / Schema 2.0  
> 前置文档：[框架 + 模组 v1.0](../archive/蒸汽航海_项目架构方案_框架与模组_V1.0.md)、[MVP GDD v1.0](../archive/蒸汽航海_MVP_GDD_V1.0.md)  
> 适用版本：正式版（Framework 1.x / Mod API 2.0 / Content Schema 2.0）

## 1. 决策

正式版采用**持久模拟经营战役存档**，开局随机：

- 一个战役 = 一份持续存在的存档，包含世界、舰队、基地、航线、发现、关系与历史。
- 新战役由种子 + 开局档案（`start_profile`）生成世界与初始资产；随机开局是正常玩法，不是异常。
- 失败不自动删档、不回到主菜单重开；破产、舰队覆灭、基地失守等进入可恢复或退休/终局状态（具体规则待定）。
- 玩家可以同时拥有多个战役存档；自动存档按战役隔离。
- 世界布局在开局时生成后固定；后续内容更新只能做兼容性增量，不能重排既有世界。

这取代 MVP 的“单局 roguelite + 自动重置”语义。

## 2. 与 MVP 的差异

| 维度 | MVP | 正式版 |
| --- | --- | --- |
| 存档 | 单局 autosave / pre_voyage | 多战役、每战役多存档槽、战役元数据 |
| 世界 | 每局生成 4–5 港，重开即换 | 开局生成大区域，固定存在，逐步探索 |
| 舰队 | 单船 + 模块 | 多船、船长/船员、编组、跨区调度 |
| 基地 | 无 | 持久基地、建筑、生产、仓储、防御 |
| 经济 | 玩家交易 + NPC 局部模拟 | 自动贸易、区域间物流、长期价格与库存 |
| 失败 | 航行失败回滚 / 重开 | 局部损失、债务、撤退、破产/退休，不静默重置 |
| 内容更新 | 换 core 包即新局 | 旧战役必须能加载；新内容按迁移规则注入 |

## 3. 状态模型

建议把 `GameState` 升级为 `CampaignState`（可保留 `GameState` 作为兼容名），只存 ID 与原始运行态：

```text
CampaignState
├── meta        save_schema / content_schema / seed / created_at / playtime / difficulty
├── clock       time_hours / paused / speed
├── world       regions / sites / fog / routes / markets / factions / npcs
├── fleet       ships[] / captains[] / crew[] / formations / cargo / transit
├── bases       bases[] / buildings / queues / storage / workers
├── trade       routes[] / orders[] / automation_states[]
├── expeditions  active[] / completed[]
├── contracts   offers / active / completed / main_chain
├── economy     money / debt / reputation / prices / stats
└── log         notices / domain events（有界）
```

约束：

- **实现状态**：save_schema / state_schema 2.0 已落地，1.x 旧档可迁移；`GameState` 暂时仍是同一个数据对象，`campaign` 块已承载元数据，并逐步加入运行态分区：`world`（生成标记、已访问区域/港口、已发现地点）、`codex`（图鉴发现）、`factions`（声望等运行态）。分区由 `GameState.ensure_campaign_sections()` 惰性补齐，只追加 ID 与原始数值。fleet / bases / trade 等分区随对应系统加入。

- **定义**（`CoreDefinition` / 未来各内容类型）仍然只存在于冻结注册表，不写入存档。
- **生成物**（世界布局、遗迹房间、遭遇实例）由“种子 + 配置 + 内容版本”确定；存档保存结果，不重复生成。
- 每个系统使用独立命名随机流：`world:*`、`combat:*`、`ruins:*`、`trade:*`、`npc:*`；新增系统不能扰动旧流。
- 存档头记录 Framework / Mod API / Content Schema / 模组清单与内容哈希；缺失关键模组拒绝加载，新增可选模组给出警告。

## 4. 生命周期

1. **新战役**：选择/输入种子 → 选择开局档案 → 生成世界与初始舰队/基地点 → 写入战役槽。
2. **继续**：列出战役（名称、种子、游玩时长、版本、内容哈希、缩略图），选择槽位加载。
3. **自动存档**：按战役独立槽位；关键交易/战斗/建造节点追加检查点。
4. **手动存档**：命名槽位，不允许覆盖其他战役。
5. **失败/终局**：破产优先进入债务重组；舰队全灭进入漂流/救援；基地失守进入流亡。是否硬性终局由难度档案决定。
6. **内容更新**：旧战役加载后只应用声明为“向后兼容”的内容增量；世界布局、已生成遗迹、进行中的战斗不重生。

## 5. 模拟层

- 采用**可暂停的 tick 模拟**（小时/日），玩家操作不阻塞时间；等待、航行、建造、自动贸易都在 tick 上结算。
- 区域级细节分层：玩家所在区域精细模拟，远方区域按日/周批量结算，避免大世界卡顿。
- 默认不做离线收益；如后续加入，必须显式配置并有上限，避免“关游戏变强”。
- 所有模拟结果走 Domain Event / Notice，UI 通过 Query 读取，不在 UI 里推进时间。

## 6. 数据契约

新系统统一遵守“三类数据”：

| 类别 | 例子 | 谁提供 |
| --- | --- | --- |
| 定义 | 武器、敌舰原型、建筑、遗迹原型、阵营、船长 | 模组 / core |
| 规则与表 | 遭遇表、掉落表、生产配方、航线模板、生成配置 | 模组 / core |
| 运行态 | 当前战斗、基地队列、已发现地点、自动贸易状态 | 存档 |

建议新增的官方内容族（名称待 Schema 2.0 定稿）：

- 世界/探索：`regions`、`sites`、`route_templates`、`world_profiles`、`weather_profiles`、`discoveries`、`factions`
- 舰队：`ship_archetypes`、`captains`、`crew_roles`、`formations`、`fleet_doctrines`
- 战斗：`weapons`、`damage_types`、`combat_abilities`、`enemy_archetypes`、`encounter_tables`、`loot_tables`
- 基地：`base_sites`、`buildings`、`building_upgrades`、`production_recipes`、`worker_roles`
- 自动贸易：`trade_policies`、`automation_rules`
- 遗迹：`ruin_archetypes`、`room_templates`、`expedition_events`、`hazard_tables`、`relics`
- 开局：`start_profiles`（世界种子约束、起始港口/区域、初始舰队、初始基地点、难度）
- 通用：`factions`、`quests`、`loot_tables`、条件/效果操作码扩展

### 单一内容类型清单

先建立 `content_types.json` 作为唯一真源，描述 `key / singular / schema / group / capability / editor 提示 / 默认模板`。  
`ContentTypes`、`schemas/` 索引、SNModMaker 的 `schema-bundle.js`、`core-index.js`、`catalog.js`、SDK 校验与静态文档全部从它派生；CI 检查生成物是否过期。

## 7. 编辑器如何约束架构

- **Schema 先行**：没有 Schema 的内容类型不允许进入 core 或发布。
- **系统视图**：在 SNModMaker 中增加开局档案、世界区域、遭遇表、生产链、遗迹房间、掉落表等专用视图，但只编辑数据。
- **静态质量门禁**：跨引用、孤儿定义、空表、不可达内容、循环依赖、开局可解性抽样、经济极端值。
- **双端校验**：编辑器静态校验 + `sdk/validate.gd` 真实加载校验；发布前两者都必须通过。
- **内容契约测试**：每类定义都能加载、跨引用解析、编辑器导入导出 round-trip、旧存档迁移。
- **不能表达为数据的新机制**：先在框架实现为受控领域服务 / 操作码，提升 Mod API 与 capability，再让模组组合；不允许用任意脚本绕过。

## 8. 落地顺序（P0）

1. 冻结 MVP 1.0 行为与存档，保留 1.x 只读迁移。
2. 定义 Content Schema 2.0 与存档 Schema 2.0；先写迁移器和“旧档可开”测试。
3. 建立 `content_types.json` 单一真源，改造框架/编辑器/SDK。
4. 定义新战役生命周期与多战役存档 UI，再开始世界生成。
5. 按垂直切片推进：世界/探索 → 舰队 → 战斗 → 基地 → 自动贸易 → 遗迹。

## 9. 待拍板问题

- 模拟节奏：按小时 tick（可暂停、可加速）还是“每日结算”回合制。
- 战役失败：继续经营（债务/流亡）还是难度决定硬终局。
- 自动贸易与远方舰队是否允许离线推进。
- 战役中允许新增/移除模组的边界。
- 多战役上限、存档大小预算与云同步需求。
