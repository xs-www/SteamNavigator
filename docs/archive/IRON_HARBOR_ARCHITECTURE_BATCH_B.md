# 铁港建筑套件 · 批次 B 验收（三栋新原型 LOD0+LOD1 + 两港组合接线）

> 需求：MODELING_REQUIREMENTS_NEXT_BATCH.md §6 / §8 / §9；前置：批次 A 验收（LOD1+共享贴图）、[PROTOTYPES_LOD0_BUILD](IRON_HARBOR_ARCHITECTURE_PROTOTYPES_LOD0_BUILD.md)、[PROTOTYPES_LOD0_VERIFY](IRON_HARBOR_ARCHITECTURE_PROTOTYPES_LOD0_VERIFY.md)。日期：2026-10-20。

> **人工视觉门禁：通过（2026-10-21，用户确认 A/B/C 截图）**。

## 0. 判定摘要
| 项 | 目标 | 实测 | 判定 |
| --- | --- | --- | --- |
| BH / WR / BT LOD0 tri | 6000–7500/8000；6000–7500/8000；9000–12000/14000 | **7388 / 7312 / 9376** | PASS |
| LOD1 tri | ≤2800 / 2800 / 4900 且 ≤35% | **2536(34.3%) / 2444(33.4%) / 2704(28.8%)** | PASS |
| 尺寸 | 12×10×12 / 18×7×8.5 / 10×8×12（±0.10） | 误差 0.000 | PASS |
| bbox/轴心 | LOD1↔LOD0 逐轴 ≤0.02、zmin=0、底面中心 | 0.000 / 0 / (0,0) | PASS |
| 网格健康 | 全 0 | 6/6 全 0 | PASS |
| §6 必须包含项 | 逐栋清单 | 3/3 全 PASS（几何检测+目视） | PASS |
| 组合变化 | ≥2 组 5 栋组合、不只靠颜色 | combo_a / combo_b / combo_old 三套 1440+960 | PASS |
| 包体 | 新原型 6 GLB + 共享贴图 | 1.96 MB + 2.03 MB（12 张，新 tile 仅 brick_wall_soot） | PASS |
| 运行时 draw/tri | 建筑 tri ≤60k；LOD1 组合 ≤20k | combo_a 75,376 整帧（建筑 32,180）；combo_b 72,144（建筑 28,948）；LOD1 7,684 | PASS |
| 加载路径 | 松散 / ZIP 一致 | 两组合均一致（见 §4） | PASS |
| 测试/发布包 | 全绿 / 可启动 | **被并发海图工作流阻断**（见 §6） | 阻塞（非本批） |
| 人工视觉门禁 | §10 | 组合截图与 960×540 已交付；verifier 独立重拍比对像素差 0.10/0.16 | 待确认 |

## 1. 三栋新原型
| 资产 | 尺寸(m) | LOD0 tri | LOD1 tri | LOD1 上限 | 比例 | GLB LOD0/LOD1 |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| SN_HT_Boiler_House | 12×10×12 | 7 388 | 2 536 | 2 800 | 34.3% | 450 076 / 157 504 B |
| SN_HT_Workshop_Row | 18×7×8.5 | 7 312 | 2 444 | 2 800 | 33.4% | 442 008 / 143 464 B |
| SN_HT_Brick_Tenement | 10×8×12 | 9 376 | 2 704 | 4 900 | 28.8% | 594 100 / 172 580 B |
| 合计 | — | 24 076 | 7 684 | 10 500 | 31.9% | 1 959 732 B |

- 结构检查 `verify_iron_harbor_prototypes_glb.py` 6/6 PASS：单根节点、5 材质槽（全 SN_Town_*）、外部共享 URI、tile 逐字节一致、LOD bbox 一致。
- 共享贴图 12 张合计 2 029 753 B（新增 `brick_wall_soot.png` 144 880 B；其余 11 张复用批次 A）。8 栋建筑几何 4 243 700 B + 共享贴图 2 029 753 B = **6 273 453 B（6.27 MB）**；core zip **6 649 601 B（6.65 MB，128 files）**。

