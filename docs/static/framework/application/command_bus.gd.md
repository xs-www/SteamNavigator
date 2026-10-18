# `framework/application/command_bus.gd`

> 作用：命令执行器：在 GameState 深拷贝上运行用例，成功才提交并发布领域事件。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CommandBus` | L1 |
| `_init(context = null) -> void` | L14 |
| `register(command_name: StringName, handler: Callable) -> void` | L18 |
| `has(command_name: StringName) -> bool` | L22 |
| `names() -> PackedStringArray` | L26 |
| `execute(command_name: StringName, params: Dictionary = {}) -> Dictionary` | L34 |
| `get_execution_log(limit: int = 50) -> Array[Dictionary]` | L72 |

## 契约与约束

- 处理器签名 `(params: Dictionary, context) -> Result envelope`。
- 失败时丢弃工作副本，原始 GameState 与哈希保持不变。
- 提交后按顺序发布 `{type, payload}` 事件；结果可请求自动存档。
- 保留最近 200 条执行日志（命令、成功、错误码、耗时）。

## 重点逻辑

### `execute(command_name, params)`

- 克隆 `context.state` 并临时替换，处理器对工作副本的修改不会泄漏到事务外。
- 成功时用 `replace_with()` 写回原对象，保持外部引用有效；随后发布事件并可选 autosave。
- 未知命令、无 context、非法返回值都转换为统一 Result.fail。

模块索引：[framework/application](./README.md)
