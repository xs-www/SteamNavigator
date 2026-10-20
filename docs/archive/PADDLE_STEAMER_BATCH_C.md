# 批次 C 验收：SN_Paddle_Steamer 视觉精修

> 需求：MODELING_REQUIREMENTS_NEXT_BATCH.md §7；精修报告：[PADDLE_STEAMER_VISUAL_POLISH_C.md](PADDLE_STEAMER_VISUAL_POLISH_C.md)；独立验收：[PADDLE_STEAMER_VISUAL_POLISH_C_VERIFY.md](PADDLE_STEAMER_VISUAL_POLISH_C_VERIFY.md)。日期：2026-10-20。

> **人工视觉门禁：通过（2026-10-21，用户确认 A/B/C 截图）**。

## 0. 判定摘要
| 项 | 目标 | 实测 | 判定 |
| --- | --- | --- | --- |
| 后部雨棚压顶感 | 减轻、固定 3/4 可读 | 投影覆盖 63.72→**41.34 m²（占游步甲板 71.4%→46.3%）**；4 薄板(0.07)+3×0.20 分缝+3×0.14 暗红分肋+后段 3.0 m 露空；薄边 0.14→0.07 | PASS |
| 明度层次 | 白船身 > 甲板 > 舱室可辨 | 白船身 `SN_White` 0.760→**0.870**；舱室/上层建筑新局部 `SN_PS_UpperWhite` **0.680**；甲板 `SN_Wood_Deck` **0.300**（共享原值） | PASS |
| 暗红压条 | 适当加粗 | 舷墙压顶 0.055→**0.075**（截面 0.145→0.195）、水线/舷缘带 0.045→0.062 厚 & 0.10→0.14 高、客舱腰线 0.13→0.16、驾驶室/游步甲板/雨棚封檐同步加粗 | PASS |
| tri 上限 | ≤11 764 | **11 764**（canopy 228→228，逐对象差集为空；纯 Python 10 896 不变） | PASS |
| 尺寸/轴心 | 24.4×8.7×10.5、水线轴心、层级不变 | 24.56×8.74×10.47（与改前逐位相同）、z −1.32…9.15、root (45,0,0)、35 对象/`SN_PS_*` 层级不变、水线轴心 verify PASS | PASS |
| 旗/铭牌/明轮安全 | 不变 | 澳洲旗与 `ENTERPRISE` 铭牌几何未动；明轮 8×45° 世界 BVH **0 穿插**、无浮空 | PASS |
| 共享材质零副作用 | 其它资产视觉不变 | `SN_Wood_Deck`/`SN_Flag_White` **逐位恢复原值**；本船新增材质 `SN_PS_UpperWhite` 仅玩家船使用（槽 8→9）；非目标 226 对象 digest 与 C 前一致 | PASS |
| 导出/实机 | GLB 正确、无黑材质/丢贴图 | `verify_paddle_steamer_glb.py` **GLB OK**（35 节点/32 网格/9 材质 doubleSided/11764 tri/Y-up bbox 24.56×10.47×8.74/水线 −1.32）；船厂 3D 舞台 1440×900/960×540 实机截图正常 | PASS |
| 测试/文档 | 全绿/一致 | 完整套件 **231 passed / 0 failed**；`gen_static_docs --check` up to date | PASS |
| 人工视觉门禁 | 三项可读、其它资产无变化 | 材料齐全（见 §4） | 待确认 |

## 1. 改动与不变量
- 只改 `tools/modeling/generators/sn_paddle_steamer_generator.py` 的材质数值、雨棚参数/轻量几何与压条厚度；几何拓扑同盒数替换，tri 不增。
- 不变量：船体 24.56×8.74×10.47 m、水线轴心、`SN_PS_Root` 单根与 35 对象层级/命名、澳洲旗、`ENTERPRISE` 铭牌、明轮 8 角零穿插与轮罩安全、11 764 tri 上限。
- 非目标回归：226 个非本船对象 digest 与 C 前完全一致；其它船/模块/设施/道具 GLB 未动；全场景 261 对象/12 集合不变。

## 2. 共享材质零副作用（修正轮）
- 第一轮曾调整共享 `SN_Wood_Deck` / `SN_Flag_White`（会影响棚屋/其它船/纵帆船 pennant），修正轮已**逐位恢复**：(0.300,0.165,0.072) r0.76、(0.800×3) r0.70。
- 明度层次改由本船独占 `SN_White` 提亮 + 新增本船局部 `SN_PS_UpperWhite`（0.680）实现；本船槽数 8→9（+1 仅玩家船，需求未限制船材质槽数）。
- `verify_paddle_steamer_scene.py`/`dryrun_paddle_steamer.py` 同步材质期望 8→9，其它阈值未放宽；`verify_paddle_steamer_glb.py` 允许集合加入 `SN_PS_UpperWhite`，其余检查不变。

