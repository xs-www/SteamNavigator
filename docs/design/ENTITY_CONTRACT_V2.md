# Steam Navigator 实体契约 v2

> 状态：Draft 3（2026-10-23，Phase A/B 与 C1/C2/C3 落地后刷新）
> 适用范围：Schema 2.0、Content Types 单一真源、注册表、跨引用校验、发布门禁与 SNModMaker
> 运行时已按类型版本加载：当前 21 个 active 类型中 13 类为 Content Schema 2.0、8 类为 1.0（含 `patches`）；
> 本文描述 v2 契约与迁移边界。

## 1. 与草案的关系

`Steam_Navigator_Mod_Entity_Constraints_Spec.md`（Draft 0.1）是目标架构参考。本文采用它的原则、通用实体契约、注册顺序、错误分级、编辑器分工与验收标准，但不直接采用：

- 把 6 种模块合并为 `Module`、把 goods/materials 合并为 `Item` 的**实体合并方案**：已分别由 C1 / C2 落地（`modules` / `items` 2.0）；Quest 由 C3 独立落地为 `quests` 2.0（不合并进 Contract）。
- 草案中的伪 Schema 关键字（`min`、`max`、`min_length`、`unique_by`、`reference`、`rules`）：改为当前校验器支持的 JSON Schema 子集 + 框架侧引用/规则校验。
- 草案缺少的本地化键、资源键、Patch 与 capability 规则：在本契约中补齐。
- `roles` 不并入模块；`strategies` 暂保留独立内容类型；`starting_builds` 是玩家开局配置，不是世界建筑布局。
- 导航/安全这类添头模块在 v2 统一归入 `utility` 类别，不再单独设内容类型或编辑器分组。

## 2. 设计原则

1. 实体定义是静态数据，运行态只保存 ID 与原始数值。
2. Schema 声明结构、枚举与范围；跨实体引用、唯一性、组合规则由框架校验器负责，不塞进 Schema 关键字。
3. 所有内容类型先在 `content_types.json` 登记；没有登记的类型不能进入 core 或发布。
4. 官方内容与第三方内容走同一注册、校验和冻结流程。
5. 不允许隐式覆盖、任意脚本或未知字段静默降级。
6. 发布门禁只区分 `error`（阻止）与 `warning` / `info`（可见但不阻止）。
7. 持久战役存档只追加兼容内容；世界布局与已生成实例不在旧档中重排。

## 3. 内容文件外壳

每个内容文件：

```json
{
  "schema_version": "2.0",
  "content_type": "items",
  "definitions": []
}
```

- `schema_version`：该类型的期望 Content Schema 版本（由 `content_types.json.types[].schema_version` 声明）；
  1.0 类型仍是 `"1.0"`，2.0 类型是 `"2.0"`，由 `ContentCompiler` 按类型校验。
- `content_type`：必须是 `content_types.json` 中 `status=active` 的 `key`。
- `definitions`：同类型定义数组；补丁文件使用 `patches`，见 §9。

## 4. 定义实体通用结构

```json
{
  "id": "core:item/timber",
  "name_key": "item.core.timber.name",
  "description_key": "item.core.timber.description",
  "tags": ["good.trade", "good.shipbuilding"],
  "enabled": true,
  "data": {},
  "information": {}
}
```

| 字段 | 约束 |
| --- | --- |
| `id` | 必填、全局唯一；`<mod_id>:<singular>/<local_id>`；类型段必须与所属内容类型的 `singular` 一致 |
| `name_key` | 必填；本地化键；缺失或空值报错 |
| `description_key` | 可选；若存在必须是非空本地化键 |
| `tags` | 可选；字符串数组，同一实体内不重复 |
| `enabled` | 必填布尔；禁用定义不得被启用定义引用 |
| `data` | 必填对象；参与模拟的权威数据 |
| `information` | 可选对象；展示/设计资料；`texture`/`model` 为资源键，不得作为模拟权威值 |

### 4.1 本地化

- 每条定义至少要在 Mod 声明的一个语言文件中存在 `name_key`。
- 缺失翻译：`warning`；`name_key` 为空或格式非法：`error`。
- 修改定义 ID 必须同步迁移 `name_key`/`description_key` 及多语言条目；编辑器负责预览与原子提交。

### 4.2 资源键

- `information.texture` / `information.model` 使用 Mod 内资源键，解析为 `asset://<mod_id>/<key>`。
- 资源必须在 `manifest.assets` 中声明且文件存在；扩展名与类型必须匹配（图片 / GLB）。
- 资源缺失或非法：`error`；资源存在但无法导入 Godot：发布门禁 `error`。

