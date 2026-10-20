# 铁港建筑套件 · 批次 B：三栋新原型 LOD0 + LOD1（Boiler House / Workshop Row / Brick Tenement）

> 前情：[IRON_HARBOR_ARCHITECTURE_LOD1_BUILD.md](IRON_HARBOR_ARCHITECTURE_LOD1_BUILD.md)（批次 A：5 栋 LOD1 + 共享贴图 + Warehouse_Short 檐口修复）。
> 本轮对应 [MODELING_REQUIREMENTS_NEXT_BATCH.md](MODELING_REQUIREMENTS_NEXT_BATCH.md) §6 的**批次 B**：
> **第一阶段**（§2–§12）先做 3 栋新原型 **LOD0** 并交人工确认轮廓；**第二阶段**（§13）在人工确认后补 **LOD1**。
> **全程不导出 GLB、不保存/覆盖 `.blend`、不改 framework/dev_mods/manifest/tests/docs-static/todo/ASSET_MAP**（由 Lead 在验收后处理）。

## 1. 范围与结论

| 项 | 结果 |
| --- | --- |
| 新增对象 | `SN_HT_Boiler_House_LOD0` / `SN_HT_Workshop_Row_LOD0` / `SN_HT_Brick_Tenement_LOD0`（集合 `SN_Iron_Harbor_Architecture`，工作台 **y=200** 一排，x=-45 / 0 / 45） |
| 尺寸 | 12.000×10.000×12.000 / 18.000×7.000×8.500 / 10.000×8.000×12.000 m —— **误差 0.000**（容差 ±0.10） |
| tri（LOD0） | **7 388** / **7 312** / **9 376**；BH/WR 目标 6 000–7 500（cap 8 000）、BT 目标 9 000–12 000（cap 14 000）——**全部在目标区间内** |
| 网格健康 | 3/3：孤立点 0 / 退化面 0 / 非流形边 0 / 边界边 0（每个实体闭合） |
| 材质 / UV | 3/3：材质槽 6（全 `SN_Town_*`，实际用 5 个槽）、UV 盒投影逐 loop 可复算、6 张 512² 贴图绑定、无塌陷 UV 面、UV 不改几何 |
| 必须包含项 | 三栋的 §6 必须项 **逐项有 Part tag 几何证据**（§6 表），无缺失 |
| 全场景回归 | 除 3 个新对象外 255 对象 digest 与动手前基线**一致**（缺失/新增/修改全 0）；y=110/150/175 的 10 个套件对象 tris/位置/尺寸不变；只有 `SN_Iron_Harbor_Architecture` 集合 10→13 |
| 预览 | **10 张 1280×800 EEVEE PNG**（每栋 3 视图 + 1 张三栋 lineup；任务完成标准里写的"7 张"应为笔误，命名规则本身是 3×3+1） |
| 渲染状态还原 | 额外跑一遍渲染前后快照：相机/引擎/分辨率/filepath/世界背景/全部 hide_render/对象数 **diffs = {}**；`TMP_*` 残留 0 |

## 2. 三栋设计说明

### 2.1 `SN_HT_Boiler_House`（12 × 10 × 12，7 388 tri）

- **体量**：主厂房 8 × 10 m（墙顶 6.85 m，双坡铁屋面脊 8.56 m）+ 低平附房（4 × 5.2 m，平屋顶 4.6 m + 女儿墙 5.1 m）+ **高砖烟囱 1.8 × 1.8 m 到 12.00 m**，三段错落屋顶；+X 为正向（附房入口朝 +X）。
- **必须包含项**（需求 §6.1）：
  1. 错落屋顶：`roof_main` 双坡（脊 8.56，板厚 0.22，立缝 8 道）+ `roof_annex` 平顶女儿墙（4.58–6.64，含除尘旋风筒）；
  2. 高砖烟囱：`chimney` 石基座 + 5 段收分砖身 + 石腰环 + 石压顶 + 铁冠/防雨帽 + 爬梯，顶面 **z=12.000**（包围盒最高点）；
  3. 外露粗管：`pipes` 492 面 / 732 tri —— +Y 长墙 2 道横管 + 附房 +X 前墙 2 道立管/横管 + 烟囱 +X 面立管 + 9 个法兰/管卡；
  4. 侧墙百叶：`louvers` 2 组（+Y 1.0 × 1.95、−Y 1.3 × 1.95，铁框 + 8 片斜叶 + 凹底封板）；
  5. 煤槽/灰斗：`coal_chute` 煤槽（+Y 墙外凸料斗 + 铁盖）+ 灰斗（−Y 墙）；
  6. 检修平台：`platform` 烟囱 +Y 侧 2.0 × 0.85 m 铁平台 + 三面栏杆（连续实体顶杆）+ 直爬梯（11 档），z 6.10–7.23。
- **轮廓识别点（≥2，去材质可辨）**：① 12 m 高砖烟囱（含石腰环）；② 沿墙外露粗管（横/立/法兰）；③ 烟囱侧检修平台 + 栏杆 + 爬梯；④ 双坡主屋面 + 低平附房错落。
- **开窗节奏**：主厂房长墙 3 高窗 + 百叶 + 煤槽；附房前墙为 2 窗 + 双开大门 + 门上气窗；背面 2 窗 + 高位气窗 + 服务门。
- **主色**：`brick_wall_soot` + `iron_rust` + `stone_base_dirty`（烟熏工业档），其余 Wood=weathered / Glass=dark。

### 2.2 `SN_HT_Workshop_Row`（18 × 7 × 8.5，7 312 tri）

