# LOD1 基础套件验收（M0-5：kit 26 件 + 4 艘可玩船）

> 状态：Accepted（2026-10-22）
> **2026-10-22 交付后变更**：铁甲舰舷侧炮拆出为独立模块（casemate 批次，见 [CASEMATE_GUN_ACCEPTANCE.md](CASEMATE_GUN_ACCEPTANCE.md)），LOD0 **8 830 → 8 158 tri**；本文件保留 M0-5 交付时快照，受影响的合计口径为：船组合计 **45 968 → 45 296**、30 件合计 **88 026 → 87 354**（LOD1 资产与各件 LOD1 tri 未变；IC LOD1 仍是拆炮前旧件）。
> 对应 backlog：`M0-5`（[MODELING_BACKLOG.md](../design/MODELING_BACKLOG.md) §2）
> 相关：[ASSET_MAP.md](../design/ASSET_MAP.md#lod1-基础套件m0-52026-10-22)（LOD1 总表） · [KIT_ASSET_LIBRARY.md §11](../design/KIT_ASSET_LIBRARY.md)（派生契约 / 工具链） · [2.5D_STAGE_PLAN.md](../design/2.5D_STAGE_PLAN.md) · [todo.md](../../todo.md)
> 前置：铁港建筑 LOD1（8 栋 × LOD0/LOD1 = 16 个 GLB，批次 A 5 栋 + 批次 B 3 栋）已在批次 A/B 交付，见 [IRON_HARBOR_ARCHITECTURE_BATCH_A.md](IRON_HARBOR_ARCHITECTURE_BATCH_A.md)。本文件只覆盖 M0-5 剩余 **30 件**（kit 26 + 船 4）。

## 1. 判定摘要

| 判定项 | 目标 | 实测 | 判定 |
| --- | --- | --- | --- |
| 交付范围 | kit 26 件 + 4 艘可玩船的远景低模 | **30/30** 已安装并验收通过（kit 26 + 船 4） | PASS |
| kit LOD1 三角面 | ≤ LOD0 × 35 % | **10 824 / 42 058 = 25.7 %**（逐件 20.8 %–30.4 %，全部 ≤ 各自上限） | PASS |
| 船 LOD1 三角面 | ≤ LOD0 × 30 % | **9 026 / 45 968 = 19.6 %**（逐艘 18.8 %–20.6 %） | PASS |
| 合计三角面 | — | **19 850 / 88 026 = 22.6 %** | PASS |
| LOD0↔LOD1 世界包围盒 | 逐轴一致 | 逐件逐轴 **0.000 m**（复算最大 1×10⁻⁶ m，容差 0.02 m） | PASS |
| 结构 | 单根节点 + 单 mesh | 30/30，根节点名 `<Asset>_LOD1` | PASS |
| 材质 / UV | 只用 `SN_Tex_*` 共享材质，每个图元有 UV | 30/30（16 项结构 check 全 true） | PASS |
| 外部贴图 | `shared_materials/*.png` 与授权 tile 逐字节一致 | **175 个 image 引用 → 11 张 PNG**，全部字节一致 | PASS |
| 网格健康（kit） | 边界边 / 非流形 / 退化面 / 孤立点 = 0 | 26/26 全 0（LOD1 复算） | PASS |
| 网格健康（船） | LOD1 不高于 LOD0 | 边界边 PF 102→71 / PS 54→43 / SF **1 306→996** / IC 0→0；非流形 / 退化 / 孤立点 0 | PASS |
| 交付体积 | — | **2 172 008 B**（kit 1 236 344 / 船 935 664，外部共享贴图） | 记录 |
| 资源登记 | 船 4 个 manifest 键 + kit 目录 LOD1 段 | manifest `model.ship.*_lod1` 4/4 路径一致；`kit_catalog.json` v1.3 含 26 件 `lod1` 块 | PASS |
| Godot 运行时 | 加载 / UV / 贴图 / 回归 | 探针 **30 件 / 67 个共享贴图实例 / 0 失败**；全量测试 **391 passed / 0 failed**（含新增 3 例） | PASS |

## 2. 范围口径（M0-5 = 约 38 个 LOD1 → 本批补 30 件）

M0-5 原文清单为「kit 26 件 + 船 4 艘 + 铁港建筑的远景低模」。按资产盘点对账（铁港建筑为 **8 栋 × LOD0/LOD1 = 16 个 GLB**）：

| 计划项 | 实际处理 |
| --- | --- |
| kit 26 件 LOD1 | 本批交付 26 个 `SN_*_LOD1.glb`（weapons 4 / ship_parts 4 / machinery 3 / cargo 4 / dock 3 / architecture 4 / environment 4） |
| 船 4 艘 LOD1 | 本批交付 `SN_Ironclad` / `SN_Paddle_Freighter` / `SN_Paddle_Steamer` / `SN_Schooner_Fame` 的 `_LOD1` |
| 铁港建筑（8 栋） | **8 个 LOD1 / 16 个 GLB**（8 LOD0 + 8 LOD1）：批次 A 5 栋 + 批次 B 3 栋，**已在前序批次交付**，本批只作总表登记，不重复出件 |
| 合计 | 8 栋建筑 + 本批 30 件 = **38 个 LOD1 GLB**（另有 8 个建筑 LOD0 与 kit / 船 LOD0 保持原样） |

- kit 的 LOD1 **不进** Core manifest（kit LOD0 本来也未登记 manifest），登记在 `tools/modeling/kit_catalog.json` 的 `lod1` 段；船的 LOD1 进 manifest，用于运行时按资源键解析。
- 不在本批范围：LOD2 / impostor billboard（backlog `M2-5`）、运行时 LOD 切换与质量档位（见 §9）。

## 3. 交付物

| 类别 | 件数 | 运行时 GLB | Core 副本 |
| --- | ---: | --- | --- |
| weapons | 4 | `assets/models/weapons/SN_*_LOD1.glb` | `dev_mods/core/assets/models/weapons/` |
| ship_parts | 4 | `assets/models/ship_parts/SN_*_LOD1.glb` | `dev_mods/core/assets/models/ship_parts/` |
| machinery | 3 | `assets/models/machinery/SN_*_LOD1.glb` | `dev_mods/core/assets/models/machinery/` |
| cargo | 4 | `assets/models/cargo/SN_*_LOD1.glb` | `dev_mods/core/assets/models/cargo/` |
| dock | 3 | `assets/models/dock/SN_*_LOD1.glb` | `dev_mods/core/assets/models/dock/` |
| architecture | 4 | `assets/models/architecture/SN_*_LOD1.glb` | `dev_mods/core/assets/models/architecture/` |
| environment | 4 | `assets/models/environment/SN_*_LOD1.glb` | `dev_mods/core/assets/models/environment/` |
| ships | 4 | `assets/models/ships/SN_*_LOD1.glb` | `dev_mods/core/assets/models/ships/` |

- 共享贴图：30 个 GLB 的 `images[].uri` 全部指回各类别已有的 `shared_materials/<texture>.png`（8 个目录 × 11 张，外部化时 `prefer_authored=True`）；安装器逐字节比较后全部跳过写入，未新增/改动任何 PNG。
- 机器计划：`tools/modeling/lod1_kit_ships_plan.json`（30 件 tri / 比例 / 上限 / GLB 路径 / bbox / 材质 / 字节 / sha256 + 总账），由安装器生成，`gen_kit_catalog.py` 合并进 kit 目录。
- 工作台：LOD1 对象在 `SN_LOD1_Kit_Ships` 集合（y=780 一排，仅用于对比渲染），不参与运行时装配；本批未重存 `.design/SN_Asset_Workbench.blend`，收尾时已把活动场景恢复为已保存基线（见 §6 末行）。

## 4. 方法（LOD1 由 LOD0 派生）

**LOD0 是唯一几何真源**，不复制生成器参数、不手摆点；LOD1 在工作台里从 LOD0 就地派生：

1. **小件保留**：源对象 ≤ `KEEP_TRI`（20 tri）的部件原样保留，其余部件复制对象加 `Decimate(collapse)` 按预算求值；单件 ratio 下限 `MIN_RATIO` = 0.08。本批实际只命中 `SN_Dock_Structure` 的 12 个三角面小件，其余资产无 ≤20 tri 子件。
2. **预算**：目标 kit 30 % / 船 25 %，硬上限 kit 35 % / 船 30 %；逐件按 LOD0 三角面算 target / cap，再按预算分配逐件 ratio。
3. **合并单 mesh**：把 LOD0 根下全部 mesh 后代统一变换到根局部空间，累加进一个 bmesh、三角化；按材质分 primitive，**不保留 socket / pivot / 层级**。
4. **去重合面**：Decimate 会把零厚度区两壁并成一对共顶点的「pillow」面；成对删除（不是只删一张，避免开口），保持邻接拓扑、不引入边界边。
5. **材质 + UV**：先按面记录材质名，合并后去重，交给 `sn_shared_materials.apply_to_object(space="local")` 重写槽位与盒式 UV（几何不变）。
6. **包围盒钉死**：LOD1 顶点在根局部空间按 LOD0 的 x/y/z min/max 逐轴重映射，保证世界包围盒逐轴一致（远景切换不跳尺寸、轴心落地/水线不变）。
7. **导出**：逐件把对象矩阵临时置单位阵、selection-only 导出 GLB，再 `glb_shared_textures.externalize_glb(prefer_authored=True)` 把内嵌贴图换成 `shared_materials/<texture>.png`。

工具：生成器 `tools/modeling/generators/sn_lod1_kit_ships_generator.py`（`build_all()` / `report()` / `export_candidates()`）；几何读取 `glb_world_bounds.py`；干跑 `dryrun_lod1_kit_ships.py`；验收 `verify_lod1_kit_ships_glb.py`；安装 `install_lod1_kit_ships.py`；预览 `render_lod1_kit_ships_preview.py`。

## 5. 逐件结果（30 件）

| 资产 | 类别 | LOD0 tri | LOD1 tri | 比例 | 上限（35 % / 30 %） | LOD1 字节 |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `SN_Weapon_Cannon` | weapons | 1 156 | 336 | 29.07 % | 404 | 39 376 |
| `SN_Weapon_GunCarriage` | weapons | 2 256 | 596 | 26.42 % | 789 | 69 028 |
| `SN_Weapon_Turret` | weapons | 1 904 | 482 | 25.32 % | 666 | 53 144 |
| `SN_Weapon_Pedestal` | weapons | 940 | 246 | 26.17 % | 329 | 29 640 |
| `SN_ShipPart_Deck` | ship_parts | 576 | 142 | 24.65 % | 201 | 18 364 |
| `SN_ShipPart_Mast` | ship_parts | 2 764 | 780 | 28.22 % | 967 | 85 464 |
| `SN_ShipPart_Funnel` | ship_parts | 1 528 | 392 | 25.65 % | 534 | 43 876 |
| `SN_ShipPart_HatchCover` | ship_parts | 840 | 210 | 25.00 % | 294 | 28 064 |
| `SN_Machinery_GearSet` | machinery | 2 020 | 494 | 24.46 % | 707 | 54 832 |
| `SN_Machinery_Winch` | machinery | 1 776 | 498 | 28.04 % | 621 | 58 008 |
| `SN_Machinery_PowerUnit` | machinery | 2 260 | 618 | 27.35 % | 791 | 68 148 |
| `SN_Cargo_Crate` | cargo | 672 | 150 | 22.32 % | 235 | 21 248 |
| `SN_Cargo_CoalScuttle` | cargo | 588 | 146 | 24.83 % | 205 | 23 036 |
| `SN_Cargo_Tank` | cargo | 1 820 | 462 | 25.38 % | 637 | 51 908 |
| `SN_Cargo_Pallet` | cargo | 316 | 84 | 26.58 % | 110 | 14 604 |
| `SN_Dock_Structure` | dock | 1 628 | 434 | 26.66 % | 569 | 47 836 |
| `SN_Dock_Jetty` | dock | 1 660 | 468 | 28.19 % | 581 | 52 232 |
| `SN_Dock_Mooring` | dock | 940 | 286 | 30.43 % | 329 | 35 260 |
| `SN_Arch_Warehouse` | architecture | 2 704 | 626 | 23.15 % | 946 | 67 576 |
| `SN_Arch_Workshop` | architecture | 1 996 | 444 | 22.24 % | 698 | 53 484 |
| `SN_Arch_Tavern` | architecture | 2 884 | 600 | 20.80 % | 1 009 | 63 652 |
| `SN_Arch_Factory` | architecture | 3 020 | 768 | 25.43 % | 1 057 | 80 968 |
| `SN_Env_Reef` | environment | 1 944 | 556 | 28.60 % | 680 | 60 364 |
| `SN_Env_Wreck` | environment | 1 046 | 268 | 25.62 % | 366 | 34 520 |
| `SN_Env_Lighthouse` | environment | 1 952 | 482 | 24.69 % | 683 | 50 524 |
| `SN_Env_Buoy` | environment | 868 | 256 | 29.49 % | 303 | 31 188 |
| `SN_Paddle_Freighter` | ships | 12 200 | 2 507 | 20.55 % | 3 660 | 257 492 |
| `SN_Paddle_Steamer` | ships | 11 764 | 2 379 | 20.22 % | 3 529 | 245 228 |
| `SN_Schooner_Fame` | ships | 13 174 | 2 484 | 18.86 % | 3 952 | 259 832 |
| `SN_Ironclad` | ships | 8 830 | 1 656 | 18.75 % | 2 649 | 173 112 |
| **kit 小计（26 件）** | — | **42 058** | **10 824** | **25.7 %** | 14 711 | **1 236 344** |
| **船小计（4 件）** | — | **45 968** | **9 026** | **19.6 %** | 13 790 | **935 664** |
| **合计（30 件）** | — | **88 026** | **19 850** | **22.6 %** | 28 501 | **2 172 008** |

> 上表「上限」为逐件 cap tri（kit = LOD0×0.35，船 = LOD0×0.30）；小计的 cap 列为 `plan.json` 的分组预算合计。

## 6. 验收证据

| 环节 | 命令 / 产物 | 结果 |
| --- | --- | --- |
| 纯 Python 干跑 | `python tools/modeling/generators/dryrun_lod1_kit_ships.py` → `.design/lod1_kit_ships/plan.json` | **DRYRUN OK**；`passed=true`、`failures=[]`；30 件 LOD0 齐全、kit tri 与 `kit_catalog.json` 一致、船合计 45 968 对账；target 合计 24 111 / cap 28 501 |
| 构建自检 | `.design/lod1_kit_ships/lod1_build_report.json`（工作台内 `report()`） | 30/30 `passed=true`；tri / bbox / 健康 / UV / 材质 10 项 check 全 true；`source_objects` 1（Ironclad 单对象）– 39（Paddle_Freighter） |
| 导出 | `.design/lod1_kit_ships/lod1_export_report.json` | 30/30 `ok=true`、`tiles_match=true`；单根节点、材质 / image 与 LOD0 一致 |
| 结构验收（安装后） | `python tools/modeling/generators/verify_lod1_kit_ships_glb.py --report .design/lod1_kit_ships/verify_report.json` | **LOD1 VERIFY OK（installed）**：`mode=installed`、30/30 `passed`、`failures=[]`；16 项 checks 全 true；manifest `model.ship.*_lod1` 4/4 路径一致；images 175 |
| 候选目录验收 | 同一 verifier 加 `--candidate`（安装前门禁） | 与安装后共用同一套 check；仓库内保留的是安装后报告（`mode=installed`） |
| 安装 | `python tools/modeling/generators/install_lod1_kit_ships.py --report .design/lod1_kit_ships/install_report.json` | **INSTALL OK**；30 件写入两处运行时目录；`backups=0`；共享贴图 8 目录逐字节比较后无写入 |
| Godot 运行时探针 | `godot --headless --path . --script res://tools/godot/verify_lod1_kit_ships.gd` | **30 件（kit 26 + 船 4）/ 67 个共享贴图实例 / 0 失败**，退出码 0；逐件单 mesh、surface 全有 UV、材质全 `SN_Tex_*`、外部 `shared_materials/*.png` 全部存在。既有 `Loaded resource as image file…` 警告来自共享贴图加载器，不是新增失败 |
| Godot 全量测试 | `$env:GODOT_BIN = "C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"; pwsh ./tools/test.ps1` | **391 passed / 0 failed / 391 total**（约 316 s），退出码 0；新增 `test_lod1_assets.gd` 3 例：单 mesh + UV + 共享贴图、tri 比例 / 上限 + LOD0↔LOD1 包围盒、4 个 `model.ship.*_lod1` manifest 键与文件 |
| manifest | `dev_mods/core/manifest.json` | 4 个 `model.ship.*_lod1` 键路径与安装文件一致；kit LOD1 不登记 manifest |
| kit 目录 | `tools/modeling/kit_catalog.json` v1.3 | 顶层 `lod1` 段（26 件 / 10 824 tri / 1 236 344 B）+ 逐件 `lod1` 块（glb / core_glb / tri_count / ratio / cap_ratio / cap_tri / bytes / materials / bbox）；`total_lod1_tri` = 10 824 |
| 工作台快照 | `.design/SN_Asset_Workbench.blend` | **本批未重存**：快照 mtime（09:43）早于构建报告（10:27），且无 `SN_Asset_Workbench_pre_lod1_*.blend` 备份；LOD1 对象只在构建/预览的 Blender 会话里存在，复现需重跑生成器；收尾已把活动场景恢复为该保存基线（8 个建筑 LOD1 仍在，30 件 kit/船 LOD1 需重跑生成器） |

## 7. 预览图（38 张）

- 8 张类别 lineup（1440×620）：
  [weapons](../design/screenshots/lod1/LOD1_lineup_weapons_1440x620.png) ·
  [ship_parts](../design/screenshots/lod1/LOD1_lineup_ship_parts_1440x620.png) ·
  [machinery](../design/screenshots/lod1/LOD1_lineup_machinery_1440x620.png) ·
  [cargo](../design/screenshots/lod1/LOD1_lineup_cargo_1440x620.png) ·
  [dock](../design/screenshots/lod1/LOD1_lineup_dock_1440x620.png) ·
  [architecture](../design/screenshots/lod1/LOD1_lineup_architecture_1440x620.png) ·
  [environment](../design/screenshots/lod1/LOD1_lineup_environment_1440x620.png) ·
  [ships](../design/screenshots/lod1/LOD1_lineup_ships_1440x620.png)
- 30 张同机位 LOD0 vs LOD1 对比（1024×640，LOD1 放在 LOD0 包围盒右侧 2 m、地面/水线对齐）：`docs/design/screenshots/lod1/SN_<Asset>_LOD0_vs_LOD1_three_quarter_1024x640.png`，例如 [Ironclad](../design/screenshots/lod1/SN_Ironclad_LOD0_vs_LOD1_three_quarter_1024x640.png) / [Schooner_Fame](../design/screenshots/lod1/SN_Schooner_Fame_LOD0_vs_LOD1_three_quarter_1024x640.png) / [Arch_Factory](../design/screenshots/lod1/SN_Arch_Factory_LOD0_vs_LOD1_three_quarter_1024x640.png)。
- 断言：8 张 lineup + 30 张对比共 38 张，均在 `docs/design/screenshots/lod1/`（screenshots 目录 gitignore，提交时 `git add -f`）。

## 8. 复现命令

```powershell
# 1) 纯 Python 干跑（不启动 Blender）：生成 .design/lod1_kit_ships/plan.json
python tools/modeling/generators/dryrun_lod1_kit_ships.py

# 2) Blender 工作台内：构建 30 件 LOD1 → 自检 → 导出候选
#    runpy.run_path("tools/modeling/generators/sn_lod1_kit_ships_generator.py", run_name="__main__")
#    build_all() → report() → export_candidates()

# 3) 候选验收（安装前门禁）
python tools/modeling/generators/verify_lod1_kit_ships_glb.py --candidate

# 4) 安装（GLB 两处 + 共享贴图 + 机器计划）
python tools/modeling/generators/install_lod1_kit_ships.py --report .design/lod1_kit_ships/install_report.json

# 5) 安装后独立验收
python tools/modeling/generators/verify_lod1_kit_ships_glb.py --report .design/lod1_kit_ships/verify_report.json

# 6) 预览（Blender 工作台内）
#    runpy.run_path("tools/modeling/generators/render_lod1_kit_ships_preview.py", run_name="__main__")

# 7) 合并 kit 目录
python tools/modeling/generators/gen_kit_catalog.py

# 8) Godot（见 §6「Godot 运行时探针 / 全量测试」）
$env:GODOT_BIN = "C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
godot --headless --path . --script res://tools/godot/verify_lod1_kit_ships.gd
pwsh ./tools/test.ps1
```

## 9. 已知边界 / 待决

1. **运行时 LOD 切换未接线**：本批只交付「可被质量档位使用」的资产，与批次 A 同一口径；LOD1 资源键 / 目录已就位，切换逻辑留给质量档位与 `M2-5`（LOD2 / impostor）。
2. **LOD1 不保留接口层级**：单 mesh、无 socket / pivot / 层级；远景不参与装配，装配契约只属于 LOD0。需要装配的场景必须用 LOD0。
3. **LOD1 是派生结果，不是手工资产**：轮廓与 UV 由 LOD0 决定；小结构（吊环、栏杆、系缆、铰链）靠 ≤20 tri 小件保留，但更细的铆钉 / 窗框 / 板缝在 LOD1 上不可依赖。
4. **近距离对比会更粗**：Decimate 产生的零厚度「pillow」成对重合面会被成对合并（保留闭合拓扑），因此在近距离对比图里小件（如储罐鞍座）比 LOD0 粗糙；远景使用不受影响。
5. **船体开放边界属 LOD0 既有特征**：帆面是单层开放曲面，LOD1 边界边按「不高于 LOD0」判定（SF 1 306→996、PF 102→71、PS 54→43、IC 0→0），不是新增破洞。
6. **kit LOD1 未登记 manifest**：kit LOD0 从未进 manifest，LOD1 保持一致，走 `kit_catalog.json`；船的 4 个 `model.ship.*_lod1` 键供运行时解析。
7. **待决**：运行时切换阈值 / 质量档位映射（近 / 中 / 远距离与低配回退）在接 `M2-5` 时一并定；`SN_Dock_Mooring` 30.43 % 已贴近 35 % 上限，若后续要加细节需先回调预算。
