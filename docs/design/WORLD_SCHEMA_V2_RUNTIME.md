# 世界与战役内容 Schema 2.0 实现契约（Phase B）

> 状态：Draft 2（2026-10-22，B0 收尾后刷新；B1 已落地）。本文件是 **Content Schema 2.0 迁移 Phase B 的执行契约**，不是已定稿 specs；
> 总方案见 [CONTENT_SCHEMA_V2_MIGRATION.md](CONTENT_SCHEMA_V2_MIGRATION.md) §4 Phase B，实体契约见
> [ENTITY_CONTRACT_V2.md](ENTITY_CONTRACT_V2.md)；探索规则见 `EXPLORATION_SYSTEM.md`，教程剧情见
> [STORY_TUTORIAL.md](STORY_TUTORIAL.md)。
>
> 前置条件（**B0 已收尾，2026-10-22**）：
> 1. **Phase A 已落地并合入 `main`**（`38d52f5` merge `schema-v2`）：按内容类型声明版本，
>    `ContentTypes.schema_version()` 是运行时唯一版本来源；
> 2. 探索系统 4.1 已在 `main`（`414baeb`），且后续 4.2–4.5 已落地：`map_profile.data` 现为 **20 个键**，新增
>    `twin_world_size`（4.3）与 `story`（4.5 教程），`exploration` 块扩到 **31 键**（见 §8.1/§8.2）；
> 3. B0 门的全量测试、生成物检查、SDK core 校验与 Node 套件全绿（证据见 §11 B0）。
>
> 分支拓扑（2026-10-22）：`main` = 探索 4.1–4.5 + 剧情 + 武器内容草案；Phase B 在 `schema-v2-phaseb` 分支推进。
> B0 已在 `main` 的内容基线上刷新本契约，**不再需要 rebase**；旧「schema-v2 待 rebase main」拓扑与冲突处理说明作废。
>
> 结论先行：Phase B = **8 类既有草案提升 active + 新增 `map_configs`（1.0 `map_profiles` 的 v2 继任者）+ 新的
> CampaignFactory 世界装配链路**；1.0 老链路原样保留，旧档不重排，1.0 模组在双读窗口内继续可用。
> `map_configs` 必须继承 1.0 `map_profile` 的**全部场景调参**（含 `twin_world_size` 与 31 键 `exploration`）；
> 教程 `story` 的归属见 §12 D13。

## 1. 范围与非目标

**范围内**

- 9 个内容类型进入运行时：`world_profiles / regions / sites / route_templates / weather_profiles / factions /
  discoveries / start_profiles` + 新增 `map_configs`。
- Schema 校验、生成物、注册表、跨引用、Core 完整性、`content_schema` 文档同步。
- 新战役运行时：`run.start` 的 `start_profile` 入口、`CampaignFactory` 世界装配、`campaign.view` 查询。
- Core v2 内容与 1.0 → 2.0 字段映射；存档 `content_versions`；编辑器 / CLI / SDK / 发布门禁。

**非目标（留给后续阶段）**

- 区域地图 / 图鉴 / 阵营的完整 2.5D UI（Phase B 只交付数据与最小查询，UI 切片另开）。
- fleet / combat / base / auto_trade / ruins 系统类型。
- Item / Module / Quest 实体合并（Phase C）。
- 移除 1.0 内容类型、ID 别名迁移器（Phase E）。

## 2. 现状基线（Phase A 之后）