- **体量**：18 m 长 × 7 m 深，墙顶 5.98 m；**3 联锯齿采光顶**（每跨 5.6 m：坡屋面 6.00→8.26 + 垂直玻璃天窗面 + 高边泛水到 8.50）；+X 端墙为入口端（门 + 2 窗 + 石匾 + 雨棚），+Y 长墙承载 3 个连续工坊 bay。
- **必须包含项**（需求 §6.2）：
  1. 3 个连续工坊 bay：`bay_doors` 496 面/1 072 tri —— 3 樘上滑轨木门（**门宽 3.6 / 2.4 / 3.0 m 三种**，均双扇 + 滑轨 + 吊架 + 门楣工字钢）；
  2. 锯齿采光顶：`sawtooth_roof` 3 跨（板厚 0.22 + 每坡 3 道立缝 + 低边檐沟 + 高边泛水），`clerestory_glazing` 3 面垂直玻璃天窗（玻璃板 + 2 竖梃 + 3 横挡 + 铁中梃）；
  3. 墙面风机：`wall_fans` 3 台（+Y 2 台 r0.52、−Y 1 台 r0.42：底座环 + 筒体 + 轮毂 + 4 叶 + 护网）；
  4. 雨棚：`canopies` 3 道（门 A / 门 C / 端头入口：单坡铁皮 + 2 斜撑 + 封边）；
  5. 外置楼梯或猫道：`external_stair` 10 级铁梯 + 双斜梁 + 连续栏杆；`catwalk` 5.6 m 长连廊猫道（托架 + 栏杆 + 端部直爬梯）；
  6. 端墙工坊招牌：`sign` 空白木牌（无文字）。
- **轮廓识别点**：① 3 联锯齿采光顶（垂直玻璃面朝天窗方向）；② 连续 3 bay 门节奏（三种门宽）；③ 外置楼梯 + 连廊猫道。
- **主色**：`brick_wall` + `glass_reflect` + `iron_dark`（干净工业档），Wood=plank / Stone=stone_base。

### 2.3 `SN_HT_Brick_Tenement`（10 × 8 × 12，9 376 tri）

- **体量**：窄高街屋 10 × 8 × 12，三层砖立面（首层 4.10 / 二层 7.10 / 檐口 10.40；女儿墙 11.00；**3 个砖烟囱，最高顶 12.00**），平屋面。
- **必须包含项**（需求 §6.3）：
  1. 三层砖立面：`walls` 806 面/1 612 tri（首层 + 二三层墙板）+ 2 道通长石腰带；
  2. 成列真凹窗洞：`windows` 1 564 面/3 544 tri（主立面 6 扇 1.1×1.7 凹 0.16 + 顶层小窗；+Y/−Y/−X 侧背立面各 6–7 扇，全部真凹口 + 木框/石窗台/石窗楣（上层加砖券拱））；
  3. 转角壁柱：`corner_piers` 344 面/752 tri（主立面两角 0.62 宽八棱砖壁柱 + 3 块石箍 + 4 角隅石）；
  4. 后侧铁质逃生楼梯：`fire_escape` 534 面/952 tri（+Y 侧后立面 3 层平台 + 2 段斜梯 + 底部直爬梯 + 连续栏杆；平台 2.6 × 0.75 m，出挑 0.74 m 在包围盒内）；
  5. 多个烟囱：`chimneys` 3 个住宅砖烟囱（两段收分 + 石压顶 + 陶土烟囱帽），顶 12.00 / 11.85 / 11.70；
  6. 首层小店雨棚/封板：`shopfront`（店面凹口 0.30 + 6 条封板 + 铁压条 + 石勒脚 + 店门）+ `awning` 铁雨棚 + 空白店招木牌；另有 `basement_grilles` / `dentils` / `balconettes` 立面细节。
- **轮廓识别点**：① 窄高街屋（10×8×12 竖长）；② 3 个屋顶烟囱；③ +Y 侧外挂铁质逃生楼梯；④ 平顶女儿墙（无塔楼，与港务办公楼钟楼地标明显区分）。
- **主色**：`brick_wall` + `stone_base_dirty` + `glass_dark` + `wood_plank_weathered`（暖砖住宅档），Iron=dark。

### 2.4 与现有 5 栋及彼此的差异（需求 §6.4：屋顶/开口节奏/附件组合/主色至少三项）

| 资产 | 屋顶形式 | 开口节奏 | 附件组合 | 主色 cell（Brick/Iron/Stone/Glass） |
| --- | --- | --- | --- | --- |
| Boiler_House | 双坡主屋面 + 低平附房 + 12 m 烟囱（三段错落） | 3 高窗 + 百叶 + 煤槽（工业，非住宅窗列） | 烟囱爬梯 + 检修平台/栏杆 + 外露粗管 + 煤槽/灰斗 | soot / rust / dirty / dark |
| Workshop_Row | 3 联锯齿采光顶（垂直天窗） | 3 连续 bay，门宽 3.6/2.4/3.0 | 外置楼梯 + 猫道 + 墙面风机 + 雨棚 + 端头招牌 | clean brick / dark / base / reflect |
| Brick_Tenement | 平顶女儿墙 + 3 个砖烟囱 | 三层成列凹窗 6 扇 + 侧背窗列 | 外挂逃生楼梯 + 转角壁柱/隅石 + 石腰带 + 店面封板/雨棚 | brick / dark / dirty / dark |
| 现有 5 栋 | 双坡（长/短仓、酒馆）/ 平顶（办公楼）/ 单坡（货棚） | 仓库双高门、办公楼三层拱门、货棚开敞柱廊 | 吊梁、钟楼、阳台、招牌、单坡侧棚 | 见批次 A 表 |

三栋之间：屋顶形式互不相同、开口节奏与附件组合完全不同、主色/材质档（烟熏工业 / 干净工业 / 暖砖住宅）不同——满足"至少三项"。

## 3. 参数化真源与生成器结构

新增 `tools/modeling/generators/sn_iron_harbor_prototypes_generator.py`（纯 Python 几何 + Blender 侧 harness，约 2 200 行）：

