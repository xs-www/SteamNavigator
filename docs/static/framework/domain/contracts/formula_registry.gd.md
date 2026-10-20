# `framework/domain/contracts/formula_registry.gd`

> 作用：框架拥有的安全期限公式注册表，供委托数据引用。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `FormulaRegistry` | L1 |
| `ensure_defaults() -> void` | L10 |
| `register(formula_id: String, formula: Callable) -> void` | L39 |
| `has(formula_id: String) -> bool` | L43 |
| `evaluate(formula_id: String, params: Dictionary = {}) -> float` | L48 |
| `ids() -> PackedStringArray` | L56 |
| `clear_runtime() -> void` | L65 |

## 契约与约束

- 内容只能引用 ID，不能提供表达式源码。
- 公式参数：distance / cargo_weight / passengers；返回小时数，未知 ID 返回 -1。
- 默认公式覆盖 tutorial_first/trade/craft、passenger、finale 与 normal 两类。

模块索引：[framework/domain](../README.md)
