# Content Schema 2.0 迁移落地方案

> 状态：Draft 6（2026-10-23，Phase D2 落地后刷新；Phase A/B、C1–C4 与 D0/D1/D2 已落地，**Phase C 完成、Phase D 进行中**）。本文件是**执行方案**，不是已定稿契约；契约性规则见
> [ENTITY_CONTRACT_V2.md](ENTITY_CONTRACT_V2.md)，路线图见 [FULL_GAME_ROADMAP.md](FULL_GAME_ROADMAP.md)
> 阶段 0/1，近期计划见 [DEV_PLAN_2026-10.md](DEV_PLAN_2026-10.md) §4.4。
>
> **结论先行**：实际按「按内容类型版本化 → 世界探索家族提升 → 实体合并 → 其余系统 → 冻结 1.0」分层落地；
> 截至 D2，**30 个 active 类型全部是 Content Schema 2.0（0 个 1.0 runtime）**，只剩 2 类编辑器草案。
> 开发期没有第三方模组与旧档负担，实体合并（C1/C2/C3/C4）**直接改 Core 内容与 ID、删除旧类型，不做别名与存档迁移**；
> 兼容策略只在发布前按 Phase E 另行评估。

## 1. 版本轴与术语

| 版本轴 | 当前值 | 状态 |
| --- | --- | --- |
| Framework | 0.2.0-dev 系列（`FrameworkInfo.VERSION`） | 随发布走 |
| Mod API | `1.0` | 未动 |
| **Content Schema** | **基线 `1.0`；按类型声明：30 类 active 全部 `2.0`（0 类 `1.0` runtime；含显式补丁）** | 运行时按 `ContentTypes.schema_version(type)` 加载；Phase A / B / C1–C4 / D0–D2 已落地，Phase C 完成、Phase D 进行中 |
| Save Schema | `2.0` | 已完成（含 1.x → 2.0 迁移） |
| State Schema | `2.0` | 已完成（`GameState.SCHEMA_VERSION`） |

本文只处理 **Content Schema**；Save / State 已是 2.0，不要在迁移中混用这两条轴。
`FrameworkInfo.CONTENT_SCHEMA`（`"1.0"`）自 Phase A 起只是**基线 / 默认值**（存档 header、编辑器默认），
不再是运行时全局门禁；每个 active 类型在 `content_types.json` 声明自己的期望版本。

## 2. 现状基线（2026-10-23 Phase D2 后快照）

### 2.1 游戏运行时

- [content_types.json](../../content_types.json) 是唯一真源：**30 个 active 类型**（29 个定义类型 +
  `patches`），**全部 `schema_version: "2.0"`，0 个 1.0 runtime 类型**。
- `ContentTypes`（生成物 [content_types.gd](../../framework/modding/content_types.gd)）带
  `SCHEMA_PATHS` / `SCHEMA_VERSIONS` / `schema_version(type)`；[content_compiler.gd](../../framework/modding/content_compiler.gd)
  按 `content_type` 取期望版本校验 envelope（Patch 再校验按**目标类型**版本），不存在全局 1.0 门禁。
  `FrameworkInfo.CONTENT_SCHEMA` 只作为基线/默认（存档 header 与编辑器默认）。
- 2.0 定义类型（29）：Phase B 的 `world_profiles / map_configs / regions / sites / route_templates /
  weather_profiles / factions / discoveries / start_profiles`；C1 的 `hulls` / `modules`；C2 的 `items`；
  C3 的 `quests`；C4 的 `port_templates` / `starting_scenarios` / `contracts` / `voyage_events` /
  `crew_roles` / `boiler_strategies`；D1 的 `weapons` / `damage_types` / `combat_abilities` /
  `enemy_archetypes` / `encounter_tables` / `loot_tables`；D2 的 `ship_archetypes` / `captains` /
  `formations` / `fleet_doctrines`；外加同样升 2.0 的 `patches`（第 30 个 active）。
- 1.0 运行时类型：**无**。`map_profiles` 已退役（`map_configs` 取代）；`port_archetypes` / `starting_builds` /
  `roles` / `strategies` / `events` 分别改名为 `port_templates` / `starting_scenarios` / `crew_roles` /
  `boiler_strategies` / `voyage_events`。
- 开局链路：C4 起**所有开局统一走 `CampaignFactory`**——`run.start` 无 `start_profile` 时
  `create_default_campaign`（默认 start profile + `starting_scenarios` 选择），显式传入时
  `create_campaign`；`build_id` / 1.0 `map_profiles` 路径已删除。