| 事实 | 证据 |
| --- | --- |
| 内容版本按类型：16 个 active 类型版本都是 `1.0`，草案是 `2.0`（当前 9 类草案：world/campaign 家族 8 类 + `weapons`；Phase B 只提升前者） | `content_types.json.types[].schema_version`、`ContentTypes.SCHEMA_VERSIONS` |
| 运行时加载：`ContentCompiler` 按类型版本校验 envelope；Patch 再校验走目标类型版本 | `framework/modding/content_compiler.gd` |
| 开局链路：`run.start(build_id, seed, tutorial)` → `RunFactory.create_run` → `create_ship` → `MapGenerator.generate(map_profile)` → `WorldGenerator.generate(_coordinate_world_profile(world))`（孪生海图世界）→ markets / npcs / main contract；`tutorial=true` 时 `StoryService.begin` 从 `map_profiles.data.story` 启动教程 | `framework/application/commands/run_start.gd`、`framework/domain/contracts/run_factory.gd`、`framework/domain/story/story_service.gd` |
| 抽象地图输入：`port_count_range / archetypes / start_archetype_tags / required_facility_tags / required_facility_max_edges / port_name_keys / edge_count_range / distance_range / route_risk_range` | `framework/domain/map/map_generator.gd` |
| 孪生世界：固定 5 块陆地布局、`min_ports = 抽象港口数`、world_map 预计算航线（`WorldMap.edges`）；世界边长由 `map_profiles.data.twin_world_size` 缩放（默认 160，clamp 64–1024）；旧档无 `world_map` 时海图降级 | `run_factory.gd::_coordinate_world_profile`、`framework/domain/world/world_generator.gd` |
| 经济 / NPC / 探索 / 教程来自 `map_profile.data`：market 用 port archetype，`npc_*`、`loan`、`supply_prices`、`intel_cost`、`trade_margin`、`player_trade_impact`，以及 `twin_world_size`（4.3）、`exploration`（31 键）、`story`（4.5 教程流） | `run_factory.gd`、`framework/domain/economy/*`、`framework/domain/exploration/exploration_rules.gd`、`framework/domain/story/story_service.gd` |
| 随机流：`map_generation / goods_generation / npc_trade / contract_generation / voyage_risk / voyage_event / event_options`（探索 4.1 另有 `exploration`） | `framework/services/rng_service.gd` |
| 存档 header：`save_schema=2.0 / state_schema=2.0 / content_schema=FrameworkInfo.CONTENT_SCHEMA(1.0)`；1.x→2.0 迁移器已存在 | `framework/services/save_service.gd`、`save_migrations.gd` |
| Campaign 分区：`campaign.world / codex / factions` + 探索 4.1 的 `data.clues`（惰性 ensure）；剧情 4.5 的 `data.story` 是独立惰性块（不在 `campaign` 下） | `framework/state/game_state.gd` |
| 注册表：`RegistryHub` 按 `ContentTypes.all()` 建通用注册表（`get_all / get_by_id / query / freeze_all`） | `framework/modding/registries/registry_hub.gd` |
| 跨引用：按类型写 `_check_*`（如 `_check_map_profiles`），缺失硬引用 `_error`、软约束 `_warn` | `framework/modding/cross_reference_validator.gd` |
| Core 完整性：`CoreCompletenessChecker._require_count` 逐类型下限 + 标签规则 | `framework/modding/core_completeness_checker.gd` |
| 1.0 `map_profile`：**20 个 data 字段**（17 个原有 + `twin_world_size` + `exploration` + `story`；`exploration` 31 键、`story` 为 `story_flow` 对象） | `schemas/map_profile.schema.json`、`dev_mods/core/content/map_profiles.json` |
| 读取 `ContentTypes.MAP_PROFILE` 的运行时位置：**15 处生产 + 2 处测试**。生产：`run_factory`、`voyage_service`、`intel_view`、`supply_view`、`intel_commands`、`debt_commands`、`trade_commands`、`supply_commands`、`port_time_service`、`clue_service`、`exploration_rules`、`story_service`、`main.gd`、`cross_reference_validator`、`core_completeness_checker` | 见 §6.5 的 resolver 改造清单；测试：`test_exploration` / `test_world_generator` |

> **Draft 1 → Draft 2 差异（B0 刷新，2026-10-22）**：Draft 1 基于探索 4.1 快照（`exploration` 19 键、14 处读取）。
> 之后 `main` 落地 4.2–4.5：`exploration` 扩到 31 键（雾比例、调查、货物行情线索、等待 / 委托线索）、新增
> `twin_world_size` 与 `story`、`MAP_PROFILE` 读取点增至 15 处生产。本契约的字段表、映射表与 resolver 清单已按
> 当前 `main` 刷新；B1 的 `map_config` schema 必须一次性覆盖 §4.1 全部字段，否则 B4 迁移会丢配置。

## 3. 类型提升清单（B1）

### 3.1 9 个类型

| key | singular | 来源 | 默认文件 | capability | 说明 |
| --- | --- | --- | --- | --- | --- |
| `world_profiles` | `world_profile` | 草案提升 | `content/world_profiles.json` | `content.world.v1` | 世界构成：区域/地点/港口/遗迹/基地/阵营数量 |
| `regions` | `region` | 草案提升 | `content/regions.json` | `content.world.v1` | 区域原型与密度/天气/阵营 |
| `sites` | `site` | 草案提升 | `content/sites.json` | `content.world.v1` | 可发现地点原型 |
| `route_templates` | `route_template` | 草案提升 | `content/route_templates.json` | `content.world.v1` | 航路原型 |
| `weather_profiles` | `weather_profile` | 草案提升 | `content/weather_profiles.json` | `content.world.v1` | 气候带 |
| `factions` | `faction` | 草案提升 | `content/factions.json` | `content.world.v1` | 阵营 |
| `discoveries` | `discovery` | 草案提升 | `content/discoveries.json` | `content.world.v1` | 图鉴条目 |
| `start_profiles` | `start_profile` | 草案提升 | `content/start_profiles.json` | `content.campaign.v1` | 战役起始配置 |
| **`map_configs`** | **`map_config`** | **新增** | `content/map_configs.json` | `content.world.v1` | 经济/港口/航路/探索等场景调参，1.0 `map_profiles` 的 v2 继任者 |

### 3.2 `content_types.json` 变更

1. `types[]` 增加上述 9 条（`kind: "definition"`、`registry: true`、`module: false`、`default_file`、`capability`、
   `schema`、`schema_version: "2.0"`、`v2_target`/`aliases` 按需）。
2. `planned` 中删除已提升的类型：`world_exploration` 系统 7 个类型全部提升 → 删除该 system 条目；
   `campaign` 系统删除 `start_profiles`，保留 `difficulty_profiles` / `simulation_profiles`。
3. `draft_schemas` / `draft_types` 中删除已提升的 8 条（提升后 `SNContentTypes.DRAFT_TYPES` 只剩 `weapons`，编辑器草案分区仍保留 1 条，不消失）。
4. `map_configs` 不进 `planned`（直接 active）。
5. `content_schema` 基线保持 `"1.0"`（存档 header 语义见 §7）。

