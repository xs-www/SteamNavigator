# `framework/domain/events/effect_executor.gd`

> 作用：顺序执行效果列表，失败即中止并返回带索引的错误。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `EffectExecutor` | L1 |

## 契约与约束

- 单次最多 16 个效果；未知/非法效果拒绝。
- 自身不克隆状态；回滚依赖 CommandBus 的事务副本。
- 成功返回执行数量、通知列表与 flags。

模块索引：[framework/domain](../README.md)