- Core：`dev_mods/core/` 29 个内容文件 / 114 条定义（9 个 Phase B v2 文件 + `hulls` / `modules` / `items` /
  `crew_roles` / `boiler_strategies` / `port_templates` / `starting_scenarios` / `contracts` /
  `voyage_events` / `quests` + D1 的 `weapons` / `damage_types` / `combat_abilities` / `enemy_archetypes` /
  `encounter_tables` / `loot_tables` + D2 的 `ship_archetypes` / `captains` / `formations` /
  `fleet_doctrines`）；`map_profiles.json` 已删除，`map_configs.json` 为唯一场景配置。
  goods+materials 已合并为 `items`（12 条 `core:item/*`，`data.crafting_material` 标志），5 类模块已合并为
  `modules`（12 条，`data.v2_category` = boiler/cargo/utility/cabin）。

### 2.2 内容 Schema 与草案

- `schemas/` 共 **35 个 Schema**：**2 个顶层**（`common` / `manifest`）+ **33 个 `schemas/v2/`**
  （`common` + 30 类 active 2.0 + 3 类草案）。不存在 1.0 内容 Schema。
- 3 类草案（`draft_schemas` / `draft_types`，仅编辑器与 Content CLI 可编辑）：
  `story_arcs`、`story_levels`，运行时暂不加载。
- v2 **未覆盖**：无；所有 active 类型（含 `patches`）均使用 2.0 Schema，仅剩 2 类剧情草案待后续系统接入。
- 旧模型清理（C1–C4）：合并完成后即删除旧类型、旧内容文件与旧 1.0 Schema（goods/materials、
  boilers/cargo_modules/navigation_modules/safety_modules/cabins、1.0 hull/roles/strategies/
  port_archetypes/starting_builds/events/contract/patch 顶层 Schema），**不保留 ID 别名**。

### 2.3 存档

- Save / State Schema 2.0 已上线，`save_migrations.gd` 负责 1.x → 2.0。
- `campaign.world / codex / factions` 分区与 clues 惰性块已建（只存 ID 与进度，不存定义）。
- v2 新档由 `prepare_for_save()` 写 `campaign.setup.content_versions`（类型 → 版本）；
  旧档加载时用当前注册表补齐缺失类型，版本漂移只 warning、不重排世界；C4 起不再推断 1.0 类型。
- 存档 header 的 `content_schema` 仍写基线 `FrameworkInfo.CONTENT_SCHEMA`（`"1.0"`），
  它不表达混合版本；实际加载集合看 `campaign.setup.content_versions`。

### 2.4 编辑器 / CLI / SDK / 门禁

- 编辑器：`SNContentTypes.TYPES`（30 个运行时类型，全部 2.0）+ `DRAFT_TYPES`（2 个草案），合计 **32**；
  schema bundle **35 个**（2 顶层 + 33 个 v2），由 `sync-schemas.mjs` 生成。
  校验器有 `schemaVersionFor` 与 `schema_version_mismatch` / `schema_version_unsupported` /
  `draft_content` / `capability_undeclared`；G8 导出守卫按“当前运行时不支持”判定（草案 / 未注册 /
  版本不符拦截，运行时 2.0 类型可部署）。
- Content CLI：`types` 输出 30 个运行时类型（全部标 runtime 2.0）与 2 个草案；
  `--draft` 只接受剩余草案类型；写出的内容文件按类型版本写 `schema_version: "2.0"`（CLI 测试 64；D-AI 新增 `combat_ai_profiles` schema 先行草案，CLI/编辑器可编辑，运行时不加载）。
- SDK `sdk/validate.gd` 走真实 `Bootstrap`（运行时语义）；`sdk/examples/example_weapons` 是 D1 的 runtime 2.0 示例，
  `sdk/examples/example_fleet` 是 D2 的 fleet 4 类型示例；发布 workflow 含 Godot 测试、`gen_content_types --check`、`gen_static_docs --check` 与 core 校验。
- 实体合并后旧档 / 旧内容模型在开发期**直接作废**（见 §4 Phase C 的开发期策略），不提供迁移器。

### 2.5 剩余差距

| 编号 | 差距 | 影响 |
| --- | --- | --- |
| G9 | ✅ Phase C3 已解耦：`contracts` 保持运输请求，`quests` 2.0 + `data.quests` + QuestService 负责抽象引导 | 委托接取生成追踪实例；task.view 聚合 |
| G10 | ✅ Phase C4 已完成：所有 1.0 定义类型 + `patch` 已升 2.0，`map_profiles` 退役 | 运行时不再有 1.0 类型 |
| G11 | Phase D：D0（sim tick）、D1（combat 6 类）与 D2（fleet 4 类）已完成；base / auto_trade / ruins 类型仍是 planned | D2 已有运行时读者；其余系统待接入 |
| G12 | Phase E：1.0 内容生成与读取尚未冻结（运行时已无 1.0 类型） | 发布门禁尚未强制 Content Schema 2.0 |
| G13 | 开发期不做旧档 / 旧内容兼容 | 发布前若需兼容，按 Phase E 重新评估 |

（Phase A/B 的 G1–G8 已随落地的按类型版本、类型提升、v2 运行时、Core v2 内容、Patch 版本规则、
`content_versions` 与 G8 导出守卫关闭；Phase C 的 G9/G10 已随 C3/C4 关闭。）

