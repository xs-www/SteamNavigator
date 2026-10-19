# `framework/tests`

> 无头测试与冒烟脚本。覆盖加载链、确定性、经济、航行、委托刷新、仓库存取、打造订单/替换/在港等待、UI 外壳接线与完整通关流程。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `cases/test_contract_flow.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_contract_refresh.gd` | 迭代 1 委托池测试：抵达刷新、持有上限、port.view 字段与同 seed 刷新确定性。 | [查看](./cases/test_contract_refresh.gd.md) |
| `cases/test_craft_wait.gd` | 迭代 2 打造订单测试：tier1 仅金币配方、下单不即时入库、port.wait/抵达结算与旧存档补齐。 | [查看](./cases/test_craft_wait.gd.md) |
| `cases/test_events_effects.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_full_clear.gd` | MVP 完整通关验收：脚本化玩家完成五段主线、中期升级、大型船组装并触发通关。 | [查看](./cases/test_full_clear.gd.md) |
| `cases/test_map_constraints.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_market_memory.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_market_trade.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_mod_loading.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_no_core_ids.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_patches.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_registry.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_rng.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_run_pipeline.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_save_load.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_schema_validator.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_semver_range.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_settings.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_ship_upgrade.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_supply.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_ui_shell.gd` | 迭代 2 主界面接线测试：把真实外壳场景挂进场景树，断言六条反馈在界面构建路径上真的生效，并守护通报文案的本地化。 | [查看](./cases/test_ui_shell.gd.md) |
| `cases/test_ui_views.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_victory.gd` | 迭代 1 通关测试：门槛、幂等颁奖、summary 完整性与安装触发。 | [查看](./cases/test_victory.gd.md) |
| `cases/test_warehouse_craft.gd` | 迭代 1 船只系统测试：仓库存取、transit 重量、材料打造、免费安装、替换/卸下、合同解锁与失败原子性。 | [查看](./cases/test_warehouse_craft.gd.md) |
| `cases/test_zip_pack.gd` | 按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。 | 本页 |
| `smoke_load.gd` | 手动冒烟：加载 Core 并打印启动报告。 | 本页 |
| `smoke_play.gd` | 手动冒烟：开局、预览、出航、事件选择。 | 本页 |
| `test_case.gd` | 测试断言与 Core bootstrap 辅助。 | 本页 |
| `test_runner.gd` | 无头测试发现、执行、汇总与退出码；首个渲染帧上运行，使 UI 套件能把外壳场景真正挂进场景树。 | 本页 |

## 模块契约

- 测试入口：`godot --headless --path . --script res://framework/tests/test_runner.gd`。
- `test_case.gd` 提供断言与 Core 启动辅助；每个用例独立 bootstrap。
- 测试源码可以引用 `core:*` ID；`test_no_core_ids.gd` 只扫描非测试框架代码。
- `test_full_clear.gd` 通过公开命令/查询脚本化跑完五段主线并组装大型船，覆盖 9 个 seed。
