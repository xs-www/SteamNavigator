# SN_Paddle_Steamer 视觉精修（批次 C）独立只读终验

> 验收对象：批次 C round 2 最终交付——`SN_Paddle_Steamer` 雨棚减重、明度层次、暗红压条加粗；
> 共享材质恢复 + 本船局部新材质 `SN_PS_UpperWhite`（槽 8→9）；GLB 导出与 Godot 实机截图。
> 依据：[MODELING_REQUIREMENTS_NEXT_BATCH.md](MODELING_REQUIREMENTS_NEXT_BATCH.md) §7/§10、
> Builder 报告 [PADDLE_STEAMER_VISUAL_POLISH_C.md](PADDLE_STEAMER_VISUAL_POLISH_C.md)、task-12 检查项。
> 独立 Verifier：一次性 Blender 只读 dump（随后回「Blender reads done」）→ 纯 Python / Godot headless / 截图分析。
> 日期：2026-10-20 · verifier-a（task-12）

## 0. 总判定

**PASS（批次 C 范围内 0 FAIL）**。37 项独立检查全部通过；2 项外部阻塞（完整测试套件 / 静态文档）已在 §7 明确
归为并发「海图 phase 2」工作流，不计入批次 C 判定；另有 3 项 NIT（§8）。

| 检查面 | 独立结果 | 判定 |
| --- | --- | --- |
| 不变量：尺寸/轴心/bbox/层级/tri/命名 | 261 对象/12 集合；35（32 mesh+3 empty）；tri **11 764**（逐对象差集空）；bbox **24.56×8.74×10.47** 与改前逐位一致；root `SN_PS_Root` (45,0,0) 单根 EMPTY；水线 min z **−1.32** | ✅ |
| 明轮安全 | 8×45° BVH 三角面相交 **0**（hits={}，矩阵已还原） | ✅ |
| 网格健康 / UV | 非流形/退化/孤立全 0；边界边仅允许的 Deck/铭牌；UV 仅铭牌 2 mesh 有 UV 且完整（flat 材质无贴图，其余无需 UV） | ✅ |
| 材质槽 8→9 | 9 槽全 `SN_Town` 之外的本船槽：新增 `SN_PS_UpperWhite` 仅本船 5 对象使用；其余 8 槽数值与改前一致 | ✅ |
| 共享材质零副作用 | `SN_Wood_Deck` (0.300,0.165,0.072)/0.76 恢复、30 用户；`SN_Flag_White` (0.800,0.800,0.800)/0.70 恢复、2 用户（PS_Flag + SF_Pennant）；`SN_White` 仅本船 7 用户 | ✅ |
| 雨棚减重 | 顶面板 **63.72 → 41.34 m²**（4 板 ×10.335，64.9%）；实测 **3 道 0.20 m 分缝**；后段露空 **3.0 m**（10.88→7.88，27.8%）；板厚 0.14→0.07 | ✅ |
| 明度层次 | 线性值 **0.870 > 0.680 > 0.300**；5 视角渲染采样均满足 白船身 > 舱室 > 甲板 | ✅ |
| 暗红压条加粗 | 舷墙压顶红面 **7.622→10.250 m²（+34.5%，对应宽 0.145→0.195）**；舷侧带红面 27.73→38.65（+39.4%）；舱室/驾驶室/游步甲板红面同向增加 | ✅ |
| GLB 导出 | 内容 + framework 镜像同 sha `cefec2b7…`、648 520 B（633.3 KiB）；35 节点/32 mesh/11764 tri/9 材质 doubleSided/Y-up bbox 24.56×10.47×8.74/min Y −1.32 | ✅ |
| Godot 实机 | 加载 32 mesh/90 surface/9 材质；无缺失/无黑材质/无贴图；精确 AABB 24.56×10.47×8.74、min Y −1.32；Y-up 轴向正确 | ✅ |
| 截图 | before/after 5 视角同机位（shift 0,0；背景结构 NCC 0.86–0.94）；结构变化 2.0–9.3%；船厂 1440/960 新船截图无黑材质、白船身可读 | ✅ |
| 非目标回归 | 内容 168 文件中仅 **2** 个 steamer GLB 变化，其余 166 全同 sha；226 非本船对象/12 集合计数与基线一致；Builder digest_after == 基线 `f865e1c2…` | ✅ |
| 完整测试 / 静态文档 | 208 passed / 2 failed / 210（fail 全部为海图外部）；B 相关子集 49/0；静态文档 stale 3 项均为海图外部文档 | ⚠ 外部阻塞 |