## 3. 迁移策略与决策

### 3.1 为什么不“一次性全量升级”

| 方案 | 需要做的事 | 代价 / 风险 | 结论 |
| --- | --- | --- | --- |
| A. 全量 bump：20 类运行时类型一次性变 2.0（当时评估） | 需一次性补写全部 20 套 v2 Schema + 迁移全部 core 内容 + 改编译器/注册表/补丁/交叉校验 | 玩法零变化、回归面最大；与在途探索/海图/实体合并工作直接冲突 | ❌ 未采用；实际按 B 分片完成 |
| B. 分层统一：按类型版本 + 纵向切片 | 先让编译器支持“每个类型自己的版本”，再逐家族提升 | 每阶段可发布、可回滚；Phase A/B/C1–C4 已按此落地 | ✅ 已采用 |

### 3.2 决策清单（已拍板）

| 编号 | 决策 | 结论 |
| --- | --- | --- |
| D1 | 版本粒度 | **按内容类型声明版本**；C4 后 20 类 active 全部为 2.0（0 个 1.0 runtime），保留一个基线常量只用于编辑器默认与提示 |
| D2 | 1.0 兼容窗口 | 原计划一个 minor 双读；**开发期（C/D，2026-10-22）拍板不要求旧档 / 旧内容兼容**，每次迭代后旧模型直接作废，发布前按 Phase E 重新评估 |
| D3 | 存档内容版本记录 | `content_schema` 保留为基线；新增 `content_versions`（类型 → 版本）惰性补齐，加载时按实际注册表推导 |
| D4 | Patch 版本 | Patch envelope 固定 `schema_version: "2.0"`；不符时由 `patches` 2.0 的 envelope 校验以 `unsupported_schema` 拦截（不再有单独的 patch 目标版本错误码），不做隐式转换 |
| D5 | 实体合并时机 | 独立于世界探索家族，单独一个阶段（Module → Item → Quest）；**开发期直接改 core ID、不保留别名/不写迁移器**（发布前若需兼容另评估） |
| D6 | planned → active 门槛 | ①运行时读者 ②注册表与引用规则 ③Core 完整性规则 ④core 内容 ⑤编辑器/CLI ⑥测试 ⑦文档；缺一不提升 |

### 3.3 与在途工作的顺序约束（已完成）

1. ~~先让探索系统 4.1 落定并提交~~（已完成，4.1–4.5 均在主线）。
2. ~~再做 Phase A~~（已完成）。
3. ~~Phase B 启动时把 `map_profile.exploration` 的参数迁入 v2 `map_config`~~（已完成：`map_configs` 覆盖 31 键
   exploration 与 `story`；`map_profiles` 已在 C4 退役并删除）。

## 4. 分阶段执行方案

> 以下工期是单人在当前代码库上的**粗估**（含测试与文档），只用于排序与拆分，不作承诺；
> 每个阶段独立可发布、可回滚。

### Phase A · 按类型版本解耦（小，1–2 天）

**状态：已落地（2026-10-21，分支 `schema-v2`）。**

目标：编译器从“全局 1.0”变成“每个类型有期望版本”，1.0 行为逐字节不变，不激活任何新类型。

| 任务 | 文件 | 内容 |
| --- | --- | --- |
| A1 | `content_types.json` | 每个 `types[]` 增加 `schema_version`（当前全 `"1.0"`）；草案继续在 `draft_types`；`content_schema` 保留为基线/默认 |
| A2 | `tools/gen_content_types.mjs` | 校验 `type.schema_version` 等于对应 Schema 的 `properties.schema_version`（兼容 `const` 与单值 `enum` 两种写法）；生成 `SCHEMA_VERSIONS` 与 `schema_version(type)`；`--check` 守护 |
| A3 | `framework/modding/content_types.gd`（生成物） | 新增 `SCHEMA_VERSIONS` + `schema_version(content_type)`；现有 API 不变 |
| A4 | `framework/modding/content_compiler.gd` | 用 `ContentTypes.schema_version(type)` 替代全局比较；错误消息报“期望版本”；Patch 再校验按目标类型版本构造 envelope |
| A5 | `SNModMaker/js/content-types.js` / `catalog.js` | 所有类型统一带 `schemaVersion`（不再用 `draft` 推断版本）；`schemaVersionFor` 读同一字段 |
| A6 | `framework/tests/cases/test_content_versions.gd`（新） | 1.0 内容通过；`goods` 声明 2.0 → `unsupported_schema` 且消息含期望版本；Patch 跨版本按目标类型版本校验 |
| A7 | 文档 | `ENTITY_CONTRACT_V2.md` §14/§16 更新版本轴与阶段状态；本文件勾选 Phase A |

实现记录：`ContentTypes.schema_version()` 成为运行时的唯一版本来源；`FrameworkInfo.CONTENT_SCHEMA` 降级为“基线/默认”（存档 header 与编辑器默认仍用它）；1.0 模组、补丁与存档行为不变，未来把 v2 类型提升 active 时只需在 `content_types.json` 把该类型 `schema_version` 改为 `"2.0"` 并提供对应 Schema 路径。

