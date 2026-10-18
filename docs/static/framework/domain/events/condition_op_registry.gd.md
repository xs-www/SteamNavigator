# `framework/domain/events/condition_op_registry.gd`

> 作用：白名单条件操作码及其只读判定实现。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ConditionOpRegistry` | L1 |

## 契约与约束

- 覆盖货币、声誉、债务、港口标签、货物/模块/岗位、完成契约、发现、船体 tier 与耐久。
- handler 只读 state/registries，不得产生副作用。
- 未知操作码由 ConditionEvaluator 报错，不默认放行。

模块索引：[framework/domain](../README.md)
