# 旧资产 UV 迁移 A 验收（31 件铁港道具 + 6 件港口设施）

> 状态：Accepted（2026-10-22）
> 对应 backlog：`M0-1`（[MODELING_BACKLOG.md §2](../design/MODELING_BACKLOG.md)）
> 工单来源：`tools/modeling/briefs/IRON_HARBOR_PLAN.md`（31 件道具）、`PORT_FACILITIES_PLAN.md`（6 件设施）
> 相关：[ASSET_MAP.md](../design/ASSET_MAP.md) · [MODELING_WORKFLOW.md §11.15/§12](../design/MODELING_WORKFLOW.md) · [todo.md](../../todo.md)

## 1. 结论

37 件旧资产完成**纯材质 / UV 改造**，几何、轴心、对象变换一律未动：

- **补 UV**：每个 mesh 新增 `UVMap`，`len(uv) == len(loops)`（合计 24,188 UV loops），盒式投影按面法线主轴 + 材质 `tile_m`；
- **切材质**：旧的 9 个纯色 `SN_*` 材质全部换成 `SN_Tex_*` 共享贴图材质（37 件共 9 个共享材质），旧槽位 0 残留；
- **重导 GLB**：37 个 GLB 重新导出，`images[].uri = shared_materials/<texture>.png` 外部化，Core 副本同步；
- **几何不变**：迁移前后逐对象几何签名（顶点坐标 + 面顶点索引 + tri + 对象变换）SHA-256 完全一致；tri 总数 **11,278**（props **6,282** / port **4,996**），与迁移前逐件相等；
- 验收：GLB 自检 **37/37**、Godot 运行时 **37 件 / 14 个共享贴图实例 / 0 失败**，旧纯色 `SN_*` 已从港区资产退场。

## 2. 迁移前基线

迁移前用 `capture_baseline.py` 记录 37 个旧 GLB（`.design/legacy_uv/baseline.json`，本地产物）：

| 指标 | props（31） | port（6） | 合计 |
| --- | ---: | ---: | ---: |
| 三角面 | 6,282 | 4,996 | **11,278** |
| 图元 | — | — | 80 |
| 无 `TEXCOORD_0` 图元 | — | — | **80 / 80** |
| 旧纯色材质 | — | — | 9 |
| 内嵌贴图 | 0 | 0 | **0** |
| GLB 体积 | 374,492 B | 277,036 B | 651,528 B |

旧 GLB 本来就是**纯色材质、无任何贴图**，因此本次不是"把已有贴图拿出来"，而是首次导出时由共享材质生成贴图、再替换为外部 URI。

## 3. 材质映射

| 旧纯色材质 | 共享贴图材质 | 说明 |
| --- | --- | --- |
| `SN_Wood` | `SN_Tex_Wood` | 木结构 / 货箱 / 托盘 / 跳板 |
| `SN_Wood_Dark` | `SN_Tex_Wood_Dark` | 深色木 / 护舷 / 龙骨墩 / 缆桩 |
| `SN_Metal` | `SN_Tex_Metal` | 钢构 / 爬梯 / 系缆桩 / 锅炉 |
| `SN_Iron` | `SN_Tex_Iron` | 水箱 / 信号塔 / 龙门吊 |
| `SN_Iron_Red` | `SN_Tex_Iron_Red` | 锈红漆面（本批未直接使用） |
| `SN_Brass` | `SN_Tex_Brass` | 黄铜件 / 铭牌 |
| `SN_Stone` | `SN_Tex_Stone` | 岸壁 / 石阶 / 干船坞 |
| `SN_Canvas` / `SN_Canvas_Shade` | `SN_Tex_Canvas_Shade` | 帆布 / 绳网 / 纸面统一到唯一帆布贴图 |
| `SN_Coal` | `SN_Tex_Coal` | 煤堆 |
| `SN_Ore` | `SN_Tex_Iron_Red` | 旧 ORE_BASE = (0.155, 0.038, 0.024) 线性 ≈ iron_red 均值 118/56/43，**不为一种材质新增贴图** |

> 旧资产实际用到 9 个 → 7 个 `SN_Tex_*`（props）/ 7 个（port）；`SN_Tex_Wood_Deck`、`SN_Tex_Glass_Dark` 不在本批引用集合内。
> 共享贴图仍为 11 张，本批**没有新增贴图**，`shared_materials.spec.json` / 贴图生成器未改。

## 4. 实现

