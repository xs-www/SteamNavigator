# 铁港建筑套件 · 第二批：其余 4 栋 drop-in（M2）

> 前情：[IRON_HARBOR_ARCHITECTURE_PHASE1.md](IRON_HARBOR_ARCHITECTURE_PHASE1.md)（几何门禁 + R1）、[IRON_HARBOR_ARCHITECTURE_M1.md](IRON_HARBOR_ARCHITECTURE_M1.md)（朝向 + 共享材质/trim sheet）。
> 本轮把 5 个 drop-in 里剩下的 4 栋按同一套语言做完：**几何纯 Python 生成器 + 共享贴图 + 盒投影 UV + 导出内容 GLB + PortStage 固定机位验证**。旧资产全部有备份，可一键回滚。

## 1. 5 个 drop-in 现状

| 资产 | 目标尺寸 X×Y×Z (m) | 三角面 | 预算档 | 主立面 | 本轮 |
| --- | --- | ---: | --- | --- | --- |
| `SN_HT_Warehouse_Long` | 20.0 × 9.0 × 11.0 | 7 436 | medium 5–8k | 本地 **+Y**（槽位 yaw 已改 −106°） | M1 完成，本轮不动 |
| `SN_HT_Warehouse_Short` | 11.0 × 9.0 × 9.5 | **3 788** | small 3–5k | 本地 **+X** | 本批 |
| `SN_HT_Harbor_Office` | 9.0 × 8.0 × 14.0 | **10 336** | landmark 8–14k | 本地 **+X** | 本批 |
| `SN_HT_Cargo_Shed` | 8.0 × 6.0 × 4.5 | **3 356** | small 3–5k | 本地 **+X**（开敞柱廊） | 本批 |
| `SN_HT_Tavern` | 10.0 × 8.0 × 8.0 | **5 116** | medium 5–8k | 本地 **+X**（山墙端 + 门廊） | 本批 |

合计城镇建筑 **30 032 tri**（工单「同屏城镇建筑 ≤60 000 tri」的 47%）。

## 2. 关键决策：主立面放在本地 +X 端面

工单 `transform.forward = "+X"`，`port_stage.gd` 的 `_build_town_blockout()` 也把门窗放在本地 +X；而旧的 batch1 资产把主立面放在 **−Y**，在固定机位里整排背对镜头——这正是工单头号验收项「任意前景建筑不得读成没有开口和结构层次的大方块」的成因。

四个槽位 yaw 分别是 −90 / −80 / −90 / −100°，资产本地 +X 法线到机位轴的夹角只有 **11.4° / 7.1° / 28.2° / 42.8°**（±Y 面则 48–83°，其中 −Y 完全背对）。因此这 4 栋**不改布局**：主立面 = +X，+Y 侧做次可见面（壁柱/窗节奏），−X/−Y 放服务门、落水管、后勤窗。

## 3. 生成器与 harness

```
tools/modeling/generators/sn_iron_harbor_warehouse_short_generator.py   纯几何（1 277 行，含 panel/窗/门/侧棚/烟囱等）
tools/modeling/generators/sn_iron_harbor_harbor_office_generator.py    纯几何（拱券/阳台/钟楼/檐口/线脚）
tools/modeling/generators/sn_iron_harbor_cargo_shed_generator.py       纯几何（柱廊/单坡棚顶/工作台/吊钩/货箱）
tools/modeling/generators/sn_iron_harbor_tavern_generator.py           纯几何（两层立面/门廊/招牌/烟囱/木桶）
tools/modeling/generators/sn_iron_harbor_kit_batch2.py                 Blender 侧：build_all / report_all / export_all / render_previews / restore_legacy
```

