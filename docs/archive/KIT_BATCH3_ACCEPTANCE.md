# 模型素材库批次 3 验收记录（architecture_kit + environment_kit，P2）

> 日期：2026-10-21 → 2026-10-22（跨午夜）
> 工单：[sn_kit_batch3.json](../../tools/modeling/briefs/sn_kit_batch3.json)
> 契约：[KIT_ASSET_LIBRARY.md §10](../design/KIT_ASSET_LIBRARY.md)
> 目录：[kit_catalog.json](../../tools/modeling/kit_catalog.json)（三批 26 件 / 13 配方 / 41,290 tri）
> 场景：`.design/SN_Asset_Workbench.blend`（x=30..70、y=576..600 工作区）

## 1. 范围

批次 3 交付 **8 件**模块化资产，沿用批次 1–2 的 `Mount` + 语义 socket + 根 extras 契约：

| 套件 | 资产 | 角色 |
| --- | --- | --- |
| `architecture_kit` | `SN_Arch_Warehouse` | 8×6 m 仓库体量 + 装卸雨棚 / 滑门 / 吊货梁 |
| | `SN_Arch_Workshop` | 8×6 m 工坊 + monitor 采光顶 + 外墙飞轮（`Drive_Shaft`） |
| | `SN_Arch_Tavern` | 6×6 m 两层酒馆 + 门廊 / 阳台 / 悬挑招牌 |
| | `SN_Arch_Factory` | 12×8 m 厂房 + 4 跨锯齿顶 + 双烟囱 + 外置吊车梁 |
| `environment_kit` | `SN_Env_Reef` | 宽平礁顶 + 4 块礁岩扶壁 + 石砌灯塔基台（`Top`） |
| | `SN_Env_Wreck` | 横倾 13° 断裂船壳 + 外露肋骨 + 断桅（穿龙骨）+ 压舱石 |
| | `SN_Env_Lighthouse` | 八边形基座 + 收分石塔 + 环廊 + 灯室 + 穹顶 |
| | `SN_Env_Buoy` | 浮筒 + 吃水裙 + 灯架 + 黄铜钟 + 锚链 |

纯资产交付：不接游戏逻辑、不登记 Core manifest 键、不改批次 1–2 资产。

## 2. 最终结果

| 资产 | tri / 预算 | bbox X×Y×Z (m) | zmin..zmax | 材质数 |
| --- | ---: | --- | --- | ---: |
| `SN_Arch_Warehouse` | 2704 / 3400 | 10.95 × 6.95 × 6.35 | 0 .. 6.350 | 8 |
| `SN_Arch_Workshop` | 1996 / 2900 | 9.32 × 6.63 × 7.04 | 0 .. 7.040 | 9 |
| `SN_Arch_Tavern` | 2884 / 3400 | 8.67 × 6.96 × 7.64 | 0 .. 7.640 | 9 |
| `SN_Arch_Factory` | 3020 / 4800 | 14.74 × 8.30 × 9.64 | 0 .. 9.640 | 8 |
| `SN_Env_Reef` | 1944 / 2400 | 7.13 × 6.44 × 5.52 | −3.000 .. 2.515 | 3 |
| `SN_Env_Wreck` | 1046 / 2800 | 8.62 × 3.96 × 4.72 | −1.498 .. 3.222 | 7 |
| `SN_Env_Lighthouse` | 1952 / 2600 | 4.62 × 4.60 × 13.16 | 0 .. 13.160 | 7 |
| `SN_Env_Buoy` | 868 / 1000 | 1.88 × 1.88 × 3.84 | −0.740 .. 3.100 | 5 |

- 批次 3 合计 **16,414 tri / 23,200 预算**；三批合计 **42,058 / 60,300**。
- 45 个 mesh 的边界边 / 非流形边 / 退化面 / 孤立点 / 零长边全 0；45/45 有向体积 > 0（法线朝外）。
- 45/45 mesh 有 `UVMap` 且 `len(uv)==len(loops)`；材质 100% 为 `SN_Tex_*`，绑定 11 张 512² 共享贴图，无纯色材质。
- 8 个根空物体 extras 齐全（建筑含 `module_x/module_y`，环境件含 `waterline`）；38 个 socket 全部精确命中工单坐标、父级 = Root。
- 命名零 `.001`、零 mesh/socket 重名：`Smokestack`（Chimney socket）、`GantryBeam`（Gantry）、`BrokenMast`（Mast）、`Catwalk`（Gallery）、`BellRig`（Bell）、`ChainLinks`（Chain）。

## 3. 关键专项验收

