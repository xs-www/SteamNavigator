# 旧资产 UV 迁移 B 验收（船模块 / 4 艘船 / 旧小镇）

> 状态：Accepted（2026-10-22）
> 对应 backlog：`M0-2`（[MODELING_BACKLOG.md §2](../design/MODELING_BACKLOG.md)）
> 相关：[ASSET_MAP.md](../design/ASSET_MAP.md) · [MODELING_WORKFLOW.md §11.16/§12](../design/MODELING_WORKFLOW.md) · [todo.md](../../todo.md)

## 1. 结论

批次 B 完成**纯材质 / UV 改造**，几何、轴心、对象变换一律未动：

- **补 UV**：单 mesh 对象用 `space="local"`、多节点船体用 `space="root"`（根节点局部坐标，跨子件连续且不烘入工作台摆位）；合计 **111,564 UV loops**；
- **切材质**：18 个旧纯色 `SN_*` 材质映射到 10 个 `SN_Tex_*` 共享贴图材质，旧槽 0 残留；
- **重导 GLB**：实际重导 **21 个 GLB**（12 船模块含占位副本 + 4 艘船 + 5 件旧小镇道具），`images[].uri = shared_materials/<texture>.png` 外部化，Core 副本同步；
- **几何不变**：tri 总数 **55,256**（modules 7,492 / ships 45,968 / town 1,796）与迁移前逐件一致；几何签名 / 对象变换全部逐位一致；
- 验收：GLB 自检 **21/21**、Godot 运行时 **21 件 / 24 个共享贴图实例 / 0 失败**。

## 2. 范围口径（backlog 25 件 → 实际重导 21 个 GLB）

backlog M0-2 写的是 **11 件船模块 + 4 艘船 + 旧小镇 10 件 = 25 件**。按当前运行时资产盘点：

| 计划 | 实际处理 |
| --- | --- |
| 11 件船模块 | 11 件专用模块（锅炉 3 / 货舱 3 / 导航 2 / 安全 2 / 客舱 1）+ `modules/SN_Boiler_Unit` 占位副本（manifest `model.module.boiler` 仍引用，内容与 props 锅炉同源）→ **12 个 GLB** |
| 4 艘船 | `SN_Ironclad` / `SN_Paddle_Freighter` / `SN_Paddle_Steamer` / `SN_Schooner_Fame` → **4 个 GLB**；`SN_Ship_Prototype`（`model.ship.prototype` 遗留键）不在 4 艘可玩船内，未纳入本批 |
| 旧小镇 10 件 | 5 栋旧建筑（Warehouse_Long / Warehouse_Short / Harbor_Office / Cargo_Shed / Tavern）**已在铁港建筑套件批次升级为 `SN_Town_*` trim-sheet LOD0**，运行时 GLB 也已替换、UV 完整，**本次只核验不重做**；剩余 **5 件**旧纯色道具（Fence_Row / Dock_Worker_A/B / Rowboat / Cargo_Lighter）→ **5 个 GLB** |
| 合计 25 件 | 5 件建筑已提前完成 + **21 个 GLB 本次重导** |

> 旧小镇 5 栋建筑的工作台对象（`SN_Harbor_Town` y=110）仍是旧几何，但运行时 GLB 已由建筑套件 `_LOD0` 产物覆盖；为避免把升级后的 GLB 覆盖回旧模型，本次**没有**导出这 5 个对象。

## 3. 迁移前基线

迁移前用 `capture_baseline_b.py` 记录 21 个旧 GLB（`.design/legacy_uv_b/baseline.json`）：

| 指标 | modules（12） | ships（4） | town（5） | 合计 |
| --- | ---: | ---: | ---: | ---: |
| 三角面 | 7,492 | 45,968 | 1,796 | **55,256** |
| 网格节点 | 12 | 101 | 5 | **118** |
| 图元 | 48 | 266 | 20 | 334 |
| 无 `TEXCOORD_0` 图元 | 48 | 263 | 20 | **331** |
| 旧纯色材质 | — | — | — | 18 |
| 内嵌贴图 | 0 | 0 | 0 | **0** |
| GLB 体积 | 425,736 B | 2,509,576 B | 112,068 B | 3,047,380 B |