- 4 个生成器都是**纯 Python**（不 import bpy），可直接 `python tools/modeling/generators/dryrun_props.py <file>` 干跑（4/4 ALL OK）。
- 几何语言与 warehouse_long 一致：`panel()` 生成带**真凹口**的闭合厚墙板（窗凹 0.14–0.16 / 门凹 0.20–0.28），显式倒角（`vchamfer_box` / 型材轮廓 / 屋面板 2 段倒角），闭合实体拼装。
- **踩过的坑（已修，值得记）**：6 个材质是全局 datablock，pply_to_object() 每次都会重建它们的 node tree，所以「按栋换 cell」必须**轮到谁就重写一次**——build/report/export/render 四个阶段都要（_apply_cells()）。第一版只在 uild_all() 里写了一次，结果最后构建的 Tavern 覆盖了全部 6 个材质，Short/Office/Shed 三栋 GLB 全部嵌成 Tavern 的 cell 套装（独立 Verifier 抓到的唯一硬阻断）。现在 export_all() 每栋导出前重写并在导出后**解析 GLB 的 image 名与本栋 cells 硬校验**（cells_ok），
ender_previews() 每栋渲染前也重写。
- 材质沿用 M1 的共享 trim sheet：**同一组 6 个材质槽**，但每栋采不同 cell（同一张 2048 图集的不同行），因此 5 栋之间有材质差异、贴图总量不增：

| 资产 | Brick | Plaster | Wood | Iron | Stone | Glass |
| --- | --- | --- | --- | --- | --- | --- |
| Warehouse_Long (M1) | brick_wall | plaster_light | wood_plank_weathered | iron_dark | stone_base_dirty | glass_dark |
| Warehouse_Short | brick_wall | plaster_light | wood_plank | **iron_rust** | stone_base | glass_dark |
| Harbor_Office | brick_wall | plaster_light | wood_plank_weathered | iron_dark | **stone_base** | **glass_reflect** |
| Cargo_Shed | （未用） | plaster_grime | wood_plank | iron_rust | stone_base | glass_dark |
| Tavern | brick_wall | **plaster_grime** | wood_plank | iron_dark | stone_base_dirty | glass_reflect |

## 4. 门禁结果（Blender 内实测，`report_all()`）

每栋都通过全部检查：`tris_in_budget / size_matches / grounded / pivot_ground_centre / material_slots_ok / palette_only / loose_verts_zero / degenerate_faces_zero / non_manifold_zero / boundary_edges_zero / uv_loops_complete / geometry_unchanged_by_uv / all_images_bound / uv_projection_ok`。

| 资产 | tri | 顶点 | 尺寸 (m) | zmin | 材质槽 | UV loop | 贴图 |
| --- | ---: | ---: | --- | ---: | ---: | ---: | --- |
| Warehouse_Short | 3 788 | 2 294 | 11.000 × 9.000 × 9.500 | 0 | 6 | 7 410 | 6 × 512² |
| Harbor_Office | 10 336 | 6 292 | 9.000 × 8.000 × 14.000 | 0 | 6 | 20 236 | 6 × 512² |
| Cargo_Shed | 3 356 | 2 112 | 8.000 × 6.000 × 4.500 | 0 | 5（无砖） | 7 068 | 5 × 512² |
| Tavern | 5 116 | 3 064 | 10.000 × 8.000 × 8.000 | 0 | 6 | 10 162 | 6 × 512² |

- **旧占位资产零改动**：`SN_Harbor_Town` 里的 4 个旧对象（512 / 1 236 / 572 / 956 tri）位置、尺寸、材质、可见性全部不变；全场景 digest 与构建前一致（246 对象）。
- **Legacy 备份**：`.design/buildings/iron_harbor/SN_HT_<Name>_legacy.glb`，sha256 分别是 `fbaa2a41…`（short）、`0adf5ac1…`（office）、`1bfe5a9f…`（shed）、`aac879af…`（tavern）；`restore_legacy()` 可一次还原 4 个。
- **新内容 GLB**：1 259 436 / 1 670 172 / 1 074 544 / 1 339 144 B（内嵌 5–6 张 512² PNG，与 `docs/design/textures/iron_harbor/tiles/` 逐字节相同），sha256 `ec303b6e… / 852b79c4… / 43cc219c… / c7532c30…`。

## 5. PortStage 实机验证（1440×900 / 960×540）