- **参数化真源唯一**：三栋的尺寸、墙线、开洞表、构件坐标全部写在本文件；`_check_specs()` 校验预算声明；后续 LOD1 与导出都从 `build_boiler_house() / build_workshop_row() / build_brick_tenement()` 重建，禁止只在 `.blend` 里手改。
- **闭合实体工具**：与 kit / batch2 同一套语言（`Part / box / tb / prism_x/y/z / panel / lprism_u / lbox / lvchamfer_box / beam / chamfer_beam / rod / arch_band / sweep`），每个构件都是独立闭合实体，拼装后边界边/非流形边为 0。
- **真凹口**：所有窗门都用 `panel()` 挖真凹口（窗凹 0.12–0.16、门凹 0.20–0.30），凹底按玻璃/木/铁材质；配木框、石窗台、石窗楣、铁棂（不是共面深色板）。
- **`Part.group(tag)` + `feature_report()`**：每栋的每个必须项/立面构件在生成时用 `with m.group("chimney"): ...` 打标；`report()` 把 tag 翻译成「面数 / tri / 包围盒」作为硬证据（如 BH `chimney` bbox 顶 z=12.000、WR `sawtooth_roof` z 5.76–8.50、BT `fire_escape` z 0.60–11.23）。
- **Blender 侧**：`build_all()`（先删旧原型再抓基线 → 只建 3 个对象 → 按栋 `apply_to_object(cells=...)` 写共享材质/UV）、`report()`（自检 + 特征证据 + 全场景 digest 回归，落盘 `prototypes_report.json`）、`render_previews()`（EEVEE 1280×800 每栋 3 视图 + lineup，`finally` 还原并删临时对象）。
- **共享材质 cell 方案**（同一张 2048 trim sheet / 同 16 张 512² tile，不新增贴图与材质）：

| 资产 | Brick | Plaster | Wood | Iron | Stone | Glass |
| --- | --- | --- | --- | --- | --- | --- |
| Boiler_House | **brick_wall_soot** | plaster_grime | wood_plank_weathered | **iron_rust** | stone_base_dirty | glass_dark |
| Workshop_Row | brick_wall | plaster_light | wood_plank | iron_dark | stone_base | **glass_reflect** |
| Brick_Tenement | brick_wall | plaster_grime | wood_plank_weathered | iron_dark | stone_base_dirty | glass_dark |

> 三栋实际用 5 个材质槽：BH 的石膏只用于？——BH 山墙为砖、无灰泥面；WR/BT 同。`apply_to_object` 仍把槽补满 6 个（`SN_Town_Plaster` 无面引用，不产生额外 draw），与批次 A 的 Cargo_Shed 行为一致。

## 4. 纯 Python 干跑

命令：

```powershell
python tools/modeling/generators/dryrun_prototypes_batch_b.py
python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_iron_harbor_prototypes_generator.py
```

结果（`.design/buildings/iron_harbor/b1/dryrun_prototypes.json`，两个入口都 `ALL OK`）：

| 对象 | tri | 目标区间 | cap | 尺寸 (m) | 目标 (m) | 尺寸差 | 边界边 | 非流形 | 退化面 | zmin | 轴心 x,y |
| --- | ---: | --- | ---: | --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| Boiler_House_LOD0 | **7 388** | 6 000–7 500 | 8 000 | 12.000, 10.000, 12.000 | 12, 10, 12 | 0,0,0 | 0 | 0 | 0 | 0.0 | 0, 0 |
| Workshop_Row_LOD0 | **7 312** | 6 000–7 500 | 8 000 | 18.000, 7.000, 8.500 | 18, 7, 8.5 | 0,0,0 | 0 | 0 | 0 | 0.0 | 0, 0 |
| Brick_Tenement_LOD0 | **9 376** | 9 000–12 000 | 14 000 | 10.000, 8.000, 12.000 | 10, 8, 12 | 0,0,0 | 0 | 0 | 0 | 0.0 | 0, 0 |
| **合计** | **24 076** | — | 30 000 | — | — | — | 0 | 0 | 0 | — | — |

## 5. Blender 工作台自检

命令（Blender MCP 内）：

```python
p = r"<repo>/tools/modeling/generators/sn_iron_harbor_prototypes_generator.py"
ns = {"__name__": "protogen", "__file__": p}
exec(compile(open(p, encoding="utf-8").read(), p, "exec"), ns)
ns["build_all"](); ns["report"](); ns["render_previews"]()
```

逐栋 21 项检查（tri 区间 / 硬上限 / 尺寸 ±0.10 / zmin / 轴心 / 材质槽 / 调色板 / 网格健康 4 项 / UV 5 项 / 必须项 / 轮廓特征 / 墙面打断 / 窗门凹深）**3/3 全部 pass**，结果落盘 `.design/buildings/iron_harbor/b1/prototypes_report.json`。

| 对象 | tri | verts | 尺寸 (m) | zmin | 轴心 | 材质槽 | UV loops | UV 范围 u / v | 绑定贴图 | 网格健康 |
| --- | ---: | ---: | --- | ---: | --- | ---: | ---: | --- | ---: | --- |
| Boiler_House_LOD0 | 7 388 | 4 474 | 12.000×10.000×12.000 | 0 | 0,0 | 6 | 14 862 | −3.0…3.0 / −2.5…6.0 | 5 × 512²（+1 未用槽） | 全 0 |
| Workshop_Row_LOD0 | 7 312 | 4 430 | 18.000×7.000×8.500 | 0 | 0,0 | 6 | 14 496 | −4.5…4.5 / −1.75…4.25 | 5 × 512²（+1 未用槽） | 全 0 |
| Brick_Tenement_LOD0 | 9 376 | 5 764 | 10.000×8.000×12.000 | 0 | 0,0 | 6 | 18 444 | −2.5…2.5 / −2.0…6.0 | 5 × 512²（+1 未用槽） | 全 0 |

- 材质使用面数（每面一个 `SN_Town_*`，无越界）：BH Brick 795 / Wood 502 / Iron 1 634 / Stone 781 / Glass 25；WR 782 / 693 / 1 520 / 554 / 43；BT 831 / 1 000 / 1 382 / 1 292 / 29（另 Plaster 槽 0 面）。
- UV：盒投影（世界坐标 / 2.0 m）逐 loop 可复算（`uv_projection_ok`）、无塌陷面、UV 写入前后几何不变（`geometry_unchanged_by_uv`）、全部使用面材质都绑定 512² 图。