## 1. 方法与只读边界

| 项 | 内容 |
| --- | --- |
| Blender | **一次性只读 dump**（`.design/verify_c/dump_c.py`）：场景/集合/226 非本船 digest rows、35 船对象完整顶点+多边形、材质表（Principled 数值+用户）、明轮安全（in-memory 旋转后立即还原，不保存/不导出）。dump 后回 Lead「Blender reads done」，之后未再读 Blender。 |
| 纯 Python | `glb_check_c.py`（自写 GLB 解析：节点/矩阵/tri/材质/bbox/逐节点几何 sha/canopy 分板/红面面积）、`sha_compare_c.py`（内容树 sha 快照/对比）、`digest_c.py`（基线 digest 定义复原尝试）、`analyze_c.py`（汇总 34 项检查） |
| Godot | headless `verify_ship_glb_c.gd`：经 ResourceLoader 载入导出 GLB，逐 surface 检查材质/贴图/UV，逐顶点计算世界包围盒（显式合成父级变换，规避首帧 global_transform 未更新） |
| 截图 | `screenshot_diff_c.py`：FFT 相位相关机位校验、高频结构差、像素明度层级、船厂截图统计 |
| 边界 | 只写 `.design/verify_c/` 与本文；未改场景/源码/资产/manifest/docs/screenshots |

## 2. 不变量复核（对照 requirements §7）

| 项 | 改前基线 | 独立实测（改后） | 结果 |
| --- | --- | --- | --- |
| 全场景对象 / 集合 | 261 / 12 | 261 / 12（各集合对象数逐项相等） | 一致 |
| 本船对象 | 35（32 mesh + 3 empty） | 35（32 mesh + 3 empty），全 `SN_PS_*` | 一致 |
| 单根 | `SN_PS_Root`（EMPTY，工作台 (45,0,0)，asset/version/units/pivot/forward_axis/style/tri_budget 齐） | 同左，parent=None | 一致 |
| tri | 11 764（逐对象见 `steamer_tris_before.json`） | 11 764；32 对象逐对象 tri 差集 **空** | 一致 |
| 尺寸 / bbox | 24.56 × 8.74 × 10.47；bbox_min (32.66,−4.37,−1.32)、max (57.22,4.37,9.15) | 逐位相同（z 范围 −1.32…9.15 不变） | 一致 |
| 水线轴心 | z=0 水线，龙骨底 −1.32（`verify_paddle_steamer_glb.py` 口径） | bbox min z / glTF min Y 均 **−1.32** | 一致（NIT-1） |
| 明轮 | 2 Pivot 挂 root，轮对象挂 Pivot | 层级一致；8×45° 与轮罩/船体/明轮台 **0 相交** | 一致 |
| 网格健康 | 全 0（Deck/铭牌允许边界） | 非流形/退化/孤立 0；边界仅 Deck/铭牌 | 一致 |
| 澳洲旗 | SN_PS_Flag 216 tri，Flag_Blue/Flag_White/Iron_Red | tri/材质不变，几何 sha 与改前 GLB 逐字节一致 | 一致 |
| ENTERPRISE 铭牌 | Port/Starboard 各 434 tri，SN_Metal | tri/材质/几何 sha 与改前一致（文字几何未动） | 一致 |
| 材质槽 | 8 | **9**（+`SN_PS_UpperWhite`，仅本船）；单对象槽数 ≤8 未放宽 | 符合 |