生成物：`ContentTypes` 增加 9 个常量、`SCHEMA_PATHS`、`SINGULAR`、`SCHEMA_VERSIONS`；`SNModMaker/js/content-types.js`
的 `TYPES` 由 16 → 25（含 patches）。`planned` 不能与 active 重名（生成器会失败）。

## 4. Schema 变更

### 4.1 新增 `schemas/v2/map_config.schema.json`（`content_type: "map_configs"`）

字段集 = 1.0 `map_profile` 的「场景调参」部分（当前 20 个 data 键）+ `twin_world_size` / `exploration`（31 键）/
`story` 原样搬迁；**不**包含已由世界构成/航路原型表达的生成区间（见 §8 映射表）。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `archetypes` | `id_ref[]` (≥4, unique) | ✓ | 港口原型轮转列表（引用 1.0 `port_archetypes`） |
| `port_name_keys` | `string[]` (≥4) | ✓ | 港口名称键 |
| `start_archetype_tags` | `string[]` | | 起始港必须带有的原型标签 |
| `required_facility_tags` | `port.*` 标签数组 | ✓ | 世界必须保证可达的设施标签 |
| `required_facility_max_edges` | int 1–4 | | 必需设施距离上限 |
| `npc_count_range` / `npc_cargo_range` | `range2` | | NPC 商船模拟参数 |
| `supply_prices` | `{coal, water, repair_per_point}` | | 补给价格 |
| `loan` | `{limit, interest_rate, term_hours}` | | 贷款额度/利率/期限 |
| `intel_cost` | number ≥0 | | 情报价 |
| `trade_margin` | number 0.5–1 | | 交易利润率 |
| `player_trade_impact` | number 0–1 | | 玩家交易冲击 |
| `default_starting_build` | `id_ref` | | 起始构筑兜底（`start_profiles.starting_build` 优先） |
| `twin_world_size` | number 64–1024（默认 160） | | 孪生海图世界边长；探索 4.3 U1 内容化，原样迁移 |
| `exploration` | object（31 键，见 §8.2） | | 探索 4.1 参数 + 4.2–4.5 追加键，原样迁移 |
| `story` | object（`story_flow`，见 STORY_TUTORIAL §7） | | 教程剧情流；是否搬入见 D13（4.5 新增，Phase B 前 Draft 2 未覆盖） |

约束：`archetypes` 数量 ≥ 世界构成里的 `port_count`；`default_starting_build` 必须指向 active 的 `starting_builds`；
`twin_world_size` 运行时 clamp 到 64–1024（与 1.0 一致）；`story` 缺失或非法时教程不门禁、不弹卡（沿用 1.0 行为）。

### 4.2 `start_profiles` 调整

- 新增**可选** `map_config`（`id_ref → map_configs`）；core 内容必须提供，第三方模组可省略（运行时用
  `core:map_config/standard` 兜底并在校验期给 warning）。
- 保留 `world_profile / starting_build / difficulty / starting_port_tags` 为必填（现有草案 schema 不变）。
- `difficulty`（easy/standard/hard）只影响起始数值与 UI 展示，不改变世界生成；具体倍率由 `start_profiles.starting_money`
  等字段显式表达（不在框架写死）。
- `starting_build` 继续引用 **1.0 `starting_builds`**（Phase C/D 再合并为 `starting_scenarios`）。
- `starting_contract` / `starting_cargo.item` 继续引用 1.0 `contracts` / `goods|materials`。

### 4.3 `world_profiles` 微调

- 新增**可选** `edge_density`（0–1）：抽象地图额外边比例；缺省用现有 `MapGenerator` 规则（`edge_count_range` 派生）。
- 其余字段保持草案定义（`region_count / sites_per_region / port_count / ruin_density / base_site_count /
  faction_count / weather_profile / start_region_tags`）。
- `port_count` 是**可玩港口数**（上限见 §12 D8）：Phase B 首个切片限制 ≤5（孪生世界固定 5 陆地布局），
  超出时校验期 warning 并 clamp。

### 4.4 其余 6 类

字段保持草案定义（见各 `schemas/v2/*.schema.json`），Phase B 不改结构；如需新增字段（如 `region.port_tags`），
必须在 B1 一并加入并在本文补映射。

## 5. 引用与完整性契约（B2）

### 5.1 跨引用规则

硬引用缺失 = `error`；引用指向**尚未 active** 的类型 = `warning: ref_inactive_type`（Phase B 期间不阻塞，
在目标类型提升后自动升级为 error）。跨 Mod 引用仍要求 manifest 依赖声明。

