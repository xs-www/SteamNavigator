# 批次 C：`SN_Paddle_Steamer` 视觉精修（雨棚减重 / 明度层次 / 暗红压条）

> 依据：[MODELING_REQUIREMENTS_NEXT_BATCH.md](MODELING_REQUIREMENTS_NEXT_BATCH.md) §7（可选视觉精修）。只改 `SN_Paddle_Steamer`，未动纵帆船 / 铁甲舰 / 明轮货船 / 模块 / 设施 / 道具 / 建筑 / 内容 JSON。
> 生成器（参数化真源）：`tools/modeling/generators/sn_paddle_steamer_generator.py`；Blender 只读验收：`verify_paddle_steamer_scene.py`；固定机位预览：`render_paddle_steamer_preview.py`；纯 Python 干跑：`dryrun_paddle_steamer.py`。
> **不导出 GLB、不保存/覆盖 `.blend`、不改 framework/dev_mods/manifest/tests/docs-static/todo/ASSET_MAP**（A4 接线留给 Lead）。
> **本版为验收修正轮（round 2）**：共享材质已恢复原值，上层建筑改用本船局部新材质 `SN_PS_UpperWhite`；雨棚再按「固定 3/4 可读」重做（0.20 分缝 + 3 道顶面暗红分肋 + 后段 3.0 m 露空）。

## 1. 结论

| 项 | 结果 |
| --- | --- |
| tri | **11 764 → 11 764**（逐对象 tri 差集为空；`SN_PS_Canopy` 228 → 228，其余对象全部不变；≤ 既有上限 11 764） |
| 尺寸 | 24.56 × 8.74 × 10.47 m（目标 24.4 × 8.7 × 10.5，容差 0.8）——**与修改前完全相同** |
| 水线/轴心 | bbox z = **−1.32 … 9.15** 不变（船底 −1.32 = GLB 验收口径 min Y），`SN_PS_Root` 仍在 (45, 0, 0)，单根空物体 |
| 层级/命名 | 35 对象（32 mesh + 3 empty）不变；`SN_PS_*` 命名、Paddle Pivot 父子关系不变 |
| 明轮安全 | 8 个 45° 旋转角与轮罩/船体/明轮台 **0 穿插**（`paddle_clearance_hits = {}`） |
| 旗 / 铭牌 | 澳洲旗（蓝底红白）与 `ENTERPRISE` 铭牌对象/位置/文字几何全部未动 |
| 网格健康 | verify 26 项全 PASS（`failures=[]`）；非流形/退化/边界（甲板+铭牌允许）规则不变，无浮空件 |
| 材质 | 本船 **9 槽**：8 个共享槽（数值恢复原值）+ 新增 1 个**仅本船使用**的 `SN_PS_UpperWhite`；其它资产零变化 |
| 非目标回归 | 226 个非本船对象 digest 与修改前完全一致（`f865e1c2…`）；全场景 261 对象、12 集合计数不变 |
| 渲染还原 | 预览前后相机/引擎/分辨率/filepath/世界背景/全部 hide_render **diffs = {}**，`TMP_*` 残留 0 |

## 2. 三项精修（before → after）

### 2.1 后部雨棚减重（`CANOPY` + `build_canopy()`）

| 参数/构造 | before | after |
| --- | --- | --- |
| 构造 | 1 块整板（box） | **4 条纵向分缝薄板 + 3 道顶面暗红分肋 + 2 根红色边梁 + 6 根细柱 + 四边暗红封檐** |
| 板厚 `t` | 0.14 m | **0.07 m**（3/4 与侧视可读出薄边） |
| 纵向分缝 | 无 | **3 道 × 0.20 m**（整船尺度下 3/4 可读） |
| 顶面分肋 | 无 | **3 道 × 0.14 m 宽暗红压条**（白板上的红色网格线，固定机位直接可读） |
| 微拱 | 无（平顶） | 内侧 2 条板抬高 **0.045 m**（浅拱） |
| 后段露空 | 无 | **后段 3.0 m 完全露空**（x0 −9.35 → −6.35，原长 10.8 m 的 **27.8%**），露出艉部游步甲板、长凳与栏杆 |
| 立柱 | 6 根/舷（0.10 × 0.10） | **3 根/舷（0.07 × 0.07）** |
| 范围 `hy/z` | 2.95 / 5.24 | 2.95 / 5.24（上层建筑占地不变） |
| 红封檐 | 高 0.11 / 四边 0.10 宽 | 高 0.11 / 四边 0.11 宽 |
| tri | 228 | **228**（19 个闭合盒，同盒数替换） |

