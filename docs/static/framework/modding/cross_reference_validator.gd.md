# `framework/modding/cross_reference_validator.gd`

> 作用：Schema 之后的语义校验：材料、构筑、委托奖励、事件条件/效果、港口市场与地图配置，

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CrossReferenceValidator` | L1 |
| `PLANNED_REF_TYPES` | L27 |
| `validate(hub: RegistryHub) -> Dictionary` | L40 |

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

模块索引：[framework/modding](./README.md)
