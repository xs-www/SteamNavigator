# `framework/application/query_bus.gd`

> 作用：只读查询执行器：给处理器临时克隆的 GameState，返回 ViewModel。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `QueryBus` | L1 |
| `_init(context = null) -> void` | L12 |
| `register(query_name: StringName, handler: Callable) -> void` | L16 |
| `has(query_name: StringName) -> bool` | L20 |
| `names() -> PackedStringArray` | L24 |
| `execute(query_name: StringName, params: Dictionary = {}) -> Dictionary` | L32 |

## 契约与约束

- 查询失败返回结构化 Result，不用 null 混淆“无数据”和“错误”。
- 处理器返回普通 Dictionary；若没有 `ok` 字段则自动包装为成功。
- 查询不得依赖副作用；克隆是隔离意外写入的兜底。

模块索引：[framework/application](./README.md)