## 6. 必须包含项 / 墙面打断 / 凹深 的几何证据

### 6.1 必须包含项（Part tag → 面数 / tri / 关键 bbox）

| 资产 | 必须项 | tag | faces / tri | 关键 bbox（m） |
| --- | --- | --- | ---: | --- |
| BH | 错落屋顶（主） | `roof_main` | 208 / 356 | z 6.56–9.50，x −6.0–2.0 |
| BH | 错落屋顶（附房） | `roof_annex` | 90 / 148 | z 4.58–6.64 |
| BH | 高砖烟囱 | `chimney` | 228 / 436 | **z 0.55–12.000**，x 3.2–5.4 |
| BH | 外露粗管 | `pipes` | 492 / 732 | z 0.62–10.44，y −4.35–5.00 |
| BH | 侧墙百叶 ×2 | `louvers` | 156 / 312 | z 3.30–5.55 |
| BH | 煤槽/灰斗 | `coal_chute` | 30 / 60 | y ±(4.99)，z 0.60–2.06 |
| BH | 检修平台 | `platform` | 206 / 384 | z 0.55–7.23，y 3.99–4.95 |
| WR | 3 连续 bay 门 | `bay_doors` | 496 / 1 072 | x −8.43–8.80，z 0–4.76 |
| WR | 锯齿采光顶 ×3 | `sawtooth_roof` | 126 / 216 | **z 5.76–8.50** |
| WR | 垂直天窗玻璃面 ×3 | `clerestory_glazing` | 144 / 288 | z 5.98–8.26 |
| WR | 墙面风机 ×3 | `wall_fans` | 264 / 444 | z 4.20–5.64 |
| WR | 雨棚 ×3 | `canopies` | 84 / 144 | z 3.49–4.35 |
| WR | 外置楼梯 | `external_stair` | 140 / 248 | x −8.25–−3.95，z 0.43–5.53 |
| WR | 连廊猫道 | `catwalk` | 168 / 312 | x −4.19–1.50，z 1.20–5.63 |
| BT | 三层砖立面 | `walls` | 806 / 1 612 | z 0.55–10.40 |
| BT | 成列真凹窗洞 | `windows` | 1 564 / 3 544 | z 0.96–9.96（**27 个真凹窗：主立面 8 + 侧/背 19，其中 26 扇配木框/石窗台/石窗楣 + 上层砖券**） |
| BT | 转角壁柱 | `corner_piers` | 344 / 752 | z 0.53–10.78 |
| BT | 后侧逃生楼梯 | `fire_escape` | 534 / 952 | y 3.20–3.945，**z 0.60–11.23** |
| BT | 多个烟囱 ×3 | `chimneys` | 192 / 312 | **z 10.44–12.000** |
| BT | 小店封板 | `shopfront` | 146 / 308 | x 4.08–4.80，z 0–4.24 |
| BT | 小店雨棚 | `awning` | 28 / 48 | x 4.42–4.98，z 3.01–3.52 |

（完整 tag 表见 `prototypes_report.json` 的 `objects.*.features`；另有 stone_base / pilasters / quoins / cornices / downpipes / vents / sign / dentils / balconettes / basement_grilles 等立面/附属构件 tag。）

### 6.2 >6 m 可见墙面打断（需求 §4.1 / task-6 第 4 条）

| 资产 | 墙面 | 长度 | 开口数 | 第二类打断 |
| --- | --- | ---: | ---: | --- |
| BH | +Y 长墙 | 7.6 m | 5 | 3 砖壁柱 + 石檐口 + 管支架 + 煤槽 |
| BH | −Y 长墙 | 7.6 m | 4 | 2 砖壁柱 + 石檐口 + 灰斗 |
| BH | −X 背墙 | 9.4 m | 4 | 2 砖壁柱 + 落水管 + 石檐口 |
| WR | +Y 长墙 | 16.8 m | 7 | 4 砖壁柱 + 2 风机 + 2 雨棚 + 石腰带 + 猫道 |
| WR | −Y 长墙 | 16.8 m | 6 | 4 砖壁柱 + 石腰带 + 落水管 + 高百叶 |
| BT | 主立面 +X | 6.4 m | 9 | 转角壁柱 + 2 道石腰带 + 店招 + 雨棚 |
| BT | +Y 侧墙 | 8.8 m | 7 | 2 道石腰带 + 外挂逃生楼梯 + 隅石 |
| BT | −Y 侧墙 | 8.8 m | 6 | 2 道石腰带 + 隅石 + 落水管 |
| BT | −X 背墙 | 6.4 m | 7 | 2 道石腰带 + 落水管 |

### 6.3 真实凹深（窗 ≥0.08 / 门 ≥0.12）

| 资产 | 窗凹深 (m) | 门凹深 (m) | 判定 |
| --- | --- | --- | --- |
| BH | 0.16 / 0.14 / 0.12（最小 0.12） | 0.28 / 0.24 / 0.24（最小 0.24） | PASS |
| WR | 0.16 / 0.14 / 0.12（最小 0.12） | 0.28 / 0.24 / 0.26（最小 0.24） | PASS |
| BT | 0.16 / 0.12（最小 0.12） | 0.30 / 0.24 / 0.20（最小 0.20） | PASS |

## 7. 全场景 digest 回归 + 渲染状态还原

