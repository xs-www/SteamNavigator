# `framework/domain/events/condition_evaluator.gd`

> 作用：解析 all/any/not 组合器并调用条件操作码，限制条件节点数。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ConditionEvaluator` | L1 |

## 契约与约束

- 单次求值最多 16 个节点；超限返回结构化错误。
- 组合器短路：all 遇 false、any 遇 true 立即返回。
- 空条件视为 true；非对象条件报错。

模块索引：[framework/domain](../README.md)
