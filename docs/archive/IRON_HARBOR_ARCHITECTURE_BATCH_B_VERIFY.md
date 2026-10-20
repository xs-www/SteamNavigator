# 铁港建筑套件 · 批次 B 最终独立终验（资产 / 两港组合接线 / 实测 / 文档 / 测试）

> 验收对象：批次 B 最终交付（task-9 产物）——三栋新原型 `SN_HT_Boiler_House` / `SN_HT_Workshop_Row` /
> `SN_HT_Brick_Tenement` 的 LOD0+LOD1、两港（iron_harbor / spice_port）组合接线、组合截图、实测、包体、文档。
> 依据：[MODELING_REQUIREMENTS_NEXT_BATCH.md](MODELING_REQUIREMENTS_NEXT_BATCH.md) §6.4 / §8 / §9 / §11.3、
> Builder 报告 [IRON_HARBOR_ARCHITECTURE_BATCH_B.md](IRON_HARBOR_ARCHITECTURE_BATCH_B.md)。
> 独立 Verifier 只读复算（自写 GLB 解析器、内容 JSON 解析、窗口模式 Godot 实测与独立截图、headless 测试）。
> 日期：2026-10-20 · verifier-a（task-10）

## 0. 总判定

**PASS（批次 B 范围内 0 FAIL）**，另有 **1 项外部工作流阻塞**（完整测试 / release / 静态文档，非批次 B 问题，见 §6）
与 **5 项 NIT**（见 §8）。批次 B 自身资产、接线、组合、实测、包体、文档全部独立复算通过：

| 检查面 | 独立结果 | 判定 |
| --- | --- | --- |
| 6 个新 GLB 结构（tri/根节点/材质槽/外部 URI/PNG/tile 逐字节/LOD bbox/zmin/尺寸） | 6/6 全 PASS（0 failure） | ✅ |
| manifest 6 新键 + 文件存在、资产键 80→**86** | 6/6 键存在、86 assets | ✅ |
| 两港接线（iron_harbor=WR+BH、spice_port=WR+BT；其余三港旧 5 栋） | archetype 内容解析 + stage_host 测试 30/30 + 实机 `[asset]` 自证 | ✅ |
| 两组 5 栋组合截图 + combo_old（1440×900 / 960×540） | 6/6 存在；独立重拍与 docs 版本像素均差 0.10–0.16（同场景同接线） | ✅ |
| 松散 / ZIP 实测一致、draw/batch/tri 预算 | combo_a 72 draws/42 batches/75 376 tri；combo_b 71/41/72 144；ZIP 同值 | ✅ |
| 包体 | 新 6 GLB 1 959 732 B（1.96 MB）；12 共享 PNG 2 029 753 B（2.03 MB）；8 栋 6 273 453 B（6.27 MB）；core zip 6 649 741 B（6.65 MB，128 files） | ✅ |
| A 批 10 GLB 回归 | 10/10 sha256 与 task-5 记录完全一致 | ✅ |
| 完整测试套件 | 188 passed / 4 failed / 192，**4/4 均外部海图工作流**（非批次 B）；B 子集 **49/0** | ⚠ 外部阻塞 |
| `gen_static_docs --check` | **stale（2 个生成文档）**——由并发工作流 22:30–22:32 改测试文件导致（生成于 22:29:22），非批次 B 源 | ⚠ 外部阻塞 |

## 1. 方法与只读边界

| 项 | 内容 |
| --- | --- |
| 工具 | `.design/verify_b/glb_check_b.py`（独立 GLB 解析：tri/根节点/材质/外部 URI/glTF aabb/PNG 字节）、`port_archetypes.json` 解析、窗口 Godot `measure_port_stage.gd` 实测、`capture_b.gd`（复制自 `capture_port_stage_res.gd`，输出改到 `.design/verify_b/out/captures/`，不覆盖 docs）、headless `test_runner.gd`、`gen_static_docs.mjs --check` |
| 只读 | 未改场景/源码/资产/manifest/文档；窗口截图只写 verifier 目录；未读 Blender（GLB+内容+实测已覆盖，工作台快照仅核对存在性） |
| 边界 | 并发「海图 phase 2」工作流的 `sn_sea_chart_panel.gd` / `test_world_generator.gd` / `test_sea_chart.gd` / `world_generator.gd` 改动不属于批次 B，不纳入判定 |

## 2. 6 个新 GLB（独立解析，0 failure）

