# `framework/modding/cross_reference_validator.gd`

> 作用：Schema 之后的语义校验：材料、构筑、委托奖励、事件条件/效果、港口市场与地图配置，

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CrossReferenceValidator` | L1 |
| `PLANNED_REF_TYPES` | L39 |
| `MODULE_CATEGORIES` | L49 |
| `MODULE_CATEGORY_REQUIRED_FIELDS` | L50 |
| `UTILITY_TAG_FIELDS` | L56 |
| `QUEST_MATCH_REFERENCE_TYPES` | L65 |
| `validate(hub: RegistryHub) -> Dictionary` | L79 |

以及 Phase B 世界/战役 9 类（world_profiles / regions / sites / route_templates /
weather_profiles / factions / discoveries / start_profiles / map_configs）的引用完整性。

## 契约与约束
- 硬引用缺失一律 `error`（`reference_missing`）；引用尚未 active 的 planned 类型只给
  `warning: ref_inactive_type`，目标类型提升后这条规则升级为 `_require` 硬校验。
- planned 目标类型没有运行时注册表，因此用本文件的 `PLANNED_REF_TYPES` 显式映射
  （来源：`content_types.json` 的 `planned` 与 WORLD_SCHEMA_V2_RUNTIME §5.1 引用表）。
- `factions.rival_factions[]` 允许指向同类型定义，但指向自身报 `reference_self`。
- `map_configs.archetypes` 数量必须 ≥ 引用它的 `start_profiles.world_profile.port_count`；
  找不到对应 world_profile 时跳过（缺失本身已由 start_profiles 检查报错）。
- 既有检查与错误码保持不变；空的 v2 Core 内容基线不受影响。
- C1：5 类模块合并为 `modules` 后，`starting_builds` 的 boiler / cargo_modules /
  navigation_module / safety_module / passenger_cabin 按 `data.v2_category`
  （boiler / cargo / utility / utility / cabin）解析；category 专属必填字段由
  `_check_module_category` 承担（合并 Schema 无法表达 if/then）。
- C3：`quests` 的 `prerequisites.quests_completed[]` 必须是已存在的 quest 定义；
  objective 的 `event` 必须是 `cmd:*` / `ui:*` 形式（D6：不静默）；objective
  `match` 里的实体引用键（`item_id` / `module_id` / `hull_id` / `role_id` /
  `strategy_id`）必须解析到对应运行时注册表（`quest_match_ref_missing`，message
  带 mod / file / entity / path），`category` 等字面过滤键跳过。
  **设计理由**：命令 / UI 事件名是字符串总线（`CommandBus` / Shell 观测），没有可枚举的
  运行时注册表交给内容校验器，因此这里只做格式硬校验；未知但格式合法的事件名属于
  「内容作者拼写」问题，无法在不引入注册表快照的前提下可靠判定，故不误报。

模块索引：[framework/modding](./README.md)
