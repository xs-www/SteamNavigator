# 模型素材库批次 2 验收记录（机械 / 货物 / 码头 P1）

> 日期：2026-10-21
> 范围：10 件模块化模型素材（机械 3 + 货物 4 + 码头 3）；纯资产交付，不接游戏逻辑、不登记 manifest。
> 工单：[sn_kit_batch2.json](../../tools/modeling/briefs/sn_kit_batch2.json)
> 素材库契约：[KIT_ASSET_LIBRARY.md §9](../design/KIT_ASSET_LIBRARY.md)
> 机器目录：[kit_catalog.json](../../tools/modeling/kit_catalog.json)（两批合并 18 件）
> 资产映射：[ASSET_MAP.md](../design/ASSET_MAP.md#模型素材库批次-2机械--货物--码头2026-10-21)

## 1. 交付清单

| 资产 | GLB | 尺寸 X×Y×Z (m) | tri / 预算 | 材质 | 接口 |
| --- | --- | --- | ---: | ---: | --- |
| `SN_Machinery_GearSet` | `assets/models/machinery/SN_Machinery_GearSet.glb` | 1.90 × 1.12 × 1.06 | 2020 / 2400 | 5 | Mount + Shaft_In/Out + Crank |
| `SN_Machinery_Winch` | `assets/models/machinery/SN_Machinery_Winch.glb` | 2.24 × 1.82 × 1.42 | 1776 / 2600 | 7 | Mount + Drum_Pivot + Rope_Out + Brake |
| `SN_Machinery_PowerUnit` | `assets/models/machinery/SN_Machinery_PowerUnit.glb` | 3.78 × 1.44 × 2.11 | 2260 / 3600 | 7 | Mount + Shaft_Out + Coupling + Steam_In + Exhaust_Out |
| `SN_Cargo_Crate` | `assets/models/cargo/SN_Cargo_Crate.glb` | 1.26 × 1.19 × 1.04 | 672 / 1000 | 8 | Mount + Stack_Top + Lift_L/R |
| `SN_Cargo_CoalScuttle` | `assets/models/cargo/SN_Cargo_CoalScuttle.glb` | 1.48 × 1.14 × 1.10 | 588 / 1500 | 8 | Mount + Fill_Top + Chute |
| `SN_Cargo_Tank` | `assets/models/cargo/SN_Cargo_Tank.glb` | 3.37 × 1.60 × 1.95 | 1820 / 2600 | 5 | Mount + Fill_Top + Outlet + Vent |
| `SN_Cargo_Pallet` | `assets/models/cargo/SN_Cargo_Pallet.glb` | 1.23 × 1.02 × 0.18 | 316 / 600 | 5 | Mount + Stack_Top |
| `SN_Dock_Structure` | `assets/models/dock/SN_Dock_Structure.glb` | 8.40 × 4.46 × 3.16 | 1628 / 3200 | 3 | Mount + Module_Next/Prev + Socket_Mooring_1/2 + Socket_Jetty |
| `SN_Dock_Jetty` | `assets/models/dock/SN_Dock_Jetty.glb` | 8.03 × 2.66 × 2.80 | 1660 / 3000 | 5 | Mount + Module_Next/Prev + Socket_Mooring + Ladder |
| `SN_Dock_Mooring` | `assets/models/dock/SN_Dock_Mooring.glb` | 1.56 × 1.15 × 0.95 | 940 / 1400 | 5 | Mount + Bitt_Port/Starboard + Ring + Rope_Tie |

- 合计 **13,680 tri / 预算 20,600**；除 `SN_Dock_Jetty`（水线 datum，桩到 z=−1.30）外全部 zmin = 0。
- 共享贴图 `SN_Tex_*` 外部化为 `shared_materials/<texture>.png`（含新增 `SN_Tex_Coal`）；`assets/models/{machinery,cargo,dock}/` 与 `dev_mods/core/assets/models/{machinery,cargo,dock}/` 双副本。
- GLB Root `extras`：`kit_family / part_role / datum / mount_frame / base_footprint_* / envelope_* / height / tri_budget / bbox_target`，码头模块另有 `module_x/y / deck_height`。

## 2. 验收证据

| 检查 | 结果 |
| --- | --- |
| 共享贴图扩展 | `SN_Tex_Coal` 加入 spec（512²、无缝、确定性）；11 张全部 deterministic / seam_ok；旧 10 张字节不变；runtime_dirs 新增 machinery/cargo/dock 六处 |
| 纯 Python 干跑 `dryrun_kit_batch2.py` | **ALL KIT BATCH 2 ASSETS OK**：10 件命名 / 父级 / tri / bbox / 基准面 / 网格健康 / 材质白名单 / 共享贴图（含煤）/ Mount+socket 坐标 / 对称 / 各件 datum 断言 |
| Blender 构建（Builder 最终轮） | 10 集合 / 101 对象（49 mesh + 52 empty）；场景 577 objects / 400 mesh / 41 collections；Camera=2、Light=1；非批次 2 对象名与位置 SHA-256 与基线一致 |
| 网格健康 | 10 件 49 mesh 全部 boundary / nonmanifold / degenerate / loose / wire = 0 |
| 命名 | 无 `.001`；mesh 与 socket 零重名（Crank / Chute / Ladder / Ring 均改 HandCrank / Spout / AccessLadder / MooringRing） |
| UV / 贴图 | 每个 mesh `UVMap` 完整、`SN_Tex_*`、贴图 512² 已绑定；煤斗含 `SN_Tex_Coal` |
| 拼装接口 | 机械链：PowerUnit Shaft_Out (1.25,0.40,0.95) / GearSet Shaft_In (−0.35,−0.48,0.58) / Winch Drum_Pivot (0,0,0.95)；货堆：Crate→Pallet Stack_Top 0.18、Crate 自叠 1.035；码头：Module_Next/Prev、Socket_Mooring_1/2、Socket_Jetty、Jetty→Dock 旋转 90° 后桥面 Δ=0、Mooring→码头顶面 Δ=0 |
| 独立 Verifier R1（task-10） | 3 项 P1：Pallet Stack_Top 0.18 与铜钉顶 0.215 互穿 35 mm；Jetty 端梯朝向错误（未贴端面且插入铺板）；Mooring 木护舷悬空 0.16 m |
| 独立 Verifier R2（task-12） | 3 项 P1 全部修复通过；新发现 Jetty `Ladder` socket 仍是旧值（错位 1.10 m） |
| 独立 Verifier R3（task-14，最终） | **passed=true / 0 failures**：Ladder socket (−4.00,0,1.30) 到梯顶中心 0.000 m；端梯 2 柱 + 6 横档 + 2 上支架贴合铺板底、无悬空；10 件 tri/bbox/zmin/健康/UV/材质/extras/socket 全绿；Pallet 0.18 / Crate 1.035 / Mooring 护舷 zmin=0 无回退 |
| GLB 结构自检 `verify_kit_batch2_glb.py` | **10/10 ALL OK**：节点 / 网格 / tri / Y-up 尺寸 / 材质 / UV / 外部共享贴图字节（含 coal.png）/ root extras / socket 节点 |
| 预览 | 3 组 lineup + 2 张码头拼装 + 20 张单件图 |

## 3. 独立质检与返工

| # | 阶段 | 发现 | 修正 |
| --- | --- | --- | --- |
| 1 | 干跑（Lead） | mesh 与 socket 同名 4 处（Crank / Chute / Ladder / Ring） | 改名为 HandCrank / Spout / AccessLadder / MooringRing |
| 2 | 干跑 | 货箱材质白名单缺 Metal/Glass、煤斗缺 Wood/Glass、动力装置缺 Wood、系缆设施缺 Stone | 材质白名单补齐 |
| 3 | 干跑 | 储罐人孔有零厚度盒（4 个退化面）、货箱 zmin=0.10、多个 bbox 偏差 | 修盒厚度 / 补箱脚 / 按实测更新 bbox 与 brief |
| 4 | Builder R1 视觉 | 齿轮组正面被实心侧板挡住、系缆绳圈悬空 0.10 m 且穿底板、栈桥铺板 ±X 轻微不对称 | 改开式机架（立柱 + 上下横梁 + 竖撑/轴承）、绳圈落到 base 顶面、铺板对称 |
| 5 | Builder R2 视觉 | 码头结构 / 栈桥爬梯朝向垂直墙面；Mooring bbox / extras 未同步 | 梯柱垂直、横档沿 X；bbox / extras 同步（Mooring 1.56、Jetty 8.03） |
| 6 | Builder R3 视觉 | Pallet 铜钉顶面凸出到 0.215（与货箱底 0.18 互穿 35 mm）、Crate Stack_Top 1.02 低于盖顶 1.035、Jetty 端梯未贴 -X 端面、Mooring 木护舷悬空 | 托盘角铁/铜钉压平到 0.18；Crate Stack_Top 改 1.035；Jetty 端梯改贴 -X 端面（YZ 平面、横档沿 Y、梯顶 1.30）；木护舷落地并半嵌入 base + 2 道铁箍；工位分离 |
| 7 | Verifier R2 | Jetty `Ladder` socket 仍 (-3.90,1.10,1.30)，与新梯位差 1.10 m | SOCKETS 改 (-4.00,0,1.30)；顺带把 4 个悬空 lower 支架换成 2 个接铺板底的上支架（tri 1660） |
| 8 | 人工验收反馈 | 机械 lineup 第一件 PowerUnit 有浮空：飞轮无轴承支撑、调速器悬在汽缸上方 | 飞轮加贯穿轴 + 两侧轴承立柱（落到横跨滑橇的木承梁，梁底 z=0）+ 轴承座/黄铜螺栓；调速器移到汽缸顶（x=−0.60）并从 z=1.35 汽缸顶升起、带法兰底座；PowerUnit 1984→2260 tri，bbox 不变；Builder 射线自检两柱 5/5 命中承梁 |

## 4. GLB 自检

`python tools/modeling/generators/verify_kit_batch2_glb.py` → **ALL KIT BATCH 2 GLB OK（failures = 0）**：

| GLB | nodes | mesh | tris | size Y-up (m) | 外部贴图 | 结果 |
| --- | ---: | ---: | ---: | --- | ---: | --- |
| SN_Machinery_GearSet | 10 | 5 | 2020 | 1.90 × 1.06 × 1.12 | 5 | ok |
| SN_Machinery_Winch | 10 | 5 | 1776 | 2.24 × 1.42 × 1.82 | 7 | ok |
| SN_Machinery_PowerUnit | 11 | 5 | 2260 | 3.78 × 2.11 × 1.44 | 7 | ok |
| SN_Cargo_Crate | 9 | 4 | 672 | 1.26 × 1.03 × 1.19 | 8 | ok |
| SN_Cargo_CoalScuttle | 9 | 5 | 588 | 1.48 × 1.10 × 1.14 | 8 | ok |
| SN_Cargo_Tank | 9 | 4 | 1820 | 3.37 × 1.95 × 1.60 | 5 | ok |
| SN_Cargo_Pallet | 7 | 4 | 316 | 1.23 × 0.18 × 1.02 | 5 | ok |
| SN_Dock_Structure | 13 | 6 | 1628 | 8.40 × 3.16 × 4.46 | 3 | ok |
| SN_Dock_Jetty | 11 | 5 | 1660 | 8.03 × 2.80 × 2.66 | 5 | ok |
| SN_Dock_Mooring | 12 | 6 | 940 | 1.56 × 0.95 × 1.15 | 5 | ok |

## 5. 预览 / 源文件

- `docs/design/screenshots/kits/kit_machinery_lineup.png` / `kit_cargo_lineup.png` / `kit_dock_lineup.png`
- `docs/design/screenshots/kits/kit_assembly_dock.png` / `kit_assembly_dock_detail.png`
- `docs/design/screenshots/kits/kit_<slug>_{three_quarter,side}.png`（gearset / winch / power_unit / crate / coal_scuttle / tank / pallet / dock_structure / jetty / mooring）
- 工作台：`.design/SN_Asset_Workbench.blend`（批次 2 摆位 y=560–600）
- 备份：`.design/kits/backup_glb/`
- 工具：`kit_batch2_generator.py` / `dryrun_kit_batch2.py` / `export_kit_batch2_glb.py` / `verify_kit_batch2_glb.py` / `render_kit_batch2_preview.py` / `gen_kit_catalog.py`

## 6. 非阻断观察

- 煤斗的煤堆偏平，后续若需要更醒目的煤堆可拉高锥体（当前 bbox 高度 1.10 m）。
- 机械轴系只提供语义 socket 与尺寸约定，不强制机械耦合（本批不含动画 / 联动逻辑）。
- 码头件根在水线 / 甲板面；栈桥桩在水下（zmin=−1.30），场景摆放时不要把 zmin 当作落地基准。
- 世界空间盒式 UV 在圆柱（储罐 / 绳鼓）侧面形成竖向条带，风格化可接受（与批次 1 一致）。
- P2（不阻塞）：托盘铁带/铜钉与铺板共面、叠箱为共面接触（装配时建议加 1–2 mm epsilon 防 z-fighting）；Crate 1.19 宽 / Pallet 1.02 宽存在工单尺寸决定的 85 mm 悬挑；Mooring 绳圈离基座顶 15 mm、系缆环与安装板 45 mm 间隙；Jetty 顶横档外缘比桥面高 19 mm（可当扶手）；场景仍有 4 个预览辅助 mesh datablock 带 `.001`（非批次 2）。
- 本批不登记 Core manifest、不接运行时装配；接入时按 `kit_catalog.json` 读取 socket 与 datum。