G8 同步收口：`Store.draftContentFiles()` / `hasDraftContent()` 识别草案内容；编辑器对含草案的项目禁用「导出并覆盖到发布包 mods/」，ZIP / exports/ / 目录导出改为二次确认并提示“游戏运行时不加载”。

验收：现有 Godot 全套 + Node 全套 + `gen_content_types --check` 全绿；1.0 项目加载行为零变化。
回滚：单 commit revert，无数据迁移。

### Phase B · 世界探索家族提升（阶段 0/1，2–4 周）

**状态：B0–B6 已完成（2026-10-22），Phase B 收尾。** 执行契约：[WORLD_SCHEMA_V2_RUNTIME.md](WORLD_SCHEMA_V2_RUNTIME.md)
（Draft 2，含 9 类类型、引用/完整性规则、CampaignFactory 流水线、1.0→2.0 字段映射、存档与落地顺序）。
B0 证据：探索 4.1 与 Phase A 均已在 `main`（无需 rebase）；契约已按 4.2–4.5 的 `map_profile` 现状刷新
（`exploration` 31 键、`twin_world_size`、`story`、15 处读取点）；Godot 419/419、生成物检查、SDK core 校验、
Node 50/50 全绿。B1 证据：9 类 2.0 类型已 active（`ContentTypes` 25 类、编辑器 26 项、schema bundle 29 个），
`map_configs` 覆盖 31 键 exploration + `story`，框架/编辑器测试与 CLI 全绿。B2–B4 证据：9 个跨引用检查 + Core
完整性 gate；`CampaignFactory` + `run.start start_profile` + `campaign.view` + 12 处 resolver；Core 9 个 v2 内容文件
（82 definitions，SDK `status: ok`）；Godot 全量 468/468、Node 50/50、CLI 57/57。

目标：8 类 v2 草案 + 新增 `map_configs`（1.0 `map_profiles` 的 v2 继任者）从 `planned`/草案提升为 active，
并由真实运行时消费（Phase B 期间保留 1.0 老链路；C4 已删除 1.0 链路与 `map_profiles`）。

| 任务 | 范围 | 说明 |
| --- | --- | --- |
| B0 | 前置 | 探索 4.1 提交；`schema-v2` rebase `main`；冻结其 1.0 `map_profile` 字段，后续只做迁移映射 |
| B1 | 类型提升 | ✅ 已完成（2026-10-22）：8 类从 `planned` 移入 `types` + 新增 `map_configs`；删除对应 `draft_types` / `draft_schemas` 条目、清理 `planned`；新增 `schemas/v2/map_config.schema.json` 并微调 `world_profiles`/`start_profiles` |
| B2 | 注册表与引用 | ✅ 已完成（2026-10-22）：`RegistryHub` 按 `ContentTypes.all()` 自动生效；`CrossReferenceValidator` 增加 9 个 `_check_*` 与 `ref_inactive_type` 规则（目标激活后自动升级硬校验）；`CoreCompletenessChecker` 增加 Phase B 规则（Core presence gate）；`FrameworkInfo.CAPABILITIES` 增加 `content.world.v1` / `content.campaign.v1` |
| B3 | 世界生成运行时 | ✅ 已完成（2026-10-22）：新 `CampaignFactory` 消费 `start_profiles → world_profiles + map_configs + regions/sites/route_templates/weather/factions/discoveries`；复用 `MapGenerator` 几何 + 孪生 `world_map`；`campaign.world / codex / factions` 接线；`run.start` 增加可选 `start_profile`，新增 `campaign.view` 查询；`ContentRefs` 统一 12 处 resolver |
| B4 | core 内容 | ✅ 已完成（2026-10-22）：`dev_mods/core/content/` 新增 9 个 v2 内容文件 + 本地化（各 +62 键）；`map_profiles.exploration` 31 键与 `story` 原样迁入 `map_configs` |
| B5 | 存档 | ✅ 已完成（2026-10-22）：新档由 `prepare_for_save()` 写 `campaign.setup.content_versions`；旧档推断 `starting_builds/map_profiles → 1.0` 并用注册表补齐；版本漂移只 warning、不重排世界 |
| B6 | 编辑器 / CLI / SDK | ✅ 已完成（2026-10-22；历史记录）：当时草案分区只剩 `weapons`；`capability_undeclared` 按 schemaVersion=2.0 判定并按 capability 去重；G8 改为“运行时不支持”（草案/未知类型/版本不符拦截，提升类型可部署）；CLI 标 runtime 2.0；release workflow 加入 Node 两套件。D1 起 `weapons` 已 active，草案只剩剧情 2 类 |

