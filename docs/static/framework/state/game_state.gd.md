# `framework/state/game_state.gd`

> 作用：纯数据运行态：可深克隆、可序列化、可哈希、事务替换，并提供收入/支出/利润统计与惰性结构修复。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `GameState` | L1 |
| `_init(initial_data: Dictionary = {}) -> void` | L24 |
| `clone() -> GameState` | L28 |
| `replace_with(other: GameState) -> void` | L32 |
| `to_dict() -> Dictionary` | L36 |
| `is_empty() -> bool` | L44 |
| `hash() -> String` | L48 |
| `schema_version() -> String` | L55 |
| `run() -> Dictionary` | L59 |
| `player() -> Dictionary` | L63 |
| `world() -> Dictionary` | L67 |
| `ship() -> Dictionary` | L71 |
| `market() -> Dictionary` | L75 |
| `contracts() -> Dictionary` | L79 |
| `stats() -> Dictionary` | L85 |
| `ensure_stats() -> Dictionary` | L89 |
| `record_income(amount: int) -> void` | L102 |
| `record_expense(amount: int) -> void` | L110 |
| `now() -> float` | L118 |
| `set_now(value: float) -> void` | L122 |
| `advance_time(hours: float) -> void` | L128 |
| `money() -> int` | L132 |
| `set_money(value: int) -> void` | L136 |
| `add_money(amount: int) -> void` | L142 |
| `current_port_id() -> String` | L146 |
| `is_at_port() -> bool` | L150 |
| `seed() -> int` | L154 |
| `push_notice(text_key: String, params: Dictionary = {}) -> void` | L158 |
| `recent_notices(limit: int = 10) -> Array` | L171 |
| `get_value(path: Array, fallback: Variant = null) -> Variant` | L177 |

## 契约与约束

- 只保存 ID/运行时数值，不保存 ContentDefinition 或 Node。
- `clone()` 深拷贝，CommandBus 的事务基础。
- `hash()` 对规范化 JSON 做 SHA-256；存档往返需一致。
- `replace_with()` 原地替换，保持外部引用。
- `stats()/ensure_stats()` 为旧存档与半初始化测试状态惰性补齐 voyages/on_time/accidents/income/expense/profit。
- `record_income()` / `record_expense()` 只累加整数并重算 profit=income-expense；贷款本金不计收入。

## 重点逻辑

### `hash()`

- 使用 JsonUtils 的排序键 + 浮点量化表示，避免字典顺序/数字类型差异。
- HashingContext SHA-256 输出十六进制；测试用保存/加载对比验证。

### `record_income(amount) / record_expense(amount)`

- 只有 amount>0 才生效；先 ensure_stats 再累加，避免旧存档缺字段。
- 所有货币变化点（市场、委托、工资、维修、情报、船厂/打造）分别调用且只调用一次，防止重复计账。

模块索引：[framework/state](./README.md)
