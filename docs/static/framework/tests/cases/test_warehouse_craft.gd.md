# `framework/tests/cases/test_warehouse_craft.gd`

> 作用：迭代 1 船只系统测试：仓库存取、transit 重量、材料打造、免费安装、替换/卸下、合同解锁与失败原子性。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_run_start_initializes_warehouses_and_transit() -> void` | L41 |
| `test_transit_weight_counts_without_cargo_capacity() -> void` | L77 |
| `test_store_and_take_materials() -> void` | L100 |
| `test_craft_consumes_warehouse_first_then_cargo_and_charges_cost() -> void` | L120 |
| `test_failed_craft_leaves_state_unchanged() -> void` | L163 |
| `test_install_from_warehouse_is_free_and_replaces_old_module() -> void` | L173 |
| `test_uninstall_and_reinstall_from_transit() -> void` | L199 |
| `test_uninstall_rejects_hull_and_boiler() -> void` | L220 |
| `test_replacement_moves_old_hull_into_warehouse() -> void` | L232 |
| `test_duplicate_cargo_module_allowed_while_slots_free() -> void` | L246 |
| `test_contract_lock_blocks_hulls_and_crafts_until_unlock() -> void` | L262 |
| `test_take_module_respects_weight_limit() -> void` | L287 |
| `test_failed_install_leaves_state_unchanged() -> void` | L298 |

## 契约与约束

- 每个用例独立 bootstrap Core 并清空初始主线载荷，保证重量/容量可预测。
- 覆盖仓库模块/材料 store+take、transit 计入总重量但不占货舱、打造仓库优先且计支出（下单不推进时间，等待后入仓）、旧件替换入仓、hull/boiler 不可卸下、重量上限拒绝、失败命令 state.hash 不变。
- 合同解锁覆盖 medium/large 船体与打造锁定；重复货舱模块允许有空槽时购买。

模块索引：[framework/tests](../README.md)