## 4. 材质映射

| 旧材质 | 共享材质 | 说明 |
| --- | --- | --- |
| `SN_Wood` / `SN_Wood_Dark` / `SN_Wood_Deck` | `SN_Tex_Wood` / `SN_Tex_Wood_Dark` / `SN_Tex_Wood_Deck` | 木结构 / 甲板 / 货舱 |
| `SN_Metal` / `SN_Iron` / `SN_Iron_Red` / `SN_Brass` / `SN_Stone` | 同名 `SN_Tex_*` | 机械 / 铁件 / 锈红漆 / 黄铜 / 石 |
| `SN_Iron_Hull` | `SN_Tex_Iron` | 铁船体旧色接近铸铁 |
| `SN_Hull_Black` | `SN_Tex_Iron` | 纵帆船黑船身：铸铁深色比深木更接近原黑（保留"黑身 + 赭黄腰线"读感） |
| `SN_Ochre` | `SN_Tex_Wood_Deck` | 赭黄漆面色值接近 deck 木贴图 |
| `SN_White` / `SN_PS_UpperWhite` | `SN_Tex_Canvas_Shade` | 无纯白贴图，映射到最接近的浅色帆布（明轮客船白身/上层建筑；两种白的层次会合并） |
| `SN_Canvas` / `SN_Canvas_Shade` | `SN_Tex_Canvas_Shade` | 帆面 / 绳网 / 旗面 |
| `SN_Flag_Red` | `SN_Tex_Iron_Red` | 红旗 / 长旒 |
| `SN_Flag_White` | `SN_Tex_Canvas_Shade` | 白旗 |
| `SN_Flag_Blue` | `SN_Tex_Glass_Dark` | 深蓝旗（玻璃深色贴图带柔和高光带） |

> 本批**没有新增贴图**；共享贴图仍为 11 张。`SN_White` / `SN_PS_UpperWhite` 合并到同一贴图后，明轮客船的二级白层次被压平（已知取舍）。

## 5. 实现

| 环节 | 脚本 | 关键点 |
| --- | --- | --- |
| 迁移核心 | `tools/modeling/generators/sn_legacy_uv_migration.py`（`migrate_all_b` / `verify_scene_b`） | 复用批次 A 的映射/几何签名机制；新增 `space="root"` 支持多节点船体；按类别遍历集合内全部 mesh |
| UV 空间 | `sn_shared_materials.apply_to_object(space="root", root=...)` | `root.matrix_world.inverted() @ obj.matrix_world`：船体各子件在世界位置连续平铺，但不烘入工作台摆位 |
| 纯 Python 预检 | `dryrun_legacy_uv_b.py` | 目标 21、18 旧材质全覆盖、基线 tri/尺寸/无 UV 事实、模块/ships 运行时贴图目录齐备 |
| 导出 | `export_legacy_uv_b_glb.py` | 单 mesh 逐件归零导出；多节点船体根节点归零后整集合导出（`export_extras=True` 保留 Root extras）；旧 GLB 备份；Core 同步；仅更新 5 件旧小镇 GLB |
| GLB 验收 | `verify_legacy_uv_b_glb.py` | 节点/网格/tri/尺寸/材质/UV/外部 PNG 字节一致；图元数允许因"多旧材质合并到同一贴图"而减少 |
| Godot 运行时验收 | `tools/godot/verify_legacy_uv_materials_b.gd` | 21 件加载、UV、albedo、`SN_Tex_*`、类别内同一 URI 命中同一 `Texture2D` |
| 回归测试 | `framework/tests/cases/test_legacy_uv_assets_b.gd`（2 例） | 外部贴图 + UV + tri/网格数不变 + 类别内实例共享 |

