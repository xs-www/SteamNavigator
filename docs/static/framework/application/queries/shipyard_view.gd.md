# `framework/application/queries/shipyard_view.gd`

> 作用：船厂独立界面 ViewModel：当前/随船运输模块、已装模块效果、港口仓库、打造配方与所有可购买模块的限制原因。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipyardViewQuery` | L1 |
| `execute(_params: Dictionary, context) -> Dictionary` | L8 |

## 契约与约束

- 与 `ship.install_module` / `ship.uninstall_module` / `ship.craft_module` 共用 ShipOps/CraftOps 的规则函数，UI 不复制规则。
- `ship.modules[]` 每行含 `effect`：模块 `data` 的深拷贝（模块缺失时 `{}`），供船厂页渲染效果行与槽位卡；can_uninstall/uninstall_blockers/weight/tier 仍由本查询给出。
- `ship.modules[]` 同时给出模块实例的 `slot/index/condition/disabled`；`ship.worst_module_condition`、`ship.disabled_modules`、`ship.module_damage_points` 供界面显示与维修预览。
- `ship.hull_model_key` 取船体定义的 `information.model`，`ship.hull_model_path` 通过 `context.assets` 解析成物理路径（松散模组或挂载 zip 内均可），供 3D 船厂舞台加载内容模组的原始 GLB。
- `candidates[].blockers` 给出全部失败码；`can_install` 为 false 时 UI 禁用按钮。
- 已安装模块标记 installed；will_replace 返回会被移入当前港仓库的旧模块 ID（空串=无替换）。
- `unlock_template_id` 给出合同解锁来源（用于 UI 文案），实际锁定判断在 ShipOps.locked_by_contract。
- `craft` 行给出材料 plan（仓库/船上/合计/是否足够）、craft_cost、craft_time_hours、money_only（materials 为空且 craft_cost>0）与 blockers。
- 顶层 `orders` 列出全部未完成打造订单（含 port_id/port_name_key/remaining_hours/at_current_port，最旧在前）；`wait_options` = [6,12,24] 小时，供船厂页在港等待按钮使用。
- `warehouse` 给出当前港仓库的模块与材料；`ship.transit_modules/transit_weight` 给出随船运输模块。
- 没有存档时也返回完整空结构（warehouse/craft/orders 均为空数组），避免 UI 空引用。
- 查询在只读克隆上调用 CraftOps.ensure_orders，不会写回真实存档。

## 重点逻辑

### `_craft_rows(hub, state, at_port, has_shipyard)`

- 只为 CraftOps.craftable 的模块生成配方行，非造船厂港口前置 no_shipyard blocker。
- material_plan 的 owned = 当前港仓库 + 船上非委托货物，打造消耗顺序与之一致。

模块索引：[framework/application](../README.md)
