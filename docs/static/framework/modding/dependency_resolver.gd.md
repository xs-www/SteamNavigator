# `framework/modding/dependency_resolver.gd`

> 作用：校验模组健康度、冲突、能力、依赖版本，并生成确定性拓扑加载顺序。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `DependencyResolver` | L1 |

## 契约与约束

- 错误分级：Core 问题或其他 fatal 阻断启动；其余模组问题禁用模组并继续。
- 冲突显式声明时按 load_priority、再按 ID 决定保留者，并记录禁用原因。
- 依赖缺失/被禁用/版本不匹配会递归禁用依赖者。
- 同一依赖层按 (load_priority, id) 排序；循环/被循环阻塞的节点全部禁用并报告。

## 重点逻辑

### `_build_order()`

- 反复执行 Kahn 排序；未进入结果的节点即循环或被循环阻塞。
- 禁用剩余节点后重建 active 集合，最多 8 轮；保证终止。
- Core 在任何阶段被禁用都会设置 fatal。

模块索引：[framework/modding](./README.md)
