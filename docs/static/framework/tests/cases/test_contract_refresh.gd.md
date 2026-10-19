# `framework/tests/cases/test_contract_refresh.gd`

> 作用：迭代 1 委托池测试：抵达刷新、持有上限、port.view 字段与同 seed 刷新确定性。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_initial_offers_and_port_view_limit_fields() -> void` | L68 |
| `test_active_limit_formula_and_accept_rejection() -> void` | L103 |
| `test_arrival_refreshes_normal_offer_pool() -> void` | L142 |
| `test_refresh_is_deterministic_for_same_seed() -> void` | L179 |

## 契约与约束

- 抵达后 offers 整池替换（instance_id 变化），main/main_offer/next_main_sequence 不受影响。
- active_limit = max(1, 1+reputation/2)，超限接取返回 too_many_contracts。
- port.view 暴露 active_limit/active_count/normal_holds/main_chain_complete。
- 同 seed+命令序列重复抵达得到相同刷新池。

模块索引：[framework/tests](../README.md)