**材质槽合并**：同一 mesh 上多个旧材质映射到同一 `SN_Tex_*` 时（如 `SN_Canvas` / `SN_Canvas_Shade`、`SN_Flag_White` / `SN_White`），`apply_to_object()` 会去重槽位，图元数随之减少。唯一受影响的是 `SN_Schooner_Fame`：图元 **73 → 70**（Headsails / Sails_Fore / Sails_Main 三处 `SN_Canvas` + `SN_Canvas_Shade` 合并），tri / 节点 / 网格数不变。首版曾记录 73→68，那是 `SN_Hull_Black` 被误映射为 `SN_Tex_Wood_Dark` 时的中间产物；改为 `SN_Tex_Iron` 后最终最小合并数为 70（见 §9）。

## 6. 导出与资源布局

```text
assets/models/modules/SN_*.glb             12 件（含 SN_Boiler_Unit）
dev_mods/core/assets/models/modules/*.glb  12 件（Core 副本）
assets/models/ships/SN_*.glb               4 件
dev_mods/core/assets/models/ships/*.glb    4 件
dev_mods/core/assets/models/props/SN_HT_*.glb  5 件（旧小镇道具只存在于 core mod）
assets/models/{modules,ships}/shared_materials/<texture>.png         各 11 张
dev_mods/core/assets/models/{modules,ships}/shared_materials/*.png   各 11 张
```

- `shared_materials.spec.json` 的 `runtime_dirs` 补齐 `port`（批次 A 遗留）+ `modules` / `ships`（本批），共 **22 个运行时目录**；重跑贴图生成器后 11 张 tile 逐字节不变、全部 deterministic / seam_ok。
- 合计 GLB 体积 3,047,380 B → **3,937,108 B**（+889,728 B ≈ 111,564 UV loops × 8 B）；
- 旧 GLB 备份：`.design/legacy_uv_b/backup_glb/{modules,ships,town}/`；`modules/SN_Boiler_Unit` 的旧 core 副本另从 git HEAD 还原保存为 `SN_Boiler_Unit.pre_migration.glb`；
- 报告：`.design/legacy_uv_b/{baseline,migration_report,export_report,verifier_report}.json`（本地产物）。

## 7. 验收证据

| 检查 | 结果 |
| --- | --- |
| `dryrun_legacy_uv_b.py` | **ALL OK** |
| `verify_legacy_uv_b_glb.py` | `files = 21, failures = 0` → **ALL LEGACY UV B GLB OK** |
| Godot `verify_legacy_uv_materials_b.gd` | **21 件 / 24 个共享贴图实例 / 0 失败** |
| 批次 A / 道具 / 设施 / 起重机回归 | `verify_legacy_uv_materials` 37/37、`verify_props` 31/31、`verify_port_facilities` 6/6、`verify_crane_materials` 4/4，0 失败 |
| 新增测试 `test_legacy_uv_assets_b::*` | **2 / 2 PASS** |
| 资产相关测试（独立 runner：A 2 + B 2 + content_asset_loader 5） | **9 / 9 PASS**（绕过被并行内容阻塞的 core bootstrap） |
| 全量测试 | **被并行内容改动阻塞**：`dev_mods/core/content/port_archetypes.json` 新增 facility `tavern`，而已提交的 `schemas/port_archetype.schema.json` enum 尚未包含 → core bootstrap fatal，与本次资产迁移无关（见 §9） |
| 独立 Verifier（只读，`verifier_report.json`） | **passed = true，failures = []**：独立 GLB 解析、Godot 回归、21 个旧 GLB 备份 SHA、Blender 只读 118 mesh / UV / 材质全部通过；唯一数字修正：纵帆船图元 73→70（见 §9） |

逐对象迁移自检（`migration_report.json`）21/21 全绿：几何签名、tri、对象变换、面材质计数、UV 完整、贴图 512 绑定全部通过；118 个 mesh 对象全部完成。

## 8. 数据