- 基线：改动前 `.design/buildings/iron_harbor/b1/baseline_digest.json`（排除 3 个新对象）→ **255 objects**；构建后同样排除 3 个对象 → **255 objects**，`missing / added / modified` 全空。
- 对比字段：对象名/类型/data 名、location/rotation/scale/dimensions、`matrix_world`、hide 标记、parent、所属集合、材质槽、mesh 顶点+面+材质索引几何哈希。
- 集合：只有 `SN_Iron_Harbor_Architecture` 由 10 → 13（+3 新原型，预期）；其余 11 个集合并集与对象数逐项一致；旧 `SN_Harbor_Town` 10 件占位、船/模块/设施/道具/起重机等全部不变。
- y=110/150/175 的 10 个套件对象 tris/位置/尺寸核对（见 `prototypes_report.json` → `regression.kit_objects_10`）：Warehouse_Long 7 436 / Short 3 788 / Office 10 336 / Shed 3 356 / Tavern 5 116（LOD0）与 1 584 / 1 060 / 1 896 / 776 / 1 248（LOD1）全部未变。
- 渲染还原：额外跑一遍 `render_previews()`，前后快照相机/引擎/分辨率/filepath/色彩模式/世界背景色+强度/全部 mesh 的 hide_render/对象数 **diffs = {}**，`TMP_*` 残留 0（`.design/buildings/iron_harbor/b1/final_scene_state.json`）。

## 8. 预览图清单（10 张，1280×800，EEVEE + 临时 3 盏太阳光/深色世界）

目录：`docs/design/screenshots/iron_harbor_architecture/`

```
SN_HT_Boiler_House_LOD0_street_3q_1280x800.png
SN_HT_Boiler_House_LOD0_front_x_1280x800.png
SN_HT_Boiler_House_LOD0_roof_1280x800.png
SN_HT_Workshop_Row_LOD0_street_3q_1280x800.png
SN_HT_Workshop_Row_LOD0_front_x_1280x800.png
SN_HT_Workshop_Row_LOD0_roof_1280x800.png
SN_HT_Brick_Tenement_LOD0_street_3q_1280x800.png
SN_HT_Brick_Tenement_LOD0_front_x_1280x800.png
SN_HT_Brick_Tenement_LOD0_roof_1280x800.png
SN_HT_PROTOTYPES_LOD0_lineup_1280x800.png      ← 三栋并排总览（同一机位）
```

三栋在固定 3/4 机位的第一眼特征：BH = 高烟囱 + 检修平台 + 外露管线 + 错落屋顶；WR = 连续 3 bay 门节奏 + 3 联锯齿采光顶 + 外置楼梯/猫道；BT = 窄高 3 层砖立面 + 3 烟囱 + 外挂逃生楼梯（与办公楼钟楼完全不同）。

## 9. LOD1 简化计划（预告，人工确认轮廓后另开任务；**本轮不做 LOD1**）

| 资产 | 需求硬上限（§6） | 建议目标（同时满足 §9「≤ LOD0 实测 35%」） | 保留 | 删除/合并 |
| --- | ---: | ---: | --- | --- |
| Boiler_House | **2 800** | ≤ 2 580（7 388 × 35%） | 烟囱（3 段收分 + 铁冠）、双坡主屋面 + 平附房错落、煤场围墙+铁门、检修平台（连续实体栏板）+ 爬梯、2 条主粗管（长墙横管 + 附房立管）、煤槽/灰斗、石基、主立面 3 个真凹口 | 窗框/窗棂/石窗台窗楣（只留凹口）、隅石、壁柱、落水管、百叶斜片（改整块百叶板）、烟囱爬梯横档（改 2 根连续导轨）、除尘旋风筒细节、屋面立缝（每坡留 2 道）、山墙压顶 |
| Workshop_Row | **2 800** | ≤ 2 559（7 312 × 35%） | 3 联锯齿顶 + 连续玻璃天窗带（每面 2 竖梃）、3 个 bay 门凹口（3.6/2.4/3.0 三种宽）、墙面风机（筒体+圆盘）、雨棚（单坡板+2 撑）、外置楼梯（实体斜梁 + 10 级踏步）、猫道 + 连续栏板 | 窗框/窗棂、隅石、壁柱柱头柱础（留柱身）、落水管、招牌木牌（改一块平板）、高百叶斜片（改整板）、屋面立缝（每跨留 1 道）、檐沟/泛水细线脚 |
| Brick_Tenement | **4 900** | ≤ 3 282（9 376 × 35%） | 三层体量 + 女儿墙/檐口、主立面 6 个窗口凹口 + 首层店面凹口 + 封板 + 雨棚、转角壁柱（去箍）、3 个烟囱、外挂逃生楼梯（3 平台 + 1 段斜梯 + 连续栏板）、石腰带、石基 | 窗框/窗台/窗楣/砖券、齿饰、balconettes、地下室格栅、隅石、落水管、侧/背窗数量减半（只留凹口）、转角壁柱石箍、店招边框 |

LOD1 的硬约束与批次 A 相同：世界包围盒/轴心（zmin=0，x/y 中心 0）与 LOD0 一致、材质槽 ≤6 且只 `SN_Town_*`、网格健康全 0、窗门仍为真凹口、不得只靠贴图撑轮廓；LOD1 也必须从本生成器的同一套参数重建（`build_<name>_lod1()` 读本文件常量），不允许在 `.blend` 手改。

## 10. 复现命令

```powershell
# 1) 纯 Python 干跑
python tools/modeling/generators/dryrun_prototypes_batch_b.py
python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_iron_harbor_prototypes_generator.py

# 2) Blender 内：建 3 个 LOD0 + 共享材质/UV + 自检（不保存 .blend、不导出 GLB）
#    exec(sn_iron_harbor_prototypes_generator.py); ns["build_all"](); ns["report"]()
#    预览：ns["render_previews"]()
```

中间产物：`.design/buildings/iron_harbor/b1/`：`baseline_digest.json`、`dryrun_prototypes.json`、`prototypes_report.json`、`final_scene_state.json`。

## 11. 已知限制 / 待人工确认

