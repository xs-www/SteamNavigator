# `framework/domain/ship/ship_modules.gd`

> 作用：船舶模块实例层：为每个已装模块维护稳定 instance_id 与 0..1 condition，对齐扁平槽位键，并作为损伤/维修/存档的唯一写入口。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipModules` | L1 |

## 契约与约束

- `ship.module_instances` 存单槽（boiler/navigation/safety/cabin）实例与有序 cargo 实例数组；`ship.module_serial` 是实例编号计数器；condition 0 表示失效。
- 扁平槽位键（boiler_id 等）仍是「装了哪个定义」的权威投影；实例层只拥有身份与状态。统一 Module 迁移后再把 definition_id 移入实例。
- `ensure()` 只增补/裁剪到与扁平键一致，保留已有 condition 与 id；新实例按槽位顺序分配 module_N，满状态。
- 写入点只有 install_slot/append_cargo/remove_cargo/remove_slot/damage/repair_all；读接口在旧船上按满状态兜底，不抛异常。
- `installed_rows()` 是维修、UI 与未来战斗定位的统一行视图（slot/index/module_id/instance_id/condition/disabled）。

## 重点逻辑

### `ensure(ship)`

- 先清掉扁平键已空的单槽实例，再为缺失槽位创建新实例；货舱按扁平列表长度逐位复用既有实例，不足的补满状态新实例。
- 幂等：布局不变时 serial、instance_id 与 condition 都不变，因此存档哈希稳定。

### `damage(ship, slot, index, amount)`

- 只在 has_slot 为真时生效；结果 clamp 到 [0,1]，newly_disabled 只在跨越 0 的那一次为真。
- 返回 instance_id 供领域事件引用具体实例。

模块索引：[framework/domain](../README.md)
