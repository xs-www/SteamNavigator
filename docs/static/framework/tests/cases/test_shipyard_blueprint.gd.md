# `framework/tests/cases/test_shipyard_blueprint.gd`

> 作用：船厂改装蓝图（P2b / P2a）回归套件：只画侧视图、槽位圆点/折线/模块方框布局、无锚点回退、武器贴片单视图、模式隔离与高亮联动。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L18 |
| `SHIPYARD_SCREEN_SCRIPT` | L19 |
| `SHIP_VIEW_SCRIPT` | L20 |
| `SLOT_TARGET_SCRIPT` | L21 |
| `STEADY_BUILD` | L22 |
| `SYNTHETIC_STAGE_SIZE` | L24 |
| `CORE_HULL_IDS` | L25 |
| `EXPECTED_ANCHOR_KEYS` | L32 |
| `test_cutaway_draws_only_the_side_view() -> void` | L137 |
| `test_every_slot_and_weapon_has_an_anchor_dot_inside_the_side_view() -> void` | L168 |
| `test_module_chips_never_overlap_and_stay_inside_the_side_view() -> void` | L212 |
| `test_content_without_slot_anchors_falls_back_without_crashing() -> void` | L245 |
| `test_mode_isolation_hides_one_group_and_refuses_its_drops() -> void` | L270 |
| `test_highlight_slots_marks_dots_chips_and_weapon_patches() -> void` | L316 |
| `test_all_core_hulls_lay_their_blueprint_chips_out_cleanly() -> void` | L402 |
| `test_small_panel_falls_back_to_a_non_overlapping_layout() -> void` | L418 |

覆盖 `.design/refit_round2_plan.md` 的 P2b 契约与 Lead 补充的 P2a 蓝图侧隔离：
- CUTAWAY 有 `blueprint_views` 时只画 side（top 不再占 48% 高度，仅保留可计算坐标）；
- 每个槽位（普通模块 + 舰载武器）在内容 `slot_anchors` / `weapon_sockets[].blueprint.side`
  的位置画圆点，圆点用折线连到贴片方框；
- 普通模块方框贴着锚点摆放（可拖放、高亮联动、互不重叠、不出界），不再固定底部 dock；
- 无 `slot_anchors` 的内容回退到通用面板锚点且不崩；
- `set_module_chips_visible(false)` / `set_weapon_patches_visible(false)` 做模式隔离
  （目标不可见、不接受拖放）。

真实 shell + 船厂页夹具（与 test_shipyard_refit 同一路径）；4 艘 Core 船的
侧视锚点布局用独立 `SNShipView` 覆盖，避免只测到开局小船。

模块索引：[framework/tests](../README.md)
