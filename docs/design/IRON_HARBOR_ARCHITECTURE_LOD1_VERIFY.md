# 铁港建筑套件 · 批次 A · LOD1 + Warehouse_Short 檐口修复 · 独立验收

> 验收对象：`docs/design/MODELING_REQUIREMENTS_NEXT_BATCH.md` §5.1 / §9 的批次 A 建模部分
> （5 栋 LOD1 + `Warehouse_Short` 檐口修复 + 工作台重建/自检/预览）。
> Builder 报告：[IRON_HARBOR_ARCHITECTURE_LOD1_BUILD.md](IRON_HARBOR_ARCHITECTURE_LOD1_BUILD.md)。
> 验收方式：**独立 Verifier 只读复算**（自写 Blender 只读 dump / 纯 Python 分析 / 生成器重建 / 截图差分），
> 不采信 Builder 报告数字；所有原始数据在 `.design/verify_a/out/`。
> 日期：2026-10-20 · Verifier：verifier-a（task-2）

## 0. 总判定

**PASS**（无硬阻断；5 栋 LOD1 全部满足 §5.1/§9 门禁；檐口修复按 Lead 口径闭合；非目标对象零改动）。

- 逐栋 tri 上限、≤35%、bbox/轴心、网格健康、材质槽/UV/贴图、必须保留特征：**5/5 全通过**。
- 檐口：屋面顶皮@墙线 − 砖墙顶 **−0.0354 m（修前）→ 0.0000 m（修后）**，`|Δ| ≤ 0.005 m` **PASS**。
- 非目标对象：245 个对象逐字段（含几何哈希）**0 modified / 0 missing / 0 added**。
- LOD0 回归：4 栋几何签名逐字节一致；`Warehouse_Short` 仅 **8 个屋面顶皮顶点**移动（z 方向 +0.01133/+0.03861 m），tri/顶点/包围盒/轴心/材质槽不变。
- 30 张 LOD1 预览图全部存在、可读、确为 LOD1 渲染（与 LOD0 同视角差异显著）。

无 FAIL 项。§8 列出 5 项「留待 task-5 最终确认」的边界说明。

## 1. 方法与基线（可复核）

| 项 | 内容 |
| --- | --- |
| 基线 t0 | 2026-10-20T16:26 在 Builder 写场景前抓取：250 对象/228 mesh；LOD1 全缺；LOD0 tri 5/5 与 BATCH2 文档相等 → 基线有效。`out/blender_dump_t0.json` |
| 终态 t1 | Builder 标 complete 且 Lead 确认无写操作后抓取：255 对象/233 mesh（+5 LOD1）。`out/blender_dump_t1.json` |
| 只读保证 | Blender 侧仅 `bpy.data` 读取；唯一非读取调用是 `bpy.context.view_layer.update()`（depsgraph 求值）。未创建/删除/移动对象、未改材质、未保存 `.blend`、未导出。 |
| 独立工具 | `blender_dump.py`（只读 dump）、`analyze_dump.py`（全门禁+剪影+特征）、`features.py`（逐栋特征检测）、`gen_indep.py`（纯 Python 生成器重建）、`compare_dumps.py`（t0↔t1）、`digest_probe.py`（场景 digest 复算）、`shot_check.py`（截图差分） |
| 复算口径 | 三角面 = 多边形 fan 三角化；bbox/轴心由 dump 顶点×`matrix_world` 重算；UV 用「面法线主轴盒投影 `world/2.0`」逐 loop 重算（45° 倒角接受任一主轴）；网格健康用独立边/Newell 计算并与 Blender bmesh 交叉核对。 |

## 2. 逐栋复算表（§5.1 / §9 门禁）