| 指标 | 迁移前 | 迁移后 |
| --- | ---: | ---: |
| GLB 数量 | 21 | 21 |
| 三角面 | 55,256 | **55,256（不变）** |
| 网格节点 | 118 | **118（不变）** |
| 图元 | 334 | 331（纵帆船材质槽合并 −3） |
| 有 UV 的图元 | 3 / 334 | **331 / 331** |
| UV loops | — | **111,564** |
| 材质 | 18 个旧纯色 | **10 个 `SN_Tex_*`** |
| 外部贴图引用 | 0 | **98 个材质引用 / 24 个运行时共享实例** |
| GLB 体积 | 3,047,380 B | 3,937,108 B |

预览（本地产物，`docs/design/screenshots/` 已 gitignore；Blender `look` material 着色）：

- [纵帆船黑船身 / 帆面](../design/screenshots/legacy_uv_b/schooner_fame_material_preview.png)
- [4 艘船（铁甲舰 + 明轮货轮）](../design/screenshots/legacy_uv_b/ironclad_freighter_material_preview.png)
- [12 件船模块 + 占位副本](../design/screenshots/legacy_uv_b/ship_modules_material_preview.png)
- [旧小镇剩余 5 件](../design/screenshots/legacy_uv_b/town_props_material_preview.png)

## 9. 过程发现与后续

**全量测试说明（并行内容改动，不是本批资产问题）**：本次全量测试运行时，工作区 `dev_mods/core/content/{map_profiles,port_archetypes}.json` 正被另一个并行代理修改（mtime 07:28），`port_archetypes.json` 新增 facility `tavern`，但已提交的 `schemas/port_archetype.schema.json` 的 `facilities.enum` 仍是 5 项，导致 core bootstrap 报 `value is not one of allowed values` / `port_archetypes 0` fatal，进而 `map_generation_failed` 等大量级联失败（见 `.design/legacy_uv_b/test_suite.log`）。本次资产迁移未触碰 `content/`、`schemas/`、`framework/`；资产相关测试用独立 runner 绕过 bootstrap 运行 **9/9 PASS**（A 2 + B 2 + content_asset_loader 5，见 `.design/legacy_uv_b/asset_tests.log`）。等并行内容/schema 对齐后应重跑全量测试。

1. **多节点资产要用根节点局部空间 UV**：世界空间会烘入工作台摆位（船在 ±45 / −70 / 90），而 `local` 会让各子件图案互相错位；`root` 空间是正确折中。
2. **材质合并会减少图元数**：多个旧材质映射到同一贴图时，同 mesh 槽位合并、GLB 图元数下降；最终 `SN_Schooner_Fame` 73→70（3 处 Canvas 合并），验收应以 tri / 节点 / 网格为几何不变量，图元数只允许"不增加且不少于网格数"。
3. **首版图元数字修正（68→70）**：第一次导出时 `SN_Hull_Black` 映射到 `SN_Tex_Wood_Dark`，黑船身变棕且 Hatches/Keel 多合并了 2 个图元；复核后改为 `SN_Tex_Iron` 并从 pre-B 工作台备份重跑迁移+导出，最终 70 才是正确最小合并数。`table.md` / verify 期望表 / 本文件均以 70 为准。
4. **3 个 nameplate 保留旧非激活 UV 层**：`SN_PS_Nameplate_Port/Starboard`、`SN_SF_Nameplate` 的 GLB 里仍有 `TEXCOORD_1`（旧 `UV贴图` 层），但 `TEXCOORD_0` 正常、运行时 / 测试 / 视觉均通过；属历史 UV 层残留，不影响交付。
5. **旧小镇 5 栋建筑已被建筑套件取代**：运行时 GLB 已是 `SN_Town_*` trim-sheet LOD0，本批只迁移剩余 5 件旧纯色道具，避免把升级后的资产覆盖回旧模型。
6. **`modules/SN_Boiler_Unit` 是 props 锅炉的占位副本**（manifest `model.module.boiler` 引用）；对象住在 `SN_IronHarbor_Props`，迁移/导出按"占位副本"单独处理。
7. **纯白 / 彩色旗帜没有对应贴图**：按"不新增贴图"原则映射到最接近的 `SN_Tex_Canvas_Shade` / `SN_Tex_Glass_Dark` / `SN_Tex_Iron_Red`；明轮客船二级白层次被压平。
8. **`SN_Hull_Black` 映射调优**：首版映射到 `SN_Tex_Wood_Dark` 后纵帆船黑船身变棕，复核后改为 `SN_Tex_Iron`（深铸铁色），保留"黑身 + 赭黄腰线"读感；为此从 pre-B 工作台备份重跑了一遍迁移+导出。
9. **后续**：`SN_Ship_Prototype`（`model.ship.prototype` 遗留键）仍是旧纯色资产，不在 4 艘可玩船范围内；如需彻底退役旧 `SN_*`，可在后续清理批次处理（或删除遗留 manifest 键）。