## 5. ID 与命名空间

```text
<namespace>:<entity_type>/<entity_id>
```

- `namespace` 必须等于 Mod ID；第三方不得写入其他 Mod 命名空间。
- `entity_type` 必须等于内容类型的 `singular`；补丁除外。
- `entity_id`：小写字母开头，允许 `a-z 0-9 _`，长度按 Schema；不允许空格、大写、路径穿越。
- 同一注册表内 ID 唯一；跨内容类型允许同名 local ID，但本地化键前缀要按编辑器规则保持稳定。
- 删除已发布 ID：正式发布版至少保留一个大版本周期的迁移别名（`aliases` 字段预留）；**开发期（C/D）例外**：
  开发器没有第三方模组与旧档负担，实体合并直接改 core ID、不保留别名 / 迁移器（2026-10-22 拍板）。

## 6. Schema 语言（v2 基线）

Schema 文件只使用当前 `SchemaValidator` 支持的 JSON Schema 子集：

- 结构：`type`、`properties`、`required`、`additionalProperties`、`patternProperties`、`items`、`prefixItems`
- 组合：`allOf`、`anyOf`、`oneOf`、`not`、`$ref`（本地引用）
- 值：`const`、`enum`、`pattern`、`minLength`、`maxLength`
- 数值：`minimum`、`maximum`、`exclusiveMinimum`、`exclusiveMaximum`
- 数组/对象：`minItems`、`maxItems`、`uniqueItems`、`minProperties`、`maxProperties`

不进入 Schema 的规则：

- `reference`：由 `CrossReferenceValidator` 按字段声明校验。
- 组合容量、部位兼容、装配前置条件：由对应系统的领域校验器负责。
- 跨文件唯一性、ID 命名空间、本地化覆盖：由 Content Compiler 负责。
- 未知字段：由 `additionalProperties: false` 报错；确需模组扩展时只允许明确命名的 `extensions` 对象。

## 7. Content Types 单一真源

[content_types.json](../../content_types.json) 是内容类型注册表，包含：

- `key`、`singular`、`key_prefix`
- `label_zh` / `label_en` / `abbr` / `color` / `group`
- `schema`（仓库相对路径）、`default_file`
- `kind`：`definition` / `patch`
- `registry`：是否进入 Definition Registry
- `capability`：预留的类型能力标识，Mod API 2.0 起用于能力声明
- `v2_target`：目标合并/改名类型（**迁移提示，不是当前实现**）
- `aliases`：未来迁移别名
- `planned`：后续系统类型，只有名称与 capability，尚无 Schema，禁止加载

迁移期约束：

- 框架 `ContentTypes`、编辑器 `catalog.js`、Schema bundle 与 SDK 校验在过渡期都必须与 `content_types.json` 一致；Godot 测试会校验 key / singular / schema 路径 / patch 类型。
- 后续版本由生成器从 `content_types.json` 生成上述清单，删除手工副本。
- 新增类型必须同时提供 Schema、编辑器默认文件、跨引用规则、测试与静态文档。

### 7.1 v2 模块分类

v2 的船舶模块不再按“导航 / 安全 / 其他小功能”拆成多个内容类型，而是统一为 `Module` 的几个类别：

| 类别 | 包含 | 说明 |
| --- | --- | --- |
| `boiler` | 锅炉 | 航速与煤水核心模块 |
| `cargo` | 货舱 | 容量模块 |
| `utility` | 导航、安全、后续小功能 | 添头模块；用 `utility_kind` 或专用能力字段区分导航加成、风险降低等 |
| `cabin` | 客舱 | 载客容量 |
| `crew` | 船员居住 | 居住/岗位相关 |

约束：

- 不为 `navigation` / `safety` 单独建内容类型或编辑器分组；编辑器只显示一个「杂项功能」类别。
- 类别内的差异由 `utility_kind`（或明确的 capability 字段）表达，校验由该类别规则负责。
- C1 已落地：5 个旧模块类型（boilers / cargo_modules / navigation_modules / safety_modules / cabins）已删除，
  统一为 2.0 `modules`；`data.v2_category` ∈ `boiler/cargo/utility/cabin`（`crew` 预留），
  utility 槽位由 `module.navigation` / `module.safety` 标签路由。
- `content_types.json` 的 `v2_module_categories` 记录该分类；`modules` 是当前唯一可加载的模块类型。

### 7.2 Schema 2.0 运行时类型与草案（已落地）

当前 13 类运行时类型使用 `schemas/v2/`：