验收：v2 世界生成可开局；旧档可继续；1.0 模组在双读窗口内仍可加载；seed 回归（现有 seed + 新 v2 seed）；
编辑器/CLI/SDK 全链零 error；`gen_content_types --check`、`gen_static_docs --check`。
回滚：B 阶段独立分支；若 v2 世界生成不达预期，保留类型草案状态、回退运行时，不影响 1.0。

### Phase C · 实体合并与残留类型 2.0 化（Module / Item / Quest / 其余 1.0 类型，1–2 周）

**状态：C1–C4 已完成（2026-10-22/23），Phase C 收尾。** C1 证据：5 类模块合并为 `modules` 2.0（12 条 core 定义，`core:module/*`）、hulls 升 2.0、`ModuleOps` 运行时与船厂分类 UI 落地；Godot 491/491。C2 证据：goods + materials 合并为 `items` 2.0（12 条 core 定义，`core:item/*`，`crafting_material` 标志），全量引用/本地化/编辑器/运行时统一到 ITEM。C3 证据：新增 `quests` 2.0（`core:quest/*` 2 条）+ 持久 `data.quests` + QuestService，委托接取生成追踪实例、task.view 聚合。C4 证据：`port_archetypes → port_templates`、`starting_builds → starting_scenarios`、`roles → crew_roles`、`strategies → boiler_strategies`、`events → voyage_events`、`map_profiles` 退役，`contracts` / `patches` 升 2.0 并删除 1.0 回退；**20 个 active 类型全部 2.0（0 个 1.0 runtime）**，schema bundle 26（2 顶层 + 24 v2）、编辑器 23（20 + 3 draft）。验证：Godot **527/527**、Node **58/58**、CLI **63/63**、SDK `status: ok`。

> **开发期策略（2026-10-22 拍板）**：开发器没有第三方模组，直接全量升级 core 到 Schema 2.0 并保证运行即可；
> 每次迭代后不保留旧存档 / 旧内容模型兼容。C-D2 的旧/新类型并存仅是分步开发手段，不是兼容窗口；每个实体
> 合并完成后即可删除旧 1.0 类型与旧内容定义，旧档直接作废（B5 的迁移矩阵不作为 C/D 门禁）。
>
> **C1 设计决策（2026-10-22）**：
> - 5 类模块（boilers/cargo/navigation/safety/cabins）合并为 `module` 2.0，`v2_category` 取
>   `boiler/cargo/utility/cabin`（`crew` 预留）；**hulls 不并入**，保留独立 `hull` 2.0；
> - 运行时新增 category-aware `ModuleOps`/`ModuleCatalog` 访问器；ship 存档继续使用扁平槽位
>   （`boiler` / `cargo_modules` / `navigation_module` / `safety_module` / `passenger_cabin`），不重写槽位结构；
> - `module.schema.json` 用 `v2_category` + 字段超集；项目 SchemaValidator 不支持 if/then，
>   category 专属必填由语义校验器负责；编辑器使用分类页签与每类默认值；
> - capability 使用 `content.modules.v1`；完整性检查按 category 计数；
> - 不做 ID 别名 / 旧存档迁移；core 内容直接改为新类型。

| 顺序 | 合并 | 迁移方式 |
| --- | --- | --- |
| C1 | **✅ 已完成（2026-10-22）**：5 类模块（boilers/cargo/navigation/safety/cabins）→ `modules` + `v2_category`（`boiler/cargo/utility/cabin`，`crew` 预留）；**hulls 独立为 `hull` 2.0**；`ModuleOps`/船厂分类 UI/完整性按 category；core 直接改新 ID，无别名 | 不保留旧类型/ID 别名；core 内容直接改为新类型；导航与安全归 `utility` |
| C2 | **✅ 已完成（2026-10-22）**：goods + materials → `items` 2.0（`data.crafting_material` 标志、字段并集）；core 12 条 `core:item/*`，全量引用/本地化/编辑器/SDK example/运行时统一到 ITEM | 直接重命名 core 内容与引用；不做 ID 别名 |
| C3 | **✅ 已完成（2026-10-22）**：委托与任务解耦——`contracts` 保持独立（运输请求）；新增 `quests` 2.0（抽象引导：剧情演出、游戏指引、非运输类系统需求），持久 `data.quests` + QuestService；委托接取后生成 quest 实例写入 `data.quests` 以供追踪；task.view 聚合 quests + accepted contracts | 不合并 contracts/quests；story 暂时保留，后续剧情模式开发时由 quests 上位替代 |

### Phase C4 · 残留 1.0 类型 2.0 化（✅ 已完成，2026-10-23）

C1–C3 之后处理剩余 1.0 定义类型，分四个切片落地：

- **C4-A**：`port_archetypes → port_templates`、`starting_builds → starting_scenarios`；`map_profiles` 退役
  （`map_configs` 取代），Core 删除 `map_profiles.json`。