| 资产 | LOD0 tri | LOD1 tri | 上限 | 占 LOD0 | LOD1 bbox (x,y,z) m | 目标尺寸 | 尺寸差 | 轴心/着地 | 结论 |
| --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- | --- |
| `SN_HT_Warehouse_Long` | 7 436 | **1 584** | 2 602 | 0.21302 | 20.000 × 9.000 × 11.000 | 20×9×11 | 0.000 | 底面中心 / zmin=0 | **PASS** |
| `SN_HT_Warehouse_Short` | 3 788 | **1 060** | 1 325 | 0.27983 | 11.000 × 9.000 × 9.500 | 11×9×9.5 | 0.000 | 底面中心 / zmin=0 | **PASS** |
| `SN_HT_Harbor_Office` | 10 336 | **1 896** | 3 617 | 0.18344 | 9.000 × 8.000 × 14.000 | 9×8×14 | 0.000 | 底面中心 / zmin=0 | **PASS** |
| `SN_HT_Cargo_Shed` | 3 356 | **776** | 1 174 | 0.23123 | 8.000 × 6.000 × 4.500 | 8×6×4.5 | 0.000 | 底面中心 / zmin=0 | **PASS** |
| `SN_HT_Tavern` | 5 116 | **1 248** | 1 790 | 0.24394 | 10.000 × 8.000 × 8.000 | 10×8×8 | 0.000 | 底面中心 / zmin=0 | **PASS** |
| **合计** | **30 032** | **6 564** | **10 508** | **0.2185** | — | — | — | — | **PASS** |

- LOD0 tri 与 §5.1 表 **5/5 精确相等**（7 436 / 3 788 / 10 336 / 3 356 / 5 116）。
- 全部 10 个对象：`rotation=(0,0,0)`、`scale=(1,1,1)`、`pivot_dx=pivot_dy=0`、`zmin=0`、集合 `SN_Iron_Harbor_Architecture`。
- LOD1 与 LOD0 世界包围盒逐轴 **0.000 m**（远优于 ±0.02 / ±0.05 容差）。
- **网格健康（10/10，独立重算）**：孤立点 0、退化面 0、非流形边 0、边界边 0、越界索引 0。
- **材质槽**：每栋均为 6 个 `SN_Town_*`（Brick/Plaster/Wood/Iron/Stone/Glass），无越界引用；Cargo_Shed LOD1 实际只引用 Wood/Iron/Stone/Glass（允许）。
- **UV**：逐 loop 完整（如 Long 3 176 / Short 2 094 / Office 3 800 / Shed 1 604 / Tavern 2 458 loops），盒投影逐 loop 可复算，mismatch=0、0 面积面=0。
- **贴图**：6 个槽各绑定 512²（Cargo_Shed LOD1 4 槽有图，其余按 `apply_to_object` 补满）；`all_images_bound / images_512` 通过。
- 剪影一致率（3/4 固定方向，256×160 占用掩码）：IoU **0.9944 / 0.9938 / 0.9994 / 0.9905 / 0.9960**，无轮廓塌陷。

## 3. §5.1「LOD1 必须保留」逐项（几何检测 + 预览目视）

检测器对 LOD0/LOD1 用**同一算法**，判定 LOD1 保留该项（阈值见 `.design/verify_a/features.py`）。

