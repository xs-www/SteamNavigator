# Content Schema 2.0 迁移落地方案

> 状态：Draft 1（2026-10-21）。本文件是**执行方案**，不是已定稿契约；契约性规则见
> [ENTITY_CONTRACT_V2.md](ENTITY_CONTRACT_V2.md)，路线图见 [FULL_GAME_ROADMAP.md](FULL_GAME_ROADMAP.md)
> 阶段 0/1，近期计划见 [DEV_PLAN_2026-10.md](DEV_PLAN_2026-10.md) §4.4。
>
> **结论先行**：不做「15 类内容一次性 bump 到 2.0」的全量升级；改为
> **按内容类型版本化 → 世界探索家族提升 → 实体合并 → 其余系统 → 冻结 1.0** 的分层统一。

## 1. 版本轴与术语

| 版本轴 | 当前值 | 状态 |
| --- | --- | --- |
| Framework | 0.2.0-dev 系列（`FrameworkInfo.VERSION`） | 随发布走 |
| Mod API | `1.0` | 未动 |
| **Content Schema** | **`1.0`** | 运行时主干仍是 1.0；2.0 只有草案 + 编辑器支持 |
| Save Schema | `2.0` | 已完成（含 1.x → 2.0 迁移） |
| State Schema | `2.0` | 已完成（`GameState.SCHEMA_VERSION`） |

本文只处理 **Content Schema**；Save / State 已是 2.0，不要在迁移中混用这两条轴。

## 2. 现状基线（2026-10-21 快照）

### 2.1 游戏运行时（唯一真正限制 2.0 的地方）

- [framework_info.gd](../../framework/core/framework_info.gd) 的 `CONTENT_SCHEMA := "1.0"` 是**全局单值门禁**。
- [content_compiler.gd](../../framework/modding/content_compiler.gd) 对每个内容文件只做一次比较：
  `envelope.schema_version != FrameworkInfo.CONTENT_SCHEMA` → `unsupported_schema`，**不按类型区分版本**，
  也没有“2.0 类型”的入口。核心模组该错误为 `fatal`，第三方模组为 `error`（启动报告 `Degraded`、内容被丢弃）。
- `ContentTypes`（生成物 [content_types.gd](../../framework/modding/content_types.gd)）只有 `SCHEMA_PATHS`，
  16 个类型全部指向 `schemas/*.schema.json`（1.0），**没有版本表**。
- Patch 再校验 `_validate_definition()` 的 envelope 同样写死 1.0。
- 世界生成仍读 1.0 `map_profiles`；正在并行落地的探索系统 4.1 直接扩展 1.0 `map_profile`（新增
  `exploration` 块，见 [EXPLORATION_SYSTEM.md](EXPLORATION_SYSTEM.md)），说明当前主线仍是“在 1.0 上迭代”。

### 2.2 内容 Schema 与草案

- active 16 类（15 个定义类型 + `patches`）全部 1.0。
- 2.0 草案 8 类 + `schemas/v2/common.schema.json`，登记在 `content_types.json` 的
  `draft_schemas` / `draft_types`，仅编辑器（SNModMaker）与 Content CLI 可编辑。
- v2 草案覆盖：`world_profiles / regions / sites / route_templates / weather_profiles / factions /
  discoveries / start_profiles`。
- v2 **不覆盖**任何现有 1.0 类型：goods / materials / hulls / boilers / cargo_modules /
  navigation_modules / safety_modules / cabins / roles / strategies / port_archetypes /
  map_profiles / starting_builds / contracts / events。想要“全量 2.0”必须先补这 15 套 Schema。

### 2.3 存档

- Save / State Schema 2.0 已上线，`save_migrations.gd` 负责 1.x → 2.0。
- `campaign.world / codex / factions` 分区与 clues 惰性块已建（只存 ID 与进度，不存定义）。
- 存档 header 的 `content_schema` 目前**直接写 `FrameworkInfo.CONTENT_SCHEMA`（恒为 1.0）**；
  一旦运行时出现 2.0 类型，这个单值字段无法表达“这次存档用了哪些版本的哪些类型”。

### 2.4 编辑器 / CLI / SDK / 门禁

- 编辑器已双版本就绪：`SNContentTypes.TYPES`（16）+ `DRAFT_TYPES`（8）；schema bundle 27 个
  （18 顶层 + 9 个 v2）；校验器有 `schemaVersionFor` 与
  `schema_version_mismatch` / `schema_version_unsupported` / `draft_content` / `capability_undeclared`。
- Content CLI 同步支持草案；`types` 分两组输出。
- SDK `sdk/validate.gd` 走真实 `Bootstrap`，因此**同样受全局 1.0 门禁**；发布 workflow 已含
  Godot 测试、`gen_content_types --check`、`gen_static_docs --check` 与 core 校验。
- 已知 UX 缺口：编辑器允许把含 2.0 草案的模组导出/部署到游戏 `mods/`，游戏启动只会
  `Degraded` 并丢弃该内容，导出侧没有阻止或二次确认。

### 2.5 差距清单