- **C4-B**：运行时切换到 `port_templates` / `starting_scenarios`，`CampaignFactory` 与 `run.start` 不再读 1.0 类型。
- **C4-C**：`events → voyage_events`、`roles → crew_roles`、`strategies → boiler_strategies`。
- **C4-D**：`contracts` 与 `patches` 升 2.0，删除 1.0 回退路径（`RunFactory` / `ContentRefs` / 存档 resolver）。

目标达成：`ContentTypes` 20 类全部 2.0（19 定义 + patch）；1.0 内容 Schema 全部删除（顶层只剩
`common.schema.json` / `manifest.schema.json`），`schemas/v2/` 为唯一内容 Schema 目录。

### Phase D · 其余系统类型（逐系统）

fleet / combat / base / auto_trade / ruins 每个系统按同一模板走：
Schema 草案 → `planned` 登记 → 达到 D6 门槛 → 提升 active → 运行时纵向切片 → 存档分区 → 编辑器/CLI/文档。
开发期同样不承诺旧档兼容；先补最小 tick/模拟框架切片（D0），再按 combat → fleet → base → auto_trade → ruins。

**当前进度（2026-10-23）**：
- **D0 ✅ 确定性模拟时钟**：`sim.pause` / `sim.resume` / `sim.set_speed` / `sim.advance` + `sim.view`，`data.sim` 惰性状态，固定 1 游戏小时步长，`sim.tick` 领域事件；不接 gameplay。
- **D1 ✅ combat**：`weapons` 提升 active + 新增 `damage_types` / `combat_abilities` / `enemy_archetypes` / `encounter_tables` / `loot_tables`（6 类 2.0）；`CombatOps` / `CombatService` / `combat.resolve` / `combat.view` / `combat.log`，Core 6 个战斗内容文件；暂不接航行风险结算。
- **D2 ✅ fleet**：`ship_archetypes` / `captains` / `formations` / `fleet_doctrines` 四类 active 2.0；`FleetOps` / `FleetService` / `fleet.assign_captain|set_formation|set_doctrine|add_ship|remove_ship` / `fleet.view`，`data.fleet` 惰性持久；Core 4 个舰队内容文件、`sdk/examples/example_fleet`。
- **下一步**：base / auto_trade / ruins 的 Schema 与运行时切片，以及 D1 航行遭遇接入 / 敌舰可视化、D2 舰队与战斗 / 航行的联动。

### Phase E · 冻结 1.0（1 周）

- 停止生成 1.0 内容；删除 1.0 读路径，遇到 1.0 内容给出明确“需要 2.0”的错误。
- 开发期已拍板不保留旧档/旧模型兼容，因此不再提供面向玩家的 1.0→2.0 存档/内容迁移工具；如发布前确需，
  另行评估。
- 发布门禁要求 Content Schema 2.0；更新 `README`、`CHANGELOG`、`ENTITY_CONTRACT_V2` 状态为 Finalized。

## 5. 兼容性矩阵（目标态）

| 场景 | Phase A | Phase B | Phase E |
| --- | --- | --- | --- |
| 1.0 内容模组 | 正常加载 | 正常加载（双读窗口） | 拒绝 + 迁移指引 |
| 2.0 世界探索内容 | 仍不可加载 | 正常加载 | 正常加载 |
| 混合版本模组（1.0 + 2.0 类型） | 允许编辑器编辑 | 允许（按类型校验） | 要求全 2.0 |
| 1.x 旧存档 | 正常 | 正常（惰性补齐） | 正常（迁移矩阵覆盖） |
| v2 世界存档读入 1.0 运行时 | 不适用 | 拒绝并保留只读提示 | — |

> **当前实现（2026-10-23 D2 后）**：Phase B、Phase C（C1–C4）与 Phase D0/D1/D2 已完成；**30 个 active 类型全部为 2.0，运行时不再有 1.0 类型**，
> 顶层 1.0 内容 Schema（roles / strategies / port_archetypes / map_profiles / starting_builds / contracts / events / patch）
> 与对应旧内容文件已删除，旧模组按「未知类型 / 版本不符」拒绝。双读窗口不再适用（见下方开发期例外）。
>
> **开发期（C/D）例外（2026-10-22 拍板）**：开发器没有第三方模组，每次迭代后旧存档 / 旧内容模型直接作废，
> 不要求跨迭代兼容；上表的 1.0 兼容列只描述已发布 MVP 的历史行为，不是 C/D 的门禁。

## 6. 测试与门禁

| 层 | 新增/更新 | 门禁 |
| --- | --- | --- |
| 框架 | `test_content_versions.gd`、`test_content_types_manifest.gd`（版本表一致性） | Godot 全套 |
| 内容 | v2 类型有效/无效样本、跨引用与完整性 | `sdk/validate.gd` |
| 编辑器 | 版本按类型统一、草案到 active 的分区与提示、导出侧约束（G8） | `run-tests.js` / `content-cli.test.mjs` |
| 生成物 | `gen_content_types.mjs` 版本表；`sync-schemas.mjs` 继续递归 | `--check` 两个门禁 |
| 存档 | 迁移矩阵、混合版本 header、世界不重排 | 存档回归用例 |
| 发布 | workflow 增加版本一致性检查 | `.github/workflows/release.yml` |

