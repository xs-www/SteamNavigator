# 铁港建筑套件 · M1：朝向调整 + 共享材质 / trim sheet 验证

> 上一轮：`SN_HT_Warehouse_Long` R1 灰模通过几何门禁并**冻结**（7 436 tri / 20.000 × 9.000 × 11.000 m / 轴心底面中心）。
> 本轮（M1）只做两件事：**把装卸门主立面转到固定机位可见**，以及**上共享材质 + trim sheet**。几何三角面与包围盒一个不动。
> 结论：材质与朝向都通过了实机固定机位验证，可以据此展开其余建筑；但有 5 个待你定的点（见 §7）。
> 独立 Verifier 复核结论：**PASS-WITH-NITS**（无硬阻断；本轮已按其意见修正文档数字/措辞，并补了 `uv_projection_ok` 门禁与 `textures_applied` 硬失败）。

---

## 1. 本轮范围

- 允许：`port_stage.gd` 的 `warehouse_long` 槽位朝向/位置、共享材质与贴图、UV、内容 GLB 替换与导入刷新、截图与文档。
- 不允许（沿用上一轮）：改几何细节、改资产名/尺寸/轴心、改运行时代码里与建模无关的部分。
- 未做（明确留到后续）：LOD1、其余 4 栋 drop-in 建筑、3 个新原型、1K 污渍遮罩通道（见 §7.4）。

## 2. 朝向/位置：主立面从「擦边」改为「正对」

旧值 `pos(-30, 1.9, -34) yaw −90°` 把 20 m 长轴指向机位，主立面（+Y）法线与机位轴差 **52.2°**，装卸门在画面里被压到几乎读不出；新值 `pos(-30, 1.9, -33) yaw −106°`（`framework/ui/stages/port_stage.gd` `TOWN_SLOTS`）。

| 指标（1440×900 投影实测） | R1 前 | M1 | 变化 |
| --- | ---: | ---: | ---: |
| 主立面法线 ↔ 机位轴夹角 | 52.2° | **35.9°** | −16.3° |
| 主立面投影面积 | 16 504 px² | **22 812 px²** | **+38.2%** |
| 装卸门（u = 2.38–5.38）投影 | 1 819 px² | **2 482 px²** | **+36.4%** |
| 装卸门（u = 6.26–9.26）投影 | 1 970 px² | **2 634 px²** | **+33.7%** |
| 主立面可见率（扣邻栋遮挡） | 69.4% | 71.6%（可见 16 336 px²，+42.7%） | 两扇装卸门 100% 无遮挡 |
| 足迹（世界 X/Z） | −34.5…−25.5 / −44.0…−24.0 | −37.08…−22.92 / −43.85…−22.15 | 仍在广场 x −60…60 / z −44…−10 内 |
| 与岸吊 AABB 间隙 | 3.50 m | 0.92 m | 仍不相交 |
| +X 山墙（吊梁） | 可见 | **仍可见**（法线偏机位轴 54°，画面左侧） | 保留了 R1 的吊梁卖点 |

读数：旧机位里装卸门被挤在长墙最右端、且压在邻栋（酒馆）前面，只有 1 条窄边；新机位里两扇 3 m 双开木门连同上方气窗、人门雨棚、右侧两扇大窗构成完整立面节奏。**代价**：长墙右端约 28% 仍被酒馆挡住（城镇布局问题，不属于本建筑），+X 山墙被压缩到 54°，吊梁只读轮廓。

## 3. 共享材质与 trim sheet

### 3.1 结构与唯一真源

```
docs/design/textures/iron_harbor/iron_harbor_trim_sheet_2048.spec.json   ← 唯一手写真源（16 cell 表 + 调色 + mean 目标）
docs/design/textures/iron_harbor/iron_harbor_trim_sheet_2048.png         ← 2048² 评审用 trim sheet（3 684 190 B, sha256 18f6828a…）
docs/design/textures/iron_harbor/iron_harbor_trim_sheet_2048.stats.json  ← 每 cell 实测 mean / 接缝率 / 校验
docs/design/textures/iron_harbor/tiles/<cell>.png                        ← 16 张 512² 独立平铺贴图（运行时真正采样，2 655 480 B）
tools/art/gen_iron_harbor_trim_sheet.py                                  ← 画图器（numpy+Pillow，确定性，可重跑出不差分像素）
tools/modeling/generators/sn_iron_harbor_materials.py                     ← 共享材质库：材质↔cell、UV、校验
```

