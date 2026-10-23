# `SNModMaker/js/catalog.js`

> 作用：字段标签、默认值、标签建议、条件/效果词汇与新建模板（含「舰载武器包」5 件武器预设）；内容类型列表来自生成的 content-types.js（`TYPES` + `DRAFT_TYPES`），并按类型提供剧情模式（篇章/关卡）的标签、默认值与枚举可读名。

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
| `TYPE_FIELD_LABELS` | L342 |
| `FIELD_HINTS` | L480 |
| `REF_LABELS` | L654 |
| `TYPE_FIELD_HINTS` | L661 |
| `DEFAULTS` | L673 |
| `TAG_SUGGESTIONS` | L1258 |
| `MODULE_CATEGORY_IDS` | L1306 |
| `MODULE_CATEGORY_TAGS` | L1307 |
| `CONDITION_OPS` | L1315 |
| `CONDITION_FIELDS` | L1321 |
| `EFFECT_OPS` | L1337 |
| `EFFECT_FIELDS` | L1345 |
| `MODIFIER_STATS` | L1369 |
| `DEADLINE_FORMULAS` | L1373 |
| `GENERATORS` | L1378 |
| `FACILITIES` | L1379 |
| `WEAPON_PRESETS` | L1391 |
| `TEMPLATES` | L1496 |
| `FIELD_ENUM_LABELS` | L1543 |
| `enumOptions(typeKey, field, values)` | L1659 |
| `KEY_PREFIX` | L1666 |
| `SNCatalog (global)` | L1668 |

## 契约与约束

- `BY_KEY` / `BY_SINGULAR` / `KEY_PREFIX` 覆盖 42 个运行时类型（全部 2.0）与 3 个 Schema 2.0 草案类型（story_arcs / story_levels）；`schemaVersionFor()` 返回类型期望版本。
- `TYPES` 含 30 个可加载类型（29 个 2.0 定义 + 2.0 显式补丁 `patches`），`DRAFT_TYPES` 为剧情 `story_arcs` / `story_levels`，`ALL_TYPES` 供编辑器侧栏、默认值与校验使用。
- `DEFAULTS` 生成的定义必须能通过对应 Schema；D5 后 42 类 active 2.0 类型（含 `map_configs` 的 31 键 exploration、6 个战斗类型、4 个舰队类型、5 个基地类型、2 个自动贸易类型与 5 个遗迹类型）与剧情篇章/关卡草案的默认值都在此维护（剧情关卡默认值自带 2 港 1 航道固定地图与首尾 checkpoint）。
- `weapons` 的字段标签 / 提示与 `DEFAULTS.weapons`（取 SNBattleSim「甲板速射炮」数值）就位；船体 `weapon_sockets` / `rig_sockets` 及 `clearance_*` / `rig_*` 字段有标签与提示。
- 剧情草案复用共享 `FIELD_LABELS`，用 `TYPE_FIELD_LABELS` / `TYPE_FIELD_HINTS` 处理同名不同义的字段（如关卡 `position` 是世界坐标、`rewards` 只允许成就/图鉴/装饰），并在 `FIELD_ENUM_LABELS` 提供 `role` / `presentation` / `fog` / `profile` / `hint_level` / 重试方式的可读名。
- `WEAPON_PRESETS` 是「舰载武器包」模板的 5 件成品数据（deck_gun / heavy_cannon / mortar / repeater / broadside）：战斗数值对齐 SNBattleSim，装配字段对齐 GLB Root extras，经济字段项目补齐，`model` 为 `model.weapon.*`；`TEMPLATES` 的 `weapons` 条目（显示名「舰载武器包」）驱动新建模组对话框与 CLI `new --template weapons`。
- `keyPrefix` 决定本地化键前缀；船只模块共用 `module`，因此跨模块类型的 local ID 必须唯一。
- 操作码、公式、设施等词汇与框架注册表保持同源；页面只做候选与提示，不自行执行。

模块索引：[SNModMaker](../README.md)