## 7. 风险与回滚

| 风险 | 影响 | 缓解 | 回滚点 |
| --- | --- | --- | --- |
| 与在途探索/海图工作冲突（最大） | `map_profile` 字段互相覆盖 | 先等探索 4.1 落定；B 阶段做字段映射 | 回退 Phase B 运行时，类型保留草案 |
| 第三方 1.0 模组失效 | 社区内容不可用 | **开发期不承诺兼容**（旧内容模型随合并作废）；发布前按 Phase E 重新评估双读 / 迁移工具 | 发布前决策 |
| Patch 跨版本错配 | 定义被错误修改 | D4 强校验：`patches` 2.0 envelope 不符由 `unsupported_schema` 拦截 | 单点回退 |
| 存档版本记录变化 | 旧档读回失败 | D3 惰性补齐 + 迁移矩阵；**C/D 开发期旧档直接作废** | 保留 `content_schema` 单值兼容 |
| 编辑器导出草案到游戏 | 玩家启动 Degraded | 已实现导出守卫（G8）：发布包部署禁用、ZIP/目录导出二次确认 | 编辑器单点回退 |

## 8. 可派发任务包（供 Agent Teams / 多人协作）

| 包 | 范围 | 依赖 | 规模 |
| --- | --- | --- | --- |
| WP1 | Phase A 框架侧（A1–A6） | 无（探索落定后即可） | 小 |
| WP2 | Phase A 编辑器/CLI 统一版本字段（A5 + G8） | WP1 的字段定义 | 小 |
| WP3 | Phase B1 类型提升 + B2 注册表/引用规则 | WP1 | 中 |
| WP4 | Phase B3 世界生成运行时 | WP3、B0 | 大 |
| WP5 | Phase B4 core v2 内容 + map_profile 迁移 | B4 字段映射 | 中 |
| WP6 | Phase B5 存档版本记录与迁移矩阵 | WP1、WP4 | 中 |
| WP7 | Phase C 实体合并（逐个） | Phase B 稳定 | 大 |
| WP8 | Phase D 系统切片 / Phase E 冻结 | 各系统 | 大 |

写作用域建议：WP1 只动 `content_types.json`、`tools/gen_content_types.mjs`、`framework/modding/`、`framework/tests/`；
WP2 只动 `SNModMaker/`；WP4 只动 `framework/domain/world|campaign` 与新注册表；避免同文件并发写。

## 9. 验收标准（Definition of Done）

- [x] Phase A：1.0 全量测试绿；版本表生成物最新；Patch 按目标类型版本校验（2026-10-21）。
- [x] Phase B · B0：探索 4.1 / Phase A 合入 main；契约刷新到 Draft 2；基线门禁全绿（2026-10-22）。
- [x] Phase B · B1：9 类 2.0 类型 active + `map_configs` Schema；编辑器 / CLI / 测试同步；生成物全绿（2026-10-22）。
- [x] Phase B · B2：9 类跨引用规则 + `ref_inactive_type`、Core Phase B 完整性（presence gate）、capability 白名单（2026-10-22）。
- [x] Phase B · B3：`CampaignFactory` 世界装配 + `run.start start_profile` + `campaign.view` + `ContentRefs` resolver 改造（2026-10-22）。
- [x] Phase B · B4：Core 9 个 v2 内容文件 + 本地化 + manifest capabilities（82 definitions，SDK `status: ok`）（2026-10-22）。
- [x] Phase B · B5：保存快照 `campaign.setup.content_versions`；旧档推断/补齐 + 漂移 warning；存档矩阵测试（2026-10-22）。
- [x] Phase B：v2 世界生成可开局；旧档可继续；编辑器/CLI/SDK 全链零 error；发布门禁通过（B6 收尾，2026-10-22）。
- [x] Phase C · C1：5 类模块 → `modules` 2.0、`hulls` 升 2.0；ModuleOps / 船厂分类 UI / 完整性按 category（2026-10-22）。
- [x] Phase C · C2：goods + materials → `items` 2.0（`crafting_material`）；全量引用 / 本地化 / 编辑器 / SDK example / 运行时统一（2026-10-22）。
- [x] Phase C · 开发期兼容：**不要求**旧 ID 别名与存档 ID 迁移；合并后直接删除旧类型 / 旧内容，旧档作废（2026-10-22 拍板）。
- [x] Phase C · C3：contracts / quests 解耦 + `quests` 2.0 + QuestService（已完成，2026-10-22）。
- [x] Phase C · C4：其余 1.0 定义类型 + `patches` 升 2.0；`map_profiles` 退役；删除 1.0 回退路径（2026-10-23）。
- [x] **Phase C 完成**：20 个 active 类型全部 2.0（0 个 1.0 runtime）；Godot 527/527、Node 58/58、CLI 63/63、SDK `status: ok`（2026-10-23）。
- [x] Phase D · D0：模拟时钟 / `sim.pause|resume|set_speed|advance` + `sim.view`，`data.sim` 固定 1h 步长（2026-10-23）。
- [x] Phase D · D1：combat 6 类 active 2.0 + Core 6 个战斗内容文件 + `CombatOps` / `CombatService` / `combat.resolve|view|log`（2026-10-23）。
- [x] **Phase D0/D1 完成快照**：26 个 active 类型全部 2.0（25 定义 + patch）；schema bundle 31（2 顶层 + 29 v2）、编辑器 28（26 runtime + 2 draft）；Godot **566/566**、Node **58/58**、CLI **63/63**、SDK `status: ok`（2026-10-23）。
- [x] Phase D · D2：fleet 4 类 active 2.0 + Core 4 个舰队内容文件 + `FleetOps` / `FleetService` / `fleet.*` 命令与 `fleet.view`；SDK `example_fleet`（2026-10-23）。
- [x] **Phase D0/D1/D2 完成快照**：30 个 active 类型全部 2.0（29 定义 + patch）；schema bundle 35（2 顶层 + 33 v2）、编辑器 32（30 runtime + 2 draft）、Core 29 内容文件 / 114 定义；Godot **578/578**、Node **59/59**、CLI **63/63**、SDK `status: ok`（2026-10-23）。
- [x] **D-AI schema 先行**：新增 draft `combat_ai_profiles`（FSM 节点/转移/条件，对齐 SNBattleSim FSM 契约；运行时不加载）；schema bundle 36（2 顶层 + 34 v2）、编辑器 33（30 runtime + 3 draft）、Node **60/60**、CLI **64/64**。
- [ ] Phase D 其余：base / auto_trade / ruins 系统类型与运行时切片。
- [ ] Phase E：1.0 生成停止；文档状态更新为 Finalized（开发期无迁移工具，发布前评估）。
- [ ] 全程：玩法数值不因迁移改变；存档世界布局不重排。

