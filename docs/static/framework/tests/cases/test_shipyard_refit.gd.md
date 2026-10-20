# `framework/tests/cases/test_shipyard_refit.gd`

> 作用：船厂界面重构契约测试（正常态 / 改装态）：三列布局、槽位与分类记忆、授权贴图与船卡缩略图、2.5D 渲染器替换钩子、拖拽安装，以及旧整页下方面板必须消失。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L12 |
| `SHIPYARD_SCREEN_SCRIPT` | L13 |
| `SHIP_VIEW_SCRIPT` | L14 |
| `SLOT_TARGET_SCRIPT` | L15 |
| `PART_ROW_SCRIPT` | L16 |
| `STEADY_BUILD` | L17 |
| `MODE_EXTERIOR` | L18 |
| `MODE_CUTAWAY` | L19 |
| `SHIP_THUMB_SIZE` | L20 |
| `MODULE_TYPES` | L21 |
| `LEGACY_SECTION_KEYS` | L24 |
| `test_normal_mode_shows_owned_ship_render_and_component_categories() -> void` | L167 |
| `test_refit_mode_switches_to_cutaway_and_remembers_mode_and_category() -> void` | L205 |
| `test_damaged_module_shows_a_condition_badge() -> void` | L253 |
| `test_cutaway_uses_the_authored_section_texture() -> void` | L282 |
| `test_ship_card_uses_the_authored_thumbnail() -> void` | L302 |
| `test_renderer_slot_is_swappable_for_the_future_2_5d_scene() -> void` | L321 |
| `test_dragging_a_warehouse_module_maps_to_install_command() -> void` | L355 |
| `test_category_navigation_switches_operations_and_misc_hosts_actions() -> void` | L430 |
| `test_shipyard_page_has_no_legacy_lower_panels() -> void` | L468 |

## 契约与约束

- 与 test_ui_shell 同一夹具：真实挂载 main.tscn 外壳并先 run.start，main.gd / 船厂页接线错误会在此失败；用例按脚本类型在 `_root_box` 里定位 ShipyardScreen。
- 槽位数 = 4 + cargo_slots +（cabin_slots > 0 时 +1），与 `SNShipView._slot_targets` 数量一致；改装开启前贴片全部隐藏。
- 正常态断言：stage 为 `EXTERIOR`、左列标题「已有船舶」、「组件」列提供六类入口、船卡显示当前船体名并预留缩略图区域（`SHIP_THUMB_SIZE` = 210×118），且页面恰好一个 ShipyardScreen。
- 改装态断言：按本地化键 `ui.label.refit` 点真实按钮 → `_category == "hulls"`、stage 为 `CUTAWAY`、全部贴片可见、按钮改为「完成改装」；竖排 tab 含「杂项」。`shell._shipyard_refit` / `_shipyard_category` 让整页重建后仍恢复改装态与所选分类。
- 贴图契约：`SHIP_VIEW_SCRIPT.SECTION_TEXTURE_PATH` 必须等于 `res://assets/ui/shipyard/ship_section.png` 且 `ResourceLoader.exists`；进入改装后 `has_section_texture()` 为真、`section_texture_size()` 两个分量 > 0。船卡缩略图断言 `_ship_thumb` 非空、页面仅有一个 TextureRect 使用它、占位文案不再出现。
- 渲染器替换：正常态在 `ship.hull_model_path` 非空（或本地有旧路径回退）时挂载 `SNShipStage3D`，断言 `has_ship()`、`has_stage()`、`stage_id()=="shipyard"`；改装态 `is_stage_visible()` 为 false、回 EXTERIOR 重新为 true；无模型时断言保留程序化占位。`set_renderer(provider)` 后节点挂到舞台下，`set_renderer(null)` 恢复内置占位。
- 拖放端到端：`WarehouseOps.add_module` 在仓库放一个导航模块 → 操作列恰好一行可拖拽；`_on_slot_drop` 发 `ship.install_module`，参数含 module_id / source 与槽位 `replace_module_id`，命令后模块离开仓库并装到船上；异类型部件与 purchase 候选被 `_accepts` 拒绝。
- 分类导航：每个分类的中间面板标题取 `ui.category.<type>`，货舱按槽位数逐个列出「货舱槽 n」；杂项承载打造订单/在港等待/仓库材料/仓库模块，且不再出现「按配方打造」「槽位」；打造入口留在对应模块分类内。
- 旧面板守护：`LEGACY_SECTION_KEYS`（parts_hud / warehouse / available_modules / craft / recipes / victory plan 等本地化键）的译文不得出现在页面任意 Label 中；这些键必须仍被本地化，键被删时用例应失败而不是静默通过。`_body` 子节点数恒为 3。
- 模块状态徽标：健康船不出现「状态 NN%」；对锅炉实例造成 50% 损耗后重建船厂页，锅炉槽位卡出现 `ui.label.status` 50% 徽标（条件值来自 shipyard.view 的 condition，不在页面计算）。

模块索引：[framework/tests](../README.md)