| 环节 | 脚本 | 关键点 |
| --- | --- | --- |
| 迁移核心 | `tools/modeling/generators/sn_legacy_uv_migration.py` | 固定映射表 + 按槽位换材质（面索引不变）→ `sn_shared_materials.apply_to_object(space="local")` 写 UV；迁移前后做几何签名 / 面材质计数对比；对已迁移对象幂等 |
| 纯 Python 预检 | `tools/modeling/generators/dryrun_legacy_uv.py` | 目标 37 件、映射全部落在共享材质 spec、贴图真源存在、基线 tri / 尺寸 / 无 UV 事实一致 |
| 导出 | `tools/modeling/generators/export_legacy_uv_glb.py` | 逐件 `location` 归零导出 → `externalize_glb(prefer_authored=True)` → 旧 GLB 备份 → Core 同步 → 4 个 `shared_materials/` 目录各补齐 11 张 PNG → 保存工作台 |
| GLB 验收 | `tools/modeling/generators/verify_legacy_uv_glb.py` | tri / 图元数 / 世界尺寸 / 贴地 / 材质名 / doubleSided / 每图元 `TEXCOORD_0` / 外部 URI / PNG 与授权 tile 逐字节一致 |
| Godot 运行时验收 | `tools/godot/verify_legacy_uv_materials.gd` | 37 件加载、surface UV、albedo、`SN_Tex_*`、同类别内同 URI 命中同一 `Texture2D` 实例 |
| 回归测试 | `framework/tests/cases/test_legacy_uv_assets.gd`（2 例） | 外部共享贴图 + 每 surface UV + tri 不变 + 类别内实例共享 |

**UV 空间选择**：单 mesh 资产用 `space="local"`。世界空间会把工作台布局位置（每批 y=24/30/36/42/48、设施 y=75）烘进 UV 相位，资产挪位后图案整体漂移；局部空间下同一几何的 UV 相位稳定、重导可复现。多节点拼装件（起重机等）继续用默认 `space="world"`，行为不变。

**重跑约定**：批次 2–5 与港口设施的生成器仍输出旧纯色 `SN_*`；若用生成器重建几何，必须再跑一次 `sn_legacy_uv_migration.migrate_all()` + `export_legacy_uv_glb.export_all()`，否则会退回纯色。批次 1 的 6 件（岸壁 / 护舷 / 系缆桩 / 木箱 / 木桶 / 矿石堆）没有完整参数化生成器，`.design/SN_Asset_Workbench.blend` 是它们的几何真源。

**共享材质库小改**：`sn_shared_materials.apply_to_object()` 新增 `space` 参数（默认 `world`）并去重"多个旧材质映射到同一 `SN_Tex_*`"造成的重复槽位。旧资产 / 新资产现有调用不传参数，行为不变。

## 5. 导出与资源布局

```text
assets/models/props/SN_*.glb                 31 件（开发态）
dev_mods/core/assets/models/props/SN_*.glb   31 件（Core 副本）
assets/models/port/SN_*.glb                  6 件
dev_mods/core/assets/models/port/SN_*.glb    6 件
assets/models/{props,port}/shared_materials/<texture>.png           各 11 张
dev_mods/core/assets/models/{props,port}/shared_materials/<texture>.png  各 11 张
```

- 每件 GLB 单节点 / 单网格 / 原点仍在底面中心，`bbox.min.y = 0`；
- 导出前后体积：651,528 B → **845,256 B**（props 485,900 / port 359,356，+193,728 B ≈ 24,188 UV loops × 8 B，符合"只增加 UV 属性"的预期）；
- 旧 GLB 备份：`.design/legacy_uv/backup_glb/{props,port}/`（本地产物，gitignore）；
- 迁移报告：`.design/legacy_uv/migration_report.json`；导出报告：`.design/legacy_uv/export_report.json`；独立验收报告：`.design/legacy_uv/verifier_report.json`（均为本地产物）。