| 拥有者.字段 | 目标类型 | 级别 | 备注 |
| --- | --- | --- | --- |
| `world_profiles.weather_profile` | `weather_profiles` | 硬（存在时） | |
| `world_profiles.start_region_tags` | 标签空间 | 软 | 至少一个匹配的 `regions.region_tags`（Completeness） |
| `regions.weather_profile` | `weather_profiles` | 硬 | 必填字段 |
| `regions.factions[]` | `factions` | 硬（存在时） | |
| `sites.ruin_archetype` | `ruin_archetypes`（planned） | 软 → `ref_inactive_type` | Phase D 激活后升级 |
| `sites.encounter_table` / `sites.loot_table` | planned | 软 | 同上 |
| `route_templates.encounter_table` | planned | 软 | 同上 |
| `factions.trade_goods[]` | `goods` / `materials` | 硬 | 复用 `_item_exists` |
| `factions.contract_family` | planned | 软 | |
| `factions.rival_factions[]` | `factions` | 硬（存在时） | 自引用允许，不可自指 |
| `discoveries.unlock_ids[]` | 任意 active 定义 | 硬 | 目标不存在 → error |
| `discoveries.source_site_kinds` / `region_kinds` | 枚举 | Schema 内校验 | |
| `start_profiles.world_profile` | `world_profiles` | 硬 | |
| `start_profiles.map_config` | `map_configs` | 软（core 必有） | 第三方可省略 |
| `start_profiles.starting_build` | `starting_builds`（1.0） | 硬 | |
| `start_profiles.starting_contract` | `contracts`（1.0） | 硬（存在时） | |
| `start_profiles.starting_cargo[].item` | `goods` / `materials` | 硬 | |
| `map_configs.archetypes[]` | `port_archetypes`（1.0） | 硬 | 数量 ≥ `world_profiles.port_count` |
| `map_configs.default_starting_build` | `starting_builds`（1.0） | 硬（存在时） | |

实现位置：`cross_reference_validator.gd` 新增 `_check_world_profiles / _check_regions / _check_sites /
_check_route_templates / _check_weather_profiles / _check_factions / _check_discoveries / _check_start_profiles /
_check_map_configs`，在 `validate()` 注册；错误码沿用 `REF-*` 语义（`reference_missing`、`ref_inactive_type`、
`reference_self` 等）。`_definition_exists()` 遍历 `ContentTypes.all()`，提升后的类型自动进入通用引用检查。
`map_profile.default_starting_build` 在 1.0 运行时从未被读取（仅 `_check_map_profiles` 校验存在性）；v2 中它只作为
`start_profiles.starting_build` 缺失时的兜底，并在校验期提示。

### 5.2 Core 完整性

`CoreCompletenessChecker.check()` 新增（在 B4 core 内容落地后启用，避免中途红）：

- 硬性：`world_profiles ≥ 1`、`map_configs ≥ 1`、`start_profiles ≥ 1`、`weather_profiles ≥ 1`、`regions ≥ 1`、
  `starting_builds ≥ 1`（已有）。
- 建议：`route_templates ≥ 1`、`factions ≥ 1`、`sites ≥ 1`、`discoveries ≥ 1`（warning）。
- 组合：至少一个 `start_profiles` 能解析 `world_profile + map_config + starting_build`；其
  `world_profile.start_region_tags` 至少匹配一个 `regions.region_tags`；`map_configs.archetypes` 数量 ≥
  `world_profiles.port_count`。

### 5.3 capability

- core `manifest.capabilities` 增加 `content.world.v1`、`content.campaign.v1`。
- 编辑器：把 `capability_undeclared` 的判定从“草案类型”改为“schema_version = 2.0 的类型”（提升后草案标记消失但能力要求仍在），
  声明后消除；运行时暂以 warning 记录，Phase D 升级为 error。

## 6. 运行时装配（B3）

### 6.1 入口

- `run.start` 命令新增可选参数 `start_profile`（完整 ID）；`build_id` 保留为 1.0 旧路径。
  - `start_profile` 存在 → `CampaignFactory.create_campaign(context, start_profile_id, seed)`；
  - 不存在 → 现有 `RunFactory.create_run` 原样执行（1.0 内容，旧档/回归不受影响）。
- `run.started` 事件 payload 增加 `start_profile / world_profile / map_config`。
- 新查询 `campaign.view`：返回 `setup / regions / sites / factions / codex / exploration`（只读快照，供 UI 与测试）。

### 6.2 `CampaignFactory.create_campaign` 流水线

