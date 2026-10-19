# `framework/tests/cases/test_full_clear.gd`

> 作用：MVP 完整通关验收：脚本化玩家完成五段主线、中期升级、大型船组装并触发通关。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_full_clear_seed_4242() -> void` | L19 |
| `test_full_clear_multiple_seeds() -> void` | L27 |

## 契约与约束

- 只经 CommandBus/QueryBus 操作，等价于 UI 可用操作；不直接写规则状态。
- 覆盖 seed 4242 的详细总结断言，以及 111/222/333/444/555/666/777/888 的多 seed 通关回归。
- 断言航次 ≤ 16、summary 字段完整、victory.view 与 state.victory 一致。
- 导航按 BFS 逐段航行；缺钱时用普通委托/贷款兜底，缺补给时按预览购买煤水。

模块索引：[framework/tests](../README.md)