## 附录 A：21 个 GLB 逐对象数据

| 对象 | 类别 | 节点 | 网格 | 图元 | tri | 尺寸 X×Y×Z (m, glTF Y-up) | 材质（省略 `SN_Tex_` 前缀） |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| `SN_Boiler_Efficient` | modules | 1 | 1 | 4 | 540 | 1.805 × 2.600 × 1.600 | `Brass`, `Iron`, `Metal`, `Wood_Dark` |
| `SN_Boiler_Performance` | modules | 1 | 1 | 4 | 1152 | 3.400 × 2.940 × 2.114 | `Brass`, `Iron`, `Metal`, `Wood_Dark` |
| `SN_Boiler_Standard` | modules | 1 | 1 | 4 | 860 | 2.820 × 2.620 × 1.900 | `Brass`, `Iron`, `Metal`, `Wood_Dark` |
| `SN_Boiler_Unit` | modules | 1 | 1 | 2 | 476 | 3.000 × 2.500 × 2.000 | `Metal`, `Wood` |
| `SN_Cabin_Passenger` | modules | 1 | 1 | 6 | 792 | 3.400 × 2.550 × 2.400 | `Brass`, `Iron`, `Metal`, `Wood`, `Wood_Dark`, `Wood_Deck` |
| `SN_Cargo_Large_Hold` | modules | 1 | 1 | 4 | 672 | 4.006 × 2.600 × 2.810 | `Brass`, `Metal`, `Wood`, `Wood_Dark` |
| `SN_Cargo_Medium_Hold` | modules | 1 | 1 | 4 | 492 | 3.200 × 2.200 × 2.400 | `Brass`, `Metal`, `Wood`, `Wood_Dark` |
| `SN_Cargo_Small_Hold` | modules | 1 | 1 | 4 | 456 | 2.400 × 1.800 × 2.000 | `Brass`, `Metal`, `Wood`, `Wood_Dark` |
| `SN_HT_Cargo_Lighter` | town | 1 | 1 | 7 | 616 | 8.000 × 1.600 × 3.000 | `Brass`, `Canvas_Shade`, `Iron`, `Metal`, `Wood`, `Wood_Dark`, `Wood_Deck` |
| `SN_HT_Dock_Worker_A` | town | 1 | 1 | 3 | 192 | 0.620 × 1.800 × 0.494 | `Canvas_Shade`, `Metal`, `Wood_Dark` |
| `SN_HT_Dock_Worker_B` | town | 1 | 1 | 4 | 228 | 0.740 × 1.800 × 0.500 | `Canvas_Shade`, `Metal`, `Wood`, `Wood_Dark` |
| `SN_HT_Fence_Row` | town | 1 | 1 | 2 | 264 | 6.000 × 1.500 × 0.300 | `Iron`, `Stone` |
| `SN_HT_Rowboat` | town | 1 | 1 | 4 | 496 | 4.200 × 0.800 × 1.500 | `Iron`, `Wood`, `Wood_Dark`, `Wood_Deck` |
| `SN_Ironclad` | ships | 1 | 1 | 8 | 8830 | 60.135 × 28.640 × 18.000 | `Brass`, `Canvas_Shade`, `Iron`, `Iron_Red`, `Metal`, `Wood`, `Wood_Dark`, `Wood_Deck` |
| `SN_Nav_Chart_Room` | modules | 1 | 1 | 5 | 636 | 2.800 × 2.600 × 2.200 | `Brass`, `Iron`, `Metal`, `Wood`, `Wood_Dark` |
| `SN_Nav_Spyglass` | modules | 1 | 1 | 4 | 328 | 1.380 × 1.750 × 0.800 | `Brass`, `Metal`, `Wood`, `Wood_Dark` |
| `SN_Paddle_Freighter` | ships | 46 | 39 | 95 | 12200 | 59.528 × 19.520 × 14.100 | `Brass`, `Iron`, `Iron_Red`, `Metal`, `Wood`, `Wood_Deck` |
| `SN_Paddle_Steamer` | ships | 35 | 32 | 90 | 11764 | 24.560 × 10.470 × 8.740 | `Brass`, `Canvas_Shade`, `Glass_Dark`, `Iron`, `Iron_Red`, `Metal`, `Wood_Deck` |
| `SN_Safety_Lifeboat` | modules | 1 | 1 | 4 | 660 | 4.200 × 1.100 × 1.500 | `Brass`, `Canvas_Shade`, `Wood`, `Wood_Dark` |
| `SN_Safety_Valve` | modules | 1 | 1 | 3 | 428 | 1.488 × 1.840 × 1.256 | `Brass`, `Iron`, `Metal` |
| `SN_Schooner_Fame` | ships | 32 | 29 | 70 | 13174 | 33.441 × 26.819 × 6.880 | `Brass`, `Canvas_Shade`, `Glass_Dark`, `Iron`, `Iron_Red`, `Metal`, `Wood`, `Wood_Dark`, `Wood_Deck` |