| 步 | 动作 | 复用/新增 |
| --- | --- | --- |
| 1 | 解析 `start_profile` → `world_profile` / `map_config`（缺省 `core:map_config/standard`）/ `starting_build` | 新 `ContentRefs` 辅助（`MAP_CONFIG` 优先、`MAP_PROFILE` 兜底） |
| 2 | 生成飞船（`RunFactory.create_ship`）与校验配置 | 复用 |
| 3 | 生成抽象地图几何：把 `world_profile.port_count` + `map_config`（archetypes / facility 标签 / name keys）适配成
`MapGenerator` 的输入（`port_count_range=[N,N]`，`edge_count_range` 由 `edge_density` 派生，`distance_range` /
`route_risk_range` 由 active `route_templates` 聚合上下界），输出同形态 `world` | 新增 `MapGenerationSpec` 适配器 + `MapGenerator.generate_spec()`（旧 `generate()` 保持不变） |
| 4 | 孪生世界：调用 `WorldGenerator.generate`，profile 由地图实际港口数构造，边长读 `map_config.twin_world_size`（默认 160，clamp 64–1024）；>5 港时按 §12 D8 处理。注意
`WorldGenerator.formal_profile()`（15–20 港验收骨架）在生产链路**未被使用**，只有 `test_world_generator` 用；
新战役走 `_coordinate_world_profile` 同款 5 陆地布局 | 复用 + `world_generator` 小幅扩展 |
| 5 | 区域装配：按 `world_profile.region_count` 生成区域实例；起始区域用 `start_region_tags` 匹配；其他区域按 `kind/size` 权重抽取；每港归属一个 `region_id`；区域天气 = `regions.weather_profile`，缺省用 `world_profile.weather_profile` | 新增 `RegionAssembler` |
| 6 | 地点装配：每区域 `sites_per_region × site_density` 个；按 `weight`、`region_kinds`、`site_kind` 抽取；写入 `campaign.world.sites[]`（实例 id、定义 id、region/port、kind、位置、discovered=false、loot/encounter 引用） | 新增 `SiteAssembler` |
| 7 | 航路：每条抽象边按两端区域类型抽 `route_templates`（`region_kinds` 过滤）；把 `kind/risk/distance/travel_time` 写入 `world.routes[].template` | 新增 `RouteAssembler` |
| 8 | 阵营：实例化 `factions` 定义（≤ `faction_count`）；初始声望 = `start_profile.starting_reputation + faction.starting_reputation`；写入 `campaign.factions` | 新增 `FactionAssembler` |
| 9 | 图鉴：按 `discoveries.weight / rarity / source_site_kinds / region_kinds / requires_tags` 为地点挂发现候选；`unlock_ids` 存入 `campaign.codex` | 新增 `DiscoveryAssembler` |
| 10 | 经济与 NPC：markets 继续按 port archetype 初始化；`supply_prices / loan / intel_cost / trade_margin /
player_trade_impact / npc_* / twin_world_size` 从 `map_config.data` 读取（旧档回退 `map_profile.data`） | `run_factory._initialize_markets` 抽成可复用 |
| 11 | 探索规则：`map_config.data.exploration`（31 键；`ExplorationRules` 改为优先 `MAP_CONFIG`、回退 `MAP_PROFILE`） | 改 resolver |
| 12 | 主线委托 / autosave / fog：沿用现有逻辑；主线委托仍来自 1.0 `contracts` | 复用 |
| 13 | 教程剧情：`tutorial=true` 时 `StoryService` 从 `map_config.data.story` 读配置（D13）；缺失时教程禁用、不门禁（沿用 1.0） | 改 `StoryService.config` |
| 14 | 写 `campaign.setup` 与 `campaign.content_versions`（§7），`state.world` 增加 `world_profile_id / map_config_id /
start_profile_id`，`map_profile_id` 在 v2 路径留空 | 新增 |

### 6.3 状态形状（v2 战役）

```text
data.run.seed / started_at / starting_build            # 兼容保留
data.campaign.setup = {
  start_profile_id, world_profile_id, map_config_id, starting_build_id,
  difficulty, seed, content_versions: { <type>: "<version>" }
}
data.campaign.world = {
  profile_id, generated: true, regions: [ {id, definition_id, kind, size, weather_profile,
  port_ids: [], site_ids: []} ], sites: [ {id, definition_id, region_id, port_id, kind,
  discovered:false, repeatable, loot_table, encounter_table} ], visited_region_ids,
  discovered_site_ids, visited_port_ids
}
data.campaign.codex = { discovered_ids: [], entries: { <discovery_id>: {site_id, at_time} } }
data.campaign.factions = { <faction_id>: {reputation, attitude, discovered, met_at} }
data.world = { 现有 ports/routes/... + world_profile_id / map_config_id / start_profile_id }
data.world_map = 孪生世界（与现有海图/迷雾/探索完全兼容）
```

注意：`GameState.CAMPAIGN_SECTION_DEFAULTS` 需要新增 `campaign.world.regions/sites`、`campaign.setup` 与
`campaign.factions` 的新字段（`attitude/discovered/met_at`），全部走 `ensure_campaign_sections()` 的逐键惰性回填，
不 bump `state_schema`；`campaign.view` 需在 `framework/application/queries/query_registry.gd` 注册。

### 6.4 确定性

- 新增随机流：`RngService.STREAM_CAMPAIGN_WORLD = &"campaign_world"`，按上下文键派生：`"regions"` / `"sites"` /
  `"routes"` / `"factions"` / `"discoveries"`；几何仍用 `STREAM_MAP_GENERATION`。
- 不可依赖字典遍历顺序：抽取前对注册表结果按 `id` 排序。
- 契约：同 seed + 同内容注册表 + 同 framework → 世界实例完全相同；不同内容版本允许不同结果，但**旧档不重排**。

### 6.5 1.0 兼容

- 1.0 路径（`run.start` 无 `start_profile`）不经过 `CampaignFactory`，行为与回归不变。
- `ContentTypes.MAP_PROFILE` 的 **15 处生产读取（+2 处测试）**统一改成 `ContentRefs.map_config(state, hub)`：
  v2 战役读 `MAP_CONFIG`，旧档读 `MAP_PROFILE`；`map_profile_id` 为空时返回 null 并走现有兜底。
  - 列表：`run_factory`、`voyage_service`、`intel_view`、`supply_view`、`intel_commands`、`debt_commands`、
    `trade_commands`、`supply_commands`、`port_time_service`、`clue_service`、`exploration_rules`、`story_service`、
    `main.gd`、`cross_reference_validator`、`core_completeness_checker`。
  - 其中 `story_service` 读 `data.story`、`clue_service` / `port_time_service` / `exploration_rules` 读 `exploration`，
    是 Draft 1 之后（4.3–4.5）新增的读取点，B3 必须一并切 resolver，**不能只改经济相关调用**。
