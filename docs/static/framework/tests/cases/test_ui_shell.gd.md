# `framework/tests/cases/test_ui_shell.gd`

> 作用：迭代 2 主界面接线测试：把真实外壳场景挂进场景树，断言六条反馈在界面构建路径上真的生效，并守护通报文案的本地化。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_dense_screen_fields_keep_horizontal_minimum_widths() -> void` | L162 |
| `test_stats_bar_shows_the_current_port_and_remaining_capacity() -> void` | L193 |
| `test_victory_plan_explains_how_to_clear_the_mvp() -> void` | L254 |
| `test_shipyard_order_and_port_wait_make_time_move() -> void` | L293 |
| `test_supply_screen_paints_the_lost_capacity_band() -> void` | L329 |
| `test_intel_screen_renders_the_port_comparison_table() -> void` | L359 |
| `test_notice_log_renders_filled_localized_text() -> void` | L406 |
| `test_every_pushed_notice_key_is_localized_in_both_languages() -> void` | L462 |

## 契约与约束

- 首帧运行器让 `_ready` 正常投递，因此控件树（含 SNSectionHeader 等自行构建子节点的组件）与游戏内一致。
- 覆盖信息条（当前港口 + 剩余载重/剩余舱容，反馈 5）、通关清单与两种提示分支（反馈 6）；期望值独立复算（RegistryHub 翻译 + ShipOps 重量/舱容 + printf），不使用被测 helper 自证。
- 覆盖船厂下单按钮 → CraftOps 订单 → 24 小时在港等待按钮 → 时间推进与成品入下单港仓库（反馈 4，经由真实按钮 pressed 信号）。
- 场景接线断言覆盖独立总览、市场、委托、船厂、补给、情报、出航页面及四个菜单页面；船厂流程从 ShipyardScreen 的真实按钮驱动。
- 流程场景接线覆盖港口记忆、抵达结算、航行中、航行事件与通关总结，逐一调用 Shell 构建入口并按脚本类型断言实例。
- 覆盖设置/总览/市场/船厂密集字段禁用自动换行、市场单元格最小宽度，以及情报矩阵固定元数据列、可扩展港口列、最小列宽和深色单元格背景。
- 覆盖补给页损失带：买煤后水的 meter.loss_value/cap_loss 与 baseline 跨度（反馈 2）、情报页 SNIntelTable 与未知港口掩码（反馈 3，列数对照 MapOps.ports）。
- 覆盖「航行记录」：真实下单 + 等待后在 zh 与 en 两种 locale 下逐行断言通报无 `%s/%d` 残留、无裸键，并与**逐语言写死的期望句子**相等（模板槽位互换照样能渲染，只有字面期望能抓住「某一种语言的文案说反了」；en 只写错顺序时该用例会失败）。
- 扫描 domain/application 源码里所有 `push_notice("…")` 字面量：每个键在 framework 或 core 的 zh_CN/en 中恰好被一套定义，两套 locale 的键集合与**保序**槽位序列一致；槽位多于一个的键必须出现在用例的逐语言字面期望清单里。
- 组件按路径 preload，不依赖编辑器全局类缓存。

模块索引：[framework/tests](../README.md)