## 附录 B：本次改动文件

**新增**

- `tools/modeling/generators/dryrun_legacy_uv_b.py`（纯 Python 预检）
- `tools/modeling/generators/export_legacy_uv_b_glb.py`（导出 / 贴图外部化 / 备份 / Core 同步）
- `tools/modeling/generators/verify_legacy_uv_b_glb.py`（21 个 GLB 独立验收）
- `tools/godot/verify_legacy_uv_materials_b.gd`（Godot 运行时共享贴图验收）
- `framework/tests/cases/test_legacy_uv_assets_b.gd`（2 例回归守护）
- `docs/archive/LEGACY_UV_MIGRATION_B_ACCEPTANCE.md`（本文件）

**修改**

- `tools/modeling/generators/sn_legacy_uv_migration.py`：批次 B 目标 / 映射 / `migrate_all_b` / `verify_scene_b` / 占位副本集合处理
- `tools/modeling/generators/sn_shared_materials.py`：`apply_to_object(space="root", root=...)`（ship 根空间 UV）
- `docs/design/textures/shared_materials/shared_materials.spec.json`：`runtime_dirs` 补 `port` / `modules` / `ships`（22 个目录）
- `docs/design/textures/shared_materials/shared_materials.stats.json`：重新生成（tile 字节不变）
- `framework/tests/test_runner.gd`：注册 `test_legacy_uv_assets_b.gd`
- `assets/models/{modules,ships}/SN_*.glb`（16）+ `dev_mods/core/assets/models/{modules,ships}/SN_*.glb`（16）+ `dev_mods/core/assets/models/props/SN_HT_*.glb`（5）
- `assets/models/{modules,ships}/shared_materials/*.png` 与 Core 对应目录（各 11 张，四目录为新建）
- `docs/design/ASSET_MAP.md` / `MODELING_WORKFLOW.md` / `MODELING_BACKLOG.md` / `todo.md` / `README.md` / `docs/archive/README.md`

**未改**

- 共享贴图字节（仍 11 张、未新增材质）；`SN_Town_*` 铁港建筑图集与 5 栋升级建筑 GLB
- Core manifest 资源键 / 内容 JSON / 框架运行时代码