## 3. 共享材质零副作用（重点）

| 材质 | 改前值（基线快照/生成器） | 独立实测（dump） | 用户 |
| --- | --- | --- | --- |
| `SN_Wood_Deck` | (0.300, 0.165, 0.072) rough 0.76 | **逐位一致** | 30 对象（`SN_PF_Deck`、港口设施、纵帆船、建筑等非本船用户全部在列） |
| `SN_Flag_White` | (0.800, 0.800, 0.800) rough 0.70 | **逐位一致** | 2：`SN_PS_Flag` + `SN_SF_Pennant`（纵帆船 pennant） |
| `SN_White` | (0.760, 0.735, 0.680) rough 0.55（改前） | (0.870, 0.850, 0.800) rough 0.52（本轮提亮） | 7，全部 `SN_PS_*`（仅本船） |
| `SN_PS_UpperWhite` | — | (0.680, 0.672, 0.655) rough 0.68 | 5，全部 `SN_PS_*`：Cabin / Canopy / Funnel / Promenade / Wheelhouse |
| `SN_Iron_Hull / Iron_Red / Metal / Brass / Flag_Blue` | 不变 | 与改前 GLB 因子逐项相同 | — |

- **其它资产不被顺带改变**：内容树 168 个文件 sha 对比，**仅 2 个 steamer GLB 变化**（内容 + framework 镜像），
  其余 166 个文件 sha **完全不变**（含其它船/模块/设施/道具/建筑/贴图/manifest/content JSON）。
  抽检共享用户与 Builder `other_asset_samples` 一致：`SN_PF_Deck`（Wood_Deck 0.300/0.165/0.072, 0.76）、
  `SN_SF_Pennant`（Flag_White 0.800/0.8/0.8, 0.70）、`SN_Ironclad`、`SN_HT_Cargo_Shed_LOD0` 材质槽未变。
- 226 个非本船对象：对象数/12 集合计数与改前基线完全一致；Builder `digest_after == baseline f865e1c2…`。
  **NIT-2**：基线 digest 只存最终值、未存定义，Verifier 无法从仓库复现该 digest 定义（尝试 100+ 字段/序列化组合
  未命中）；已用「内容 sha 零改动 + 计数/集合一致 + 共享材质用户表一致」独立佐证非目标未变。

## 4. 三项精修量化（before → after）

### 4.1 雨棚减重（独立解析 before/after GLB `SN_PS_Canopy`）

| 指标 | before | after | 独立结论 |
| --- | --- | --- | --- |
| 顶面主覆盖（板） | 1 块整板 63.72 m² | **4 板 × 10.335 = 41.34 m²（64.9%）** | 与 Builder 数字一致 |
| 顶面板连通块 | 1 大板 + 3 附件 = 4 | **10**（4 板 + 3 分肋 + 边条） | 结构确实重做 |
| 纵向分缝 | 0 | **3 × 0.20 m**（顶面覆盖按 0.02 m 栅格实测 3 个 0.20 间隙） | 与声明一致 |
| 后段露空 | 0 | **3.0 m**（bbox x 10.88 → 7.88） | 与声明一致 |
| 板厚 / 浅拱 | 0.14 m / 平 | 0.07 m / 4 板顶面 z 均差 **0.045 m** | 与声明一致 |
| tri | 228 | 228（不变） | 一致 |

### 4.2 明度层次

- 材质线性值：`SN_White` **0.870** > `SN_PS_UpperWhite` **0.680** > `SN_Wood_Deck` **0.300**（独立读取 dump）。
- 渲染采样（5 固定机位 after 像素分类，白/二级白/木色像素均值）：three_quarter 0.853 > 0.552 > 0.404；
  broadside 0.796 > 0.517 > 0.420；bow 0.629 > 0.518 > 0.372；stern_quarter 0.766 > 0.515 > 0.375；
  top 0.847 > 0.790 > 0.402 —— **5/5 满足白船身 > 舱室 > 甲板**。