| 资产 | LOD0 tri | LOD1 tri | LOD1 上限 / 占比 | LOD0↔LOD1 bbox（Blender 序） | zmin | 根节点 | 材质槽 | 外部 URI / tile |
| --- | ---: | ---: | --- | --- | ---: | --- | --- | --- |
| `SN_HT_Boiler_House` | **7 388** | **2 536** | 2 800 / **34.3%**（≤35%） | 12.00×10.00×12.00 → 12.00×10.00×12.00（Δ0.000） | 0 | 1 | 6（用 5，全 `SN_Town_*`） | 5 URI，PNG 逐字节=brick_wall_soot/wood_plank_weathered/iron_rust/stone_base_dirty/glass_dark |
| `SN_HT_Workshop_Row` | **7 312** | **2 444** | 2 800 / **33.4%** | 18.00×7.00×8.50 → 18.00×7.00×8.50（Δ0.000） | 0 | 1 | 6（用 5） | 5 URI，tile 逐字节一致 |
| `SN_HT_Brick_Tenement` | **9 376** | **2 704** | 4 900 / **28.8%** | 10.00×8.00×12.00 → 10.00×8.00×12.00（Δ0.000） | 0 | 1 | 6（用 5） | 5 URI，tile 逐字节一致 |

- glTF（Y-up）轴向尺寸复算：BH 12.00×12.00×10.00、WR 18.00×8.50×7.00、BT 10.00×12.00×8.00（与任务书一致）。
- **共享贴图池 12 张**（新增 `brick_wall_soot.png` 144 880 B，其余 11 张复用批次 A）：12/12 与
  `docs/design/textures/iron_harbor/tiles/` 对应文件 **sha256 逐字节一致**；6 个 GLB 引用的 URI 全部命中该池。
- 独立结果与 Builder `b4/structure_verify.json` 的 6/6 PASS 一致（该文件仅作对照，未采信）。

## 3. manifest / 包体 / A 批回归

- `dev_mods/core/manifest.json`：assets **86**（批次 B 前 80，+6）；6 个新键（`model.prop.{boiler_house,workshop_row,brick_tenement}` 与各自 `_lod1`）全部存在且文件大小与磁盘一致。
- 包体（十进制 MB，与 Builder 报告口径一致）：
  - 新 6 GLB **1 959 732 B（1.96 MB）**；12 张共享 PNG **2 029 753 B（2.03 MB）**；
  - 8 栋建筑 = A 批 10 GLB（LOD0 1 895 364 B + LOD1 388 604 B）+ 新 6 GLB + 12 PNG = **6 273 453 B（6.27 MB）**；
  - `dist/mods/core-1.0.0.snavmod.zip` = **6 649 741 B（6.65 MB），128 files**，含 6 新 GLB 与 12 张共享 PNG。
- **A 批回归**：`SN_HT_{Warehouse_Long,Warehouse_Short,Harbor_Office,Cargo_Shed,Tavern}` × {LOD0,LOD1} 共 10 个
  GLB 的 sha256 与 task-5 验收记录**完全一致（10/10）**；旧占位/其它对象未在内容层改动（manifest 仅 +6 键）。

## 4. 两港组合接线

- `dev_mods/core/content/port_archetypes.json` 独立解析：
  - `core:port_archetype/iron_harbor`：`warehouse_long → model.prop.workshop_row`、`tavern → model.prop.boiler_house`；
  - `core:port_archetype/spice_port`：`warehouse_long → model.prop.workshop_row`、`harbor_office → model.prop.brick_tenement`；
  - `free_town` / `fishing_village` / `glass_port`：**0 个 prototype 槽位**（保持旧 5 栋）。
- `framework/ui/stages/port_stage.gd` 的 `TOWN_SLOTS` 5 槽位位置/朝向/scale 与批次 A 终态一致（**布局未改**，仅换资产）。
- `port.town_visuals` 解析链：`test_stage_host` **30/30 passed**（含 town_visuals / 资产解析断言）；
  实机截图自证行逐个打印 8 栋 `[asset]`（如 `SN_HT_Workshop_Row.glb slot=warehouse_long tris=7312`,
  `SN_HT_Boiler_House.glb slot=tavern tris=7388`, `SN_HT_Brick_Tenement.glb slot=harbor_office tris=9376`），
  surfaces=uv_surfaces=textured_surfaces、6×512² 贴图加载成功。

## 5. 组合截图与实机实测（独立重跑）