| 专项 | 结果 |
| --- | --- |
| 建筑落地 | 4/4 件 zmin=0；雨棚立柱、吊车立柱、驱动轮支架、烟囱、招牌均有实体接触（无浮空；招牌/吊钩/吊索属设计吊挂） |
| 礁石承灯塔 | `Top` world (30.60,579.60,2.48)；压顶正十边形 circumR 2.66 / apothem 2.529 > 灯塔基座八边形 circumR 2.488；**16/16 采样点命中压顶面，gap 0.0000、水平外挑 0** |
| 礁岩扶壁 / 外圈岩裙 | 4 块扶壁全部与主礁石实体交叠（18–43 tri）；用户反馈底座边缘悬空后，石鼓改等径 r2.66 + 外圈 10 块礁岩裙（外缘 ≥2.75 > 压顶 2.70），24 方位向下 raycast 全部命中岩石，底座周边无悬空 |
| 残骸断桅 | 桅脚在船底、桅座横梁接两舷：`BrokenMast` ↔ `Hull` 0.0030 m、↔ `Ribs` 0.0040 m（修复前 1.064 m） |
| 压舱石 | 5 颗最低点到船底内底 gap −0.0094 / −0.0097 / −0.0100 / −0.0099 / −0.0103 m（轻嵌 0.94–1.03 cm）；全量顶点扫描无石尖穿出外板（最小余量 +0.139 m） |
| 龙骨共面 | 龙骨顶面 −1.220 与内底板 −1.200 竖直间隙 0.0205 m（≥0.01），消除 P2 z-fighting |
| 浮标钟 | `BellRig` ↔ `LampFrame` 最近 0.0000 m |

## 4. 验证轮次

1. **纯 Python 干跑** `dryrun_kit_batch3.py`：8/8 通过；抓出 mesh/socket 同名 6 处、礁石湿痕面拆分导致非流形、压顶覆盖不足、压舱石悬空；随礁石返工最终 total 16,414。
2. **Builder R1**：一次建 8 件 15,214 tri，共享贴图 8/8 PASS；几何 BVH/raycast 复核发现残骸断桅悬空、礁石平台装不下灯塔基座。
3. **Builder R2–R4**：断桅穿龙骨、礁石加宽平顶 + 石鼓 + 压顶、压舱石逐颗贴底、浮标钟贴灯架；压顶 16 采样点通过。
4. **Builder R5**：礁石加 4 块扶壁 + 龙骨下沉 2 cm；压顶 16/16、Ballast 5/5、无穿外皮；total 15,646。
5. **独立 Verifier（task-18）**：只读复算 8 件 tri/bbox/zmin、45 mesh 健康、UV/材质、38 socket、拼装/落地/落座，**passed=true / failures=0**；`BATCH3 VERIFY PASS`。
6. **用户反馈 R6–R8（礁石底座）**：环境 lineup 中「底部石头没有全部比底座大、边缘悬空」→ 石鼓改等径 r2.66，外圈礁岩裙 10 → 12 → **16 块密排**（r1.10、h4.20、环绕 2.25，顶部盖过石鼓底沿并嵌入）；最终 36/36 方位点 (r=2.66, z=1.15) 在岩石实体内、1° 细扫 357/360、岩石外缘 36/36 ≥2.75（min 2.948，相对压顶 +0.288 m）；look 无露白/空隙；Reef 1944 tri、bbox 7.13×6.44×5.52、total 16,414。
7. **Builder 最终复核**：16 块裙岩版本 total 16,414、灯塔落座 16/16 gap 0、外缘 36/36 ≥2.75、36 方位实体承托 36/36；批次 1–2 对象计数不变。
8. **独立 Verifier 增量复检（task-27）**：最终礁石版本只读复核（岩裙承托 36 方位 / 灯塔落座 / 总量 / 无回归）；结果见 `BATCH3 FINAL DELTA PASS` 报告。
9. **GLB 自检** `verify_kit_batch3_glb.py`：8/8 ALL OK（节点数 / mesh 数 / tri / Y-up 尺寸 / groundY / 外部贴图 URI 与字节 / UV / 根 extras）。

## 5. 产物

- GLB：`assets/models/architecture/SN_Arch_*.glb`（4）+ `assets/models/environment/SN_Env_*.glb`（4），以及 `dev_mods/core/assets/models/{architecture,environment}/` 副本。
- 共享贴图：两处 `shared_materials/`（11 张/目录），`shared_materials.spec.json` 的 `runtime_dirs` 已扩到 16 个目录。
- 预览：`docs/design/screenshots/kits/kit_architecture_lineup.png` / `kit_environment_lineup.png` / `kit_assembly_town{,_detail}.png` / `kit_assembly_coast{,_detail}.png` 与 8 件 × {3/4, 侧视}。
- 工具链：`kit_batch3_generator.py` / `dryrun_kit_batch3.py` / `export_kit_batch3_glb.py` / `verify_kit_batch3_glb.py` / `render_kit_batch3_preview.py`；`gen_kit_catalog.py` 合并三批；`sn_kit_materials.py` 白名单并入 architecture/environment。

## 6. 已知 P2（不阻塞，记录备查）

- 礁石压顶 8 颗铁栓头高出压顶面 0.035 m，位于灯塔基座 footprint 外，不干涉落座。
- 石砌基台为等径石鼓（r2.66）+ 压顶沿（r2.70，+0.04 m），外圈 16 块礁岩裙顶部盖过石鼓底沿；从侧视看是「石鼓坐在岩石圈里」，不再有悬空边。
- 预览 `kit_assembly_coast.png` 使用临时水面平面（不进资产）；礁石水下部分在预览里被水面遮挡。
- 建筑 `Module_Next/Prev` 只约定位移，不做自动吸附 / 碰撞；本批不接运行时装配。
- 1° 细扫有 3 个单点采样（az 204°/223°/316°）落在岩石棱面缝隙上，属单点级、无可见空洞；36 方位门禁已 36/36。