## 3. 导出与运行时资产
- 导出脚本改为**双写**：`dev_mods/core/assets/models/ships/SN_Paddle_Steamer.glb`（运行时内容，648 520 B，sha256 `cefec2b7aa2d…`）与 `assets/models/ships/SN_Paddle_Steamer.glb`（dev 预览镜像，同 sha）。
- 旧 GLB 备份 `.design/ships/backup_glb/SN_Paddle_Steamer.01.glb`；工作台 `.design/SN_Asset_Workbench.blend` 与船体快照 `.design/ships/SN_Paddle_Steamer.blend` 已保存。
- dev 预览 `dev_scenes/port_stage/port_stage_preview.gd` 的玩家船路径改指 core 内容资产，PortStage 截图与游戏一致。

## 4. 人工视觉门禁材料
1. before/after 固定机位：`.design/ships/paddle_steamer_before_batch_c/paddle_steamer_{three_quarter,broadside,bow,stern_quarter,top}.png` → `docs/design/screenshots/paddle_steamer_*_batchc.png`（同相机、同 render 脚本）。
2. Godot 实机：`docs/design/screenshots/paddle_steamer_c/shipyard_paddle_steamer_{1440x900,960x540}.png`（船厂 3D 舞台正常态）；`docs/design/screenshots/iron_harbor_architecture/SN_HT_Warehouse_Long_LOD0_port_stage_{1440x900,960x540}.png`（PortStage 固定机位，新船入画）。
3. 需确认：雨棚在 3/4 与实机中不再读成整块压顶；白船身/舱室/甲板层次可辨；暗红压条比例克制；其它资产（棚屋/货棚/纵帆船/铁甲舰）外观无变化。

## 5. 交付物（§8 对照）
- 参数化生成器更新：`sn_paddle_steamer_generator.py`（含 @static-doc）；dry-run `dryrun_paddle_steamer.py`。
- 工作台集合 + `.blend` 快照；单件运行时 GLB + 结构检查（`verify_paddle_steamer_glb.py` / `verify_paddle_steamer_scene.py`）。
- 3/4、正侧、艏、艉、俯视 before/after；Godot 1440×900/960×540 实机；tri/材质/包体/尺寸不变量对比。
- `ASSET_MAP.md` 船章节、`todo.md`、静态文档同步；verifier 独立验收见配套报告。

## 5.1 独立验收（verifier-a，task-12）
- 结论：**PASS（批次 C 范围 37/37 检查全过，0 FAIL）**；报告 [PADDLE_STEAMER_VISUAL_POLISH_C_VERIFY.md](PADDLE_STEAMER_VISUAL_POLISH_C_VERIFY.md)。
- 独立复算：tri 11 764（32 对象差集空）、bbox 24.56×8.74×10.47 逐位一致、明轮 8×45° BVH 0 穿插、旗/铭牌几何 sha 不变；新增材质仅本船 5 对象；`SN_Wood_Deck`/`SN_Flag_White` 逐位恢复；**内容树 168 文件仅 2 个 steamer GLB 变化、其余 166 全同 sha**。
- 三项量化：雨棚 63.72→41.34 m²、3×0.20 分缝、后段 3.0 m 露空、板厚 0.14→0.07；明度 0.870>0.680>0.300（5 视角采样通过）；压条红面 +34.5%/+39.4%。
- GLB/Godot：同 sha `cefec2b7…`（648 520 B），Godot 载入 32 mesh/90 surface/9 材质，无黑材质/缺材质，逐顶点 AABB 精确；截图同机位（shift 0,0、结构差 2.0–9.3%）。
- NIT：①水线口径实际为龙骨底 **−1.32**（verify 容差 0.30），非 −0.32；②基线 digest 仅存值未存定义（建议下次固化脚本）；③before/after 渲染曝光差 +8.9/255，用同机位结构差+层内明度判定。

## 5.2 外部阻塞（非批次 C）
- 并发海图 phase 2 工作流期间：完整套件 **208 passed / 2 failed / 210**（2 个失败与解析错误均为海图）、`gen_static_docs --check` stale 3 项均为海图外部文档；批次 C 相关子集 **49/0**。此前干净基线 231 passed 在当前外部状态下不可复现，与本批改动无关。待海图工作流稳定后重跑即可。

## 6. 未闭合 / 风险
1. tri 恰在上限 11 764，后续任何加件需先减面。
2. 船材质槽 8→9（+1 批次，仅玩家船）；若未来要求船槽恒定，可退回「仅 SN_White 提亮」但层次会弱一档。
3. 雨棚分缝 0.20 / 后段露空 3.0 m 是按 1400 px 3/4 与实机可读选定，如要更轻可继续调参（不改 tri）。
4. 人工视觉门禁待确认。
