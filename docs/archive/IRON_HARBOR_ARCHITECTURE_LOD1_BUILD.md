# 铁港建筑套件 · 批次 A：5 栋 LOD1 参数化生成 + Warehouse_Short 檐口修复

> 前情：[IRON_HARBOR_ARCHITECTURE_M1.md](IRON_HARBOR_ARCHITECTURE_M1.md)（Warehouse_Long 朝向 + 共享材质/trim sheet）、[IRON_HARBOR_ARCHITECTURE_BATCH2.md](IRON_HARBOR_ARCHITECTURE_BATCH2.md)（其余 4 栋 LOD0）。
> 本轮对应 [MODELING_REQUIREMENTS_NEXT_BATCH.md](MODELING_REQUIREMENTS_NEXT_BATCH.md) §5.1 / §9 的**批次 A 建模部分**：5 栋建筑 LOD1、Warehouse_Short 檐口修复、LOD0 可复现重建、工作台自检与预览证据。
> **本轮不导出 GLB、不保存/覆盖 `.blend`、不改 manifest/framework/tests/docs/static/todo.md/ASSET_MAP.md**（按任务约束由 Lead 在验收后处理）。

## 1. 范围与结论

| 项 | 结果 |
| --- | --- |
| 新增对象 | `SN_HT_<Name>_LOD1` × 5（集合 `SN_Iron_Harbor_Architecture`，工作台 y=175 一排） |
| LOD0 重建 | 5 栋全部从生成器重建；4 栋与重建前会话对象**几何签名逐字节一致**，Warehouse_Short 仅屋面 8 个顶点按修复变化 |
| LOD1 三角面 | 合计 **6 564 tri**（LOD0 30 032 的 **21.85%**，上限 10 508） |
| LOD1 逐栋上限 | 全部 ≤ LOD0 的 35%（最紧的 Warehouse_Short 27.98%，余量 265 tri） |
| bbox / 轴心 | LOD1 与 LOD0 世界包围盒逐轴差值 **0.000 m**；底面中心 zmin=0、x/y 包围盒中心 = 0（10/10 通过） |
| 网格健康 | 孤立点 0 / 退化面 0 / 非流形边 0 / 边界边 0（10/10 通过，每个实体闭合） |
| 材质 / UV | 每栋 6 槽全部 `SN_Town_*`；UV 盒投影逐 loop 可复算；6 张 512² 贴图全部绑定（10/10 通过） |
| 檐口修复 | 屋面顶皮在 ±Y 墙线处：**−3.543 cm → 0.000 cm**；立缝檐口端悬空：**4.525 cm → 0.688 cm** |
| 全场景回归 | 除 10 个套件对象外，245 个对象的 digest 与改动前基线**完全一致**（缺失/新增/修改全 0；旧 `SN_Harbor_Town` 10 件占位零改动） |
| 预览图 | **30 张 1280×800 EEVEE PNG**（5 栋 × [3 张 LOD1 + 3 张 LOD0/LOD1 同机位对比]） |

## 2. 参数化真源与生成器结构

新增 `tools/modeling/generators/sn_iron_harbor_architecture_lod1_generator.py`（约 1 400 行，纯 Python 几何 + Blender 侧 harness）：

