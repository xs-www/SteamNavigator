# `SNModMaker/js/catalog.js`

> 作用：字段标签、默认值、标签建议、条件/效果词汇与新建模板（含「舰载武器包」5 件武器预设）；内容类型列表来自生成的 content-types.js（`TYPES` + `DRAFT_TYPES`）。

- 关键依赖：`JSON Schema（结构约束）`、`content-types.js（由 content_types.json 生成）`
- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `GENERATED` | L12 |
| `TYPES` | L19 |
| `DRAFT_TYPES` | L20 |
| `ALL_TYPES` | L21 |
| `BY_KEY` | L22 |
| `BY_SINGULAR` | L23 |
| `GROUPS` | L24 |
| `schemaVersionFor(typeKey)` | L27 |
| `FIELD_LABELS` | L34 |
| `TYPE_FIELD_LABELS` | L257 |
| `FIELD_HINTS` | L292 |
| `REF_LABELS` | L379 |
| `TYPE_FIELD_HINTS` | L386 |
| `DEFAULTS` | L390 |
| `TAG_SUGGESTIONS` | L664 |
| `CONDITION_OPS` | L690 |
| `CONDITION_FIELDS` | L696 |
| `EFFECT_OPS` | L712 |
| `EFFECT_FIELDS` | L720 |
| `MODIFIER_STATS` | L744 |
| `DEADLINE_FORMULAS` | L748 |
| `GENERATORS` | L753 |
| `FACILITIES` | L754 |
| `WEAPON_PRESETS` | L766 |
| `TEMPLATES` | L871 |
| `FIELD_ENUM_LABELS` | L918 |
| `enumOptions(typeKey, field, values)` | L962 |
| `KEY_PREFIX` | L969 |
| `SNCatalog (global)` | L971 |

## 契约与约束

- `BY_KEY` / `BY_SINGULAR` / `KEY_PREFIX` 覆盖运行时类型与 Schema 2.0 草案类型；`schemaVersionFor()` 返回类型期望版本（草案 2.0，其余 1.0）。
- `TYPES` 仍只含可加载的 Content Schema 1.0 类型，`DRAFT_TYPES` 与 `ALL_TYPES` 供编辑器侧栏、默认值与校验使用。
- `DEFAULTS` 生成的定义必须能通过对应 Schema；9 个草案类型的默认值必须补齐 `schemas/v2/*` 的必需字段。
- `weapons` 草案的字段标签 / 提示与 `DEFAULTS.weapons`（取 SNBattleSim「甲板速射炮」数值）就位；船体 `weapon_sockets` / `rig_sockets` 及 `clearance_*` / `rig_*` 字段有标签与提示。
- `WEAPON_PRESETS` 是「舰载武器包」模板的 5 件成品数据（deck_gun / heavy_cannon / mortar / repeater / broadside）：战斗数值对齐 SNBattleSim，装配字段对齐 GLB Root extras，经济字段项目补齐，`model` 为 `model.weapon.*`；`TEMPLATES` 的 `weapons` 条目（显示名「舰载武器包」）驱动新建模组对话框与 CLI `new --template weapons`。
- `keyPrefix` 决定本地化键前缀；船只模块共用 `module`，因此跨模块类型的 local ID 必须唯一。
- 操作码、公式、设施等词汇与框架注册表保持同源；页面只做候选与提示，不自行执行。

模块索引：[SNModMaker](../README.md)
