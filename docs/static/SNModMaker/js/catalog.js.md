# `SNModMaker/js/catalog.js`

> 作用：字段标签、默认值、标签建议、条件/效果词汇与新建模板；内容类型列表来自生成的 content-types.js（`TYPES` + `DRAFT_TYPES`）。

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
| `TYPE_FIELD_LABELS` | L214 |
| `FIELD_HINTS` | L235 |
| `REF_LABELS` | L278 |
| `DEFAULTS` | L283 |
| `TAG_SUGGESTIONS` | L525 |
| `CONDITION_OPS` | L550 |
| `CONDITION_FIELDS` | L556 |
| `EFFECT_OPS` | L572 |
| `EFFECT_FIELDS` | L580 |
| `MODIFIER_STATS` | L604 |
| `DEADLINE_FORMULAS` | L608 |
| `GENERATORS` | L613 |
| `FACILITIES` | L614 |
| `TEMPLATES` | L622 |
| `KEY_PREFIX` | L660 |
| `SNCatalog (global)` | L662 |

## 契约与约束

- `BY_KEY` / `BY_SINGULAR` / `KEY_PREFIX` 覆盖运行时类型与 Schema 2.0 草案类型；`schemaVersionFor()` 返回类型期望版本（草案 2.0，其余 1.0）。
- `TYPES` 仍只含可加载的 Content Schema 1.0 类型，`DRAFT_TYPES` 与 `ALL_TYPES` 供编辑器侧栏、默认值与校验使用。
- `DEFAULTS` 生成的定义必须能通过对应 Schema；8 个草案类型的默认值必须补齐 `schemas/v2/*` 的必需字段。
- `keyPrefix` 决定本地化键前缀；船只模块共用 `module`，因此跨模块类型的 local ID 必须唯一。
- 操作码、公式、设施等词汇与框架注册表保持同源；页面只做候选与提示，不自行执行。

模块索引：[SNModMaker](../README.md)
