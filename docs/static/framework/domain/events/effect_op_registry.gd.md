# `framework/domain/events/effect_op_registry.gd`

> 作用：白名单效果操作码及其纯实现（货币、补给、货物、船只与模块、委托、情报、通知）。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `EffectOpRegistry` | L1 |

## 契约与约束

- 每个 handler 接收 `(node, execution_context)`，返回 `{ok,error_code,message_key}`。
- 失败表示整个命令事务回滚；效果按数组顺序执行。
- `damage_ship` 应用安全设备 damage_mul；耐久归零设置 voyage_failed。
- `damage_module` 按 `slot`（boiler/navigation/safety/cabin/cargo）+ 可选 `index` 扣减模块实例 condition，发布 ship.module_damaged；hull 不是模块槽位，非法槽位返回 unknown_module_slot。
- `update_intelligence` 生成并存储快照；`emit_notice` 写入 GameState 通知。
- 未知操作码永远不会执行。

模块索引：[framework/domain](../README.md)