`godot --headless --path . --import` 后由 `tools/godot/capture_port_stage_res.gd` 抓图；脚本现在逐个读取 5 个槽位 GLB 并打印自证行：

```
[asset] SN_HT_Warehouse_Long.glb  slot=warehouse_long  surfaces=6 tris=7436 uv=6 tex=6
[asset] SN_HT_Warehouse_Short.glb slot=warehouse_short surfaces=6 tris=3788 uv=6 tex=6
[asset] SN_HT_Harbor_Office.glb   slot=harbor_office   surfaces=6 tris=10336 uv=6 tex=6
[asset] SN_HT_Cargo_Shed.glb      slot=cargo_shed      surfaces=5 tris=3356 uv=5 tex=5
[asset] SN_HT_Tavern.glb          slot=tavern          surfaces=6 tris=5116 uv=6 tex=6
```

- 城镇 `props=47 blockouts=0`（5 栋全部用新资产，没有回退白盒）。
- 静态合批：`batches=59 (multimesh=11 material=48)`，meshes 163→60，surfaces 286→60，`draw_meshes=91`，`tris=73 228`。
- **tri 增量精确对账**：73 228 − 53 908 = **19 320 = Σ新(22 596) − Σ旧(3 276)** —— 说明 4 个槽位确实换成了新资产，没有多塞任何东西。
- 截图：`docs/design/screenshots/iron_harbor_architecture/SN_HT_Warehouse_Long_LOD0_port_stage_{1440x900,960x540}.png`（画面里 5 栋都在；[asset] 行为脚本原样输出，含 uv_surfaces= / 	extured_surfaces=）。

## 6. 单栋预览（每栋 3 张，1280×800）

`docs/design/screenshots/iron_harbor_architecture/<Asset>_LOD0_{street_3q,front_x,roof}_1280x800.png`：3/4 街道视角、+X 正交正视、屋顶。渲染时只保留当前一栋（其余 kit 建筑临时隐藏），临时相机/3 盏太阳/世界背景全部在 `finally` 里还原。

## 7. 已知限制 / 待决

1. **draw call 从 71 → 91（+20）**：每栋 GLB 内嵌自己那份贴图，Godot 为每份内嵌图建独立 Texture2D，`_material_signature` 含 texture 实例 id ⇒ 5 栋之间无法跨楼合批。修法：把 6 张 tile 作为**共享外部贴图**（`.gltf + .bin + 贴图` 或导出后统一重写 image URI），让 5 栋引用同一贴图资源；代价是资产格式从单文件 GLB 变成多文件。当前 91 draw calls 仍在可接受范围，先记录不改。
2. **包体**：5 栋 GLB 合计 6.82 MB（每栋内嵌同一套贴图），共享外部贴图后总包体会降到 ~3.8 MB。
3. **LOD1** 仍未做（工单要求 ≤ LOD0 的 35%）；质量档位接入后再统一导出。
4. **3 个新原型**（Boiler_House / Workshop_Row / Brick_Tenement）未做。
5. `SN_HT_Cargo_Shed` 只用 5 个材质槽（无砖），`apply_to_object` 仍补满 6 个槽以便统一——没有面使用第 6 槽，不产生额外 draw。
6. 城镇布局未动（除 M1 已经改过的 warehouse_long 槽位）；4 栋新建筑靠 +X 主立面朝向机位。
7. **`SN_HT_Warehouse_Short` 两处亚像素级问题**：① ±X 山墙外皮原本与砖墙外皮 x=±5.30 共面、重叠 0.12 m²/端（跨材质外表面共面，属工单禁止项）→ 本轮已把山墙整体内收 0.02 m 修掉；② 主屋面檐口段顶皮比墙线低约 3.5 cm（砖墙顶沿 ±Y 檐口各露一条细砖线、立缝靠檐口端悬空约 4 cm）→ 记录为已知亚像素残留（124 m 下 0.5–0.7 px），修法写在生成器注释里；为避免再动已通过门禁的几何，未在本轮追加第 4 个构建周期。