- **不复制 LOD0 数字**。`lod0(asset)` 用 importlib 加载 5 个 LOD0 生成器，LOD1 直接读取它们的模块常量（`TARGET_SIZE / HALF_* / WALL_* / EAVE_Z / RIDGE_* / ROOF_* / *_OPENINGS / DESIGN 常量`），并复用它们自己的**闭合实体工具**：`Part / box / tb / prism_x / prism_y / prism_z / lprism_u / lbox / lp / lvchamfer_box / beam / rod / chamfer_beam / panel / sweep / rod / revolved / ring_at / larc_band / lprism_d / plot` 级别的 `_stone_plinth / _plinth / _gable / _cornice / _chimney / _roof_section / _shed_roof_section / _threshold / _loading_apron / _arch_lune / _win_rows`。
- 因此 LOD1 的外轮廓、墙线、开口坐标、屋面坡度、石基/檐口/烟囱/塔身位置与 LOD0 **同源**，`_check_sources()` 在 dry-run 与 Blender 构建时会校验 `TARGET_SIZE` 未漂移。
- 每栋一个顶层函数：`build_warehouse_long_lod1 / build_warehouse_short_lod1 / build_harbor_office_lod1 / build_cargo_shed_lod1 / build_tavern_lod1`，返回 `Part`（顶点/面/每面材质）。
- Blender 侧入口：`build_all()`（重建 5 栋 LOD0 + 建 5 栋 LOD1 + 每栋写共享材质/UV + 基线 digest）、`report()`（自检 + LOD0↔LOD1 对比 + 可复现 + 檐口修复 + digest 回归，落盘 `.design/buildings/iron_harbor/a1/lod1_report.json`）、`render_previews(assets=None)`（EEVEE 预览 + finally 还原）。
- 纯 Python 干跑入口：`build_all_geometry()`（`ITEMS / TOTAL_BUDGET = 10 508` 满足 `dryrun_props.py` 约定）。

## 3. LOD1 设计：每栋保留 / 删除项

| 资产 | LOD0 tri | LOD1 tri | LOD1 上限 | 比例 | LOD1 保留（需求 §5.1） | LOD1 删除 |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| `SN_HT_Warehouse_Long` | 7 436 | **1 584** | 2 602 | 21.30% | 长体量、2 个双高装卸门真凹口（3.0×5.18，凹 0.28）、山墙吊梁（牛腿+倒角主梁+吊链吊钩）、双坡铁屋面（板厚 0.24+脊瓦+8 立缝）、石基、石檐口、两端山墙+铁拉杆、2 个简化通风帽 | 窗框/窗棂/窗台窗楣、气窗、滑轨吊架吊轮、落水管/檐沟、砖壁柱、门槛平台细部 |
| `SN_HT_Warehouse_Short` | 3 788 | **1 060** | 1 325 | 27.98% | 不对称单坡侧棚（3 木柱+过梁+斜撑+单坡铁屋面+封檐板）、装卸门真凹口、**偏置屋面通风管**、不对称双坡主屋面、石基、±X 山墙三角、简化石檐口、主立面 2 窗/背面门/后侧 2 窗/侧棚 2 窗 | 窗框窗棂、招牌、砖壁柱、落水管/檐沟、服务门台阶/门槛台/石腰线、山墙窗+铁拉杆、檐口细线脚 |
| `SN_HT_Harbor_Office` | 10 336 | **1 896** | 3 617 | 18.34% | 三层分段（2 道通长石腰线）、拱形入口（拱肩填石+6 段拱券环+拱心石+深木双门+铁门槛）、钟楼（砖塔身+石基环+2 面空白钟盘+石檐环+八棱尖顶+铁尖 z=14.00）、石檐口、2 个阳台大轮廓（石板+连续实体栏板）、主立面 6 窗+2 落地门、+Y 6 窗、4 根转角石壁柱、平屋面+女儿墙、屋角旗杆座、空白石匾 | 窗框窗棂窗台窗楣、落地门框、齿饰、落水管/檐沟、四面钟盘中的 −X/−Y 两面、内壁柱、阳台牛腿/栏杆立柱 |
| `SN_HT_Cargo_Shed` | 3 356 | **776** | 1 174 | 23.12% | 开敞柱廊（4 柱+石柱础+前檐梁+系梁+2 斜撑）、单坡铁皮棚顶（厚 0.22+前檐 2 段倒角）、工作台大体量、后墙+高位小窗真凹口、石基+前侧踏步、±Y 低矮女墙、后挡板木带（简化）、吊钩（简化吊链）、1 木箱+1 木桶体量 | 12 道立缝（留 4 道）/10 道露明椽、货箱/托盘/麻袋堆、木梯/吊灯/绞盘/铁柱箍/连接板/矮挡墙压条/拉杆 |
| `SN_HT_Tavern` | 5 116 | **1 248** | 1 790 | 24.39% | 两层轮廓（首层砖/二层灰泥+层间石腰带）、门廊（石地面+2 木柱+石柱础+斜撑+廊顶横梁+单坡廊顶）、悬挂空白招牌、高砖烟囱（顶 z=8.00）、双坡屋面+脊瓦、石基+门槛、±X 山墙+石檐口、门窗真凹口 | 窗框窗棂窗台窗楣/百叶窗扇、木桶/落水管/檐沟、门廊矮栏/灯架/铁锚板/转角错缝石、山墙百叶窗、山墙铁拉杆 |
| **合计** | **30 032** | **6 564** | **10 508** | **21.85%** | — | — |

