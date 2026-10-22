# `framework/domain/ship/module_ops.gd`

> 作用：Content Schema 2.0 统一模块类型 `modules` 的分类访问器：按 `data.v2_category`

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ModuleOps` | L1 |
| `CATEGORIES` | L24 |
| `SLOT_CATEGORIES` | L27 |
| `SLOT_KEYS` | L36 |
| `INSTANCE_SLOTS` | L45 |
| `CATEGORY_SLOTS` | L54 |
| `UTILITY_SLOTS` | L61 |
| `NAVIGATION_TAG` | L62 |
| `SAFETY_TAG` | L63 |
| `CATEGORY_REQUIRED_FIELDS` | L66 |
| `UTILITY_TAG_FIELDS` | L74 |
| `all(hub: RegistryHub) -> Array[ContentDefinition]` | L80 |
| `all_of_category(hub: RegistryHub, category: String) -> Array[ContentDefinition]` | L84 |
| `get_by_id(hub: RegistryHub, module_id: String) -> ContentDefinition` | L92 |
| `is_module(hub: RegistryHub, module_id: String) -> bool` | L98 |
| `category_of(definition: ContentDefinition) -> String` | L102 |
| `category_of_id(hub: RegistryHub, module_id: String) -> String` | L108 |
| `count(hub: RegistryHub, category: String) -> int` | L112 |
| `slot_category(slot: String) -> String` | L117 |
| `category_slots(category: String) -> Array` | L121 |
| `ship_slot_key(slot: String) -> String` | L126 |
| `instance_slot(slot: String) -> String` | L131 |
| `accepts(definition: ContentDefinition, slot: String) -> bool` | L135 |
| `accepts_category(category: String, slot: String) -> bool` | L139 |
| `slot_for(definition: ContentDefinition, ship: Dictionary = {}) -> String` | L145 |
| `slot_for_with_request(definition: ContentDefinition, ship: Dictionary, requested_slot: String) -> String` | L151 |
| `slot_for_category(category: String, ship: Dictionary = {}) -> String` | L160 |
| `slot_for_definition(definition: ContentDefinition, ship: Dictionary = {}) -> String` | L176 |
| `required_fields(definition: ContentDefinition) -> Array` | L194 |

（boiler / cargo / utility / cabin，`crew` 预留）查询定义，并把 ship 存档的扁平槽位
映射到 category（boiler / cargo_modules / navigation_module / safety_module /
passenger_cabin），供 ship_ops / ship_commands / shipyard_view / craft_ops /
完整性检查与船厂 UI 共用。

## 契约与约束
- 5 类 1.0 模块已合并为单一 active 2.0 类型 `ContentTypes.MODULE`；hulls 仍是独立
  `ContentTypes.HULL`，不属于模块目录。
- ship 存档保持原有扁平槽位（`boiler_id` / `cargo_modules` / `navigation_module_id` /
  `safety_module_id` / `passenger_cabin_id`）与 `module_instances` 形状，不做迁移。
- utility 同时覆盖原导航与安全模块：定义 tags `module.navigation` / `module.safety`
  决定购买安装的目标槽；无标签或冲突时兜底第一个空 utility 槽（先 navigation 后
  safety）。UI 拖放时以拖放目标槽为准。
- category 专属必填字段由语义校验器（CrossReferenceValidator）负责，因为项目
  SchemaValidator 不支持 if/then；本文件只提供字段表。

模块索引：[framework/domain](../README.md)