| 来源 | 类型 | Schema |
| --- | --- | --- |
| Phase B | `world_profiles` / `map_configs` / `regions` / `sites` / `route_templates` / `weather_profiles` / `factions` / `discoveries` / `start_profiles` | 同名 `v2/*.schema.json` |
| C1 | `hulls`（类型与 ID 不变） / `modules`（5 类模块合并） | `v2/hull.schema.json` / `v2/module.schema.json` |
| C2 | `items`（goods + materials 合并，`data.crafting_material` 标志） | `v2/item.schema.json` |
| C3 | `quests`（抽象引导目标链，不复制 contract 的 payload / 目的地 / 结算） | `v2/quest.schema.json` |

- `schemas/v2/common.schema.json`：2.0 通用定义、ID、标签、资源信息与 cargo stack。
- `hulls` 的 `hull_data` 内联原 `module_common` 字段（tier / weight / purchase_price / craft_* / materials /
  modifiers）并保留 `size_tag`、`weapon_sockets` / `rig_sockets` 镜像与 `rig_plan`。
- `modules` 用 `v2_category` + 字段超集；项目 SchemaValidator 不支持 if/then，category 专属必填由语义校验器
  （`ModuleOps` / 跨引用 / 完整性）负责。
- 3 类草案（`draft_schemas` / `draft_types`，仅编辑器与 Content CLI 可编辑，运行时暂不加载）：
  - `v2/weapon.schema.json`（`weapons`）：战斗字段对齐 SNBattleSim、装配字段对齐 `weapon-assembly@2`、经济字段
    对齐 `module_common`；契约见 [WEAPON_CONTENT_SCHEMA.md](WEAPON_CONTENT_SCHEMA.md)。
  - `v2/story_arc.schema.json` / `v2/story_level.schema.json`（`story_arcs` / `story_levels`）：剧情模式 S1
    数据契约；契约见 [STORY_MODE.md](STORY_MODE.md)。
- `content_types.json.types[]` 为每个 active 类型声明 `schema` 与 `schema_version`；草案在
  `draft_schemas` / `draft_types` 登记，各自带 `schema_version: "2.0"` 与 capability。
- `schema-bundle.js` 递归收录 `schemas/` 共 **27 个**文件（10 个顶层 + 17 个 `v2/`：`v2/common`、
  13 类运行时 2.0、`weapon` 与剧情 2 个草案）；校验器按基准文件所在目录解析 `common.schema.json` 等
  跨文件 `$ref`。
- 版本与告警：`Validate.schemaVersionFor` 按类型推导期望版本；声明版本与类型不符报
  `schema_version_mismatch`，非 1.0 / 2.0 报 `schema_version_unsupported`；草案内容给 `draft_content` 警告；
  使用 capability 但未写入 `manifest.capabilities` 时给 `capability_undeclared` 警告（同一 capability 一条）。
- 编辑器与 CLI 对 13 类运行时 2.0 正常编辑 / 校验 / 导出，对 3 类草案标 draft（含它的项目不能部署到发布包）。
- 剩余 1.0 定义类型（Phase C4）：`roles / strategies / port_archetypes / map_profiles / starting_builds /
  contracts / events`（+ `patches`）。
- 测试：`test_schema_v2_drafts.gd`（Phase B 9 类 + `map_configs`）、`test_schema_v2_weapons.gd`
  （`weapons` 与 hull socket 镜像）、`test_item_categories.gd`（C2 items）、`test_quest_service.gd`
  （C3 quests / 委托追踪实例）、`test_content_versions.gd`（按类型版本与生成物一致性）。

## 8. 定义、生成与运行态

| 类别 | 存放 | 规则 |
| --- | --- | --- |
| 定义 | 模组 JSON / 冻结注册表 | 不可变；不写运行态 |
| 生成参数 | Map/World/Start 配置定义 | 只参数化算法，不包含已生成实例 |
| 运行态 | 战役存档 | 只存 ID、数值、队列、位置、状态；可哈希、可迁移 |

持久战役中，世界布局、遗迹房间、遭遇实例在开局或首次进入时生成并写入存档；内容更新不得改变已生成结果。

船舶模块实例（[SHIP_MODULE_INSTANCES.md](../specs/SHIP_MODULE_INSTANCES.md)）属于「运行态」：`ship.module_instances` 只存 `instance_id` 与 `condition`，已安装的定义 ID 仍由扁平槽位键表达；实例表由 `ShipModules.ensure()` 与扁平键对齐，随存档持久化。模块 condition 暂不进入派生属性计算，战斗阶段再接入。

## 9. 显式 Patch