## 10. 决策记录

- 2026-10-22 全部按建议拍板：D1 按类型版本、D2 一个 minor 双读、D3 `campaign.setup.content_versions`、
  D4 Patch 版本强校验、D5 实体合并独立阶段、D6 七项提升门槛；Phase B 契约的 D7 新增 `map_configs`、
  D8 首个切片 ≤5 港、D9 planned 引用先 warning、D10 保留 1.0 `starting_builds`、D11 `run.start start_profile`、
  D12 `campaign.view` + 最小展示、D13 `story` 搬入 `map_configs.story`。
- Phase B 与世界探索运行时同一个发布版本（类型提升与运行时同版本）。
- 「编辑器禁止把草案内容部署到发布包」已作为 Phase A 的 G8 小修完成。
- 2026-10-22（C1/C2 期间）开发期策略：不做旧档 / 旧内容兼容，实体合并直接改 core 内容与 ID、删除旧类型；
  D2 的双读窗口不再适用于 C/D（发布前按 Phase E 重新评估）。
- 2026-10-22（C2 收尾）删除已无类型引用的 8 个 1.0 Schema（goods/material/boiler/cargo_module/
  navigation_module/safety_module/cabin/hull）；schema bundle 34 → 26（10 顶层 + 16 个 v2），C3 后为 27（10 顶层 + 17 个 v2）。
- 2026-10-23（C4 收尾）：port_templates / starting_scenarios / crew_roles / boiler_strategies / voyage_events 改名，
  contracts / patches 升 2.0，`map_profiles` 退役；删除全部 1.0 内容 Schema 与 1.0 回退路径；
  schema bundle **26（2 顶层 + 24 v2）**、编辑器 **23（20 runtime + 3 draft）**；Phase C 完成，下一步 Phase D/E。
- 2026-10-23（D0/D1）：先落确定性模拟时钟（`data.sim`、1h 固定步长、`sim.*` 命令与 `sim.view`），再把 `weapons` 与
  `damage_types` / `combat_abilities` / `enemy_archetypes` / `encounter_tables` / `loot_tables` 共 6 类提升 active；
  **26 active（25 定义 + patch）**、schema bundle **31（2 顶层 + 29 v2）**、编辑器 **28（26 runtime + 2 draft）**；
  Phase D 继续 fleet / base / auto_trade / ruins。
- 2026-10-23（D2）：新增 `ship_archetypes` / `captains` / `formations` / `fleet_doctrines` 四类 active 2.0（content.fleet.v1），
  落地 `FleetOps` / `FleetService` / `fleet.*` 命令与 `fleet.view`、`data.fleet` 惰性持久；
  **30 active（29 定义 + patch）**、schema bundle **35（2 顶层 + 33 v2）**、编辑器 **32（30 runtime + 2 draft）**、
  Core **29 文件 / 114 定义**；Phase D 继续 base / auto_trade / ruins。