窗体/门洞全部用 `panel()` 生成的**真凹口**背书（窗 0.14–0.16 m、门 0.20–0.28 m），凹底直接给玻璃/工/铁材质，没有共面深色贴片；栏杆按需求改为带厚度连续实体板。所有 LOD1 三角面均高于"只靠贴图撑轮廓"的最低量，LOD0 的轮廓识别点（长体量/双高门/吊梁、单坡侧棚/偏置通风管、钟楼/拱门/阳台、开敞柱廊/单坡棚顶/工作台、门廊/招牌/烟囱）全部保留。

## 4. Warehouse_Short 檐口修复（唯一一处 LOD0 几何改动）

### 4.1 根因（旧参数化真源的实际测量）

`_roof_section()` 把檐口倒角起点从 `ye` 向内收 0.06 m，却**没有**同步抬升 `0.06 × SLOPE`，导致主屋面顶皮实际坡度被抬高：

| 量（旧 `HEAD` 生成器实测） | 值 |
| --- | ---: |
| 名义坡度 `SLOPE` | 0.643598 |
| 旧顶皮实际有效坡度（脊线 → 倒角起点） | **0.655858** |
| 顶皮在 ±Y 墙线（`y = Y_RIDGE ± 2.89`）处 z | **7.46457**（墙线 `EAVE_Z = 7.50000`，低 **3.543 cm**） |
| 屋面立缝檐口端底皮 z / 该处屋面顶皮 z | 7.35241 / 7.30716 → **悬空 4.525 cm** |

这正是 [BATCH2 §7.7](IRON_HARBOR_ARCHITECTURE_BATCH2.md) 记录的"砖墙顶沿 ±Y 檐口露一条细砖线 + 立缝靠檐口端悬空"。

### 4.2 修法（只改 `_roof_section` 的 6 个顶皮点 z，不改平面布局）

`tools/modeling/generators/sn_iron_harbor_warehouse_short_generator.py` `_roof_section()` 现在让所有倒角点都按真实顶皮线取 z：

```python
def top(y):
    return RIDGE_TOP - abs(y - Y_RIDGE) * SLOPE
# 脊线底皮 / 檐口外沿底皮 / 檐口立面顶 / 倒角第 1 段 / 倒角第 2 段 / 脊线顶皮
```

三角面、顶点数、包围盒、轴心、主立面开口全部不变；只移动 8 个屋面顶皮顶点（每坡 2 个截面点 × 挤出 2 端）。

### 4.3 修复前后实测（旧源码实测 vs 新源码实测）

| 指标 | 修复前（HEAD 生成器实跑） | 修复后 | 差值 |
| --- | ---: | ---: | ---: |
| 顶皮有效坡度 | 0.655858 | **0.643598**（= SLOPE） | −0.012260 |
| 顶皮在 ±Y 墙线处 z | 7.46457 | **7.50000** | +0.03543 m |
| 顶皮 − 墙线（`EAVE_Z`=7.50） | **−3.543 cm** | **0.000 cm** | +3.543 cm |
| 立缝檐口端悬空量 | **4.525 cm** | **0.688 cm**（设计值 0.03 m 中心偏移 − 半厚；立在顶皮上） | −3.837 cm |
| tri / verts | 3 788 / 2 294 | **3 788 / 2 294** | 0 / 0 |
| 包围盒 | 11.000 × 9.000 × 9.500 | **11.000 × 9.000 × 9.500** | 0 |
| zmin / 轴心 | 0 / 0,0 | **0 / 0,0** | 0 |
| 变化顶点 | — | **8 个，最大位移 3.861 cm** | — |
| 材质槽 / 贴图 | 6 槽 | 6 槽，同一套 cell | 不变 |