- 补丁文件使用 `content_type: "patches"`，每项声明 `target`、`source_version`、操作列表。
- 目标必须存在且启用；同一目标路径冲突必须报错，不按加载顺序决定胜负。
- Patch 只修改数据，不执行代码；不支持新增内容类型或绕过 Schema。
- 补丁后的定义仍要经过 Schema、跨引用与完整性校验。

## 10. 跨引用与组合校验

- 引用使用完整 ID；禁止用名称、显示文本或数组位置引用。
- 硬引用：目标必须存在且启用；缺失为 `error`。
- 可选引用：目标存在时校验，缺失时保留 null/空值，不报错。
- 标签引用：按标签查询候选，定义必须声明允许的标签空间；不得依赖未声明标签。
- 跨 Mod 引用：引用方必须声明依赖或走框架公共依赖；未声明依赖的跨 Mod 硬引用为 `error`。
- 循环依赖：Mod 依赖与前置条件按类型规则检测；普通双向引用不自动视为循环。
- 组合校验示例（v2 船舶模型）：部位类型已注册、模块类别兼容、部位容量总和、单部位/整船数量上限、装配前置条件。实现前需先完成 Hull/Compartment/Module 迁移。

## 11. 条件与效果

- 条件/效果是框架注册的**操作码**，不是模组字符串或脚本。
- 每个操作码必须同时提供：参数 Schema、纯函数执行器、允许的上下文作用域、错误码与单元测试。
- 事件、委托、战斗、遗迹、自动贸易共用同一套操作码；新增系统扩展操作码而不是自造 DSL。
- 未注册操作码、参数不合法、引用无法解析：`error`。
- 嵌套表达式限制递归深度并检测循环。

## 12. 注册与加载顺序

与现有启动链对齐：

```text
scan → manifest / dependency resolve → schema compile
→ duplicate ID / namespace → cross-reference → core completeness
→ freeze registries → FrameworkApi
```

要求：

- 先完成类型注册（含未来部位类型、模块类别、操作码）再校验实体引用。
- 所有校验在临时注册表上完成；通过后才冻结。
- 冻结后定义不可变；启用/禁用模组必须重新加载。

## 13. 错误模型与发布门禁

```json
{
  "code": "REF-001",
  "severity": "error",
  "entity_id": "core:contract/main_01",
  "path": "data.rewards.unlock_ids[0]",
  "message": "Referenced definition does not exist.",
  "related_entities": ["core:hull/medium_standard"]
}
```

- 级别：`error` 阻止发布/加载；`warning`、`info` 仅提示。
- 错误码按领域稳定：`ENT-*` 实体、`REF-*` 引用、`HCM-*`  Hull/模块组合、`MAP-*` 世界、`QST-*` 委托、`EVT-*` 事件、`ASSET-*` 资源、`LOC-*` 本地化、`API-*` 版本/能力。
- 未知字段、未知类型、未知操作码不得静默降级。
- 编辑器与 `sdk/validate.gd` 使用同一语义规则；编辑期可保存草稿，正式导出必须零 `error`。

## 14. 版本与能力

| 版本 | 作用 |
| --- | --- |
| Framework | 可执行程序与领域算法 |
| Mod API | Manifest、Schema、命令、事件与 DSL 契约 |
| Content Schema | 单类 JSON 数据格式 |
| Save Schema | 战役存档结构 |

- Content Schema 主版本变化在**发布版**必须提供迁移器与旧档只读兼容；**开发期（C/D）例外**：不保留旧档 / 旧内容
  兼容，实体合并后旧档直接作废（2026-10-22 拍板，详见迁移方案 §3.2 D2/D5）。
- **内容版本按类型声明**：`content_types.json.types[].schema_version` 是每个类型的期望版本，生成 `ContentTypes.SCHEMA_VERSIONS`；`ContentCompiler` 按 `content_type` 取期望版本校验 envelope（Patch 再校验同样按目标类型版本），`FrameworkInfo.CONTENT_SCHEMA` 只作为基线/默认（存档 header 与编辑器默认）。当前状态：13 类运行时类型为 `2.0`（Phase B 9 类 + C1 `hulls`/`modules` + C2 `items` + C3 `quests`），8 类（含 `patches`）仍为 `1.0`。
- 新系统通过 capability 暴露（`content.world.v1`、`content.modules.v1`、`content.items.v1`、`content.quests.v1`、`content.combat.v1`…）；模组使用新能力必须声明。
- `v2_target` 只用于规划剩余迁移（`port_template` / `starting_scenario` / `voyage_event` 等），不代表当前可加载类型；已完成的 `map_profile → map_config`、模块合并、Item 合并与 Quest 解耦已从迁移提示转为实际类型。