| 资产 | 必须保留项 | LOD0 实测 | LOD1 实测 | 判定 |
| --- | --- | --- | --- | --- |
| Warehouse_Long | 长体量 | X=20.000 | X=20.000 | ✅ |
| | 双高门（宽≥2.2、高≥4.0、真凹口） | 2 组 | 2 组（凹口面积 58.3→45.9 m²） | ✅ |
| | 山墙吊梁（+X 山墙外伸、檐口以上） | 面积 103.0 m²（含山墙端构件） | 94.9 m²（≥50%） | ✅ |
| | 双坡顶 | ±Y 坡面各 139.9 m² | ±Y 坡面各 139.9 m² | ✅ |
| | 石基 | 底部 0.8 m 石面 1 082.9 m²、足迹 20×9 | 1 074.5 m²、足迹 20×9 | ✅ |
| Warehouse_Short | 单坡侧棚（+Y、y>1.7、z<5.5） | 坡面 41.1 m² + 梁柱 | 坡面 39.6 m² + 梁柱 | ✅ |
| | 装卸门（+X，真凹口） | 1 组 | 1 组 | ✅ |
| | 偏置通风管 | (x=1.55, y=0.55)、z 7.98–9.06 | **同位置** (1.55, 0.55)、z 7.98–9.06 | ✅ |
| | 屋顶不对称（屋脊偏心） | 屋脊 y=−1.29 | 屋脊 y=−1.29 | ✅ |
| Harbor_Office | 三层分段（≥2 道通长石腰线） | 2 层（4.70 / 7.85 m） | 2 层 | ✅ |
| | 拱形入口 | 门洞宽 2.10、石拱环 6.15 m² | 门洞宽 2.10、石拱环 **1.86 m²**（简化拱券环，形状与拱心石保留） | ✅（形状目视：`out/crops/office_arch_zoom.png`） |
| | 钟楼 | 塔身/钟盘区 z 11.05–13.02、足迹 3.36×3.36 | 同（z=14.00 铁尖保留） | ✅ |
| | 檐口（挑出带） | 70.2 m² | 66.4 m² | ✅ |
| | 阳台大轮廓 | 检出 4 块凸出面板（含栏板） | 5 块（连续实体栏板） | ✅（目视 2 个主阳台） |
| Cargo_Shed | 开敞柱廊（+X 无封闭前墙） | 前墙面积 0.18 m²（开敞） | 0 m²（开敞） | ✅ |
| | 单坡棚顶 | 主坡 −X 59.2 m²（5.57°） | 主坡 −X 51.2 m² | ✅ |
| | 工作台大体量 | 低区木体量 114.6 m² | 68.6 m²（≥45%） | ✅ |
| | 柱列（≥3 柱） | 6 | 7 | ✅ |
| Tavern | 两层轮廓（首层砖/二层灰泥+石腰带） | 砖低区 166.2 / 灰泥高区 118.6 m² | 180.4 / 122.4 m² | ✅ |
| | 门廊 | 凸出体量 56.2 m²（z<4.8） | 38.3 m² | ✅（目视：2 柱+单坡廊顶） |
| | 悬挂空白招牌 | 深挑出小面板 1 处 | 1 处（木牌+铁悬臂+吊链） | ✅（目视） |
| | 高烟囱 | 屋面以上 z 7.78–8.00、足迹 1.19×0.99 | 同位置同尺寸 | ✅ |
| **整体** | 不依赖颜色的轮廓可辨 | — | 5 栋剪影可辨（含 960×540 尺度代理） | ✅ |

> 检测方法：`features.py` 为每项用独立几何检测器（凹口连通面板、坡向面积、屋脊高度、屋面以上竖向簇、低区材质体量），对 LOD0/LOD1 **同一算法**；形状类项目（拱券曲率、钟盘、门廊/招牌观感）再以 1280×800 预览目视确认。拱券判据取「门洞面板 + 门头以上石拱环体量」，不要求 LOD1 保持 LOD0 的装饰体量（简化允许）。

960×540 可读性：把 LOD1 3/4 预览按 PortStage 960 分辨率下的建筑屏幕尺寸（M1 实测约 173×127 px）缩到 25% 后，5 栋仍可凭剪影区分（`.design/verify_a/out/crops/lod1_960_scale_proxy.png`）。**真实 960×540 固定机位需 task-5 导出后实机复测**。

## 4. LOD0 回归与场景完整性（§9「不得修改其它船/模块/设施/道具」）

### 4.1 LOD0 重建：4 栋逐字节一致，Short 仅屋面 8 顶点

逐对象几何签名（顶点多重集 + 面/材质）t0 vs t1：

