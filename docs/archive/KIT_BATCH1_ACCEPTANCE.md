# 模型素材库批次 1 验收记录（武器套件 + 船体部件）

> 日期：2026-10-21
> 范围：8 件模块化模型素材（4 件武器套件 + 4 件船体部件）；纯资产交付，不接游戏逻辑、不登记 manifest。
> 工单：[sn_kit_batch1.json](../../tools/modeling/briefs/sn_kit_batch1.json)
> 素材库契约：[KIT_ASSET_LIBRARY.md](../design/KIT_ASSET_LIBRARY.md)
> 机器目录：[kit_catalog.json](../../tools/modeling/kit_catalog.json)
> 资产映射：[ASSET_MAP.md](../design/ASSET_MAP.md#模型素材库批次-1武器套件--船体部件2026-10-21)

## 1. 交付清单

| 资产 | GLB | 尺寸 X×Y×Z (m) | tri / 预算 | 材质 | 接口 |
| --- | --- | --- | ---: | ---: | --- |
| `SN_Weapon_Cannon` | `assets/models/weapons/SN_Weapon_Cannon.glb` | 4.00 × 1.44 × 0.82 | 1156 / 1400 | 5 | Mount + Pitch_Pivot + Trunnion_L/R + Muzzle + Breech |
| `SN_Weapon_GunCarriage` | `assets/models/weapons/SN_Weapon_GunCarriage.glb` | 2.96 × 1.79 × 1.10 | 2256 / 2800 | 7 | Mount + Yaw_Pivot + Trunnion_L/R (z=0.62) |
| `SN_Weapon_Turret` | `assets/models/weapons/SN_Weapon_Turret.glb` | 5.12 × 3.44 × 3.04 | 1904 / 3400 | 6 | Mount + Yaw_Pivot + GunPort + Muzzle + Hatch + Anchor_1..4 |
| `SN_Weapon_Pedestal` | `assets/models/weapons/SN_Weapon_Pedestal.glb` | 1.90 × 1.90 × 1.20 | 940 / 1100 | 4 | Mount + Collar + Yaw_Pivot + Anchor_1..4 |
| `SN_ShipPart_Deck` | `assets/models/ship_parts/SN_ShipPart_Deck.glb` | 8.40 × 6.00 × 0.36 | 576 / 1800 | 4 | Mount + Socket_Mast/Funnel/Hatch/Weapon_Port/Weapon_Starboard |
| `SN_ShipPart_Mast` | `assets/models/ship_parts/SN_ShipPart_Mast.glb` | 1.77 × 6.20 × 12.84 | 2764 / 2800 | 6 | Mount + Top + Lookout + Yard_Lower/Upper_Mount + Deadeye_Port/Starboard |
| `SN_ShipPart_Funnel` | `assets/models/ship_parts/SN_ShipPart_Funnel.glb` | 2.40 × 2.00 × 4.66 | 1528 / 1800 | 4 | Mount + Exhaust + Steam_Inlet + Stay_1..4 |
| `SN_ShipPart_HatchCover` | `assets/models/ship_parts/SN_ShipPart_HatchCover.glb` | 2.72 × 2.00 × 0.49 | 840 / 1400 | 6 | Mount + Hinge_Fwd/Aft + Opening_Center + Lid_Pivot_Fwd/Aft |

- 合计 **11,964 tri** / 预算 16,500；全部 zmin = 0（火炮是俯仰子件，根 = 耳轴轴心，局部 zmin = −0.24）。
- 共享贴图 `SN_Tex_*` 外部化为 `shared_materials/<texture>.png`；`assets/models/{weapons,ship_parts}/` 与 `dev_mods/core/assets/models/{weapons,ship_parts}/` 双副本。
- GLB Root `extras`：`kit_family / part_role / forward / up / datum / mount_frame / base_footprint_* / envelope_* / height / tri_budget / bbox_target`，炮塔 / 基座 / 炮架 / 火炮带 `mount_class`，甲板带 `deck_height / module_x / module_y`。

## 2. 验收证据

| 检查 | 结果 |
| --- | --- |
| 纯 Python 干跑 `dryrun_kit_batch1.py` | **ALL KIT ASSETS OK**：8 件命名 / 父级 / tri / bbox / 基准面 / 网格健康 / 材质白名单 / 共享贴图 / Mount+socket 坐标 / 左右对称 / Yaw 子节点世界高度 / Anchor 半径 / 甲板 socket 承载 Heavy 炮塔 |
| Blender 构建（Builder R3） | 8 集合 / 95 对象（35 mesh + 60 empty）；场景 476 objects / 351 mesh / 31 collections；Camera=2、Light=1；非 kit 对象名 SHA-256 与基线一致 |
| 网格健康 | 8 件全部 boundary = 0、nonmanifold = 0、degenerate = 0、loose = 0 |
| 命名 | 无 `.001` 后缀；mesh 名与 socket 名零重名（Cannon BreechBlock vs Breech、Pedestal CollarRing vs Collar、Mast Platform vs Top） |
| UV / 贴图 | 每个 mesh 有 `UVMap` 且 `len(uv) == len(loops)`；全部 `SN_Tex_*`；贴图 512² 已绑定 |
| 拼装对齐 | 火炮 Trunnion_L/R + root (0,0,0.62) 与炮架 Trunnion_L/R 世界坐标 gap = 0.000000 m、朝向一致 |
| 独立 Verifier R1（只读） | 3 项硬缺陷 + 1 项 P2（见 §3） |
| 返工 R3 + 复检 | 见 §3 / §4 |
| GLB 结构自检 `verify_kit_glb.py` | 8/8 ALL OK（节点 / 网格 / tri / Y-up 尺寸 / 材质 / UV / 外部共享贴图字节 / root extras / socket 节点） |
| 预览 | lineup ×2 + 拼装 ×2 + 单件 3/4 与侧视 ×8 |

## 3. 独立质检发现与返工

| # | 资产 | 失败项 | 修正 |
| --- | --- | --- | --- |
| 1 | `SN_Weapon_Turret` | Yaw 子 socket 用根坐标挂在 z=0.22 的 Yaw_Pivot 下，GunPort/Muzzle/Hatch 整体高 0.22 m | socket 改为 Yaw 局部坐标（world = +0.22）：GunPort/Muzzle local z=1.12、Hatch local z=2.58 |
| 2 | `SN_Weapon_Turret` | Anchor_1..4 在四角 (±1.55,±1.55)，半径 2.19 > 基座 1.72，悬空 0.533 m | 收到基座环 45° 螺栓位 (±1.06,±1.06,0.20)，半径 1.5，到表面距离 0.013 m |
| 3 | `SN_ShipPart_Deck` | 实际 22 条铺板，工单要求 24 条 | 改 24 条（步距 5.5/24，板宽 0.225） |
| 4 | `SN_ShipPart_Deck` | P2：Heavy 炮塔放在原 weapon socket (2.80,1.80) 会出甲板边缘 0.32/0.52 m | weapon socket 内移到 (±2.30,1.10)，炮塔底座完全落在甲板内 |

## 4. 人工验收反馈

- 用户 2026-10-21：「桅杆的观望台不应该在最顶上吗」→ 把驻人瞭望台从下桅头（z≈7.9）移到**桅顶**（台面 z=12.08–12.16）：三面半栏杆（-X 侧留登台梯口）、长梯（下端落到上横桁 z=10.40）+ 3 道支撑、4 根斜撑、黄铜单筒望远镜；下桅头只保留 trestle / crosstree 结构；新增 `SN_ShipPart_Mast_Lookout`（0.50, 0, 12.16）接口。桅杆 tri 2140 → 2764（预算 2700 → 2800）。
- 甲板 weapon socket、Turret Anchor、Yaw 子 socket 的修正同步写入 [KIT_ASSET_LIBRARY.md](../design/KIT_ASSET_LIBRARY.md) 与 `kit_catalog.json`。

## 5. 预览 / 源文件

- `docs/design/screenshots/kits/kit_weapon_lineup.png` / `kit_ship_parts_lineup.png`（武器 lineup 里火炮放在临时展示托架上，因为它的根 = 耳轴轴心）
- `docs/design/screenshots/kits/kit_assembly_gun.png` / `kit_assembly_deck.png` / `kit_assembly_deck_detail.png`
- `docs/design/screenshots/kits/kit_<slug>_{three_quarter,side}.png`
- 工作台：`.design/SN_Asset_Workbench.blend`（kit 集合摆位 y=440–543）
- 备份：`.design/kits/backup_glb/`
- 生成器 / 干跑 / 导出 / 自检 / 预览 / 目录：`tools/modeling/generators/kit_batch1_generator.py` / `dryrun_kit_batch1.py` / `export_kit_glb.py` / `verify_kit_glb.py` / `render_kit_preview.py` / `gen_kit_catalog.py`

## 6. 非阻断观察

- 世界空间盒式 UV 在烟囱等圆柱侧面形成竖向条带（风格化，可接受）。
- 炮管相对塔身略短（外伸 1.9 m / 塔径 3.4 m），低模约定下可接受。
- 桅杆只做桅身 / 瞭望台 / 横桁 / 眼板，不含帆面与索具（留给后续 `rig_kit`）；烟囱不含蒸汽几何（VFX 在 Godot 侧）。
- 本批不登记 Core manifest、不接运行时装配；socket 是模型侧契约，后续接入 `ShipVisualAssembler` 时按 `kit_catalog.json` 读取。

## 装配规范 v2 迁移（2026-10-22）

武器部件 Cannon / GunCarriage / Turret / Pedestal 与甲板 weapon socket 已统一为 `SN_Mount` / `SN_Pivot_Yaw` / `SN_Pivot_Pitch` / `SN_Recoil` / `SN_Muzzle` / `SN_Anchor_*` / `SN_Socket_Weapon_Port|Starboard`；炮管/炮尾挂 `SN_Recoil`，甲板 socket 改为 `SN_Socket_Weapon_*`。BLEND 内节点带资产前缀避免全局重名，GLB 导出后由 `glb_weapon_nodes.standardize()` 归一化，`verify_kit_glb.py` 8/8 通过。契约见 [WEAPON_SOCKET_CONTRACT.md](../design/WEAPON_SOCKET_CONTRACT.md)。