| 编号 | 差距 | 影响 |
| --- | --- | --- |
| G1 | `CONTENT_SCHEMA` 全局单值门禁 | 任何 2.0 类型都无法加载，无法按类型渐进 |
| G2 | 生成物没有“类型 → 期望版本”表 | 编辑器/CLI/框架三处只能靠特例推断 |
| G3 | 8 类草案未 active | 无注册表、无引用规则、无 Core 完整性规则、无默认内容文件 |
| G4 | 无 v2 世界生成运行时 | 草案没有读者，即使提升 active 也不生效 |
| G5 | Core 没有 v2 世界内容 | 3.0 类型没有官方数据可用 |
| G6 | Patch 版本语义未定义 | 跨版本补丁没有规则，容易静默错配 |
| G7 | 存档 `content_schema` 单值 | 混合版本存档无法表达实际加载集合 |
| G8 | 编辑器导出侧缺约束 | 草案内容可直接部署，玩家得到 Degraded 启动（**已修复**：含草案内容的项目禁用发布包部署，ZIP/目录导出二次确认） |

## 3. 迁移策略与决策

### 3.1 为什么不“一次性全量升级”

| 方案 | 需要做的事 | 代价 / 风险 | 结论 |
| --- | --- | --- | --- |
| A. 全量 bump：15 类内容一次性变 2.0 | 补写 15 套 v2 Schema（当前只有 8 类世界/战役草案）+ 迁移全部 core 内容 + 改编译器/注册表/补丁/交叉校验 + 第三方 1.0 模组全部失效（或维护双读） | 玩法零变化、回归面最大；与在途探索/海图工作直接冲突 | ❌ 不推荐 |
| B. 分层统一：按类型版本 + 纵向切片 | 先让编译器支持“每个类型自己的版本”，再逐家族提升 | 每阶段可发布、可回滚；编辑器已提前就绪 | ✅ 推荐 |

### 3.2 决策清单（需确认）

| 编号 | 决策 | 建议 |
| --- | --- | --- |
| D1 | 版本粒度 | **按内容类型声明版本**（active 1.0、v2 类型 2.0），保留一个基线常量只用于编辑器默认与提示 |
| D2 | 1.0 兼容窗口 | v2 运行时上线后，**保留一个 minor 版本周期**的双读；窗口结束只读兼容 + 迁移工具 |
| D3 | 存档内容版本记录 | `content_schema` 保留为基线；新增 `content_versions`（类型 → 版本）惰性补齐，加载时按实际注册表推导 |
| D4 | Patch 版本 | Patch 的 `schema_version` 必须等于**目标类型**版本；不符报 `patch_schema_mismatch`，不做隐式转换 |
| D5 | 实体合并时机 | 独立于世界探索家族，单独一个阶段（Module → Item → Quest），必须带 ID 别名与迁移器 |
| D6 | planned → active 门槛 | ①运行时读者 ②注册表与引用规则 ③Core 完整性规则 ④core 内容 ⑤编辑器/CLI ⑥测试 ⑦文档；缺一不提升 |

### 3.3 与在途工作的顺序约束

1. 先让**探索系统 4.1 落定并提交**（它正在扩 1.0 `map_profile`）。
2. 再做 Phase A（不动玩法、不动内容）。
3. Phase B 启动时把 `map_profile.exploration` 的参数迁入 v2 `map_config`
   （`content_types.json` 的 `v2_target` 已提示 `map_profiles → map_config`），
   或在过渡窗口内让 v2 世界生成同时读 1.0 `map_profiles`，避免探索功能返工。

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
并由真实运行时消费；1.0 老链路与旧档保持可用。

| 任务 | 范围 | 说明 |
| --- | --- | --- |
| B0 | 前置 | 探索 4.1 提交；`schema-v2` rebase `main`；冻结其 1.0 `map_profile` 字段，后续只做迁移映射 |
| B1 | 类型提升 | ✅ 已完成（2026-10-22）：8 类从 `planned` 移入 `types` + 新增 `map_configs`；删除对应 `draft_types` / `draft_schemas` 条目、清理 `planned`；新增 `schemas/v2/map_config.schema.json` 并微调 `world_profiles`/`start_profiles` |
| B2 | 注册表与引用 | ✅ 已完成（2026-10-22）：`RegistryHub` 按 `ContentTypes.all()` 自动生效；`CrossReferenceValidator` 增加 9 个 `_check_*` 与 `ref_inactive_type` 规则（目标激活后自动升级硬校验）；`CoreCompletenessChecker` 增加 Phase B 规则（Core presence gate）；`FrameworkInfo.CAPABILITIES` 增加 `content.world.v1` / `content.campaign.v1` |
| B3 | 世界生成运行时 | ✅ 已完成（2026-10-22）：新 `CampaignFactory` 消费 `start_profiles → world_profiles + map_configs + regions/sites/route_templates/weather/factions/discoveries`；复用 `MapGenerator` 几何 + 孪生 `world_map`；`campaign.world / codex / factions` 接线；`run.start` 增加可选 `start_profile`，新增 `campaign.view` 查询；`ContentRefs` 统一 12 处 resolver |
| B4 | core 内容 | ✅ 已完成（2026-10-22）：`dev_mods/core/content/` 新增 9 个 v2 内容文件 + 本地化（各 +62 键）；`map_profiles.exploration` 31 键与 `story` 原样迁入 `map_configs` |
| B5 | 存档 | ✅ 已完成（2026-10-22）：新档由 `prepare_for_save()` 写 `campaign.setup.content_versions`；旧档推断 `starting_builds/map_profiles → 1.0` 并用注册表补齐；版本漂移只 warning、不重排世界 |
| B6 | 编辑器 / CLI / SDK | ✅ 已完成（2026-10-22）：草案分区只剩 `weapons`；`capability_undeclared` 按 schemaVersion=2.0 判定并按 capability 去重；G8 改为“运行时不支持”（草案/未知类型/版本不符拦截，提升类型可部署）；CLI 标 runtime 2.0、`new --draft` 仅 weapons；release workflow 加入 Node 两套件 |