**可量化对比（顶面覆盖率与构件参数）**

| 指标 | before | after |
| --- | --- | --- |
| 雨棚投影面积 | 10.8 × 5.9 = **63.72 m²** | 4 条板 × 7.8 m × 1.325 m = **41.34 m²**（为 before 的 **64.9%**） |
| 占艉部游步甲板面积比（甲板 16.4 × 5.44 = 89.22 m²） | **71.4%** | **46.3%** |
| 后段露空长度 | 0 | **3.0 m**（原雨棚长度的 27.8%） |
| 分缝条数 / 宽度 | 0 / — | **3 条 / 0.20 m** |
| 顶面暗红分肋 | 0 | **3 道 / 0.14 m 宽** |
| 边缘厚度（板） | 0.14 m | **0.07 m** |
| 雨棚 bbox（世界坐标） | x −9.39…1.49，z 5.24…5.40 | x 38.61…46.49（局部 −6.39…1.49），z 3.42…5.385 |

效果：固定 3/4 与俯视均能读出「白板 + 红色分肋网格 + 0.20 分缝 + 后段露空」，不再是整块平板；tri 不变。

### 2.2 白色船身 / 甲板 / 舱室明度层次（`COLORS` / `REUSE_COLORS`）

| 材质（线性 base color） | before | after | 说明 |
| --- | --- | --- | --- |
| `SN_White` | (0.760, 0.735, 0.680) rough 0.55 | **(0.870, 0.850, 0.800) rough 0.52** | 仅本船使用，提亮为最亮层 |
| `SN_PS_UpperWhite`（**新增，仅本船局部**） | — | **(0.680, 0.672, 0.655) rough 0.68** | 舱室 / 驾驶室 / 锅炉围罩 / 雨棚板·柱 / 游步甲板支柱 / 窗间柱：第二层白 |
| `SN_Wood_Deck` | (0.300, 0.165, 0.072) rough 0.76 | **恢复 (0.300, 0.165, 0.072) rough 0.76** | 共享材质，保持原值；甲板仍用原色 |
| `SN_Flag_White` | (0.800, 0.800, 0.800) rough 0.70 | **恢复 (0.800, 0.800, 0.800) rough 0.70** | 共享材质（纵帆船 pennant），保持原值 |
| `SN_Iron_Hull` / `SN_Iron_Red` / `SN_Metal` / `SN_Brass` / `SN_Flag_Blue` | 不变 | 不变 | 深色船底、暗红压条、金属与旗蓝保持 |

明度层级（线性值）：**白船身 0.870 > 舱室/上层建筑 0.680 > 木甲板 0.300**；白船身提亮只影响本船（`SN_White` 仅 `SN_Paddle_Steamer` 使用），上层建筑改用本船局部新材质，共享材质零改动。

> 本船材质槽 8 → **9**（+1 仅玩家船）：唯一新增 `SN_PS_UpperWhite`，只在 `SN_PS_Cabin / Wheelhouse / Funnel / Promenade / Canopy` 的上层建筑面上使用。

### 2.3 暗红压条适度加粗（几何厚度）

| 部位 | before | after |
| --- | --- | --- |
| 舷墙压顶 `CAP_T` | 0.055 m；截面外伸 0.025 / 内收 0.015（总宽 ≈0.145） | **0.075 m；外伸 0.050 / 内收 0.040（总宽 ≈0.195）** |
| 舷侧水线带 / 舷缘带 | 厚 0.045；高 0.10（z 0.14–0.24 / 1.42–1.52） | **厚 0.062；高 0.14（z 0.13–0.27 / 1.39–1.53）** |
| 客舱暗红腰线 | 高 0.13；外凸 0.012 | **高 0.16；外凸 0.017** |
| 驾驶室暗红封檐 | 高 0.07；宽 0.10 | **高 0.085；宽 0.12** |
| 游步甲板暗红封檐 | 高 0.11；外凸 0.035 | **高 0.13；外凸 0.045** |
| 雨棚封檐 / 顶面分肋 / 边梁 | 高 0.11 / — | 高 0.11；顶面 3 道 0.14 宽分肋、两舷 0.12 宽边梁（均暗红） |

