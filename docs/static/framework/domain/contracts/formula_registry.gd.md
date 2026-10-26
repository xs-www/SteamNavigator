# `framework/domain/contracts/formula_registry.gd`

> 作用：框架拥有的安全期限公式注册表，供委托数据引用。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `FormulaRegistry` | L1 |
| `ensure_defaults() -> void` | L21 |
| `register(formula_id: String, formula: Callable) -> void` | L63 |
| `has(formula_id: String) -> bool` | L67 |
| `evaluate(formula_id: String, params: Dictionary = {}) -> float` | L72 |
| `ids() -> PackedStringArray` | L80 |
| `clear_runtime() -> void` | L89 |

## 契约与约束
- 内容只能引用 ID，不能提供表达式源码。
- 公式参数：distance / cargo_weight / passengers；返回小时数，未知 ID 返回 -1。
- 默认公式覆盖 tutorial_first/trade/craft、passenger、finale 与 normal 两类。
- `distance` 参数是海图世界该边的权威距离（绘制路径折线长度），公式按「里程 / 目标
  航速」换算时限；`tutorial_express` 的隐含航速 13.5 夹在标准与极速之间，短航线下限
  只有 0.5h，保住「标准迟到 / 极速准时」的教学契约（不再用固定 6h 下限）。
- `none` 恒返回 0，表示「无期限委托」（第三主线起，反馈 #3）；`<= 0` 由
  `ContractOps.create_instance` 落成无期限哨兵。

模块索引：[framework/domain](../README.md)