- 规格：4×4 cell、512 px/cell、**2.0 m 表面/cell = 256 px/m**、无 gutter（图集只做评审，不直接采样）、PNG-8（≤96 色）压到每张 145–187 KB。
- 16 个 cell：`brick_wall / brick_wall_soot`、`stone_base / stone_base_dirty`、`iron_dark / iron_rust`、`roof_sheet / roof_sheet_weathered`、`glass_dark / glass_reflect`、`wood_plank / wood_plank_weathered`、`plaster_light / plaster_grime`、`iron_grate / timber_beam`。本楼采样其中 6 个；其余 10 个（8 个变体档 + 2 个为后续建筑预留的格栅/梁木）已画好待用。
- 质量门禁（生成器自检，`all_ok=true`）：每 cell 实测 mean 与目标差（检测阈值 ±14，本次实际 ≤ ±0.5/255）、接缝率（自身左右/上下边界差 vs 内部差）**0.07–1.75**（限 <2.5）、两跑字节一致。

### 3.2 为什么图集是「评审件」、运行时按材质各取一张平铺贴图

工单要的是「共享 2K trim sheet」。图集本身做了，但**不能**让 UV 直接落进 cell 采样：本楼墙体、屋面、石基、檐沟都是**单个 20 m 级大四边形**，而「UV 限制在 cell 矩形内」的映射必须对大面做 `fract()` 或切分网格——两者都要加几何：

| 方案 | 代价（Blender 实测） | 结论 |
| --- | --- | --- |
| 把面切成 ≤2 m 的 UV 岛 | **+5 416 tri**（7 436 → 12 852） | 超 8 000 预算，且违反「几何冻结」 |
| 切到 ≤4 m | **+1 484 tri**（7 436 → 8 920） | 仍超预算 |
| **每个材质一张平铺贴图，UV 不设上限 + REPEAT** | **0 tri** | 采用 |

所以：trim sheet 是**唯一可评审的创作真源**；构建时把 6 个被采样的 cell 原字节导出为 `<cell>.png`（字节与图集 cell 完全一致），材质各绑一张，UV 直接 `world / 2.0` 无限平铺。所有建筑共享同一套贴图 = 工单要的「共享材质」。

### 3.3 UV 规则（`apply_to_object`）

- 按面法线主轴盒投影：`±Y 面 → (u,v) = (x,z)/2`、`±X 面 → (y,z)/2`、`±Z 面/屋面 → (x,y)/2`。
- **不做**每部件偏移：`v` 与世界 Z 对齐 ⇒ 砖缝、石缝绕整栋连续（转角不跳层）；屋面 `v = Y` ⇒ 本楼屋面采样的铆接铁板纹理（`iron_dark`）沿坡向铺开、几何立缝顺坡；门扇 `v = Z` ⇒ 木板竖直。（瓦楞 cell `roof_sheet` 本轮未被采样，见 §5.6。）
- 结果：14 560 条 loop 全部有 UV，u ∈ [−5.0, 5.0]、v ∈ [−2.25, 5.5]；**几何完全未变**（7 436 tri / 4 486 顶点，`geometry_unchanged_by_uv=true`）。
- 全部 6 个材质槽仍是 `SN_Town_*` 调色板，不新增槽位（工单上限 6）。

### 3.4 本楼采样的 6 个 cell

| 材质槽 | cell（mean sRGB） | 覆盖的构件 |
| --- | --- | --- |
| `SN_Town_Brick` | `brick_wall` (118,86,72) | 长墙/侧墙墙板、壁柱 |
| `SN_Town_Plaster` | `plaster_light` (196,184,160) | 山墙三角（浅色山墙是深色屋面能读出来的原因） |
| `SN_Town_Wood` | `wood_plank_weathered` (70,60,50) | 装卸门门扇、人门、服务门（灰褐旧木与橙砖靠色相拉开） |
| `SN_Town_Iron` | `iron_dark` (52,54,56) | 滑轨/吊架/滚轮、门槛、吊梁/滑轮、落水管、通风帽、**屋面+脊瓦+立缝** |
| `SN_Town_Stone` | `stone_base_dirty` (116,111,101) | 石基、檐口、窗台/门槛（潮湿污渍让 0.58 m 基座不再是一条惨白带） |
| `SN_Town_Glass` | `glass_dark` (38,47,50) | 15 扇窗 + 2 个气窗（暗窗） |

「轻度污渍」本轮的实现方式：污渍**烘进 cell**（砖的烟熏/雨痕、石的潮湿、铁的锈斑、屋面的锈流、木的风化灰），并以 `*_soot / *_dirty / *_weathered / *_rust / *_grime` 变体覆盖更强一档。本楼有意挑了「木、石用风化档、砖用干净档」，保住体量价值结构。**没有**做建筑级（整栋从下往上变脏的）大尺度污渍——那需要额外通道，见 §7.4。