| LOD0 对象 | tri t0→t1 | verts t0→t1 | 顶点变化 | 最大位移 | 判定 |
| --- | --- | --- | ---: | ---: | --- |
| Warehouse_Long | 7 436 → 7 436 | 4 486 → 4 486 | 0 | 0 | **IDENTICAL** |
| Warehouse_Short | 3 788 → 3 788 | 2 294 → 2 294 | **8** | **0.03861 m** | 仅屋面顶皮（见 §5） |
| Harbor_Office | 10 336 → 10 336 | 6 292 → 6 292 | 0 | 0 | **IDENTICAL** |
| Cargo_Shed | 3 356 → 3 356 | 2 112 → 2 112 | 0 | 0 | **IDENTICAL** |
| Tavern | 5 116 → 5 116 | 3 064 → 3 064 | 0 | 0 | **IDENTICAL** |

Short 的 8 个变化顶点全部位于 `x=±5.5`（屋面 X 两端）、`y∈{−4.4824, −4.44, 1.86, 1.9024}`（±Y 檐口倒角点），z 抬升 +0.01133 / +0.03861 m，所属面材质 = `SN_Town_Iron`（屋面顶皮）。**x/y 未动、无其它顶点/面变化 → 尺寸、轴心、主立面、材质槽均未变。**

### 4.2 非目标对象：245 对象零改动（含几何哈希）

- 我的 t0↔t1 全场景对象行（名称/类型/位置/旋转/缩放/三角面/材质/隐藏/父级/集合）：
  **added 仅 5 个 LOD1、removed 0、modified 0**；非目标 digest `641e49f9…` 完全一致。
- 进一步按 Builder 的 digest 定义（含**逐对象几何哈希**、世界矩阵、dims、材质槽、集合、可见性）独立复算并与 `.design/buildings/iron_harbor/a1/baseline_digest.json` 逐行比对：
  **245/245 对象、0 missing / 0 added / 0 modified**；baseline 视图 digest `6f703b07…` 与当前重算**相等**；当前全字段 digest `ad4773e9…` 与 Builder 报告的 digest_after 一致。
  （`out/digest_probe.json`；baseline 文件为旧行 schema，比对在 baseline 实际记录的 14 个字段上进行，含 geo 哈希。）
- 旧 `SN_Harbor_Town` 10 件占位（`SN_HT_Warehouse_Long` 1 132 tri / Short 512 / Office 1 236 / Shed 572 / Tavern 956 / Fence_Row 264 / Worker_A 192 / Worker_B 228 / Rowboat 496 / Cargo_Lighter 616）位置/三角面/集合**全部不变**，与 BATCH2 文档一致。
- LOD0 工作台位置与 BATCH2/M1 一致（Long −48,110 / Short −30,150 / Office −10,150 / Shed 10,150 / Tavern 30,150）；LOD1 新建于 y=175 一排，未动 PortStage。

## 5. Warehouse_Short 檐口修复（§5.1 额外修复项）

Lead 确认口径：**主屋面檐口顶皮 @ 砖墙顶线所在 ±Y 墙面 − 砖墙顶 Z(7.5000)，`|Δ| ≤ 0.005 m`**。

| 指标（独立复算） | 修前（t0） | 修后（t1） | 判定 |
| --- | ---: | ---: | --- |
| 顶皮 @ 墙线 z（−Y / +Y） | 7.4646 / 7.4646 | **7.5000 / 7.5000** | — |
| 顶皮 − 砖墙顶 | **−0.0354 m / −0.0354 m** | **0.0000 m / 0.0000 m** | `|Δ|≤0.005` **PASS** |
| 立缝檐口端与屋面顶皮间隙（顶面参考） | 0.1013 m | 0.0627 m | 同向改善（−0.0386 m） |
| 砖墙顶露出石檐口（设计线脚） | 0.040 m | 0.040 m | 不变（非本缺陷，顶皮现已齐平覆盖） |