- `EXPLORATION_SYSTEM` 的 `ExplorationRules.read(state, hub)` 与 `STORY_TUTORIAL` 的 `StoryService.config(state, hub)`
  同样切换 resolver；教程故事块随 `map_configs.story` 迁移（D13）。

## 7. 存档与版本（B5）

| 项 | 决策 |
| --- | --- |
| header | `save_schema=2.0`、`state_schema=2.0` 不变；`content_schema` 继续写基线 `1.0`（D3：它只是默认/基线） |
| 新字段 | `state.campaign.setup.content_versions`（类型 → 期望版本），新战役创建时从 `ContentTypes.SCHEMA_VERSIONS` 快照写入 |
| 旧档 | `ensure_campaign()` 惰性补齐：无 `setup` 时推断 `{starting_build → 1.0, map_profile → 1.0}`，`content_versions` 由当前注册表补齐；**不重排世界、不重新随机** |
| 版本漂移 | 加载时若 `content_versions` 与当前注册表不一致 → warning（存档仍可读，旧内容按原定义 ID 解析）；破坏性迁移留 Phase E |
| 迁移器 | `save_migrations.gd` 在 1.x→2.0 分支补 `content_versions`；`_ensure_current` 对缺失字段惰性补齐 |
| ID 稳定 | 1.0 `core:map_profile/standard` 保留；v2 使用新 ID `core:map_config/standard`；别名与迁移在 Phase E 统一 |

## 8. Core 内容与 1.0 → 2.0 字段映射（B4）

### 8.1 1.0 `map_profile` 字段去向

| 1.0 字段 | v2 去向 |
| --- | --- |
| `port_count_range` | `world_profiles.port_count`（取可玩目标值；core 用 5） |
| `edge_count_range` | `world_profiles.edge_density`（派生；无则 `MapGenerator` 默认） |
| `distance_range` / `route_risk_range` | `route_templates.distance_range / risk_range`（多条航路各自定义） |
| `archetypes` / `port_name_keys` / `start_archetype_tags` | `map_configs.*` |
| `required_facility_tags` / `required_facility_max_edges` | `map_configs.*` |
| `npc_count_range` / `npc_cargo_range` | `map_configs.*` |
| `supply_prices` / `loan` / `intel_cost` / `trade_margin` / `player_trade_impact` | `map_configs.*` |
| `default_starting_build` | `map_configs.default_starting_build`（`start_profiles.starting_build` 优先） |
| `twin_world_size`（4.3 新增） | **`map_configs.twin_world_size` 原样迁移**（默认 160，clamp 64–1024） |
| `exploration`（4.1 新增，4.2–4.5 扩到 **31 键**） | **`map_configs.exploration` 原样迁移**（键名/范围不变） |
| `story`（4.5 新增，`story_flow`） | **`map_configs.story` 原样搬迁**（D13 建议；需 `StoryService` 切 resolver） |

### 8.2 `exploration` 键（4.1 初始 19 键 + 4.2–4.5 追加 12 键 = 31 键，原样搬入）

基础（4.1）：`rumor_clue_chance / intel_clue_cost / max_active_clues / level_weights{rumor,intel} /
credibility_range{rumor,intel} / distance_error_ratio / search_zone_radius / search_zone_noise /
discovery_chance_base / discovery_chance_per_credibility / risk_base / risk_per_unreliability /
drift_durability_loss / drift_extra_coal / drift_extra_water / drift_hours / alert_threshold /
alert_progress / turnback_extra_ratio`。

4.2–4.5 追加：`fog_port_reveal_ratio / fog_vision_ratio`（4.3.1 雾比例）、`investigation_cost /
investigation_hours / investigation_success_chance`（4.3.2 / 4.4.3 逐级调查）、`goods_clue_expiry_hours /
goods_clue_price_error_ratio / goods_clue_source_weights`（4.4.1 货物行情线索）、`wait_clue_hours_block /
wait_clue_chance_per_block / wait_clue_max_chance / contract_clue_chance`（4.4.2 等待 / 委托线索来源）；
`credibility_range` 同时扩成 `{rumor,intel,wait,contract}` 四组。B1 的 `map_config.exploration` schema 必须包含
这 31 键（`additionalProperties: false`），B4 迁移时整块复制，不得只搬 4.1 的 19 键。

### 8.3 新增 core 内容（`dev_mods/core/content/`）

| 文件 | 最小内容 |
| --- | --- |
| `world_profiles.json` | `core:world_profile/default_world`：region_count 5、sites_per_region 6、port_count 5、ruin_density 0.2、base_site_count 2、faction_count 3、weather_profile → `core:weather_profile/temperate`、start_region_tags `["region.start"]` |
| `map_configs.json` | `core:map_config/standard`：§8.1 全部字段（数值取自现 1.0 `core:map_profile/standard`，含 `twin_world_size`）+ `exploration` 31 键原块 + `story` 块（D13） |
| `regions.json` | 至少 5 条，`region_tags` 覆盖 `region.start / coastal / archipelago / open_sea / industrial` |
| `sites.json` | ≥6 条，覆盖 ruin/wreck/landmark/encounter；`repeatable` 按玩法 |
| `route_templates.json` | ≥3 条（sea_lane / trade_route / hazardous_shortcut） |
| `weather_profiles.json` | ≥2 条（temperate / storm_belt） |
| `factions.json` | ≥3 条（merchant_guild / naval / pirates） |
| `discoveries.json` | ≥6 条（blueprint / relic / lore，权重与解锁引用指向现有 1.0 定义） |
| `start_profiles.json` | ≥2 条（standard / hard）：引用 `core:world_profile/default_world` + `core:map_config/standard` + 现有 `core:starting_build/*` |
| 本地化 | 以上所有 `name_key / description_key` 的 `zh_CN` + `en` 条目 |
| manifest | 9 个新内容文件；`capabilities` 增加 `content.world.v1` / `content.campaign.v1` |