比例保持克制：压条厚度只增加 0.02–0.05 m，不改变船体轮廓与白船身主导关系；tri 不因加粗变化。

## 3. 不变量核验

### 3.1 Blender 只读验收（`verify_paddle_steamer_scene.py`）

`PADDLE_STEAMER_VERIFY`：**passed = true，failures = []**，26 项 health 全 true：

- 集合/命名/层级：`collection_membership / prefix / root_present / root_is_empty / root_at_workbench_pos / root_props(7) / root_asset / pivot ×2 / paddle_parent ×2`
- 指标：`tri_budget`（11 764 ≤ 12 000）、`bbox`（24.56×8.74×10.47）、`mesh_health`、`materials`（9 槽，含 `SN_PS_UpperWhite`）、`materials_double_sided`
- 安全/结构：`paddle_clearance`（8 个旋转角 0 穿插）、`hull_mirror`、`connectivity_floating`（floating = []）、`regression`（其它对象位置/数量未变）
- 阈值说明：单对象材质槽数仍 ≤8、双面/尺寸/tri 等阈值**未放宽**；仅 `materials` 期望集合 8→9，原因是新增 1 个仅本船使用的局部材质。

### 3.2 共享材质恢复核验（改动前值取自 C 之前快照 `.design/ships/paddle_steamer_before_batch_c/gen_head_snapshot.py`）

| 材质 | 改动前（HEAD 快照） | 本轮重建后 | 结论 |
| --- | --- | --- | --- |
| `SN_Wood_Deck` | (0.300, 0.165, 0.072) rough 0.76 | (0.300, 0.165, 0.072) rough 0.76 | **已恢复，一致** |
| `SN_Flag_White` | (0.800, 0.800, 0.800) rough 0.70 | (0.800, 0.800, 0.800) rough 0.70 | **已恢复，一致** |
| `SN_White` | (0.760, 0.735, 0.680) rough 0.55 | (0.870, 0.850, 0.800) rough 0.52 | 本船独占，按任务保留提亮 |

抽样其它资产对象（重建后实测）：

| 对象 | 相关材质 | 实测值 |
| --- | --- | --- |
| `SN_PF_Deck`（明轮货船） | `SN_Wood_Deck` | (0.300, 0.165, 0.072) rough 0.76 |
| `SN_Ironclad`（铁甲舰） | `SN_Wood_Deck` | (0.300, 0.165, 0.072) rough 0.76 |
| `SN_SF_Pennant`（纵帆船三角旗） | `SN_Flag_White` | (0.800, 0.800, 0.800) rough 0.70 |
| `SN_HT_Cargo_Shed_LOD0/LOD1`（建筑） | 使用 `SN_Town_*` 材质 | 与本船无关，未被改动 |

### 3.3 干跑 / digest / 还原

- `dryrun_paddle_steamer.py`：`ALL OK`，纯 Python 几何 tri **10 896** / 12 000、bbox 24.56×8.74×10.47、z 范围 −1.32…9.15、9 材质（含 `SN_PS_UpperWhite`）、边界/非流形/退化/镜像全部通过。
- 非目标对象 digest：226 对象 `f865e1c2fce49f048fcba6780daeb704f4e0f4223b1cb02db863ede4f824c6c2` 修改前后一致；全场景 261 对象、12 个集合对象数不变。
- 渲染还原：预览前后相机/引擎/分辨率/filepath/色彩模式/世界背景/全部 hide_render diffs = {}，`TMP_*` 残留 0；5 张 after 图拷贝成功。

## 4. 前后预览