- 8 个移动顶点即屋面顶皮倒角点（§4.1），没有改动墙线、石檐口、主立面开口或材质。
- 与 Builder 报告的差别仅在**参考面**：Builder 的「立缝悬空 4.525→0.688 cm」取立缝**底皮**；我取立缝**顶面**（0.1013→0.0627 m）。两者同向、量级一致，且主判据（顶皮 vs 墙线）完全一致。
- 尺寸/轴心/主立面不变量：11.000×9.000×9.500、zmin=0、轴心 (0,0)、主立面 +X 开口（装卸门/2 窗）与 6 材质槽均不变（§2/§4.1）。

## 6. 参数化真源与可复现性

- 纯 Python 干跑（独立执行）：`python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_iron_harbor_architecture_lod1_generator.py`
  → 5 件 **ALL OK**（1 584 / 1 060 / 1 896 / 776 / 1 248，合计 **6 564 / 10 508**，尺寸与目标一致，无边界/非流形/退化面）。
- 生成器重建 vs 工作台网格（`gen_indep.py` + `compare_dumps.py`）：
  - 5 栋 **LOD0**：ti/尺寸/材质槽/zmin 与生成器**逐栋一致**；
  - 5 栋 **LOD1**：网格 vs LOD1 生成器 `build_all_geometry()` 顶点最大偏差 **≤ 8.2e-7 m**（float32 存储精度），材质面积逐槽相同（≤1e-4）→ 工作台 LOD1 确为**生成器输出**，非 `.blend` 手改。
- LOD1 cell 方案：`LOD1_SPECS` 与 `sn_iron_harbor_kit_batch2.BUILDINGS` **逐栋相同**（Short/Office/Shed/Tavern 完全一致；Long = 共享材质模块默认 M1 cells），6 个槽位齐全、cell id 均在 trim sheet spec 内。

## 7. 预览截图（Builder 交付物复核）

- `docs/design/screenshots/iron_harbor_architecture/`：`<Asset>_LOD1_{street_3q,front_x,roof}_1280x800.png` **15 张**，全部 1280×800 可读；`<Asset>_LOD1_vs_LOD0_*` **15 张**，全部可读。
- **确为 LOD1 而非 LOD0**：与 LOD0 同视角图差分（`shot_check.py`）：
  - front_x：mean 19.47–35.46、max 186–197、>8/255 像素占 32–50%；
  - street_3q：mean 2.97–5.99、max 177–197、>8 占 5.9–12.2%；
  - roof：mean 0.59–4.14、max 126–158（Tavern 屋面 LOD0/LOD1 同构所以均值低，但 max 148 证明不是同一张图）。
  - Warehouse_Long 的 LOD0 单价图只有 1440×900（M1 命名），故其 3 张 LOD1 图无 1280×800 LOD0 对照；由 15 张 `LOD1_vs_LOD0` 对比图与目视确认（对比图中 LOD1 缺窗框/落水管、LOD0 保留，差异明显）。
- 目视确认（`.design/verify_a/out/crops/`）：Long 长体量+双高门+山墙吊梁+双坡顶+通风帽；Short 装卸门+单坡侧棚+偏置通风管；Office 三层+拱门+钟楼+阳台+檐口；Shed 开敞柱廊+单坡棚顶+工作台；Tavern 两层+门廊+悬挂招牌+烟囱。

## 8. 未闭合项 / 需在 task-5 最终确认的边界（非本批 FAIL）