- 说明：after 渲染整体曝光比 before 高约 **+8.9/255**（重打光），故绝对像素值不与 before 直接比较，只做层内比较。

### 4.3 暗红压条加粗（按材质红面面积/厚度独立量化，before/after GLB）

| 部位 | 红面面积 before → after | 结论 |
| --- | --- | --- |
| 舷墙压顶 | 7.622 → **10.250 m²（+34.5%）** | 对应截面宽 0.145→0.195（+34.5%），与报告一致；顶面厚度口径 0.293 m 不变（说明是加宽不是加高） |
| 舷侧水线/舷缘带 | 27.725 → **38.648 m²（+39.4%）** | 对应厚 0.045→0.062、高 0.10→0.14 |
| 客舱腰线 | 7.170 → 9.039（+26%） | 高 0.13→0.16 |
| 驾驶室封檐 | 5.564 → 6.724（+20.8%） | 高 0.07→0.085、宽 0.10→0.12 |
| 游步甲板封檐 | 13.884 → 16.418（+18.3%） | 高 0.11→0.13 |
| 雨棚红封檐/分肋 | 10.838 → **26.864** | 新增 3 道顶面分肋 + 四边封檐 |

## 5. GLB / Godot 实机

- 导出：`dev_mods/core/assets/models/ships/SN_Paddle_Steamer.glb` 与 `assets/models/ships/…` **同 sha
  `cefec2b7aa2da660…`，648 520 B（633.3 KiB）**；改前备份 `.design/ships/backup_glb/SN_Paddle_Steamer.01.glb`
  存在（647 860 B，sha `fdef6425…` 与改前内容一致）。
- GLB 结构（自写解析器）：35 节点 / 32 mesh / 3 empty、单根 `SN_PS_Root`、11764 tri、9 材质（全 doubleSided）、
  glTF Y-up bbox **24.56 × 10.47 × 8.74**、min Y **−1.32**；旗/铭牌/明轮/船体节点几何 sha 与改前一致。
- Godot headless 载入（`VERIFY_C_SHIP_GLB`，passed=true）：32 mesh 节点 / 90 surface / **9 材质**；无缺失材质；
  **无近黑无贴图材质**；逐顶点世界 AABB **24.56 × 10.47 × 8.74、min Y −1.32**（轴向 Y-up 正确）；
  `surface_get_format` 显示仅 2 个 surface 有 UV（两片铭牌），船体 flat 材质无贴图、无需 UV。
- 截图：
  - before/after 5 视角（`.design/ships/paddle_steamer_before_batch_c/` vs `paddle_steamer_*_batchc.png`）：
    尺寸逐一相同（1400×820 / 1500×720 / 1100×820 / 1200×820 / 1000×900）；相位相关 shift **全部 (0,0)**；
    静态背景高频结构 NCC **0.864–0.937**（top 视角背景为无特征渐变，NCC 0.447 按低能量规则豁免，shift/size 仍一致）；
    高频结构差异像素 **2.0%–9.3%**，差异 bbox 覆盖船体区域 → 确为新模型、同机位、差异可见。
  - 船厂实机：`docs/design/screenshots/paddle_steamer_c/shipyard_paddle_steamer_{1440x900,960x540}.png` 存在；
    near-black 像素 **0.0000**、白船身像素 1.94%/1.40%、暖色甲板/压条 2.78%；**无黑材质接管**、白船身可读。
  - PortStage 固定机位已用新船重拍：`SN_HT_Warehouse_Long_LOD0_port_stage_{1440x900,960x540}.png`
    （23:17 更新，1440 版 1 649 995 B）。

## 6. 非目标回归 / 内容未误改

- 内容树 168 文件 sha：**changed=2**（仅 steamer GLB 两路径）、added=0、removed=0；`non_target_clean=true`。
- 226 非本船对象 digest：Builder 报告 `digest_after = f865e1c2… = baseline`，count 226/226、objects_total 261、
  12 集合对象数不变（独立读取 dump 复核计数与集合逐项一致）。
