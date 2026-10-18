# `SNModMaker/js/catalog.js`

> 作用：内容类型展示元数据、字段标签、默认值、标签建议、条件/效果词汇与新建模板。

- 关键依赖：`JSON Schema（结构约束）`、`ContentTypes（类型/singular 映射）`
- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TYPES` | L11 |
| `BY_KEY` | L223 |
| `BY_SINGULAR` | L224 |
| `GROUPS` | L225 |
| `FIELD_LABELS` | L228 |
| `TYPE_FIELD_LABELS` | L355 |
| `FIELD_HINTS` | L368 |
| `REF_LABELS` | L394 |
| `DEFAULTS` | L399 |
| `TAG_SUGGESTIONS` | L568 |
| `CONDITION_OPS` | L584 |
| `CONDITION_FIELDS` | L590 |
| `EFFECT_OPS` | L606 |
| `EFFECT_FIELDS` | L614 |
| `MODIFIER_STATS` | L638 |
| `DEADLINE_FORMULAS` | L642 |
| `GENERATORS` | L647 |
| `FACILITIES` | L648 |
| `TEMPLATES` | L656 |
| `KEY_PREFIX` | L694 |
| `SNCatalog (global)` | L696 |

## 契约与约束

- `TYPES` 的顺序决定侧栏分组与表单类型；每项的 `schema` 必须对应仓库 `schemas/` 文件。
- `keyPrefix` 决定本地化键前缀；船只模块共用 `module`，因此跨模块类型的 local ID 必须唯一。
- `DEFAULTS` 生成的定义必须能通过对应 Schema；新增字段时同步更新这里与 `store.js`。
- 操作码、公式、设施等词汇与框架注册表保持同源；页面只做候选与提示，不自行执行。

模块索引：[SNModMaker](../README.md)
