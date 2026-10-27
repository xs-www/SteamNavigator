# `tools/check_story_schema_freeze.mjs`

> 作用：Story Mode 数据契约冻结门禁：锁定 story_arc / story_level Schema 与

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `canonical(value)` | L34 |
| `digest(value)` | L44 |
| `readJson(file)` | L48 |
| `currentDigests()` | L52 |
| `loadLock()` | L66 |
| `compare(lock, current)` | L71 |

common 里的 story DSL 定义，防止在实现加载链/运行时前被无意改动。

## 契约与约束
- 冻结契约见 `docs/specs/STORY_MODE_DATA_CONTRACT_V2.md`；锁文件在
  `schemas/v2/story_schema_freeze.json`。
- 比较对象是**规范化 JSON**（递归 key 排序）的 SHA-256，格式化/缩进变化不算改动。
- `common.schema.json` 只锁 story_presentation / story_stage / story_condition /
  story_match 四个定义；同文件的其它系统字段不受影响。
- 默认 `--check`：任何漂移都退出码 1，并提示先评审契约再 `--update`。
- `--update`：重新冻结（写入新 digest）；只在明确决定升契约版本/接受变更时使用。
- `--json`：输出机器可读摘要。

模块索引：[tools](./README.md)
