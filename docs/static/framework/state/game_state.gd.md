# `framework/state/game_state.gd`

> 作用：纯数据运行态：可深克隆、可序列化、可哈希、事务替换。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `GameState` | L1 |
| `_init(initial_data: Dictionary = {}) -> void` | L14 |
| `clone() -> GameState` | L18 |
| `replace_with(other: GameState) -> void` | L22 |
| `to_dict() -> Dictionary` | L26 |
| `is_empty() -> bool` | L34 |
| `hash() -> String` | L38 |
| `schema_version() -> String` | L45 |
| `run() -> Dictionary` | L49 |
| `player() -> Dictionary` | L53 |
| `world() -> Dictionary` | L57 |
| `ship() -> Dictionary` | L61 |
| `market() -> Dictionary` | L65 |
| `contracts() -> Dictionary` | L69 |
| `now() -> float` | L73 |
| `set_now(value: float) -> void` | L77 |
| `advance_time(hours: float) -> void` | L83 |
| `money() -> int` | L87 |
| `set_money(value: int) -> void` | L91 |
| `add_money(amount: int) -> void` | L97 |
| `current_port_id() -> String` | L101 |
| `is_at_port() -> bool` | L105 |
| `seed() -> int` | L109 |
| `push_notice(text_key: String, params: Dictionary = {}) -> void` | L113 |
| `recent_notices(limit: int = 10) -> Array` | L126 |
| `get_value(path: Array, fallback: Variant = null) -> Variant` | L132 |

## 契约与约束

- 只保存 ID/运行时数值，不保存 ContentDefinition 或 Node。
- `clone()` 深拷贝，CommandBus 的事务基础。
- `hash()` 对规范化 JSON 做 SHA-256；存档往返需一致。
- `replace_with()` 原地替换，保持外部引用。

## 重点逻辑

### `hash()`

- 使用 JsonUtils 的排序键 + 浮点量化表示，避免字典顺序/数字类型差异。
- HashingContext SHA-256 输出十六进制；测试用保存/加载对比验证。

模块索引：[framework/state](./README.md)