## 2. 组合接线（§6.4）
- manifest 新增 6 键（3 LOD0 + 3 LOD1），资产键 80→86。
- `iron_harbor`：`warehouse_long→workshop_row`、`tavern→boiler_house`（WR + BH）；
- `spice_port`：`warehouse_long→workshop_row`、`harbor_office→brick_tenement`（WR + BT）；
- 其余三港保持原 5 栋（对照）；PortStage 5 个建筑槽与布局不变，只换资产。
- 组合 a = WR/BH/Office/Short/Shed；组合 b = WR/Short/BT/Shed/Tavern；combo_old = 原 5 栋。

## 3. PortStage 实测
| 组合 | draw_meshes(preview/harbor) | draws preview/sparse/market/harbor/supply | batches | 整帧 tri | 建筑 tri |
| --- | --- | --- | ---: | ---: | ---: |
| combo_old | 73 | 71/64/65/71/69 | 41 | 73 228 | 30 032 |
| combo_a | 74 | 72/65/65/72/70 | 42 | 75 376 | 32 180 |
| combo_b | 73 | 71/64/63/71/69 | 41 | 72 144 | 28 948 |
- 均无 blockout（5 栋全部命中）、无黑材质/丢贴图；两组 `[asset]` 行逐栋自证 8 个 GLB 结构与 tri。

## 4. 加载路径
| 路径 | combo_a | combo_b |
| --- | --- | --- |
| 松散 dev_mods | 72/65/65/72/70，batches 42，tri 75 376 | 71/64/63/71/69，batches 41，tri 72 144 |
| 挂载 core zip（`--core-zip`） | **完全一致** | **完全一致** |
- 修复了 ZIP 模式下 combo 原型路径必须跟随 `SN_TOWN_ASSET_ROOT` 的问题（否则新旧建筑贴图来自不同根、共享实例失效会多 9 个批次）。

## 5. 截图与人工门禁材料（§10）
- 组合：`docs/design/screenshots/iron_harbor_architecture/SN_HT_Warehouse_Long_LOD0_combo_{a,b,old}_port_stage_{1440x900,1280x720,960x540}.png`。
- 单栋：Builder 交付 LOD0 10 张 + LOD1/对比 18 张（`SN_HT_<Name>_LOD0/LOD1_*` 与 `_LOD1_vs_LOD0_*`）；Verifier 独立剪影/960 代理图 `.design/verify_b/out/proxy_960_prototypes.png`、`silhouettes_b.png`。
- 人工需确认：两组组合在 1440/960 下能凭轮廓区分（WR 锯齿顶、BH 高烟囱+管线+平台、BT 窄高街屋+逃生梯+多烟囱）；无穿插/遮挡玩家船与招牌热点。

## 6. 外部阻塞（非批次 B 问题）
仓库同时存在**并发的「海图 phase 2」工作流**，其未完成代码导致：
- release 导出启动 fatal：`sn_sea_chart_panel.gd` Parse Error（release 日志 `status: fatal`）；
- 完整测试套件无法全绿：192 total（部分 sea chart 套件加载失败）+ 4 failures，含 `test_ui_shell::test_sea_chart_entry_integration`、`test_no_core_ids::test_framework_has_no_concrete_core_ids`。
- 批次 B 相关子集（mod_loading / content_asset_loader / stage_host / ui_views / run_pipeline）独立跑 **49 passed / 0 failed**；`gen_static_docs --check` up to date。
- 待海图 workstream 稳定后需重跑：完整测试套件、release 导出+启动（预计单独一次 2–3 分钟）。

## 7. 交付物（§8）
生成器/LOD1/干跑/导出/结构检查脚本均在 `tools/modeling/generators/`；运行时 6 GLB + 共享贴图已装入 core；工作台快照 `.design/SN_Asset_Workbench.blend`（16 个套件对象，旧快照备份 `b4/SN_Asset_Workbench_pre_batch_b_20261020.blend`）；报告：本文件 + PROTOTYPES_LOD0_BUILD（§13 LOD1）/PROTOTYPES_LOD0_VERIFY；ASSET_MAP/todo/README/静态文档已同步。

## 8. 未闭合
1. 并发海图工作流修复后重跑完整测试与 release 包（见 §6）。
2. 人工视觉门禁（§10）：两组组合截图确认。
3. Verifier 终验（task-10）待执行。
4. NIT：BT 侧门门扇面深 0.10 m（开口进深 0.18 达标）；BT 第 3 烟囱 11.23 m；WR↔Long 剪影相似度 0.861、BT↔Office 0.892（均低于 0.92 阈值，需人工确认）。