1. **BH tri 7 388 距目标区间上沿（7 500）仅 112 tri**：本轮已把烟囱/平台/管线/煤场围墙全部做完，后续若还要加细节需先在其他构件上减面或放宽目标区间。
2. **BH 检修平台位于烟囱 +Y 侧**：在固定 3/4 机位可读（平台+栏杆+爬梯在烟囱右侧），但投影面积不大；若人工视觉门禁认为不够醒目，可把平台加宽到 2.4 m 或移到 +X 面（需同步减面）。
3. **WR 锯齿顶的 +X 端是垂直玻璃天窗面**（3 个天窗面朝 +X，固定机位能读出锯齿节奏）；若人工希望端墙是实心砖山墙，需要把第 3 个天窗面改成砖山墙（会改变轮廓与 tri）。
4. **朝向约定**：+X 为正向；三栋的"入口端"都在 +X。WR 的 18 m 三 bay 节奏在 +Y 长墙（3/4 机位可见），若 PortStage 槽位要求长墙正对镜头，可在接线时按槽位 yaw 旋转，不影响资产本身。
5. **三栋各用 5 个实际材质槽**（Plaster/或 Brick 槽 0 面）：共享模块仍补满 6 槽，未用槽不产生 draw；与批次 A Cargo_Shed 行为一致。
6. **未做 960×540 / 1440×900 实机验证与 PortStage 接入**：本轮只交付 Blender 建模/自检/预览证据；GLB 导出、manifest、LOD1 与实机门禁属于 Lead/Verifier 后续阶段（本批不导出内容资产）。
7. 任务完成标准写"7 张预览图"，但同段命名规则为每栋 3 视图 + 1 张 lineup（3×3+1=10）；实际交付 10 张，若只需要 7 张可按需删减 roof 视图。
8. `docs/static/`、`todo.md`、`ASSET_MAP.md` 未更新（任务禁止；由 Lead 验收后同步）；新增生成器与 dryrun 脚本已在文件头写 `@static-doc`（作用 / 契约与约束 / 重点逻辑）。
9. BH 主厂房与附房之间保留一道共享墙（x=1.8，结构厚度，非外露死面）；它只作为两个体量的分隔，LOD1 阶段可与其他内部面一起删除/简化。

## 12. 本轮改动文件

| 文件 | 类型 | 说明 |
| --- | --- | --- |
| `tools/modeling/generators/sn_iron_harbor_prototypes_generator.py` | 新增 | 三栋 LOD0 参数化真源 + build_all/report/render harness（@static-doc 头：第 2–51 行） |
| `tools/modeling/generators/dryrun_prototypes_batch_b.py` | 新增 | 纯 Python 干跑（tri 区间/上限/尺寸/健康/必须项 tag），落盘 `dryrun_prototypes.json` |
| `docs/archive/IRON_HARBOR_ARCHITECTURE_PROTOTYPES_LOD0_BUILD.md` | 新增 | 本报告（含 LOD1 计划） |
| `docs/design/screenshots/iron_harbor_architecture/SN_HT_{Boiler_House,Workshop_Row,Brick_Tenement}_LOD0_*_1280x800.png` + `SN_HT_PROTOTYPES_LOD0_lineup_1280x800.png` | 新增 | 10 张预览 |
| `.design/buildings/iron_harbor/b1/*` | 中间产物 | baseline/dryrun/report/final_state JSON（不交付运行时） |

---

# 13. 第二阶段：三栋新原型 LOD1（人工确认 LOD0 轮廓后）

> 本阶段对象：`SN_HT_Boiler_House_LOD1` / `SN_HT_Workshop_Row_LOD1` / `SN_HT_Brick_Tenement_LOD1`，
> 集合 `SN_Iron_Harbor_Architecture` 的 **y=225** 一排（x=-45 / 0 / 45），未改动 y=110/150 的 A 批 5 栋 LOD0、
> y=175 的 A 批 5 栋 LOD1、y=200 的 3 栋新原型 LOD0 及其它任何对象。
> 几何仍由同一份参数化真源 `sn_iron_harbor_prototypes_generator.py` 的 `build_*_lod1()` 生成（读 LOD0 常量），
> 纯 Python 干跑入口 `tools/modeling/generators/dryrun_prototypes_lod1.py`。

## 13.1 预算与 bbox 对比（实测，Blender `report_lod1()`）

| 资产 | LOD0 tri | LOD1 tri | 硬上限 | 占 LOD0 比例 | ≤35% | LOD0 尺寸 | LOD1 尺寸 | bbox 逐轴差 | zmin | 轴心 |
| --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- | ---: | --- |
| Boiler_House | 7 388 | **2 536** | 2 800 | **34.33%** | PASS | 12.000×10.000×12.000 | 12.000×10.000×12.000 | 0.000, 0.000, 0.000 | 0 | 0, 0 |
| Workshop_Row | 7 312 | **2 444** | 2 800 | **33.43%** | PASS | 18.000×7.000×8.500 | 18.000×7.000×8.500 | 0.000, 0.000, 0.000 | 0 | 0, 0 |
| Brick_Tenement | 9 376 | **2 704** | 4 900 | **28.84%** | PASS | 10.000×8.000×12.000 | 10.000×8.000×12.000 | 0.000, 0.000, 0.000 | 0 | 0, 0 |
| **合计** | 24 076 | **7 684** | 10 500 | 31.9% | — | — | — | — | — | — |

- LOD1 与 LOD0 的局部 bbox 6 个角点差也全部 0（`bbox_corner_delta_vs_lod0` 全 0，容差 0.02 m）。
- 干跑（`lod1_dryrun.json`）与 Blender 实测数字一致：2 536 / 2 444 / 2 704，三栋均 `ALL OK`。

## 13.2 LOD1 保留 / 删除表（详细计划见 `.design/buildings/iron_harbor/b1/lod1_dryrun.json` 的 `plan`）