- 改前快照资产：`.design/ships/paddle_steamer_before_batch_c/`（5 图 + baseline_digest + steamer_tris_before +
  batchc_rebuild_verify）与 `.design/ships/backup_glb/SN_Paddle_Steamer.01.glb` 均存在。

## 7. 测试 / 静态文档（外部工作流阻塞，非批次 C FAIL）

- 完整 headless 套件：**208 passed / 2 failed / 210 total**（83.6 s）。2 个失败均来自并发「海图 phase 2」：
  `test_ui_shell::test_sea_chart_entry_integration`（依赖 `sn_sea_chart_panel.gd` 编译失败）与
  `test_sea_chart.gd` 套件解析失败；批次 C 相关子集（mod_loading 4 + content_asset_loader 5 + stage_host 30 +
  ui_views 6 + run_pipeline 4）**49 passed / 0 failed**。
- Lead 所述 231 基线**当前不可复现**：外部海图套件解析失败导致可加载用例降至 210；属外部改动，非批次 C 回归。
- `gen_static_docs --check`：**stale 3 项**——`framework/tests/cases/test_sea_chart.gd.md`、
  `framework/ui/components/sn_sea_chart_panel.gd.md`、`manifest.json`（hash ledger）；均因外部海图文件在
  docs 生成（23:18）后再次改动。批次 C 自身生成器文档（`sn_paddle_steamer_generator.py.md`）已生成、不在 stale 列表。
- 结论：测试全绿 / 静态文档 up-to-date 需外部工作流修复后重跑；不构成本批 FAIL。

## 8. NIT / 说明

1. **水线轴心口径措辞**：task-12 写「≈−0.32」，实际 verify/GLB/场景三处一致为 **−1.32**（龙骨底），
   且 `verify_paddle_steamer_glb.py` 容差 0.30；本报告实测 −1.32，建议任务描述修正为 −1.32。
2. **digest 定义未归档**：基线只存 digest 值，无法从仓库复现算法；建议 Builder 把 `scene_digest` 行 schema
   与函数固化到脚本（可复用批次 A/B 的 `scene_digest`）。
3. **before/after 渲染曝光差 +8.9/255**：两轮重打光导致绝对像素不可直接比；本报告改用「同机位结构差 + 层内明度
   层级」判定，差异像素比例与轮廓变化一致。
4. 完整测试 231 基线因外部海图工作流不可复现（见 §7）；release 启动未由本 Verifier 独立复跑（外部 Parse Error 已知）。
5. 独立工具在 `.design/verify_c/`，可重跑（命令见下）。

## 9. 复现命令

```powershell
# 只读 Blender dump（本次已执行；之后不再读 Blender）
#   p = r"<repo>\.design\verify_c\dump_c.py"; ns={"__name__":"verify_c_dump","__file__":p,"bpy":bpy}
#   exec(compile(open(p,encoding="utf-8").read(),p,"exec"), ns); ns["dump"]()

python .design/verify_c/glb_check_c.py          # before/after GLB 结构、canopy、红面、内容 sha
python .design/verify_c/sha_compare_c.py --compare
python .design/verify_c/digest_c.py
python .design/verify_c/screenshot_diff_c.py
python .design/verify_c/analyze_c.py            # 汇总 37 项检查
godot --headless --path . --script res://.design/verify_c/godot/verify_ship_glb_c.gd
godot --headless --path . --script res://framework/tests/test_runner.gd
node tools/gen_static_docs.mjs --check
```

## 附录 · 证据（`.design/verify_c/out/`）

`blender_dump_tc1.json`（6.7 MB）、`glb_check_c.json`、`sha_compare_c.json`、`digest_c.json`、
`screenshot_diff_c.json`、`screenshots_diff/`、`godot_ship_glb.log`、`test_full_c.log`、`static_docs_check.log`、
`analyze_c.json`；基线副本 `.design/verify_c/baseline/SN_Paddle_Steamer_before.glb` 与
`baseline_content_sha.json`。
