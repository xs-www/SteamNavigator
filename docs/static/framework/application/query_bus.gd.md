# `framework/application/query_bus.gd`

> 作用：只读查询执行器：在临时克隆的 GameState 上运行 ViewModel 查询，保证有 bug 的查询写不进活状态。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `QueryBus` | L1 |
| `_init(context = null) -> void` | L37 |
| `register(query_name: StringName, handler: Callable) -> void` | L41 |
| `has(query_name: StringName) -> bool` | L45 |
| `names() -> PackedStringArray` | L49 |
| `begin_read_scope() -> void` | L59 |
| `end_read_scope() -> void` | L64 |
| `invalidate_read_snapshot() -> void` | L72 |
| `read_scope_depth() -> int` | L76 |
| `execute(query_name: StringName, params: Dictionary = {}) -> Dictionary` | L80 |

## 契约与约束
- 查询失败返回结构化 Result（`unknown_query` / `no_context` / `invalid_result`），不用 null 混淆“无数据”和“错误”。
- 处理器返回普通 Dictionary；没有 `ok` 字段时自动包装为成功。
- 默认每个查询克隆一次 `context.state`（HEAD 开局约 11.6 ms），克隆在调用期间临时替换 `context.state`，结束后还原原对象。
- **读作用域**（性能）：`begin_read_scope()` / `end_read_scope()` 期间所有查询共享同一份克隆快照，整页重建的 N 次查询只付一次克隆成本；嵌套调用折叠到最外层。
- `invalidate_read_snapshot()` 由 `CommandBus` 在提交成功后调用：活状态已变，作用域内下一次查询会重新克隆，不会读到过期快照。
- 查询仍不得依赖副作用；共享快照把“查询不写状态”这条不变量从“隔离”降级为“共享只读”，由 `test_ui_shell::test_query_read_scope_*` 守护语义。

## 重点逻辑
### `execute(query_name, params)`
- 作用域内用共享快照，作用域外每次克隆；`context.state` 替换后调用处理器并在 finally 语义处还原（当前实现为顺序还原，处理器异常路径由 Result 兜底）。

模块索引：[framework/application](./README.md)
