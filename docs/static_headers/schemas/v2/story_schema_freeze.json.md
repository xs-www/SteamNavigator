作用：Story Mode 数据契约 V2 的冻结锁文件：记录 `story_arc.schema.json` / `story_level.schema.json` 与 `common.schema.json` 中 12 个 story `$defs`（presentation / stage / condition / match / line / choice / page_entry / action_entry / market_filter / module_filter / access / effect）的规范化 JSON SHA-256，供 `tools/check_story_schema_freeze.mjs --check` 在本地 / CI / 发布链路中发现无意漂移。

- 契约正文：`docs/specs/STORY_MODE_DATA_CONTRACT_V2.md`；只有按该文档 §14 的版本流程才能重新冻结。
- `contract` / `contract_version` / `frozen_at` 标识契约版本；`files` 是两个剧情 Schema 的 digest；`common_schema` + `common_story_defs` 只锁 story DSL，`common.schema.json` 的其它系统定义（condition_node / effect / payload / rewards 等）不受影响。
- 重新冻结：`node tools/check_story_schema_freeze.mjs --update`；仅在没有契约变更或已升契约版本时使用。
- 不参与运行时加载；不是内容文件，不登记进 `content_types.json` / Core manifest。
