# `SNModMaker/js/catalog.js`

> 作用：字段标签、默认值、标签建议、条件/效果词汇与新建模板；内容类型列表来自生成的 content-types.js。

- 关键依赖：`JSON Schema（结构约束）`、`content-types.js（由 content_types.json 生成）`
- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `GENERATED` | L12 |
| `TYPES` | L16 |
| `BY_KEY` | L17 |
| `BY_SINGULAR` | L18 |
| `GROUPS` | L19 |
| `FIELD_LABELS` | L22 |
| `TYPE_FIELD_LABELS` | L149 |
| `FIELD_HINTS` | L162 |
| `REF_LABELS` | L188 |
| `DEFAULTS` | L193 |
| `TAG_SUGGESTIONS` | L362 |
| `CONDITION_OPS` | L378 |
| `CONDITION_FIELDS` | L384 |
| `EFFECT_OPS` | L400 |
| `EFFECT_FIELDS` | L408 |
| `MODIFIER_STATS` | L432 |
| `DEADLINE_FORMULAS` | L436 |
| `GENERATORS` | L441 |
| `FACILITIES` | L442 |
| `TEMPLATES` | L450 |
| `KEY_PREFIX` | L488 |
| `SNCatalog (global)` | L490 |

## 契约与约束

- `TYPES` 来自 `SNContentTypes.TYPES`；manifest 的顺序决定侧栏分组与表单类型，每项的 `schema` 对应仓库 `schemas/` 文件。
- `keyPrefix` 决定本地化键前缀；船只模块共用 `module`，因此跨模块类型的 local ID 必须唯一。
- `DEFAULTS` 生成的定义必须能通过对应 Schema；新增字段时同步更新这里与 `store.js`。
- 操作码、公式、设施等词汇与框架注册表保持同源；页面只做候选与提示，不自行执行。

模块索引：[SNModMaker](../README.md)
