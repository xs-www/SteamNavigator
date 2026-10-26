# `framework/application/command_bus.gd`

> 作用：命令执行器：在 GameState 深拷贝上运行用例，成功才提交、发布领域事件并可请求自动存档。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CommandBus` | L1 |
| `_init(context = null) -> void` | L30 |
| `register(command_name: StringName, handler: Callable) -> void` | L34 |
| `has(command_name: StringName) -> bool` | L38 |
| `names() -> PackedStringArray` | L42 |
| `execute(command_name: StringName, params: Dictionary = {}) -> Dictionary` | L50 |
| `get_execution_log(limit: int = 50) -> Array[Dictionary]` | L92 |

## 契约与约束
- 处理器签名 `(params: Dictionary, context) -> Result envelope`；失败时丢弃工作副本，原始 GameState 与哈希保持不变。
- 成功时用 `original_state.replace_with(working_state)` 写回原对象，保持外部引用有效（查询/存档持有的仍是同一个 GameState）。
- 成功后按顺序发布 `{type, payload}` 事件，并通知 `QueryBus.invalidate_read_snapshot()`：活状态已变，页重建的共享读快照必须作废。
- 结果带 `autosave` 且 `context.autosave_enabled` 时触发自动存档（开局/抵达/剧情/委托等节点）。
- 保留最近 200 条执行日志（命令、成功、错误码、耗时、游戏时间）。

## 重点逻辑
### `execute(command_name, params)`
- 克隆 `context.state` 并临时替换，处理器对工作副本的修改不会泄漏到事务外。
- 非法返回值/未知命令/无 context 统一转换为结构化 Result.fail；只有 `ok` 为真才提交。

模块索引：[framework/application](./README.md)