## 4. 证据

### 4.1 Blender 八视图（`docs/design/screenshots/iron_harbor_architecture/`）

`*_port_stage_fixed_1440x900` / `*_port_stage_fixed_960x540`（固定机位换算）、`*_port_stage_centred_1440x900`、`*_street_low_1440x900`（1.7 m 眼高）、`*_front_1440x900`（+Y 正交正视）、`*_roof_1440x900`、**`*_detail_door_1440x900`**（装卸门近景：砖/木/铁/玻璃/石）、**`*_detail_base_1440x900`**（墙脚：石基/砖/落水管/门槛/五金）。

### 4.2 PortStage 实机固定机位

`SN_HT_Warehouse_Long_LOD0_port_stage_1440x900.png`、`..._960x540.png`（由 `tools/godot/capture_port_stage_res.gd` 抓，窗口模式真实渲染）。

实机自证行（脚本新增，`[asset]` 直接读内容路径导入后的场景）：

```
[asset] SN_HT_Warehouse_Long.glb surfaces=6 tris=7436 uv_surfaces=6 textured_surfaces=6
        materials=["SN_Town_Brick","SN_Town_Plaster","SN_Town_Wood","SN_Town_Iron","SN_Town_Stone","SN_Town_Glass"]
        textures={each: 512x512}
```

- GLB：1 473 876 B，sha256 `1b6d995f0f62bc1d3cb650ff22d3faae6bbd934fa99f0631f01e7cf1f62e437d`，6 个内嵌 PNG（合计 1 018 310 B）、6 个 primitive 全部带 `TEXCOORD_0`；三角面仍 **7 436**。
- Stage：`town props=47 blockouts=0`、`static batches=39 (multimesh=11 material=28)`、meshes 163→40、surfaces 299→40、`draw_meshes=71`。
- 注意：本机 stage 的 `tris=53 908`（取自 10:59:27 的 stage 自检输出；10:58 起 stage 已导入带贴图 7 436 tri 版本）**不能**再当资产增量用——并行工作流在 10:54–10:58 往城镇里加了摊位/杂物并改了船位，stage 总量已含那批内容。本轮资产证据一律以上面的 `[asset]` 行为准（上一轮用「stage 总量差 = 资产 tri 差」的方法在并发改动下失效，已在文档改正）。
- 纹理经过 static batching 后仍在（batcher 的 `_material_signature` 带 `albedo_texture` 且合并时保留 `ARRAY_TEX_UV`），1440 图上 6 个材质槽（Brick / Plaster / Wood / Iron（含屋面）/ Stone / Glass）都能分辨。

### 4.3 门禁检查表

| 检查 | 结果 |
| --- | --- |
| 三角面/顶点/包围盒/轴心 | 7 436 / 4 486 / 20.000×9.000×11.000 m / zmin 0；`geometry_unchanged_by_uv=true` |
| 网格健康 | 孤立点 0 / 退化面 0 / 非流形边 0 / 边界边 0（UV 不影响流形性） |
| 材质槽 | 6 个，全部调色板内，全部绑定 512² 贴图（`all_images_bound=true`）；带贴图构建若贴图缺失则 `textures_applied=false` 直接判失败，不会静默退回灰模 |
| UV | 14 560/14 560 loop 有 UV、无塌陷面（`no_collapsed_uv_faces=true`）、**按面主轴重算的盒投影逐 loop 一致**（`uv_projection_ok=true`，容差 1e-4） |
| 旧占位资产 | 场景 digest 与基线一致，`SN_Harbor_Town/SN_HT_Warehouse_Long`（1 132 tri）零改动 |
| 导入缓存 | 换 GLB 后 `godot --headless --path . --import` 刷新，否则 stage 仍渲旧模型 |
| 回滚路径 | 旧 GLB 备份 `.design/buildings/iron_harbor/SN_HT_Warehouse_Long_legacy.glb`，sha256 仍是 `2576e3db…`；`restore_legacy_glb()` 一键还原 |
| 贴图来源 | `docs/design/textures/iron_harbor/tiles/` 为手写源；Godot 会把内嵌贴图解包到 GLB 同级目录，已在 `.gitignore` 排除（构建产物） |

## 5. 已知限制（都不是本轮要修的）