## 6. 验收证据

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 纯 Python 预检 | `python tools/modeling/generators/dryrun_legacy_uv.py` | **ALL OK** |
| 37 个 GLB 结构 / 贴图 | `python tools/modeling/generators/verify_legacy_uv_glb.py` | `files = 37, failures = 0` → **ALL LEGACY UV GLB OK** |
| Godot 运行时共享贴图 | `godot --headless --path . --script res://tools/godot/verify_legacy_uv_materials.gd` | **37 件 / 14 个共享贴图实例 / 0 失败** |
| 道具回归 | `godot ... res://tools/godot/verify_props.gd` | **31 件，失败 0**（尺寸 / tri / 贴地 / `SN_Tex_*`） |
| 设施回归 | `godot ... res://tools/godot/verify_port_facilities.gd` | **6 件，失败 0** |
| 起重机共享贴图回归 | `godot ... res://tools/godot/verify_crane_materials.gd` | **4 个 GLB / 10 个共享贴图实例 / 0 失败** |
| 新增测试 | `test_legacy_uv_assets::*` | **2 / 2 PASS**（外部贴图 + 类别内实例共享） |
| 全量测试 | `godot --headless --path . --script res://framework/tests/test_runner.gd` | 本批运行快照：360 passed / 3 failed / 363 total（02:09）；独立 Verifier 重跑：**362 passed / 1 failed / 363 total**（02:21）。失败均属并行 supply→market / 剧情改动，见 §8 |
| 独立只读验收 | Verifier `verifier-legacy-uv`（只读 Blender + 独立 GLB 解析 + Godot 探针） | **passed = true，failures = []**；`.design/legacy_uv/verifier_report.json` |

逐对象迁移自检（`migration_report.json`）37/37 全绿，关键项：

- `geometry_signature_unchanged` 37/37
- `geometry_counts_unchanged` / `transform_unchanged` 37/37
- `material_usage_preserved` 37/37（按映射后名称守恒）
- `uv_layer_complete` 37/37（`UVMap`，24,188 loops）
- `images_bound_512` 37/37

> 说明：`migration_report.json` 是幂等重跑产物——`SN_Barrel` 先做过单件试跑，其 `before` 快照已是 `SN_Tex_*`（其余 36 件 `before` 仍是旧槽）。**迁移前旧材质证据以 `baseline.json` 为准**：37 件、9 个旧纯色材质（`SN_Brass` / `SN_Canvas` / `SN_Coal` / `SN_Iron` / `SN_Metal` / `SN_Ore` / `SN_Stone` / `SN_Wood` / `SN_Wood_Dark`）、80/80 图元无 UV、0 内嵌贴图。独立 Verifier 已用 baseline + 现 GLB + Blender 场景三方交叉确认。

## 7. 数据

| 指标 | 迁移前 | 迁移后 |
| --- | ---: | ---: |
| 文件数 | 37 | 37 |
| 三角面 | 11,278 | **11,278（不变）** |
| 图元 | 80 | 80 |
| 有 UV 的图元 | 0 | **80** |
| 材质 | 9 个旧纯色 `SN_*` | **9 个 `SN_Tex_*`（7 张 props + 7 张 port 运行时副本，共 14 个共享实例）** |
| 外部贴图 | 0 | **80 个材质引用，全部 `shared_materials/<texture>.png`** |
| GLB 体积 | 651,528 B | 845,256 B |

预览（本地产物，`docs/design/screenshots/` 已 gitignore；Blender `look` material 着色）：

- [道具材质预览](../../design/screenshots/legacy_uv/props_material_preview.png)（8 件近景：木纹 / 石纹 / 煤堆 / 锈红矿等）
- [港口设施材质预览](../../design/screenshots/legacy_uv/facilities_material_preview.png)（6 件全景）
- [市场棚近景](../../design/screenshots/legacy_uv/market_stall_material_preview.png)（帆布 / 木 / 黄铜）

## 8. 全量测试中的失败（均与本次资产迁移无关）

本批完成过程中跑了两遍全量测试，失败项全部来自并行进行中的剧情 / 补给（4.5.3 supply→market）改动：

| 运行 | 结果 | 失败项 |
| --- | --- | --- |
| 本批 02:09 运行 | 360 passed / 3 failed / 363 total | `test_every_pushed_notice_key_is_localized_in_both_languages`（core localization 156 vs 158，`good.core.spices.*` 只在 en）、`test_overview_defaults_to_the_3d_port_stage_with_compact_chrome`、`test_supply_screen_paints_the_lost_capacity_band` |
| 独立 Verifier 02:21 重跑 | **362 passed / 1 failed / 363 total** | 仅 `test_overview_defaults_to_the_3d_port_stage_with_compact_chrome`（"legacy supply id redirects to the market"），属 supply→market 重定向 |

- 前两条已随并行代理更新修复 / 重命名；剩余一条断言 supply 导航与市场页挂载，不涉及 GLB / UV / 材质 / 贴图；
- 证据路径（均为并行改动的未提交文件）：`framework/ui/shell/main.gd`（SCREENS 去 supply、supply→market 重定向）、`framework/application/queries/port_view.gd`、`framework/ui/screens/port/supply_screen.gd`、`framework/tests/cases/test_ui_shell.gd`、`dev_mods/core/localization/*`、`dev_mods/core/content/map_profiles.json`、`framework/domain/story/story_service.gd`；
- 本次迁移只改 `assets/models/{props,port}/**`、`dev_mods/core/assets/models/{props,port}/**`、新增脚本 / Godot 验收 / 测试 / 文档，**没有触碰 `framework/`、`localization/`、`story/`**；本次新增的 2 个资产测试 `test_legacy_uv_assets::*` 两次运行均 PASS。