**Before（原图，已备份）**：`.design/ships/paddle_steamer_before_batch_c/`
```
paddle_steamer_three_quarter.png  (1400×820)
paddle_steamer_broadside.png      (1500×720)
paddle_steamer_bow.png            (1100×820)
paddle_steamer_stern_quarter.png  (1200×820)
paddle_steamer_top.png            (1000×900)
```
`docs/design/screenshots/` 中原文件名的 5 张保持为 before。

**After（同机位、同渲染脚本）**：`docs/design/screenshots/`
```
paddle_steamer_three_quarter_batchc.png
paddle_steamer_broadside_batchc.png
paddle_steamer_bow_batchc.png
paddle_steamer_stern_quarter_batchc.png
paddle_steamer_top_batchc.png
```
固定 3/4 可辨差异：① 雨棚白板上有 3 道暗红分肋 + 3 道 0.20 分缝，后段 3.0 m 露空、薄边 0.07，明显不再压顶；② 船身白提亮、上层建筑退到二级白、木甲板保持原色，三层明度清晰；③ 舷墙压顶、水线带/舷缘带、舱室腰线与各封檐的暗红压条更厚。

## 5. 改动文件与证据

| 文件 | 说明 |
| --- | --- |
| `tools/modeling/generators/sn_paddle_steamer_generator.py` | `@static-doc` 头更新（9 槽/局部材质/雨棚构造）；`COLORS` 增 `SN_PS_UpperWhite`、`SN_Flag_White`/`SN_Wood_Deck` 恢复原值、`SN_White` 保留提亮；`MAT_WHITE_2 = SN_PS_UpperWhite`；`CANOPY` 参数与 `build_canopy()` 重做（4 板 + 0.20 分缝 + 3 道红分肋 + 后段露空）；`_ensure_material()` 重建时按参数表刷新材质值（共享材质恢复原值） |
| `tools/modeling/generators/dryrun_paddle_steamer.py` | `ALLOWED_MATERIALS` 增加 `SN_PS_UpperWhite`（9 槽） |
| `tools/modeling/generators/verify_paddle_steamer_scene.py` | `expected_mats` 8→9（唯一新增 `SN_PS_UpperWhite`，注释说明理由；其它阈值未放宽） |
| `docs/design/screenshots/paddle_steamer_<view>_batchc.png` × 5 | after 预览（同机位） |
| `.design/ships/paddle_steamer_before_batch_c/` | 5 张 before 图 + `baseline_digest.json` + `steamer_tris_before.json` + `gen_head_snapshot.py`（C 前生成器快照）+ `batchc_rebuild_verify.json`（重建/verify/材质恢复/其它资产抽样/digest/覆盖率/截图清单） |
| `docs/archive/PADDLE_STEAMER_VISUAL_POLISH_C.md` | 本报告 |

## 6. 风险 / 注意

1. **新增 1 个本船局部材质**：`SN_PS_UpperWhite` 只用于本船上层建筑（本船材质槽 8→9）。这是为满足「共享材质零改动」而选的方案；如果坚持船材质槽也不增加，可退回「只用原 8 槽 + 仅 `SN_White` 提亮 + 几何压条/雨棚减重」——但上层建筑与船身同为 0.870 白，明度层次会弱一档。
2. **共享材质已恢复**：`SN_Wood_Deck`、`SN_Flag_White` 数值与 C 之前快照逐位一致（见 §3.2），`SN_HT_*` 建筑/货棚/其它船外观恢复原值；`SN_White` 仅本船使用，仍为提亮值。
3. **tri 恰在上限**：11 764（= 任务上限），雨棚用同盒数替换保持不增；后续任何加件都会超限，需要先减面。
4. **雨棚分缝/分肋密度**：0.20 m 分缝 + 3 道红分肋是在整船尺度（3/4 图宽 1400 px）下选的可读值；若人工希望更"轻"可继续加大 `CANOPY_GAP`（如 0.30）或把后段露空从 27.8% 提到 1/3（x0 −6.0）。
5. **未做 Godot 实机/PortStage 截图与 GLB**（按指示留给 Lead）；未动 docs/static、todo.md、ASSET_MAP。
6. **预览文件命名**：现有渲染脚本固定输出 `paddle_steamer_<view>.png`；本轮把新图复制为 `_batchc` 后缀，并把 `docs/` 中原名文件恢复为 before，保证 before/after 可直接对照。