| 资产 | 保留（§6 轮廓识别点 + 大轮廓） | 删除 / 合并 |
| --- | --- | --- |
| Boiler_House | 石基；错落双坡主屋面 + 平附房屋面；**12 m 高砖烟囱**（3 段收分 + 2 石腰环 + 铁冠 + 简化爬梯 5 档）；**外露粗管**（+Y 横管 + 附房前墙立管/横管 + 烟囱立管 + 法兰/管卡）；**检修平台 + 三面连续实体栏板 + 简化爬梯**；煤场围墙 + 铁门；煤槽料斗；石檐口（整条板）；主立面 2 窗 + 附房 1 窗（真凹口，简化木框 + 石窗台）；2 樘简化门；1 个脊部通风帽 | 窗框/窗棂/石窗台窗楣（只留简化框）；隅石；2 根壁柱（留 1 根）；落水管/檐沟；屋面立缝 8→4；烟囱爬梯横档 7→5；除尘旋风筒细节；门口石匾；第二个通风帽；百叶斜片 → 整块铁板 |
| Workshop_Row | 石基；**3 联锯齿采光顶**（坡面 + 高边泛水到 8.50 + 低边檐沟 + 每坡 1 道立缝）；**3 面垂直玻璃天窗带**（玻璃 + 2 竖梃 + 1 横挡）；**3 个连续 bay 门（门宽 3.6/2.4/3.0 三种）** + 门楣；端头入口门；**墙面风机 ×2**（筒体）；**雨棚 ×2 + 端头雨棚**；**外置铁楼梯**（7 级 + 双斜梁 + 连续栏杆）；**连廊猫道 + 连续栏板 + 端部爬梯**；石檐口（整条板）+ 端头招牌；+Y 2 根壁柱；2 个高位窗（简化框）+ 1 块整板百叶 | 窗框/窗棂；隅石；4→2 根壁柱（只留 +Y 可见侧）；落水管；屋面立缝每坡 3→1；天窗横挡 2→1；猫道托架 4→3、爬梯 6→4 档；楼梯 8→7 级、栏杆 2 根→1 根；百叶斜片→整板；铁中梃/护网细件；檐沟/泛水细线脚；第二个通风帽 |
| Brick_Tenement | 石基；**三层砖立面**（首层/二层/三层墙板 + 2 道石腰带）；**主立面 6 个真凹窗 + 首层店面凹口 + 封板 4 条 + 空白店招 + 雨棚**；**转角壁柱**（去石箍）；**3 个砖烟囱**（两段收身 + 石压顶 + 2 陶土帽，最高顶 12.00）；**外挂铁逃生楼梯**（3 平台 + 1 段斜梯 + 连续栏板 + 底部爬梯）；平屋面 + 女儿墙 + 石檐口（整条板）；侧/背窗列各留 1–2 个真凹口 + 2 樘门 | 窗框/窗棂/石窗台/窗楣/砖券（主立面保留简化木框 + 石窗台）；齿饰；balconettes；地下室格栅；隅石；落水管；侧/背窗数量减半；转角壁柱石箍；店招边框/封板压条细件；屋顶检修口 |

> 窗门仍全部是 `panel()` 真凹口（窗凹 0.16、门凹 0.20–0.30），不是共面深色板。

## 13.3 Blender 自检（3/3 全 pass，`lod1_report.json`）

| 对象 | tri | verts | 尺寸 (m) | zmin | 材质槽 | UV loops | UV 范围 u / v | 绑定贴图 | 网格健康 |
| --- | ---: | ---: | --- | ---: | ---: | ---: | --- | ---: | --- |
| Boiler_House_LOD1 | 2 536 | 1 538 | 12.000×10.000×12.000 | 0 | 6 | 5 240 | −3.0…3.0 / −2.5…6.0 | 5 × 512²（+1 未用槽） | 全 0 |
| Workshop_Row_LOD1 | 2 444 | 1 454 | 18.000×7.000×8.500 | 0 | 6 | 4 976 | −4.5…4.5 / −1.75…4.25 | 5 × 512²（+1 未用槽） | 全 0 |
| Brick_Tenement_LOD1 | 2 704 | 1 660 | 10.000×8.000×12.000 | 0 | 6 | 5 536 | −2.5…2.5 / −2.0…6.0 | 5 × 512²（+1 未用槽） | 全 0 |

- 每栋 19 项检查全 pass：`tris_within_cap / tris_within_35pct_lod0 / size_matches_target_0.02 / bbox_matches_lod0_0.02 / grounded_zmin_zero / pivot_ground_centre / material_slots_le_6 / palette_only / loose_verts_zero / degenerate_faces_zero / non_manifold_zero / boundary_edges_zero / uv_loops_complete / uv_projection_ok / no_collapsed_uv_faces / all_images_bound / images_512 / geometry_unchanged_by_uv / silhouette_features_present`。
- 材质 cells 与 LOD0 完全一致（BH `brick_wall_soot/iron_rust/stone_base_dirty` 等；未改色）。材质使用面数：BH Brick 373 / Wood 174 / Iron 570 / Stone 226 / Glass 9；WR 409 / 261 / 387 / 182 / 27；BT 419 / 284 / 394 / 306 / 13（Plaster 槽 0 面，补满 6 槽但无面引用）。

## 13.4 轮廓识别点几何证据（LOD1 tag → 面数 / tri / bbox）

| 资产 | 轮廓点 tag | faces / tri | 关键 bbox（m） |
| --- | --- | ---: | --- |
| BH | `chimney` | 116 / 220 | **z 0.55–12.000**；x 3.24–5.36 |
| BH | `pipes` | 198 / 288 | z 0.80–10.40；y −2.93–5.00 |
| BH | `platform` | 96 / 180 | z 0.55–7.15；y 3.99–4.95 |
| BH | `roof_main` + `roof_annex` + `yard_wall` | 98+62+42 面 | 主坡 z 6.56–9.50 / 附房 z 4.58–6.15 / 围墙 z 0.55–2.68 |
| WR | `sawtooth_roof` | 78 / 144 | **z 5.76–8.50** |
| WR | `clerestory_glazing` | 72 / 144 | z 5.98–8.26 |
| WR | `bay_doors` | 204 / 408 | x −8.42–8.80，z 0–4.54（3 樘三种宽） |
| WR | `external_stair` + `catwalk` | 90+72 面 | stair z 0.43–5.52；catwalk z 1.20–5.55 |
| WR | `wall_fans` | 40 / 56 | y 2.82–3.04，z 4.55–5.65 |
| BT | `windows` | 240 / 480 | z 1.10–9.27（主立面 6 + 侧/背真凹窗） |
| BT | `chimneys` | 174 / 276 | **z 10.44–12.000**（3 个） |
| BT | `fire_escape` | 246 / 428 | y 3.20–3.96，**z 0.60–11.20** |
| BT | `corner_piers` | 44 / 104 | z 0.53–10.36 |
| BT | `shopfront` + `parapet` | 78+54 面 | shopfront z 0–4.15；parapet z 10.38–11.10 |