## 15. 编辑器契约

- 通用实体编辑：元数据、Schema 表单、枚举/数值、引用选择、ID 唯一性、未知字段、路径定位。
- 专用视图：装配、世界/区域、起始场景、委托、事件、战斗遭遇、生产链、遗迹房间；只编辑数据。
- 编辑器不能实现独立校验规则；必须与运行时/SDK 共用同一规则来源。
- Schema 2.0 运行时类型：13 类已按 v2 Schema 正常编辑 / 校验 / 导出并部署；3 类草案（`weapons` / `story_arcs` /
  `story_levels`）在侧栏「Schema 2.0 草案 / 运行时不加载」分区标 draft，内容文件按类型写
  `schema_version: "2.0"`，运行时暂不加载。
- 草案与能力：内容使用 capability 但未写入 `manifest.capabilities` 时「校验」面板给出
  `capability_undeclared` 警告（按 `schemaVersion = 2.0` 判定）；声明后消除。G8 导出守卫按
  “当前运行时不支持”判定：草案 / 未注册类型 / 版本不符拦截，运行时 2.0 类型可部署。
- 导出前：静态校验零 `error`，并调用 `sdk/validate.gd` 做真实加载校验。
- 每次 Schema / `content_types.json` 变更后重新生成编辑器 bundle，并在 CI 检查是否过期。

## 16. 迁移阶段

1. **冻结 1.0**：✅ 已落地（盘点 + 基线测试）。
2. **单一真源**：✅ 已落地（`content_types.json` 接入框架测试、编辑器与 SDK）。
3. **存档与 Schema 2.0**：✅ 已落地（Save/State 2.0、`content_versions`；旧档兼容在开发期不承诺）。
4. **新系统类型**：Phase B 世界/战役 9 类 ✅；Phase D 的舰队、战斗、基地、自动贸易、遗迹仍为 planned。
5. **实体合并**：C1 `modules`/`hulls` + C2 `items` + C3 `quests`（与 `contracts` 解耦）✅；Phase C4 待开工。开发期直接改 core ID，
   **不做 ID 别名 / 内容迁移器**。
6. **清理**：✅ 已开始（C1/C2 删除旧类型与旧内容，2026-10-22 删除 8 个死 1.0 Schema）；Phase E 冻结 1.0 读路径。

阶段 3–6 的可执行切片、文件触点、兼容性矩阵与验收见
[CONTENT_SCHEMA_V2_MIGRATION.md](CONTENT_SCHEMA_V2_MIGRATION.md)。

## 17. 验收标准

- [x] `content_types.json` 与框架、编辑器、SDK 一致，测试守护。
- [x] 所有实体 ID 合法、唯一，引用可解析。
- [x] 未知字段、未知类型、未知操作码均产生明确 `error`。
- [ ] 编辑器与发布门禁使用同一套语义校验（编辑器静态校验 + SDK 运行时校验已就位，语义合并随 Phase B6/C 收尾）。
- [ ] 旧 MVP 存档迁移后可继续；新战役可创建、保存、读回。**开发期例外**：每次内容模型迭代后旧档作废，
  只要求新战役可创建、保存、读回。
- [x] 第三方模组可注册新内容类型内的数据，但不能覆盖已有 ID 或绕过校验。
- [x] 发布产物零 `error`；`warning` 可见。
- [ ] Core 内容迁移后无玩法回归（C1/C2 全量回归已绿；以 Phase E 发布门禁再次验证）。

## 18. 待决策

- ~~Item（goods/materials）合并时机~~：已由 C2 落地（`items` 2.0，`data.crafting_material`）。
- ~~Module（六类模块）合并~~：已由 C1 落地（`modules` 2.0 + `v2_category`；`hulls` 独立升 2.0）；
  Compartment 模型何时进入舰队阶段仍待定。
- ~~C3 `quests` 2.0 字段范围与 QuestService 持久化时机~~：已由 C3 落地（`data.quests` 惰性 ensure；
  quest 实例只存 `quest_id / stage_index / counters / flags / contract_instance_id`）。
- 奖励 / effects 系统（Quest 完成发奖、`spawn_contract` 等）暂缓，待 C4/后续切片决定数据形状。
- Phase C4 剩余 1.0 类型的提升顺序与命名（`port_templates` / `starting_scenarios` / `voyage_events` 等）。
- `strategies` 是否保留独立类型，或并入 Module 配置。
- 持久战役的 tick 粒度、失败恢复与离线模拟边界。