## 9. 过程发现与后续

1. **活体 Blender 缓存纯 Python 模块**：改完 `sn_shared_materials` 后首次执行仍用旧签名（`unexpected keyword argument 'space'`）；`migrate_all()` 先 `importlib.reload` 再跑（与 §11.13 同类坑）。
2. **单 mesh 资产必须用局部空间 UV**：世界空间会把工作台布局位置烘进 UV 相位，资产挪位后图案漂移；多节点拼装件继续用世界空间。
3. **旧纯色 GLB 没有贴图**：外部化的输入是"本次导出时生成的内嵌图"，`prefer_authored=True` 保证共享 PNG 与授权 tile 逐字节一致。
4. **共享目录按类别划分**：props / port 各持一份 `shared_materials/`，`ContentAssetLoader` 在同一类别内复用 `Texture2D`（跨类别不共享），这是现有分类目录约定的延续。
5. **后续 M0-2**：11 件船模块 + 4 艘船 + 旧小镇 10 件仍需补 UV / 切 `SN_Tex_*`；船体 UV 工作量大（舷侧 / 甲板 / 帆面分区），单独一批。

## 附录 A：37 件逐对象数据

| 对象 | 类别 | tri | 图元 | 尺寸 X×Y×Z (m, glTF Y-up) | 材质（省略 `SN_Tex_` 前缀） |
| --- | --- | ---: | ---: | --- | --- |
| `SN_Barrel` | props | 168 | 3 | 0.900 × 1.100 × 0.900 | `Metal`, `Wood`, `Wood_Dark` |
| `SN_Bell` | props | 176 | 1 | 0.680 × 0.880 × 0.536 | `Metal` |
| `SN_Boiler_Unit` | props | 476 | 2 | 3.000 × 2.500 × 2.000 | `Metal`, `Wood` |
| `SN_Buoy` | props | 260 | 2 | 1.141 × 1.800 × 1.200 | `Metal`, `Wood_Dark` |
| `SN_Capstan` | props | 292 | 2 | 1.200 × 1.100 × 1.200 | `Metal`, `Wood` |
| `SN_Cargo_Net` | props | 248 | 2 | 3.000 × 0.104 × 3.000 | `Canvas_Shade`, `Metal` |
| `SN_Chain_Coil` | props | 352 | 1 | 1.043 × 0.266 × 0.941 | `Metal` |
| `SN_Coal_Chute` | props | 128 | 2 | 2.500 × 1.500 × 1.500 | `Metal`, `Wood_Dark` |
| `SN_Coal_Pile` | props | 240 | 1 | 3.000 × 1.170 × 2.500 | `Coal` |
| `SN_Crate` | props | 120 | 3 | 1.200 × 1.200 × 1.200 | `Metal`, `Wood`, `Wood_Dark` |
| `SN_Dock_Fender` | props | 46 | 2 | 0.300 × 2.500 × 0.300 | `Metal`, `Wood_Dark` |
| `SN_Dock_Ladder` | props | 156 | 1 | 0.608 × 3.200 × 0.275 | `Metal` |
| `SN_Dock_Stairs` | props | 120 | 2 | 3.000 × 3.000 × 2.000 | `Stone`, `Wood` |
| `SN_Dock_Wall` | props | 588 | 3 | 6.000 × 3.500 × 3.000 | `Metal`, `Stone`, `Wood_Dark` |
| `SN_Dry_Dock` | port | 516 | 3 | 18.000 × 2.600 × 8.000 | `Metal`, `Stone`, `Wood_Dark` |
| `SN_Fender_Ball` | props | 120 | 2 | 0.824 × 0.900 × 0.800 | `Canvas_Shade`, `Metal` |
| `SN_Flag_Pole` | props | 116 | 2 | 1.424 × 6.000 × 0.259 | `Canvas_Shade`, `Wood` |
| `SN_Gangway` | props | 252 | 2 | 6.000 × 0.520 × 1.200 | `Metal`, `Wood` |
| `SN_Gas_Lamp` | props | 194 | 2 | 0.350 × 3.500 × 0.314 | `Canvas_Shade`, `Metal` |
| `SN_Gear_Crate` | props | 200 | 2 | 0.820 × 0.818 × 0.858 | `Metal`, `Wood` |
| `SN_Grab_Bucket` | props | 228 | 1 | 1.494 × 1.460 × 1.500 | `Metal` |
| `SN_Handcart` | props | 228 | 2 | 2.020 × 1.000 × 1.060 | `Metal`, `Wood` |
| `SN_Keel_Block` | props | 96 | 2 | 1.200 × 0.600 × 0.811 | `Metal`, `Wood_Dark` |
| `SN_Market_Stall` | port | 768 | 5 | 5.000 × 3.200 × 3.000 | `Brass`, `Canvas_Shade`, `Metal`, `Wood`, `Wood_Dark` |
| `SN_Mooring_Bollard` | props | 288 | 1 | 0.620 × 0.700 × 0.620 | `Metal` |
| `SN_Mooring_Rope` | props | 172 | 1 | 0.880 × 0.440 × 0.900 | `Canvas_Shade` |
| `SN_Notice_Board` | port | 272 | 4 | 2.800 × 2.600 × 0.500 | `Canvas_Shade`, `Metal`, `Wood`, `Wood_Dark` |
| `SN_Ore_Pile` | props | 150 | 1 | 4.000 × 1.500 × 3.000 | `Iron_Red` |
| `SN_Pallet` | props | 96 | 1 | 1.200 × 0.135 × 1.000 | `Wood` |
| `SN_Plate_Stack` | props | 144 | 2 | 2.994 × 0.550 × 2.000 | `Metal`, `Wood_Dark` |
| `SN_Port_Sign` | props | 120 | 2 | 2.040 × 1.600 × 0.250 | `Metal`, `Wood` |
| `SN_Sack_Pile` | props | 160 | 1 | 1.450 × 0.795 × 0.950 | `Canvas_Shade` |
| `SN_Shipyard_Gantry` | port | 1064 | 4 | 14.000 × 10.000 × 4.014 | `Brass`, `Iron`, `Metal`, `Wood_Dark` |
| `SN_Signal_Tower` | port | 1052 | 5 | 3.200 × 8.500 × 2.400 | `Brass`, `Canvas_Shade`, `Iron`, `Metal`, `Wood_Dark` |
| `SN_Steam_Pipe` | props | 108 | 1 | 2.040 × 0.414 × 0.268 | `Metal` |
| `SN_Timber_Stack` | props | 240 | 3 | 4.000 × 1.222 × 1.510 | `Metal`, `Wood`, `Wood_Dark` |
| `SN_Water_Tank` | port | 1324 | 4 | 4.000 × 5.200 × 4.000 | `Brass`, `Iron`, `Metal`, `Stone` |