> 数据来源：`.design/buildings/iron_harbor/a1/lod1_report.json` 的 `cornice_fix`。旧参数化真源从 `git show HEAD:tools/modeling/generators/sn_iron_harbor_warehouse_short_generator.py` 取出，作为 `warehouse_short_pre_fix.py` 在 Blender 内**真实重新生成**后测量（不是手算）。

## 5. 纯 Python 干跑（不进 Blender）

命令：

```powershell
python tools/modeling/generators/dryrun_lod1_batch_a.py       # LOD0/LOD1 对比 + 落盘
python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_iron_harbor_architecture_lod1_generator.py
```

结果（`.design/buildings/iron_harbor/a1/dryrun_lod1.json`，`ALL OK`）：

| 对象 | LOD0 tri | LOD1 tri | 上限 | 比例 | 尺寸 (m) | 目标 (m) | 尺寸差 | 边界边 | 非流形 | 退化面 | zmin | 轴心 x,y |
| --- | ---: | ---: | ---: | ---: | --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| `SN_HT_Warehouse_Long_LOD1` | 7 436 | **1 584** | 2 602 | 0.2130 | 20.000, 9.000, 11.000 | 20, 9, 11 | 0,0,0 | 0 | 0 | 0 | 0.0 | 0, 0 |
| `SN_HT_Warehouse_Short_LOD1` | 3 788 | **1 060** | 1 325 | 0.2798 | 11.000, 9.000, 9.500 | 11, 9, 9.5 | 0,0,0 | 0 | 0 | 0 | 0.0 | 0, 0 |
| `SN_HT_Harbor_Office_LOD1` | 10 336 | **1 896** | 3 617 | 0.1834 | 9.000, 8.000, 14.000 | 9, 8, 14 | 0,0,0 | 0 | 0 | 0 | 0.0 | 0, 0 |
| `SN_HT_Cargo_Shed_LOD1` | 3 356 | **776** | 1 174 | 0.2312 | 8.000, 6.000, 4.500 | 8, 6, 4.5 | 0,0,0 | 0 | 0 | 0 | 0.0 | 0, 0 |
| `SN_HT_Tavern_LOD1` | 5 116 | **1 248** | 1 790 | 0.2439 | 10.000, 8.000, 8.000 | 10, 8, 8 | 0,0,0 | 0 | 0 | 0 | 0.0 | 0, 0 |
| **合计** | 30 032 | **6 564** | 10 508 | 0.2185 | — | — | — | 0 | 0 | 0 | — | — |

`dryrun_props.py`（通用约定入口）同样 `ALL OK`：5 件 tri 全部低于 strict 上限、尺寸与目标一致、无边界/非流形/退化面/浮空。

## 6. Blender 工作台自检

命令（Blender MCP 内）：

```python
p = r"<repo>/tools/modeling/generators/sn_iron_harbor_architecture_lod1_generator.py"
ns = {"__name__": "lod1gen", "__file__": p}
exec(compile(open(p, encoding="utf-8").read(), p, "exec"), ns)
ns["build_all"](); ns["report"]()          # 落盘 .design/buildings/iron_harbor/a1/lod1_report.json
ns["render_previews"](["SN_HT_Tavern"])    # 可选：按资产渲染预览
```

每栋 16 项检查（`tris_within_cap / size_matches_target_0.02 / grounded_zmin_zero / pivot_ground_centre / material_slots_le_6 / palette_only / loose_verts_zero / degenerate_faces_zero / non_manifold_zero / boundary_edges_zero / uv_loops_complete / uv_projection_ok / no_collapsed_uv_faces / all_images_bound / images_512 / geometry_unchanged_by_uv`）**10/10 对象全部 pass**（LOD0 用于对照、LOD1 为交付项）。