**实测**（窗口 Godot，`measure_port_stage.gd`；独立执行，非引用 Builder 数字）：

| 组合 / 路径 | draws preview/sparse/market/harbor/supply | batches | 整帧 tri | draw_meshes | 建筑 tri 合计 |
| --- | --- | ---: | ---: | ---: | ---: |
| combo_a 松散 | 72 / 65 / 65 / 72 / 70 | **42** | **75 376** | 74 | 32 180 |
| combo_a `--core-zip` | 72 / 65 / 65 / 72 / 70 | **42** | **75 376** | 74 | 32 180 |
| combo_b 松散 | 71 / 64 / 63 / 71 / 69 | **41** | **72 144** | 73 | 28 948 |

- 建筑 tri 合计独立复算：combo_a = WR 7 312 + BH 7 388 + Office 10 336 + Short 3 788 + Shed 3 356 = **32 180**；
  combo_b = WR 7 312 + Short 3 788 + BT 9 376 + Shed 3 356 + Tavern 5 116 = **28 948**（均 ≤60 000）。
- LOD1 组合复算：combo_a 8 712 tri、combo_b 8 232 tri（≤20 000）；三栋新原型 LOD1 合计 7 684。
- **松散 = ZIP 完全一致**（draws/batches/tri/draw_meshes 同值），且 ZIP 路径下共享贴图仍合批
  （draw_meshes 74 ≤75 目标、≤80 硬上限）。
- 与 Builder 报告差异：报告的 combo_a `draw_meshes=75`，我方重跑为 **74**（同为 ≤75；其余 draws/batches/tri 完全一致）。

**组合截图**：`docs/design/screenshots/iron_harbor_architecture/SN_HT_Warehouse_Long_LOD0_combo_{a,b,old}_port_stage_{1440x900,960x540}.png` 6/6 存在且非空。
- 独立纠偏：用当前接线重拍 combo_a 1440×900、combo_b 960×540 到 `.design/verify_b/out/captures/`，
  与 docs 版本像素平均差 **0.101 / 0.157**（>8 级差异像素 0.23% / 0.21%）→ docs 截图确由当前接线生成、非旧图复用。
- 目视（1440 与 960 两档）：combo_a 可见 WR 锯齿玻璃顶 + BH 高烟囱/外露管；combo_b 可见 WR 锯齿顶 + BT 窄高三层
  砖楼+3 烟囱+逃生梯；两组合与 combo_old 明显不同（不靠颜色靠轮廓）；建筑间距与批次 A 相同、未见互相穿插，
  未见压住玩家船/市场摊位/船吊（船在左、市场居中、建筑在后排）。

## 6. 测试 / 静态文档（外部工作流阻塞，非批次 B FAIL）

- 完整 headless 套件：**188 passed / 4 failed / 192 total**（38.2 s）。4 个失败全部落在并发「海图 phase 2」工作流：
  1. `test_ui_shell::test_sea_chart_entry_integration` —— 依赖 `framework/ui/components/sn_sea_chart_panel.gd`（该文件 Parse Error，外部未完成）；
  2. `test_no_core_ids::test_framework_has_no_concrete_core_ids` —— 报 `domain/world/world_generator.gd` 硬编码 `core:*`（外部工作流文件）；
  3. `test_world_generator` 套件加载失败 —— `framework/tests/cases/test_world_generator.gd:174` Parse Error（外部，22:32:31 修改）；
  4. `test_sea_chart` 套件加载失败 —— 依赖同一 `SNSeaChartPanel`（外部）。
- **批次 B 相关子集**（mod_loading / content_asset_loader / stage_host / ui_views / run_pipeline）独立统计
  **49 passed / 0 failed**（4+5+30+6+4），与 Lead/Builder 数字一致。
- `gen_static_docs --check`：**stale（2 changed path(s)）**——`framework/tests/README.md` 与 `manifest.json`（ledger）。
  原因可定位：静态文档生成于 **22:29:22**，而并发工作流在 **22:30:55 / 22:32:31** 改了
  `framework/tests/scratch_runner.gd` / `test_world_generator.gd`，导致 tests 模块 README 与 hash ledger 过期；
  批次 B 自身新增生成器（`sn_iron_harbor_prototypes_generator.py` 等）的静态文档已生成且不在 stale 列表。
- 结论：测试全绿 / release 可启动 / 静态文档 up-to-date 三项**需外部海图工作流修复后重跑**，本报告不作为批次 B FAIL。

