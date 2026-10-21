# `framework/state/game_state.gd`

> 作用：纯数据运行态：可深克隆、可序列化、可哈希、事务替换，并提供战役元数据与分区（world/codex/factions）、探索进度记录、收入/支出/利润统计与惰性结构修复。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `GameState` | L1 |
| `SCHEMA_VERSION` | L9 |
| `CAMPAIGN_DEFAULTS` | L13 |
| `CAMPAIGN_SECTION_DEFAULTS` | L26 |
| `STATS_DEFAULTS` | L42 |
| `CLUES_DEFAULTS` | L54 |
| `STORY_DEFAULTS` | L65 |
| `_init(initial_data: Dictionary = {}) -> void` | L80 |
| `clone() -> GameState` | L84 |
| `replace_with(other: GameState) -> void` | L88 |
| `to_dict() -> Dictionary` | L92 |
| `from_dict(value: Dictionary) -> GameState` | L96 |
| `is_empty() -> bool` | L100 |
| `hash() -> String` | L104 |
| `schema_version() -> String` | L111 |
| `campaign() -> Dictionary` | L115 |
| `ensure_campaign() -> Dictionary` | L120 |
| `ensure_campaign_sections(campaign: Dictionary, warnings: Array = []) -> void` | L138 |
| `campaign_world() -> Dictionary` | L162 |
| `campaign_codex() -> Dictionary` | L166 |
| `campaign_factions() -> Dictionary` | L172 |
| `mark_region_visited(region_id: String) -> bool` | L176 |
| `is_region_visited(region_id: String) -> bool` | L180 |
| `mark_port_visited(port_id: String) -> bool` | L184 |
| `is_port_visited(port_id: String) -> bool` | L188 |
| `discover_site(site_id: String) -> bool` | L192 |
| `is_site_discovered(site_id: String) -> bool` | L196 |
| `discover_codex(discovery_id: String) -> bool` | L201 |
| `is_codex_discovered(discovery_id: String) -> bool` | L205 |
| `set_faction_reputation(faction_id: String, value: int) -> void` | L209 |
| `faction_reputation(faction_id: String) -> int` | L219 |
| `run() -> Dictionary` | L252 |
| `player() -> Dictionary` | L256 |
| `world() -> Dictionary` | L260 |
| `ship() -> Dictionary` | L264 |
| `market() -> Dictionary` | L268 |
| `contracts() -> Dictionary` | L272 |
| `stats() -> Dictionary` | L278 |
| `clues() -> Dictionary` | L283 |
| `ensure_clues() -> Dictionary` | L287 |
| `story() -> Dictionary` | L302 |
| `ensure_story() -> Dictionary` | L306 |
| `explore_voyage() -> Variant` | L319 |
| `set_explore_voyage(voyage: Variant) -> void` | L323 |
| `is_exploring() -> bool` | L327 |
| `ensure_stats() -> Dictionary` | L331 |
| `record_income(amount: int) -> void` | L344 |
| `record_expense(amount: int) -> void` | L352 |
| `now() -> float` | L360 |
| `set_now(value: float) -> void` | L364 |
| `advance_time(hours: float) -> void` | L370 |
| `money() -> int` | L374 |
| `set_money(value: int) -> void` | L378 |
| `add_money(amount: int) -> void` | L384 |
| `current_port_id() -> String` | L388 |
| `is_at_port() -> bool` | L392 |
| `seed() -> int` | L396 |
| `push_notice(text_key: String, params: Dictionary = {}) -> void` | L400 |
| `recent_notices(limit: int = 10) -> Array` | L413 |
| `get_value(path: Array, fallback: Variant = null) -> Variant` | L419 |

## 契约与约束

- Schema 2.0 只保存 ID/运行时数值，不保存 ContentDefinition 或 Node；新增 campaign 块承载持久战役身份、生命周期与逐步加入的子分区。
- `clone()` 深拷贝，CommandBus 的事务基础。
- `hash()` 对规范化 JSON 做 SHA-256；存档往返需一致。
- `replace_with()` 原地替换，保持外部引用。
- `campaign()/ensure_campaign()` 为旧状态或测试状态补齐 campaign 默认字段；id 从 seed 派生。
- `CAMPAIGN_SECTION_DEFAULTS` + `ensure_campaign_sections()` 按系统逐步加入分区：`world`（生成标记与已访问区域/港口/已发现地点 id）、`codex`（发现条目 id）、`factions`（id → 运行态字典）。顶层 `world` 仍是已生成地图布局，`campaign.world` 只记探索进度。
- 进度写入全部幂等并只追加 id：`mark_region_visited` / `mark_port_visited` / `discover_site` / `discover_codex` 返回是否新增；`set_faction_reputation` 夹取到 [-100,100]。
- `stats()/ensure_stats()` 为旧存档与半初始化测试状态惰性补齐 voyages/on_time/accidents/income/expense/profit。
- `record_income()` / `record_expense()` 只累加整数并重算 profit=income-expense；贷款本金不计收入。

## 重点逻辑

### `hash()`

- 使用 JsonUtils 的排序键 + 浮点量化表示，避免字典顺序/数字类型差异。
- HashingContext SHA-256 输出十六进制；测试用保存/加载对比验证。

### `ensure_campaign_sections(campaign, warnings)`

- 逐分区补默认值；分区或分区字段缺失时复制默认容器（数组/字典深拷贝），并可选记录 `campaign.<section>.<field> backfilled` 警告。
- 只增补不覆盖：已有进度数组原样保留，重复调用幂等。

### `record_income(amount) / record_expense(amount)`

- 只有 amount>0 才生效；先 ensure_stats 再累加，避免旧存档缺字段。
- 所有货币变化点（市场、委托、工资、维修、情报、船厂/打造）分别调用且只调用一次，防止重复计账。

模块索引：[framework/state](./README.md)