验收：v2 世界生成可开局；旧档可继续；1.0 模组在双读窗口内仍可加载；seed 回归（现有 seed + 新 v2 seed）；
编辑器/CLI/SDK 全链零 error；`gen_content_types --check`、`gen_static_docs --check`。
回滚：B 阶段独立分支；若 v2 世界生成不达预期，保留类型草案状态、回退运行时，不影响 1.0。

### Phase C · 实体合并（Module / Item / Quest，1–2 周）

| 顺序 | 合并 | 迁移方式 |
| --- | --- | --- |
| C1 | 6 类模块 → `module` + `v2_category`（`boiler/cargo/utility/cabin/crew`） | 保留旧内容类型与 ID 别名一个版本；导航/安全归入 `utility` |
| C2 | goods + materials → `item`（`crafting_material` 标志） | ID 别名（`core:good/x` ↔ `core:item/x`）+ 本地化键迁移 |
| C3 | contracts → `quest`（生成器字段分离） | 别名 + 存档 ID 迁移 |

### Phase D · 其余系统类型（逐系统）

fleet / combat / base / auto_trade / ruins 每个系统按同一模板走：
Schema 草案 → `planned` 登记 → 达到 D6 门槛 → 提升 active → 运行时纵向切片 → 存档分区 → 编辑器/CLI/文档。

### Phase E · 冻结 1.0（1 周）

- 停止生成 1.0 内容；双读窗口结束，遇到 1.0 内容给出明确迁移错误。
- 提供 `sdk/migrate_content.gd`（或 CLI）把 1.0 模组迁移到 2.0。
- 发布门禁要求 Content Schema 2.0；更新 `README`、`CHANGELOG`、`ENTITY_CONTRACT_V2` 状态为 Finalized。

## 5. 兼容性矩阵（目标态）

| 场景 | Phase A | Phase B | Phase E |
| --- | --- | --- | --- |
| 1.0 内容模组 | 正常加载 | 正常加载（双读窗口） | 拒绝 + 迁移指引 |
| 2.0 世界探索内容 | 仍不可加载 | 正常加载 | 正常加载 |
| 混合版本模组（1.0 + 2.0 类型） | 允许编辑器编辑 | 允许（按类型校验） | 要求全 2.0 |
| 1.x 旧存档 | 正常 | 正常（惰性补齐） | 正常（迁移矩阵覆盖） |
| v2 世界存档读入 1.0 运行时 | 不适用 | 拒绝并保留只读提示 | — |

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
| 第三方 1.0 模组失效 | 社区内容不可用 | 一个 minor 版本双读 + 明确 warning + 迁移工具 | 双读开关 |
| Patch 跨版本错配 | 定义被错误修改 | D4 强校验 + `patch_schema_mismatch` | 单点回退 |
| 存档版本记录变化 | 旧档读回失败 | D3 惰性补齐 + 迁移矩阵 | 保留 `content_schema` 单值兼容 |
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
- [ ] Phase C：实体合并后旧 ID 别名可用一个版本；存档 ID 迁移可回读。
- [ ] Phase E：1.0 生成停止；迁移工具可用；文档状态更新为 Finalized。
- [ ] 全程：玩法数值不因迁移改变；存档世界布局不重排。

## 10. 决策记录

- 2026-10-22 全部按建议拍板：D1 按类型版本、D2 一个 minor 双读、D3 `campaign.setup.content_versions`、
  D4 Patch 版本强校验、D5 实体合并独立阶段、D6 七项提升门槛；Phase B 契约的 D7 新增 `map_configs`、
  D8 首个切片 ≤5 港、D9 planned 引用先 warning、D10 保留 1.0 `starting_builds`、D11 `run.start start_profile`、
  D12 `campaign.view` + 最小展示、D13 `story` 搬入 `map_configs.story`。
- Phase B 与世界探索运行时同一个发布版本（类型提升与运行时同版本）。
- 「编辑器禁止把草案内容部署到发布包」已作为 Phase A 的 G8 小修完成。