1. **960×540 真实固定机位可读性**：本批不导出 GLB，Godot 实机 960×540 属 task-5；本报告只给 25% 尺度代理（5 栋可辨）。
2. **逐栋 material cell 的最终证据**：6 个 `SN_Town_*` 是全局 datablock，工作台实时状态只反映「最后应用」的 cells（本次 t1 dump 抓到的 image 名即非 Builder 文档里的最终 Tavern 组，正好复现该已知坑）。本报告的 cell 结论来自「LOD1 spec 与 BATCH2 LOD0 spec 逐栋相同 + 槽位/512² 绑定」，**每栋 GLB 的实际 image 需在 task-5 从导出文件复核**。
3. **LOD1 窗体无框、Office 仅保留 2 面钟盘、Long 屋面复用 LOD0 细节**：Builder 已在报告 §11 声明；均不违反 §5.1「必须保留」清单（窗框/窗棂/次要面属允许删除项）。
4. **玻璃面积下降**（如 Long 52.9→29.8 m²、Office 55.0→27.4 m²）：窗不在各栋「必须保留」清单内，且剪影/主立面凹口保留；记为已知简化，不判 FAIL。
5. **砖墙顶露出石檐口 0.04 m 保持不变**：属设计线脚关系；Lead 口径的 3.5 cm 缺陷（顶皮 vs 墙线）已归零，且 8 顶点只动 z，不存在隐藏的第二处几何改动。

## 9. 与 Builder 报告数字对照（独立复核结果）

| Builder 报告声明 | Verifier 独立实测 | 一致 |
| --- | --- | --- |
| LOD1 tri 1 584 / 1 060 / 1 896 / 776 / 1 248，合计 6 564（21.85%） | 完全一致（6 564，0.2185） | ✅ |
| LOD1 上限/35% 全部通过 | 完全一致（最紧 Short 27.98%） | ✅ |
| LOD1↔LOD0 bbox 逐轴 0.000 | 一致 | ✅ |
| 网格健康全 0、材质/UV 10/10 | 一致（独立重算） | ✅ |
| 檐口顶皮@墙线 −3.543cm → 0.000cm | −0.0354 m → 0.0000 m | ✅ |
| 立缝悬空 4.525→0.688cm（底皮参考） | 顶面参考 0.1013→0.0627 m，同向 | ✅（口径差） |
| 4 栋 LOD0 几何签名一致、Short 仅 8 顶点 | 一致（8 顶点、max 3.861cm、仅 z） | ✅ |
| 非目标 245 对象 digest 一致 | 一致（含几何哈希，0 modified） | ✅ |
| 30 张 1280×800 预览 | 15 单图 + 15 对比图，全部可读 | ✅ |
| 场景 255 对象（233 mesh） | 一致 | ✅ |

## 10. 复现命令

```powershell
# 1) 只读 dump（Blender MCP execute_blender_code 内，TAG=t0/t1）
#    ns = {"__name__":"verify_a_dump","__file__":p,"VERIFY_TAG":"t1","bpy":bpy}
#    exec(compile(open(p,encoding="utf-8").read(),p,"exec"),ns); ns["dump"]()
# 2) 全门禁 + 剪影 + 特征 + 檐口 + LOD0 回归
python .design/verify_a/analyze_dump.py t1
python .design/verify_a/compare_dumps.py
python .design/verify_a/gen_indep.py --tag t1
python .design/verify_a/shot_check.py --crops
# 3) 生成器纯 Python 干跑
python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_iron_harbor_architecture_lod1_generator.py
# 4) 场景 digest 复算（Blender MCP）
#    ns = {"__name__":"verify_a_digest","__file__":p,"bpy":bpy}; ns["run"]()
```

## 附录 · 原始数据（`.design/verify_a/out/`）

`blender_dump_t0.json`、`blender_dump_t1.json`、`analyze_t0.json`、`analyze_t1.json`、
`analyze_t1.log`、`gen_indep_t0.json`、`gen_indep_t1.json`、`gen_indep_t1.log`、
`compare_t0_t1.json`、`digest_probe.json`、`shot_check.log`、`crops/`（目视裁剪图）。
脚本：`blender_dump.py`、`analyze_dump.py`、`features.py`、`gen_indep.py`、
`compare_dumps.py`、`digest_probe.py`、`shot_check.py`、`README.md`（验收清单与口径）。