## 9. 编辑器 / CLI / SDK / 门禁（B6）

| 面 | 变更 |
| --- | --- |
| 编辑器类型目录 | `TYPES` 16 → 25；提升的 8 类从 `DRAFT_TYPES` 移除，草案分区只剩 `weapons`（战斗，不属 Phase B）；9 类显示版本 2.0 |
| 校验语义 | `draft_content` 只对草案类型提示（提升后不再出现）；`capability_undeclared` 改为“schemaVersion=2.0 且未声明 capability” |
| 导出守卫（G8） | 判定从「draft **或** schema_version 2.0」改为「**当前运行时不支持**」：`info.draft` 或未知类型/版本不可加载；提升后的 9 类允许部署 |
| CLI | `types` 运行时组新增 9 类（`schema_version: "2.0"`）；`describe` 显示 v2 Schema；`add/new` 写 2.0 envelope；`validate` 走新引用规则 |
| SDK / 发布 | `sdk/validate.gd` 需通过新增 9 类内容；release workflow 无新增步骤（沿用 `gen_content_types --check` / `gen_static_docs --check` / Godot tests / sdk validate） |
| 会被影响的既有测试 | `framework/tests/cases/test_content_versions.gd`（断言所有 runtime 类型 1.0、草案不在 runtime → 改为新类型表）；`test_schema_v2_drafts.gd:207`（断言草案仍 planned/非 active → 改为“8 类已 active + `weapons` 仍 draft + 保留有效/无效样本”）；`test_content_types_manifest.gd:20-45`（manifest types 与 `ContentTypes.all()` 数量）；`test_map_constraints.gd`（30 seed 硬约束走 1.0 路径，须保持不变）；`test_world_generator.gd`（`formal_profile` 15–20 港断言，扩展该函数时需同步）；`test_run_pipeline.gd`；`test_exploration.gd` / `test_story_ui.gd`（新增的 `map_profile` 读取点，resolver 切换后须保持 1.0 行为）；`SNModMaker/tests/run-tests.js`（24/8 草案断言 → 25/1，并补 map_configs）；`content-cli.test.mjs`（types 计数） |
| 生成物同步 | 每次改 `schemas/**` 后必须跑 `node SNModMaker/tools/sync-schemas.mjs`（嵌入式 schema bundle 有新鲜度断言；B0 已修复一次 `hull.schema.json` 过期）。`gen_content_types.mjs` / `gen_static_docs.mjs` 照旧 `--check` |

## 10. 测试与验收（B6）

| 层 | 用例 |
| --- | --- |
| Schema | 9 类各 1 有效 + 1 无效样本（沿用 `test_schema_v2_drafts` 风格）；`map_configs.exploration` 31 键全键校验、`twin_world_size` 范围、`story` 非法配置回退 |
| 引用 | 每个硬/软引用一条缺失用例；`ref_inactive_type` 只 warning；跨 Mod 依赖缺失报错 |
| 完整性 | core 缺 `world_profile / map_config / start_profile / weather_profile / region` 时 error；组合规则 |
| 运行时 | `campaign.start`（或 `run.start start_profile=`）：世界生成成功、port id 连续、区域/地点/阵营/图鉴/探索规则落盘；同 seed 两次完全一致；不同 seed 不同；`campaign.view` 返回形状稳定 |
| 教程 | v2 战役 `run.start start_profile= tutorial=true` 从 `map_configs.story` 进入剧情；缺 `story` 时教程禁用且不门禁；`story.view` 形状与 1.0 教程局一致 |
| 存档 | 1.x / 2.0 旧档照常加载（不重排、不补生成）；v2 新档 round-trip；`content_versions` 快照与漂移 warning |
| 回归 | 现有 9-seed 完整通关回归必须在 1.0 路径保持不变；海图/迷雾/探索演出/教程/港口界面冒烟 |
| 编辑器/CLI | 类型计数与版本、草案分区消失、capability 提示、G8 语义（v2 active 可部署、草案仍拦截） |
| 门禁 | Godot 全套、`gen_content_types --check`、`gen_static_docs --check`、`sync-schemas` 新鲜度、`sdk/validate.gd`、Node 50+/CLI 47+ |

## 11. 落地顺序、依赖与回滚

