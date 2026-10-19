# `framework/tests/cases/test_shipyard_refit.gd`

> 作用：船厂改装 UI 契约测试：纵剖图槽位与模式持久、2.5D 渲染器替换钩子、拖拽仓库模块到槽位的端到端链路。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_refit_cutaway_lists_every_slot_and_switches_mode() -> void` | L75 |
| `test_renderer_slot_is_swappable_for_the_future_2_5d_scene() -> void` | L112 |
| `test_dragging_a_warehouse_module_maps_to_install_command() -> void` | L130 |

## 契约与约束

- 与 test_ui_shell 同一夹具：真实挂载 main.tscn 外壳并先 run.start，main.gd / 船厂页接线错误会在此失败。
- 槽位数 = 4 + cargo_slots +（cabin_slots > 0 时 +1），与 SNShipView._slot_targets 数量一致；改装开启前贴片全部隐藏。
- 按本地化键 `ui.label.refit` 找到改装按钮并真实 emit pressed：进入 CUTAWAY，`shell._shipyard_refit` 让重建后的船厂页仍保持改装态。
- 渲染器替换：默认 `has_renderer() == false`；`set_renderer(provider)` 后节点挂到舞台下，`set_renderer(null)` 恢复内置占位。
- 拖放端到端：`WarehouseOps.add_module` 在仓库放一个导航模块 → HUD 恰好一行可拖拽；`_on_slot_drop` 发 `ship.install_module`，参数含 module_id / source 与槽位 replace_module_id，命令后模块离开仓库并装到船上。
- 覆盖来源与类型校验：异类型部件、purchase 候选均被 `_accepts` 拒绝。

模块索引：[framework/tests](../README.md)