## 附录 B：本次改动文件

**新增**

- `tools/modeling/generators/sn_legacy_uv_migration.py`（迁移核心：映射 / 局部空间 UV / 几何签名 / 验收）
- `tools/modeling/generators/dryrun_legacy_uv.py`（纯 Python 预检）
- `tools/modeling/generators/export_legacy_uv_glb.py`（导出 / 贴图外部化 / 备份 / Core 同步）
- `tools/modeling/generators/verify_legacy_uv_glb.py`（37 个 GLB 独立验收）
- `tools/godot/verify_legacy_uv_materials.gd`（Godot 运行时共享贴图验收）
- `framework/tests/cases/test_legacy_uv_assets.gd`（2 例回归守护）
- `docs/archive/LEGACY_UV_MIGRATION_A_ACCEPTANCE.md`（本文件）

**修改**

- `tools/modeling/generators/sn_shared_materials.py`：`apply_to_object(space=...)`（默认 world 不变）+ 材质槽去重 + 头顶文档
- `tools/godot/verify_props.gd`：材质名必须是 `SN_Tex_*`
- `tools/godot/verify_port_facilities.gd`：调色板改为 `SN_Tex_*`
- `framework/tests/test_runner.gd`：注册 `test_legacy_uv_assets.gd`
- `docs/design/ASSET_MAP.md` / `MODELING_WORKFLOW.md` / `MODELING_BACKLOG.md` / `todo.md`
- `assets/models/{props,port}/SN_*.glb`（37）+ `dev_mods/core/assets/models/{props,port}/SN_*.glb`（37）
- `assets/models/{props,port}/shared_materials/*.png` 与 Core 对应目录（各 11 张；port 两目录为新建）

**未改**

- 共享材质 spec / 贴图生成器 / 贴图字节（仍 11 张，未新增材质）
- Core manifest 资源键 / 内容 JSON / 框架运行时代码