## 13.5 全场景 digest 回归 + 渲染状态还原

- LOD1 建前基线（`lod1_baseline_digest.json`）：**258 objects**（255 + 3 栋 LOD0）；建后排除 3 个 LOD1：**258 = 258**，`missing / added / modified` 全空；`digest_before == digest_after`（`ced15655…`）。
- 全场景对象数 **258 → 261**（+3 LOD1，符合 Lead 预期）；集合只有 `SN_Iron_Harbor_Architecture` 13 → 16，其余 11 个集合并集/对象数不变。
- LOD0 + A 批 10 个对象逐对象状态（tri/verts/geo hash/location/dims）与建前快照一致（`lod0_and_batch_a_changed = []`）。
- 渲染还原：额外跑一遍 `render_lod1_previews()`，前后快照相机/引擎/分辨率/filepath/色彩模式/世界背景/全部 hide_render/3 个 LOD1 location/对象数 **diffs = {}**，`TMP_*` 残留 0（`.design/buildings/iron_harbor/b1/lod1_final_scene_state.json`）。

## 13.6 LOD1 预览图清单（18 张，1280×800，EEVEE）

目录：`docs/design/screenshots/iron_harbor_architecture/`

```
SN_HT_Boiler_House_LOD1_{street_3q,front_x,roof}_1280x800.png
SN_HT_Boiler_House_LOD1_vs_LOD0_{street_3q,front_x,roof}_1280x800.png
SN_HT_Workshop_Row_LOD1_{street_3q,front_x,roof}_1280x800.png
SN_HT_Workshop_Row_LOD1_vs_LOD0_{street_3q,front_x,roof}_1280x800.png
SN_HT_Brick_Tenement_LOD1_{street_3q,front_x,roof}_1280x800.png
SN_HT_Brick_Tenement_LOD1_vs_LOD0_{street_3q,front_x,roof}_1280x800.png
```

对比图做法与批次 A 相同：LOD1 临时平移到 LOD0 旁 3 m，同一机位同框渲染，渲染后立即还原位置。

## 13.7 LOD1 已知限制 / 风险

1. **LOD1 窗只保留简化框 + 石窗台**（BT 主立面同样），近景贴脸看会偏简；固定机位可读，符合 §6 LOD1 规则。
2. **BH LOD1 34.33% / WR 33.43%** 距 35% 门禁余量较小（约 50 / 57 tri）；后续如要加细节需先减面（BT 余量充足：28.84%）。
3. **BH LOD1 检修平台仍在烟囱 +Y 侧**（与 LOD0 同位置），3/4 机位可读（右侧带连续栏板的铁平台 + 爬梯），但投影面积小；如需更醒目需改 LOD0+LOD1 同步调整。
4. **WR LOD1 只保留 +Y 侧 2 根壁柱与 2 台风机**（-Y 侧不可见构件删除），锯齿顶/3 bay 门节奏/楼梯猫道均保留。
5. **BT LOD1 侧/背窗数量减半**（主立面 6 窗全保留）；逃生楼梯保留 3 平台 + 1 段斜梯（删除第二段斜梯，保留连续栏板与底部爬梯）。
6. LOD1 各用 5 个实际材质槽（Plaster 0 面），共享模块补满 6 槽、无额外 draw；cells 与 LOD0 一致未改色。
7. 未导出 GLB、未保存 `.blend`、未做 960×540/1440×900 实机验证与 PortStage 接入（属 Lead/Verifier 后续阶段）。
8. `docs/static/`、`todo.md`、`ASSET_MAP.md` 未更新（任务禁止；由 Lead 验收后同步）；`sn_iron_harbor_prototypes_generator.py` 的 `@static-doc` 头（第 2–66 行）已覆盖 LOD0+LOD1 两阶段。

## 13.8 LOD1 本轮改动文件

| 文件 | 类型 | 说明 |
| --- | --- | --- |
| `tools/modeling/generators/sn_iron_harbor_prototypes_generator.py` | 修改 | 新增 `LOD1_SPECS / build_*_lod1() / build_all_geometry_lod1() / build_lod1() / report_lod1() / render_lod1_previews()`；@static-doc 头扩为 LOD0+LOD1 |
| `tools/modeling/generators/dryrun_prototypes_lod1.py` | 新增 | LOD1 纯 Python 干跑（cap/35%/bbox/轴心/健康/轮廓 tag），落盘 `lod1_dryrun.json` |
| `docs/archive/IRON_HARBOR_ARCHITECTURE_PROTOTYPES_LOD0_BUILD.md` | 修改 | 新增本章 §13（LOD1 预算/保留删除/bbox 对比/证据/预览） |
| `docs/design/screenshots/iron_harbor_architecture/SN_HT_{Boiler_House,Workshop_Row,Brick_Tenement}_LOD1[ _vs_LOD0]_{street_3q,front_x,roof}_1280x800.png` | 新增 | 18 张 LOD1/对比预览 |
| `.design/buildings/iron_harbor/b1/{lod1_dryrun.json,lod1_report.json,lod1_baseline_digest.json,lod1_final_scene_state.json}` | 中间产物 | LOD1 干跑/自检/digest 证据 |
