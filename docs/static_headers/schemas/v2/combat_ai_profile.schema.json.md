作用：战斗 AI 状态机（Content Schema 2.0 **草案**，schema 先行）：`combat_ai_profiles` 的 FSM 决策图（节点/转移/条件）与目标优先级、偏好交战距离。

- 运行时不加载：登记在 `content_types.json.draft_schemas` / `draft_types`，只供 SNModMaker 与 Content CLI 编辑、draft 校验；Core 不写该类型内容，`ContentTypes` 不生成常量。
- 枚举与上限来自 SNBattleSim：`runtime_action` = FSM_ACTIONS 10 项；`conditions` = FSM_CONDITIONS 16 项；`nodes` ≤ 20、`transitions` ≤ 80、每条转移 `conditions` 1–8；`logic` = all / any，首条满足的转移生效。
- 语义校验（SNModMaker/validate.js 与后续运行时）：`initial` 必须引用已声明节点；转移 `from` / `to` 必须存在；节点 id 不得重复。
- 相关：`SNBattleSim/docs/FSM_MOD_CONTRACT.md`、`SNBattleSim/js/tactics.mjs`、`sdk/templates/draft_combat_ai_profile/`（草案示例）、`content_types.json`。