## 7. 文档一致性复核

| 文档 | 复核结果 |
| --- | --- |
| `IRON_HARBOR_ARCHITECTURE_BATCH_B.md` | tri/LOD1/尺寸/bbox/结构/包体/draw/tri 数字与独立复算一致；§6 外部阻塞描述与实测一致；§8 未闭合项准确 |
| `ASSET_MAP.md` §批次 B | 三栋尺寸/tri/LOD1 上限、组合接线（WR+BH / WR+BT）、截图与实测数字与复算一致 |
| `todo.md` §批次 B | 三栋 tri/LOD1/bbox/健康/§6 与外部阻塞条目已更新 |
| `PROTOTYPES_LOD0_BUILD/VERIFY` | 已存在且与 stage 实机自证一致（tri 7 388/7 312/9 376） |
| 静态文档 | 见 §6（外部 stale）；批次 B 新增文件文档已生成 |

## 8. NIT / 说明（不影响 PASS 判定）

1. **任务书 task-9 描述与终态不一致**：任务书写 iron_harbor `warehouse_short→boiler_house`，实际实现/内容/Lead 终态为
   `tavern→boiler_house`（组合 a = WR/BH/Office/Short/Shed）。实现与 ASSET_MAP 一致，建议同步任务书措辞。
2. **report combo_a draw_meshes=75 vs 实测 74**（差 1，均 ≤75 目标；draws/batches/tri 一致）。
3. **`b4/legacy/` 为空**（Builder 报告称旧内容备份到该目录）；因 A 批 10 GLB 经 sha256 验证零改动、无需回滚内容，
   属报告措辞问题，建议补一句「旧资产未改动，legacy 目录无需内容」。
4. **`gen_static_docs --check` 当前 stale**：外部工作流修复后需重跑一次（预计很快）。
5. **`test_no_core_ids` 失败**指向 `domain/world/world_generator.gd` 硬编码 core id（外部），批次 B 未新增此类调用
   （新增代码仅 generator/导出/文档与内容 JSON，均不进入 framework 运行时）。
6. 完整测试/release 未由本 Verifier 独立复跑：release 启动 fatal 为已知外部 `sn_sea_chart_panel.gd` Parse Error，
   按 Lead 指示归为外部阻塞；修复后需重跑并补一次 release 启动证据。
7. 组合截图为 preview 场景（`SN_TOWN_COMBO`）实机渲染，未做游戏内正式入口（主菜单→港口）点击流验证；该链路由
   `test_ui_views`/`test_stage_host` 49/0 间接覆盖，正式启动仍待 release 修复后人工确认。

## 9. 复现命令

```powershell
# GLB / manifest / 贴图池 / 包体 / A 批 sha 回归（纯 Python，0 failure）
python .design/verify_b/glb_check_b.py

# 实机实测（窗口模式；combo_a 松散 / combo_b 松散 / combo_a ZIP）
$env:SN_TOWN_COMBO='a'; godot --path . --script res://tools/godot/measure_port_stage.gd
$env:SN_TOWN_COMBO='b'; godot --path . --script res://tools/godot/measure_port_stage.gd
$env:SN_TOWN_COMBO='a'; godot --path . --script res://tools/godot/measure_port_stage.gd -- --core-zip=dist/mods/core-1.0.0.snavmod.zip

# 独立组合截图（输出到 .design/verify_b/out/captures/，不覆盖 docs）
$env:SN_TOWN_COMBO='a'; godot --path . --script res://.design/verify_b/godot/capture_b.gd -- 1440 900 LOD0 combo_a
$env:SN_TOWN_COMBO='b'; godot --path . --script res://.design/verify_b/godot/capture_b.gd -- 960 540 LOD0 combo_b

# 测试 / 静态文档
godot --headless --path . --script res://framework/tests/test_runner.gd
node tools/gen_static_docs.mjs --check
```

## 附录 · 证据文件（`.design/verify_b/out/`）

`glb_check_b.json` / `.log`、`measure_combo_a_loose.log`、`measure_combo_b_loose.log`、
`measure_combo_a_zip.log`、`capture_combo_{a,b}.log`、`captures/`（独立重拍 PNG）、`test_full.log`；
内容与架构依据：`dev_mods/core/manifest.json`、`dev_mods/core/content/port_archetypes.json`、
`dev_mods/core/assets/models/props/iron_harbor_shared/`、`dist/mods/core-1.0.0.snavmod.zip`。