1. **124 m 距离下纹素远小于像素**：相机距约 126 m、1 px ≈ 74 mm 表面，而 1 texel = 2.0 m/512 ≈ 3.9 mm，即每个像素覆盖约 19×19 texel，图案细节在固定机位必然被平均掉；砖缝 0.077 m ≈ 1 px。固定机位只能读出材质**价值结构**（砖墙暖红 / 石基浅 / 屋面深 / 门木褐 / 窗黑 / 山墙奶白），图案细节要靠近景图。
2. **960×540**：体量+材质分区仍可读，门五金、窗框、滚轮是亚像素。
3. **邻栋遮挡 ~28%**：酒馆（`tavern` 槽位）挡住长墙右端两扇大窗；要完全露出需要动城镇布局（并行工作流的地盘）。
4. **1 px 蓝点**：所有建筑/船边缘都有，属 stage 视口抗锯齿，不是本模型。
5. **仓库体积**：图集 3.68 MB + 贴图 2.66 MB（PNG-8 已压过）；其余 4 栋直接复用同一套贴图，不再增重。
6. **屋面与铁件共用 `SN_Town_Iron`**（6 槽限制）：`roof_sheet`（瓦楞铁）画好了但本楼没用，屋面靠几何立缝+脊瓦读；若允许 7 个槽位可给屋面单开材质。
7. **无大尺度污渍通道**：见 §7.4。

## 6. 复现

```powershell
# 1) 重画 trim sheet（确定性；改 spec 后必须重跑）
python tools/art/gen_iron_harbor_trim_sheet.py
# 2) Blender 内：重建几何 + 上材质/UV + 自检
#    ns = {...}; exec(生成器); ns["build_all"](); ns["report"]()
# 3) Blender 内：导出含内嵌贴图的内容 GLB（并留候选副本）
#    export_warehouse_long_r1()
# 4) 刷新导入 + 抓两张实机图
godot --headless --path . --import
godot --path . --script res://tools/godot/capture_port_stage_res.gd -- 1440 900
godot --path . --script res://tools/godot/capture_port_stage_res.gd -- 960 540
# 5) 回滚（如需）
#    restore_legacy_glb() + godot --headless --path . --import
```

## 7. 待决定

1. **是否据此展开其余 4 栋**（warehouse_short / harbor_office / cargo_shed / tavern + 3 个新原型）？现成的复用面：6 材质槽、6 张贴图、UV 规则、trim sheet 的 10 个未用 cell（8 个变体档 + 2 个预留：`iron_grate` / `timber_beam`）。
2. **内容 GLB 是否正式保留本轮带贴图版本**？当前内容路径已是带贴图资产（已 import）；旧资产备份与还原脚本都在。
3. **布局改动是否保留**？`warehouse_long` 的 yaw −106/pos −33 是为此机位服务的；与带贴图 GLB 必须同进同退（旧资产门窗朝背面，换回旧 GLB 时朝向会显得更差）。
4. **污渍强度与 1K 污渍遮罩通道**：工单写的是「共享 2K trim sheet + 1K 污渍遮罩」，本轮只做到「污渍烘进 cell + 变体档」，没有独立遮罩通道。若需要建筑级污渍（底部积灰、檐下烟熏），可选：(a) 每材质一张 1K 遮罩图（6 张，槽位不变，UV 需第二套或线性 UV 复用）；(b) 顶点色污渍（1 个 COLOR_0 属性，无额外贴图，但要验证 Godot 导入是否 `vertex_color_use_as_albedo`）。建议先 (b) 试验。
5. **是否给屋面单开第 7 个材质槽**（突破工单「≤6 槽」）以用上 `roof_sheet` 瓦楞铁；或同一张铁材质下把屋面 UV 旋到瓦楞方向（会同时影响铁件，不推荐）。

## 8. 贴图设计与规格书的小偏差（生成侧已记录）

- 无缝约束下，屋面肋取 **13 条 / 2 m（0.1538 m，比 0.15 m 宽 2.6%）**、木板取 **9 条 / 2 m（0.2222 m，宽 1%）**、砖层 26 层 / 2 m、石层 4 层 / 2 m；规格书里按像素写的旧数字（18.4 px 砖层 / 36 px 肋 / 53 px 板）只作美术意图，**以米制为准**。
- 96 色量化的极平滑灰泥在掠射光下可能有轻微 banding（3 m 内未见），在意可升到 128 色。
- `iron_rust` 仍偏棕橙（palette 决定），若美术要更冷的锈可下轮调 tint。
- 近均值风险对（未来同楼并用时需 tint 区分）：`wood_plank ↔ timber_beam` ΔRGB≈11、`iron_dark ↔ iron_grate` ≈14、`glass_dark ↔ iron_dark` ≈17。
- 生成器确定性：另起独立进程全量重跑，montage 与 16 张 tile 逐字节一致（`deterministic_check=true`）。