| 对象 | tri | verts | 尺寸 (m) | zmin | 材质槽（全 `SN_Town_*`） | UV loops | UV 范围 u / v | 绑定贴图 | 网格健康 |
| --- | ---: | ---: | --- | ---: | ---: | ---: | --- | ---: | --- |
| `SN_HT_Warehouse_Long_LOD0` | 7 436 | 4 486 | 20.000×9.000×11.000 | 0 | 6 | 14 560 | −5.0…5.0 / −2.25…5.5 | 6 × 512² | 全 0 |
| `SN_HT_Warehouse_Long_LOD1` | **1 584** | 902 | 20.000×9.000×11.000 | 0 | 6 | 3 176 | −5.0…5.0 / −2.25…5.5 | 6 × 512² | 全 0 |
| `SN_HT_Warehouse_Short_LOD0` | 3 788 | 2 294 | 11.000×9.000×9.500 | 0 | 6 | 7 410 | −2.75…2.75 / −2.25…4.75 | 6 × 512² | 全 0 |
| `SN_HT_Warehouse_Short_LOD1` | **1 060** | 606 | 11.000×9.000×9.500 | 0 | 6 | 2 094 | −2.75…2.75 / −2.25…4.75 | 6 × 512² | 全 0 |
| `SN_HT_Harbor_Office_LOD0` | 10 336 | 6 292 | 9.000×8.000×14.000 | 0 | 6 | 20 236 | −2.25…2.25 / −2.0…7.0 | 6 × 512² | 全 0 |
| `SN_HT_Harbor_Office_LOD1` | **1 896** | 1 060 | 9.000×8.000×14.000 | 0 | 6 | 3 800 | −2.25…2.25 / −2.0…7.0 | 6 × 512² | 全 0 |
| `SN_HT_Cargo_Shed_LOD0` | 3 356 | 2 112 | 8.000×6.000×4.500 | 0 | 6（5 用） | 7 068 | −2.0…2.0 / −1.5…2.25 | 5 × 512² | 全 0 |
| `SN_HT_Cargo_Shed_LOD1` | **776** | 480 | 8.000×6.000×4.500 | 0 | 6（4 用） | 1 604 | −2.0…2.0 / −1.5…2.25 | 4 × 512² | 全 0 |
| `SN_HT_Tavern_LOD0` | 5 116 | 3 064 | 10.000×8.000×8.000 | 0 | 6 | 10 162 | −2.5…2.5 / −2.0…4.0 | 6 × 512² | 全 0 |
| `SN_HT_Tavern_LOD1` | **1 248** | 712 | 10.000×8.000×8.000 | 0 | 6 | 2 458 | −2.5…2.5 / −2.0…4.0 | 6 × 512² | 全 0 |

> 材质槽说明：`apply_to_object` 会把 6 个调色板材质补满槽位；表中"n 用"是实际被面引用的槽数。Cargo_Shed 的 LOD1 只用木/铁/石/玻璃 4 个槽（LOD0 另用灰泥麻袋 5 个槽），补满的未用槽没有面引用，不产生额外 draw；`all_images_bound / images_512` 检查均通过。

LOD0↔LOD1 对比（world bbox 按同槽位换算，两者 location 仅工作台行不同、旋转/缩放一致）：

| 资产 | bbox 尺寸差 Δx,Δy,Δz (m) | bbox 角点差 | zmin 差 | 轴心差 | 判定 |
| --- | --- | --- | ---: | --- | --- |
| Warehouse_Long | 0.000, 0.000, 0.000 | 全 0 | 0 | 0, 0 | PASS |
| Warehouse_Short | 0.000, 0.000, 0.000 | 全 0 | 0 | 0, 0 | PASS |
| Harbor_Office | 0.000, 0.000, 0.000 | 全 0 | 0 | 0, 0 | PASS |
| Cargo_Shed | 0.000, 0.000, 0.000 | 全 0 | 0 | 0, 0 | PASS |
| Tavern | 0.000, 0.000, 0.000 | 全 0 | 0 | 0, 0 | PASS |

材质 cell 与 BATCH2 `BUILDINGS` 完全一致（Warehouse_Long 用共享材质模块默认 M1 cells）；`apply_to_object(obj, cells=...)` 在每一栋测量前**轮到谁就重写一次**，规避共享材质 datablock 覆盖坑。最终全局材质状态停在最后应用的 Tavern cells（与 BATCH2 行为一致），任何导出/渲染前都必须按栋重写。

## 7. LOD0 可复现证据