| 步 | 内容 | 依赖 | 回滚 |
| --- | --- | --- | --- |
| B0 | **✅ 已完成（2026-10-22）**：探索 4.1（及 4.2–4.5）与 Phase A 都已在 `main`，无需 rebase；刷新本契约到 Draft 2（31 键 exploration、`twin_world_size`/`story`、15 处读取）；重新同步 SNModMaker schema bundle。基线证据：Godot **419/419**、`gen_content_types --check`、`gen_static_docs --check`、SDK core 校验、Node **50/50** 全绿 | 探索 4.1 + Phase A | 无（准备） |
| B1 | **✅ 已完成（2026-10-22）**：`content_types.json` 9 类 active（8 类草案提升 + 新增 `map_configs`）、`schemas/v2/map_config.schema.json`、`world_profiles.edge_density`、`start_profiles.map_config`、生成物（`ContentTypes` 25 类 / 编辑器 26 项 / schema bundle 29 个）、框架与编辑器测试同步改写。证据：Godot 全量、Node **50/50**、CLI **57/57**、生成器 `--check` 全绿 | B0、Phase A | revert commit（类型回到草案） |
| B2 | 注册表自动生效；cross-ref 9 个 `_check_*`；completeness（core 落地后启用）；capability | B1 | revert 校验器改动 |
| B3 | `CampaignFactory` + `run.start start_profile` + `campaign.view` + resolver 改造（15 处生产读取 + 2 处测试） | B1、B2、B4（core 内容可并行） | 保留入口但默认不走 v2；revert 运行时 |
| B4 | core 9 个 v2 内容文件 + 本地化 + manifest capabilities | B1 | 回退内容文件（旧内容仍在） |
| B5 | `content_versions` + 迁移器 + 存档矩阵测试 | B3 | revert 迁移器；旧档不受影响 |
| B6 | 编辑器/CLI/G8/测试/文档/门禁；`test_schema_v2_drafts` 改写 | B1–B5 | 逐项 revert |

并行写作用域建议：B1 只动 `content_types.json` / `schemas/v2/` / `tools/gen_content_types.mjs`；B2 只动
`framework/modding/`；B3 只动 `framework/domain/{campaign,world,map}`、`framework/application/{commands,queries}`、
`framework/state/game_state.gd`、`framework/services/rng_service.gd`；B4 只动
`dev_mods/core/**`；B6 只动 `SNModMaker/**`、`framework/tests/**`、`docs/**`。

## 12. 决策

> **已拍板（2026-10-22，全部按建议值）**：D2 双读一个 minor；D3 `campaign.setup.content_versions`；D7 新增
> `map_configs`；D8 首个切片 ≤5 港；D9 planned 引用先 warning 后升级 error；D10 保留 1.0 `starting_builds`；
> D11 复用 `run.start` 的 `start_profile`；D12 只交付 `campaign.view` + 最小展示；D13 `story` 搬入
> `map_configs.story`。

| 编号 | 决策 | 建议 |
| --- | --- | --- |
| D2 | 1.0 双读窗口长度 | 一个 minor 版本周期；窗口内 1.0 `map_profiles` 与 v2 并存 |
| D3 | 存档内容版本记录 | `content_schema` 保持基线 + `campaign.setup.content_versions` 类型映射（§7） |
| D7 | 是否新增 `map_configs` | **是**：1.0 `map_profiles` 的 v2 继任者，字段一一对应，避免把经济参数塞进 `world_profiles` |
| D8 | 可玩港口数与孪生世界 | Phase B 首个切片限制 ≤5 港（复用现有 5 陆地孪生布局）；>5 需要扩展 `_coordinate_world_profile`，留给后续切片 |
| D9 | 引用 planned 类型的策略 | Phase B 期间 warning（`ref_inactive_type`），目标类型激活后自动升级为 error |
| D10 | `start_profiles` 与 1.0 `starting_builds` | Phase B 保留 1.0 `starting_builds`，`start_profiles` 只是战役场景；合并留 Phase C |
| D11 | 新战役入口 | 复用 `run.start` 可选 `start_profile` 参数（不新增命令），legacy 默认路径不变 |
| D12 | UI 范围 | Phase B 只交付 `campaign.view` 与最小调试展示，区域/图鉴/阵营的 2.5D 页面另开切片 |
| D13 | v2 战役的教程 `story` 来源（B0 新增，4.5 引入） | **建议：`story` 块原样搬入 `map_configs.story`**，`StoryService.config` 走 `ContentRefs`；这样 `run.start start_profile= tutorial=true` 与 1.0 教程局行为一致。备选：双读 1.0 `map_profile`（把 `map_profile_id` 留作 story 回退）或 v2 战役不支持教程（功能回退，不推荐） |

> D2 / D3 / D7–D13 仍需拍板；D13 是 B0 刷新契约时新发现的问题（Draft 1 写于剧情系统 4.5 之前）。

## 13. 验收（Phase B DoD）

- [ ] 9 类内容可在编辑器/CLI 中创建、校验、导出并**被运行时加载**；
- [ ] `run.start start_profile=` 能生成完整 v2 世界（区域/地点/航路/阵营/图鉴/探索规则），同 seed 可复现；
- [ ] 海图 / 港口 / 探索演出 / 迷雾 / 教程剧情在 v2 战役中正常工作，且旧档行为零回归；
- [ ] 存档记录 `content_versions`，旧档惰性补齐且世界不重排；
- [ ] 跨引用/完整性/能力校验按 §5 生效，编辑器与 SDK 语义一致；
- [ ] 1.0 模组在双读窗口内仍可加载；发布门禁（Godot + Node + 生成器检查 + SDK）全绿。