1. **跨会话一致**：改动前先把工作台 5 栋 LOD0 的几何签名（顶点坐标 + 面/材质索引的 sha256）落到 `.design/buildings/iron_harbor/a1/lod0_before.json`；从生成器重建后对比（`lod0_session_reproducibility.json`）：

| LOD0 对象 | 重建前 tri | 重建后 tri | 几何签名 | 说明 |
| --- | ---: | ---: | --- | --- |
| Warehouse_Long | 7 436 | 7 436 | **一致** | 逐字节相同 |
| Warehouse_Short | 3 788 | 3 788 | 不一致（符合预期） | 仅檐口修复的 8 个屋面顶点（§4） |
| Harbor_Office | 10 336 | 10 336 | **一致** | 逐字节相同 |
| Cargo_Shed | 3 356 | 3 356 | **一致** | 逐字节相同 |
| Tavern | 5 116 | 5 116 | **一致** | 逐字节相同 |

2. **同会话重复构建**：`report()` 内置"构建前对象 vs 重建对象"签名对比；连续两次 `build_all()` 后 5 栋全部 `geo_sig_equal=true`、`changed_vertices=0`、`max_vertex_delta_m=0.0`。

## 8. 全场景 digest 回归

- 基线：改动前 `.design/buildings/iron_harbor/a1/baseline_digest.json`，排除 5 个 `_LOD0` 后 **245 个对象**（全场景 250 objects = 228 mesh + 19 empty + 2 camera + 1 light）。
- 构建后：排除 10 个 `_LOD0/_LOD1` 后仍 **245 个对象**（全场景 255 objects = 233 mesh + 19 empty + 2 camera + 1 light）。
- 对比字段：对象名/类型/data 名、location/rotation/scale/dimensions、`matrix_world`、`hide_render/hide_viewport`、parent、所属集合、材质槽、**mesh 顶点+面+材质索引几何哈希**（`final_scene_state.json`）。
- 结果：`missing = []`、`added = []`、`modified = []`，集合对象数逐项一致；旧 `SN_Harbor_Town` 10 件 `SN_HT_*` 占位（y=110 一排：Warehouse_Long / Short / Harbor_Office / Cargo_Shed / Tavern / Fence_Row / Dock_Worker_A / Dock_Worker_B / Rowboat / Cargo_Lighter）位置/尺寸/集合/几何不变；其他 9 个集合（船、模块、设施、道具、起重机、干船坞等）全部不变。
- 说明：`Warehouse_Long_LOD0` 与旧占位 `SN_HT_Warehouse_Long` 同处 `(-48, 110, 0)` 是上一轮工作台既有摆放，本轮沿用未动。

## 9. 预览图清单（30 张，1280×800，EEVEE + 临时 3 盏太阳光/深色世界）

目录：`docs/design/screenshots/iron_harbor_architecture/`；命名规则：
- `<Asset>_LOD1_{street_3q,front_x,roof}_1280x800.png`（每栋 3 张）
- `<Asset>_LOD1_vs_LOD0_{street_3q,front_x,roof}_1280x800.png`（同机位左右并排：LOD1 临时平移到 LOD0 旁 3 m，渲染后立刻还原位置）

```
SN_HT_Warehouse_Long_LOD1_{street_3q,front_x,roof}_1280x800.png
SN_HT_Warehouse_Long_LOD1_vs_LOD0_{street_3q,front_x,roof}_1280x800.png
SN_HT_Warehouse_Short_LOD1_{street_3q,front_x,roof}_1280x800.png
SN_HT_Warehouse_Short_LOD1_vs_LOD0_{street_3q,front_x,roof}_1280x800.png
SN_HT_Harbor_Office_LOD1_{street_3q,front_x,roof}_1280x800.png
SN_HT_Harbor_Office_LOD1_vs_LOD0_{street_3q,front_x,roof}_1280x800.png
SN_HT_Cargo_Shed_LOD1_{street_3q,front_x,roof}_1280x800.png
SN_HT_Cargo_Shed_LOD1_vs_LOD0_{street_3q,front_x,roof}_1280x800.png
SN_HT_Tavern_LOD1_{street_3q,front_x,roof}_1280x800.png
SN_HT_Tavern_LOD1_vs_LOD0_{street_3q,front_x,roof}_1280x800.png
```

- 每栋 LOD1 可读轮廓：长体量+双高门+吊梁（Long）；短体量+单坡侧棚+偏置通风管（Short）；三层分段+拱门+钟楼+阳台（Office）；低矮开敞柱廊+单坡棚顶+工作台（Shed）；两层砖灰泥+门廊+悬挂招牌+烟囱（Tavern）。
- 渲染状态还原实测：额外跑一遍渲染前后对场景「相机/引擎/分辨率/filepath/色彩模式/世界背景色+强度/全部 mesh 的 hide_render/对象数/LOD1 location」逐项快照，`diffs = {}`；临时对象 `TMP_*` 残留 0（`final_scene_state.json`）。

## 10. 复现命令

```powershell
# 1) 纯 Python 干跑（不需要 Blender）
python tools/modeling/generators/dryrun_lod1_batch_a.py
python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_iron_harbor_architecture_lod1_generator.py

# 2) Blender 内：重建 5 栋 LOD0 + 建 5 栋 LOD1 + 自检（不保存 .blend、不导出 GLB）
#    exec(sn_iron_harbor_architecture_lod1_generator.py); ns["build_all"](); ns["report"]()

# 3) Blender 内：预览渲染（逐栋或一次全部；finally 还原相机/灯/世界/引擎/分辨率）
#    ns["render_previews"](["SN_HT_Warehouse_Short", ...])  或  ns["render_previews"]()
```

中间产物（本批不交付到内容目录）：`.design/buildings/iron_harbor/a1/`
`baseline_digest.json`、`lod0_before.json`、`lod0_session_reproducibility.json`、`dryrun_lod1.json`、`lod1_report.json`、`final_scene_state.json`、`warehouse_short_pre_fix.py`（HEAD 旧源码副本，仅用于修复前后测量）。

## 11. 已知限制 / 待决

1. **LOD1 窗体无框**：只保留真凹口 + 凹底材质，删除窗框/窗棂/窗台窗楣（需求允许删除小件）。固定 3/4 机位可读为"深色开口"，近景贴脸看会偏简；这是 LOD1 的预期表现。
2. **Harbor_Office 只保留 2 面钟盘**（+X/+Y 可见面），−X/−Y 做成实墙；钟盘无指针细节。钟楼轮廓、尖顶、铁尖 z=14.00 全部保留。
3. **Warehouse_Long LOD1 屋面直接复用 LOD0 的 `_roof()`**（含 8 道立缝 + 脊瓦 + 完整石檐口），是 1 584 tri 的主要来源；仍远低于 2 602 上限，换来 bbox 与轮廓零风险。若后续要更低，可减立缝至 4 道。
4. **Tavern 高烟囱在 3/4 机位被屋脊部分遮挡**：烟囱位置取自 LOD0 真源（−X 端），轮廓顶 z=8.00 保留；这是原设计位置，不为了 LOD1 挪动。
5. **Cargo_Shed LOD1 只用到 4 个调色板材质**（无砖/灰泥面）；共享模块仍把材质槽补满 6 个（与 LOD0 的 5 槽行为一致），未使用的槽没有面引用，不产生额外 draw 面。
6. **共享材质 datablock 坑仍在**：6 个 `SN_Town_*` 是全局 datablock，最终状态 = 最后应用的 Tavern cells。任何按栋导出/渲染前必须再次 `apply_to_object(cells=...)`；本批 `report()`/`render_previews()` 已按栋重写并在测量前验证。
7. **LOD1 位置**：放在工作台 y=175 一排（LOD0 在 y=110/150 两排），这是工作台摆放，不动 PortStage 槽位；实际接入时按资产名替换即可。
8. **本批不更新** `docs/static/`、`todo.md`、`ASSET_MAP.md`、manifest、GLB 内容与 `.blend`（任务明确禁止/留给 Lead 验收后处理）。新增生成器与 dryrun 脚本已在文件头写 `@static-doc` 注释块。
9. **未做 960×540 / 1440×900 实机验证**：本轮只交付 Blender 1280×800 预览与几何/材质证据；Godot 固定机位验收属于 Lead/Verifier 环节（本批不导出内容 GLB）。
