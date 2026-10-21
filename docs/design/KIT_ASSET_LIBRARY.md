# 模型素材库（批次 1 P0：武器套件 + 船体部件；批次 2 P1：机械 / 货物 / 码头；批次 3 P2：建筑 / 环境）

> 状态：Active（2026-10-21）
> 工单：[sn_kit_batch1.json](../../tools/modeling/briefs/sn_kit_batch1.json) / [sn_kit_batch2.json](../../tools/modeling/briefs/sn_kit_batch2.json) / [sn_kit_batch3.json](../../tools/modeling/briefs/sn_kit_batch3.json)
> 机器可读目录：[kit_catalog.json](../../tools/modeling/kit_catalog.json)（三批合并，含装配配方）
> 验收记录：[KIT_BATCH1_ACCEPTANCE.md](../archive/KIT_BATCH1_ACCEPTANCE.md) / [KIT_BATCH2_ACCEPTANCE.md](../archive/KIT_BATCH2_ACCEPTANCE.md) / [KIT_BATCH3_ACCEPTANCE.md](../archive/KIT_BATCH3_ACCEPTANCE.md)

## 1. 目的

把「搭船 / 搭港口场景 / 战斗演出 / 基地与海域小景」需要用到的 P0 / P1 / P2 模块抽成 **26 件可独立摆放、也可按 socket 互相拼装** 的低模资产，形成长期复用的模型素材库：

| 套件 | 资产 | 用途 |
| --- | --- | --- |
| `weapon_kit` | `SN_Weapon_Cannon`（火炮炮管总成） | 俯仰子件，插进炮架 / 炮塔 / 基座 |
| | `SN_Weapon_GunCarriage`（四轮炮架） | 接收火炮耳轴，组成完整舰炮 |
| | `SN_Weapon_Turret`（装甲回转炮塔） | 自带走炮的甲板炮塔（Heavy） |
| | `SN_Weapon_Pedestal`（武器基座） | 甲板通用回转安装点（Medium） |
| `ship_parts` | `SN_ShipPart_Deck`（甲板模块） | 8.4 × 6.0 m 母模块，带 5 个装配 socket |
| | `SN_ShipPart_Mast`（桅杆总成） | 下桅 / 桅顶瞭望台 / 上桅 / 双横桁 |
| | `SN_ShipPart_Funnel`（蒸汽烟囱） | 后倾收分烟囱 + 蒸汽管 + 4 根拉索 |
| | `SN_ShipPart_HatchCover`（货舱盖） | 双开盖板 + 铰链 Pivot + 内部格栅 |
| `machinery_kit` | `SN_Machinery_GearSet`（齿轮组） | 三级齿轮传动、动力分配 |
| | `SN_Machinery_Winch`（卷扬机） | 绳鼓 / 棘轮 / 曲柄，拉索与起重 |
| | `SN_Machinery_PowerUnit`（动力装置） | 卧式蒸汽机 + 飞轮，动力输出 |
| `cargo_kit` | `SN_Cargo_Crate`（货箱） | 可堆叠货箱 |
| | `SN_Cargo_CoalScuttle`（煤斗） | 燃料转运，含 SN_Tex_Coal 碎煤 |
| | `SN_Cargo_Tank`（储罐） | 卧式储罐 + 人孔 / 阀门 |
| | `SN_Cargo_Pallet`（托盘） | 堆码底座 |
| `dock_kit` | `SN_Dock_Structure`（码头结构） | 8.4×4.2 m 石砌岸壁模块 |
| | `SN_Dock_Jetty`（栈桥） | 8×2.6 m 木栈桥模块（桩到水下） |
| | `SN_Dock_Mooring`（系缆设施） | 双柱缆桩 + 系缆环 + 绳圈 |
| `architecture_kit` | `SN_Arch_Warehouse`（仓库） | 8×6 m 体量 + 装卸雨棚 / 吊货梁 / 滑门 |
| | `SN_Arch_Workshop`（工坊） | 8×6 m 体量 + 采光顶 + 外墙飞轮（接动力装置） |
| | `SN_Arch_Tavern`（酒馆） | 6×6 m 两层 + 门廊 / 阳台 / 悬挑招牌 |
| | `SN_Arch_Factory`（厂房） | 12×8 m 体量 + 锯齿采光顶 + 双烟囱 + 外置吊车梁 |
| `environment_kit` | `SN_Env_Reef`（礁石） | 宽平礁顶 + 4.6 m 石砌灯塔基台 + 水线上下礁石 |
| | `SN_Env_Wreck`（沉船残骸） | 倾斜断裂木船壳 + 外露肋骨 + 断桅 |
| | `SN_Env_Lighthouse`（灯塔） | 石塔 + 环廊 + 灯室 + 穹顶 |
| | `SN_Env_Buoy`（航标浮标） | 浮筒 + 灯架 + 钟 + 锚链 |

三批均为**纯资产交付**：不接游戏逻辑、不登记 Core manifest 键、不改现有船体 / 武器批次 1–2 资产。

## 2. 资产表

| 资产 | GLB | 集合 | 尺寸 X×Y×Z (m) | tri | 材质 | 基准面 / 根 |
| --- | --- | --- | --- | ---: | ---: | --- |
| `SN_Weapon_Cannon` | `assets/models/weapons/SN_Weapon_Cannon.glb` | `SN_Weapon_Cannon_Prototype` | 4.00 × 1.44 × 0.82 | **1156** | 5 | 根 = **耳轴轴心**（局部 z −0.24…0.58） |
| `SN_Weapon_GunCarriage` | `assets/models/weapons/SN_Weapon_GunCarriage.glb` | `SN_Weapon_GunCarriage_Prototype` | 2.96 × 1.79 × 1.10 | **2256** | 7 | 地面 z=0；耳轴座 z=0.62 |
| `SN_Weapon_Turret` | `assets/models/weapons/SN_Weapon_Turret.glb` | `SN_Weapon_Turret_Prototype` | 5.12 × 3.44 × 3.04 | **1904** | 6 | 甲板面 z=0；回转轴 z=0.22 |
| `SN_Weapon_Pedestal` | `assets/models/weapons/SN_Weapon_Pedestal.glb` | `SN_Weapon_Pedestal_Prototype` | 1.90 × 1.90 × 1.20 | **940** | 4 | 甲板面 z=0；领圈 z=1.10 |
| `SN_ShipPart_Deck` | `assets/models/ship_parts/SN_ShipPart_Deck.glb` | `SN_ShipPart_Deck_Prototype` | 8.40 × 6.00 × 0.36 | **576** | 4 | 底面 z=0；甲板面 z=0.33 |
| `SN_ShipPart_Mast` | `assets/models/ship_parts/SN_ShipPart_Mast.glb` | `SN_ShipPart_Mast_Prototype` | 1.77 × 6.20 × 12.84 | **2764** | 6 | 甲板面 z=0；桅顶瞭望台 z=12.16；桁 socket z=5.90 / 10.40 |
| `SN_ShipPart_Funnel` | `assets/models/ship_parts/SN_ShipPart_Funnel.glb` | `SN_ShipPart_Funnel_Prototype` | 2.40 × 2.00 × 4.66 | **1528** | 4 | 甲板面 z=0；排气口 z=4.55 |
| `SN_ShipPart_HatchCover` | `assets/models/ship_parts/SN_ShipPart_HatchCover.glb` | `SN_ShipPart_HatchCover_Prototype` | 2.72 × 2.00 × 0.49 | **840** | 6 | 甲板面 z=0；盖板铰链 z=0.40 |

批次 1 合计 **11,964 三角面**（预算 16,500），全部为闭合壳体、边界边 / 非流形边 / 退化面 / 孤立点均为 0；共享贴图 `SN_Tex_*` 外部化为 `shared_materials/<texture>.png`，每个图元都带 `TEXCOORD_0`。三批合计 **42,058 三角面 / 60,300 预算**（批次 2 13,680 / 20,600、批次 3 16,414 / 23,200）。

## 3. 坐标与命名约定

- 1 unit = 1 m；Blender `+X` 前向、`+Z` 向上；glTF 导出后 `+Y` 向上，Godot 尺寸为 (Blender X, Blender Z, Blender Y)；Godot 中前向为 `−Z`，使用时绕 Y 轴 +90°（与既有武器 / 船体约定一致）。
- 地面类部件根在底面中心（`zmin = 0`）；**火炮是例外**：根 = 耳轴轴心（`Pitch_Pivot` 在原点），便于直接插进炮架的耳轴座。
- 对象命名：`SN_<Asset>_<Part>`；空节点命名：`SN_<Asset>_<Role>`（Root / Mount / Pivot / Socket_* / Anchor_*）。
- 每件资产根下都有 `SN_<Asset>_Mount` 空节点；装配只对齐 **Root / Mount**，不对齐具体 mesh。
- Root 节点 `extras` 写机器可读字段：`asset / version / kit_family / part_role / forward / up / datum / mount_frame / base_footprint_x/y / envelope_x/y / height / tri_budget / bbox_target`，炮塔 / 基座 / 炮架 / 火炮另有 `mount_class`，甲板另有 `deck_height / module_x / module_y`。

## 4. 接口（socket）契约

> 2026-10-22 起武器部件统一为 **装配规范 v2**（见 [WEAPON_SOCKET_CONTRACT.md](WEAPON_SOCKET_CONTRACT.md)）：BLEND 工作台里节点带资产前缀（避免全局重名），**GLB 内统一为 `SN_Mount` / `SN_Pivot_Yaw` / `SN_Pivot_Pitch` / `SN_Recoil` / `SN_Muzzle` / `SN_Anchor_*` / `SN_Socket_Weapon_*`**。

| 资产 | 接口空节点（GLB 标准名） | 说明 |
| --- | --- | --- |
| Cannon | `SN_Mount`、`SN_Pivot_Pitch`、`SN_Recoil`、`SN_Muzzle`、`Trunnion_L/R`、`Breech` | 炮管/炮尾挂 `SN_Recoil`；耳轴 L/R 在 `(−0.15, ±0.62, 0)` |
| GunCarriage | `SN_Mount`、`SN_Pivot_Yaw`、`Trunnion_L/R`（z=0.62） | 接收 Cannon；`SN_Pivot_Yaw` 可做整机回转 |
| Turret | `SN_Mount`、`SN_Pivot_Yaw`（z=0.22）、`GunPort`、`SN_Muzzle`、`Hatch`、`SN_Anchor_1..4` | `Heavy` class；炮身固定（yaw_only） |
| Pedestal | `SN_Mount`、`Collar`（z=1.10）、`SN_Pivot_Yaw`（z=1.18）、`SN_Anchor_1..4` | `Medium` class，上层武器安装面 = `Collar` |
| Deck | `Mount`、`Socket_Mast`、`Socket_Funnel`、`Socket_Hatch`、`SN_Socket_Weapon_Port`、`SN_Socket_Weapon_Starboard` | 全部在甲板面 z=0.33；weapon socket 在 (±2.30, 1.10) |
| Mast | `Mount`、`Top`（z=12.60）、`Lookout`（0.50, 0, 12.16）、`Yard_Lower_Mount`（5.90）、`Yard_Upper_Mount`（10.40）、`Deadeye_Port/Starboard` | 瞭望台在桅顶，-X 侧留登台梯口 |
| Funnel | `Mount`、`Exhaust`（0.35, 0, 4.55）、`Steam_Inlet`、`Stay_1..4` | 烟囱有 0.35 m 后倾 |
| HatchCover | `Mount`、`Hinge_Fwd/Aft`、`Opening_Center`、`Lid_Pivot_Fwd/Aft` | 两片盖板分别挂在 ±1.30 的 Pivot 下，可绕 Y 开合 |

> 所有接口都是空节点，不参与几何；GLB 自检会逐个核对节点存在与 extras 字段。武器部件的节点名由 `glb_weapon_nodes.standardize()` 在导出后归一化，`gen_kit_catalog.py` 同步输出标准名。

## 5. 装配配方

### 5.1 火炮 + 炮架

```text
炮架 Root → 世界地面（z=0），+X 朝炮口
火炮 Root → 炮架 Root + (0, 0, 0.62)     # 耳轴轴心落在炮架 Trunnion_L/R
```

组成完整舰炮（`kit_assembly_gun.png`）。炮架 `SN_Pivot_Yaw` 可选做整机回转；火炮 `SN_Pivot_Pitch` 绕 Y 俯仰，`SN_Recoil` 沿 -X 后坐，`SN_Muzzle` 为炮口特效点。

### 5.2 甲板上建

```text
Deck Root → 世界位置（甲板面 z=0.33）
Mast      Root → Deck Root + Socket_Mast
Funnel    Root → Deck Root + Socket_Funnel
Hatch     Root → Deck Root + Socket_Hatch
Turret    Root → Deck Root + Socket_Weapon_Port      # z +0.33
Pedestal  Root → Deck Root + Socket_Weapon_Starboard # z +0.33
```

组成带桅杆 / 烟囱 / 货舱盖 / 炮塔 / 基座的甲板模块（`kit_assembly_deck.png`）。

### 5.3 武器基座

基座是通用回转安装点：`Collar`（z=1.10）为上层武器安装面，`Yaw_Pivot`（z=1.18）为回转轴；现有武器批次 1–2 的 Light/Medium 资产可视觉落座，不改变其几何。

## 6. 工具链

| 环节 | 命令 |
| --- | --- |
| 工单 | `tools/modeling/briefs/sn_kit_batch1.json` |
| 生成器 | `tools/modeling/generators/kit_batch1_generator.py` |
| 干跑（纯 Python） | `python tools/modeling/generators/dryrun_kit_batch1.py` |
| Blender 构建 | `runpy.run_path(.../kit_batch1_generator.py, run_name="__main__")` |
| 导出 GLB | `runpy.run_path(.../export_kit_glb.py, run_name="__main__")` |
| GLB 自检 | `python tools/modeling/generators/verify_kit_glb.py` |
| 预览渲染 | `runpy.run_path(.../render_kit_preview.py, run_name="__main__")` |
| 目录导出 | `python tools/modeling/generators/gen_kit_catalog.py` |

共享贴图：`assets/models/{weapons,ship_parts}/shared_materials/` 与 `dev_mods/core/assets/models/{weapons,ship_parts}/shared_materials/`；`shared_materials.spec.json` 的 `runtime_dirs` 已加入这两个新目录。GLB 的 `images[].uri` 是相对 URI `shared_materials/<texture>.png`，运行时 `ContentAssetLoader` 按路径共享同一个 `Texture2D`。

## 7. 预览

- [武器套件 lineup](screenshots/kits/kit_weapon_lineup.png)
- [船体部件 lineup](screenshots/kits/kit_ship_parts_lineup.png)
- [火炮 + 炮架拼装](screenshots/kits/kit_assembly_gun.png)
- [甲板 + 桅杆 + 烟囱 + 货舱盖 + 炮塔 + 基座拼装（全景）](screenshots/kits/kit_assembly_deck.png)
- [甲板模块近景（socket 拼装关系）](screenshots/kits/kit_assembly_deck_detail.png)
- 单件 3/4 与侧视：`screenshots/kits/kit_<slug>_{three_quarter,side}.png`（cannon / gun_carriage / turret / pedestal / deck / mast / funnel / hatch_cover）

## 8. 已知边界

- 本批不登记 Core manifest、不接运行时换装 / `ShipVisualAssembler`；socket 是模型侧契约，运行时装配留到后续阶段。
- 桅杆只做桅身 / 桅顶瞭望台 / 横桁 / 眼板，不含帆面与索具（已由 M0-4 `rig_kit` 交付 12 件 `SN_Rig_*`：桅杆 / 横桁 / 斜桁 / 帆杠 / 艏斜桁 / 三种帆面 / 侧支索 / 支索 / 动索，见 [RIG_KIT_CONTRACT.md](RIG_KIT_CONTRACT.md)）；烟囱不含蒸汽几何（VFX 在 Godot 侧做）。
- 火炮不带底座（根 = 耳轴），单独导入时轴心在地面以上；独立摆放需要一个承托件或把它放进炮架 / 炮塔。
- 旧纯色材质 `SN_*` 资产未迁移；本批全部是 `SN_Tex_*` 共享贴图。

## 9. 批次 2（P1）：机械 / 货物 / 码头

批次 2 新增 **10 件**，沿用批次 1 的 Mount + 语义 socket + 根 extras 契约；新增共享贴图 `SN_Tex_Coal`（512² 无缝碎煤）。

### 9.1 资产表

| 资产 | GLB | 集合 | 尺寸 X×Y×Z (m) | tri | 材质 | 基准面 / 根 |
| --- | --- | --- | --- | ---: | ---: | --- |
| `SN_Machinery_GearSet` | `assets/models/machinery/SN_Machinery_GearSet.glb` | `SN_Machinery_GearSet_Prototype` | 1.90 × 1.12 × 1.06 | **2020** | 5 | 地面 z=0；+X 动力流，齿轮轴沿 Y |
| `SN_Machinery_Winch` | `assets/models/machinery/SN_Machinery_Winch.glb` | `SN_Machinery_Winch_Prototype` | 2.24 × 1.82 × 1.42 | **1776** | 7 | 地面 z=0；鼓轴 (0,0,0.95) |
| `SN_Machinery_PowerUnit` | `assets/models/machinery/SN_Machinery_PowerUnit.glb` | `SN_Machinery_PowerUnit_Prototype` | 3.78 × 1.44 × 2.11 | **2260** | 7 | 地面 z=0；飞轮轴 (1.25,0,0.95) |
| `SN_Cargo_Crate` | `assets/models/cargo/SN_Cargo_Crate.glb` | `SN_Cargo_Crate_Prototype` | 1.26 × 1.19 × 1.04 | **672** | 8 | 地面 z=0；Stack_Top z=1.035 |
| `SN_Cargo_CoalScuttle` | `assets/models/cargo/SN_Cargo_CoalScuttle.glb` | `SN_Cargo_CoalScuttle_Prototype` | 1.48 × 1.14 × 1.10 | **588** | 8 | 地面 z=0；Fill_Top z=0.95 |
| `SN_Cargo_Tank` | `assets/models/cargo/SN_Cargo_Tank.glb` | `SN_Cargo_Tank_Prototype` | 3.37 × 1.60 × 1.95 | **1820** | 5 | 地面 z=0；罐轴 +X，z=0.95 |
| `SN_Cargo_Pallet` | `assets/models/cargo/SN_Cargo_Pallet.glb` | `SN_Cargo_Pallet_Prototype` | 1.23 × 1.02 × 0.18 | **316** | 5 | 地面 z=0；Stack_Top z=0.18 |
| `SN_Dock_Structure` | `assets/models/dock/SN_Dock_Structure.glb` | `SN_Dock_Structure_Prototype` | 8.40 × 4.46 × 3.16 | **1628** | 3 | **水线 z=0**；顶面 z=3.02；+Y 水域 |
| `SN_Dock_Jetty` | `assets/models/dock/SN_Dock_Jetty.glb` | `SN_Dock_Jetty_Prototype` | 8.03 × 2.66 × 2.80 | **1660** | 5 | **水线 z=0**；桥面 z=1.30；桩到 z=−1.30 |
| `SN_Dock_Mooring` | `assets/models/dock/SN_Dock_Mooring.glb` | `SN_Dock_Mooring_Prototype` | 1.56 × 1.15 × 0.95 | **940** | 5 | 甲板面 z=0 |

批次 2 合计 **13,680 三角面**（预算 20,600）；两批合计 **25,644 三角面 / 37,100 预算**。

### 9.2 接口

| 资产 | 接口空节点 | 说明 |
| --- | --- | --- |
| GearSet | `Mount`、`Shaft_In`（−Y, z=0.58）、`Shaft_Out`（−Y, z=0.50）、`Crank`（+Y, z=0.20） | 开式机架，±Y 侧可见 3 级齿轮 |
| Winch | `Mount`、`Drum_Pivot`（0,0,0.95）、`Rope_Out`（0.90,0,1.10）、`Brake` | 绳鼓轴沿 Y；Rope_Out 是出绳点 |
| PowerUnit | `Mount`、`Shaft_Out`（1.25,0.40,0.95，+Y 轴端）/ `Coupling`（1.25,0,0.95）、`Steam_In`（−1.55,0,1.95）、`Exhaust_Out`（−0.40,0,2.10） | 飞轮轴 +Y |
| Crate | `Mount`、`Stack_Top`（0,0,1.035）、`Lift_L/R`（±Y） | 可堆叠；Stack_Top 为盖顶提手面 |
| CoalScuttle | `Mount`、`Fill_Top`（0,0,0.95）、`Chute`（0.76,0,0.38） | 含 `SN_Tex_Coal` 煤堆 |
| Tank | `Mount`、`Fill_Top`（0.20,0,1.82）、`Outlet`（1.76,0,0.95）、`Vent`（−0.60,0,1.95） | 卧式铆接罐 |
| Pallet | `Mount`、`Stack_Top`（0,0,0.18） | 7 板条 / 3 纵梁 / 3 垫块；顶面与铁带/铜钉齐平 |
| Dock_Structure | `Mount`、`Module_Next/Prev`（±4.20,0,3.02）、`Socket_Mooring_1/2`（±2.40,0,3.02）、`Socket_Jetty`（0,2.10,1.30） | 沿 X 平铺 |
| Dock_Jetty | `Mount`、`Module_Next/Prev`（±4.00,0,1.30）、`Socket_Mooring`（2.00,0,1.30）、`Ladder`（−4.00,0,1.30） | 模块沿 X 平铺；端部爬梯在 −X 端面 |
| Dock_Mooring | `Mount`、`Bitt_Port/Starboard`（±0.42,0,0.95）、`Ring`（0,0.52,0.40）、`Rope_Tie`（−0.55,0.25,0.33） | 放码头 `Socket_Mooring_*` |

### 9.3 装配配方

- **动力链**：`PowerUnit` Shaft_Out（飞轮轴 +Y）→ `GearSet` Shaft_In（−Y 侧）→ `GearSet` Shaft_Out / Crank → `Winch` Drum_Pivot；三件 Root 都放地面，按轴高差做视觉对齐。
- **货堆**：`Crate` Root 放 `Pallet` Stack_Top（z=0.18）；货箱再用自身 Stack_Top（z=1.035）向上堆。
- **码头模块平铺**：相邻 `Dock_Structure` Root 沿 X 平移 8.40 m，`Module_Next` 与下一件 `Module_Prev` 重合；Root 放水线高度 z=0。
- **系缆设施上码头**：`Dock_Mooring` Root 对齐 `Socket_Mooring_1/2`（±2.40,0,3.02）。
- **栈桥接码头**：`Dock_Jetty` Root = 码头 Root + (0,2.10,0)，绕 Z 旋转 +90°（栈桥 +X → 码头 +Y）；桥面 z=1.30 正对 `Socket_Jetty`，桩伸到水下 z=−1.30。

### 9.4 工具链（批次 2）

| 环节 | 命令 |
| --- | --- |
| 工单 | `tools/modeling/briefs/sn_kit_batch2.json` |
| 生成器 | `tools/modeling/generators/kit_batch2_generator.py` |
| 干跑 | `python tools/modeling/generators/dryrun_kit_batch2.py` |
| Blender 构建 | `runpy.run_path(.../kit_batch2_generator.py, run_name="__main__")` |
| 导出 GLB | `runpy.run_path(.../export_kit_batch2_glb.py, run_name="__main__")` |
| GLB 自检 | `python tools/modeling/generators/verify_kit_batch2_glb.py` |
| 预览渲染 | `runpy.run_path(.../render_kit_batch2_preview.py, run_name="__main__")` |

共享贴图运行时副本新增 `assets/models/{machinery,cargo,dock}/shared_materials/` 与对应 Core 目录；`SN_Tex_Coal` 由 `tools/art/gen_shared_material_textures.py` 生成。

### 9.5 预览

- [机械 lineup](screenshots/kits/kit_machinery_lineup.png)
- [货物 lineup](screenshots/kits/kit_cargo_lineup.png)
- [码头 lineup](screenshots/kits/kit_dock_lineup.png)
- [码头 + 栈桥 + 系缆 + 货箱拼装](screenshots/kits/kit_assembly_dock.png) / [近景](screenshots/kits/kit_assembly_dock_detail.png)
- 单件 3/4 与侧视：`kit_<slug>_{three_quarter,side}.png`（gearset / winch / power_unit / crate / coal_scuttle / tank / pallet / dock_structure / jetty / mooring）

### 9.6 批次 2 边界

- 机械轴系只提供语义 socket 与尺寸约定，不强制机械耦合（不写动画 / 联动逻辑）。
- 煤堆使用新增 `SN_Tex_Coal`；若后续内容包体积敏感，可按需共享贴图。
- 码头件 Root 在水线 / 甲板面，栈桥桩在水下（zmin=−1.30）；场景摆放时把 Root 放到水面高度，不要按 zmin=0 落地。
- 本批同样不登记 manifest、不接运行时装配。

## 10. 批次 3（P2）：建筑 / 环境

批次 3 新增 **8 件**：建筑 4（仓库 / 工坊 / 酒馆 / 厂房）+ 环境 4（礁石 / 残骸 / 灯塔 / 航标浮标）。沿用 Mount + 语义 socket + 根 extras 契约，新增 `module_x / module_y`（建筑平铺）与 `waterline`（环境水线）两个机器可读字段；**不新增贴图**，沿用 11 张 `SN_Tex_*`。

### 10.1 资产表

| 资产 | GLB | 集合 | 尺寸 X×Y×Z (m) | tri | 材质 | 基准面 / 根 |
| --- | --- | --- | --- | ---: | ---: | --- |
| `SN_Arch_Warehouse` | `assets/models/architecture/SN_Arch_Warehouse.glb` | `SN_Arch_Warehouse_Prototype` | 10.95 × 6.95 × 6.35 | **2704** | 8 | 地面 z=0；体量 8×6 居根；+X 装卸立面 |
| `SN_Arch_Workshop` | `assets/models/architecture/SN_Arch_Workshop.glb` | `SN_Arch_Workshop_Prototype` | 9.32 × 6.63 × 7.04 | **1996** | 9 | 地面 z=0；−Y 外墙飞轮（Drive_Shaft） |
| `SN_Arch_Tavern` | `assets/models/architecture/SN_Arch_Tavern.glb` | `SN_Arch_Tavern_Prototype` | 8.67 × 6.96 × 7.64 | **2884** | 9 | 地面 z=0；体量 6×6；门廊 + 台阶在 +X |
| `SN_Arch_Factory` | `assets/models/architecture/SN_Arch_Factory.glb` | `SN_Arch_Factory_Prototype` | 14.74 × 8.30 × 9.64 | **3020** | 8 | 地面 z=0；体量 12×8；吊车梁 + 平台在 +X |
| `SN_Env_Reef` | `assets/models/environment/SN_Env_Reef.glb` | `SN_Env_Reef_Prototype` | 7.13 × 6.44 × 5.52 | **1944** | 3 | **水线 z=0**；礁石到 −3.0；石砌灯塔基台顶 z=2.48 |
| `SN_Env_Wreck` | `assets/models/environment/SN_Env_Wreck.glb` | `SN_Env_Wreck_Prototype` | 8.62 × 3.96 × 4.72 | **1046** | 7 | **水线 z=0**；船底到 −1.50；船体绕 X 横倾 13° |
| `SN_Env_Lighthouse` | `assets/models/environment/SN_Env_Lighthouse.glb` | `SN_Env_Lighthouse_Prototype` | 4.62 × 4.60 × 13.16 | **1952** | 7 | 基座底面 z=0；塔轴 Z；门在 +X |
| `SN_Env_Buoy` | `assets/models/environment/SN_Env_Buoy.glb` | `SN_Env_Buoy_Prototype` | 1.88 × 1.88 × 3.84 | **868** | 5 | **水线 z=0**；吃水裙到 −0.74 |

批次 3 合计 **16,414 三角面**（预算 23,200），全部闭合壳体、网格健康四项全 0；GLB 贴图全部外部化为 `shared_materials/<texture>.png`。

### 10.2 接口

| 资产 | 接口空节点 | 说明 |
| --- | --- | --- |
| Warehouse | `Mount`、`Module_Next/Prev`（±4.00,0,0）、`Door_Front`（4.00,−1.60,0）、`Hoist`（6.30,−1.45,3.98）、`Sign`（4.05,−1.60,4.50） | 滑门 / 装卸雨棚 / 吊货梁 / 招牌 |
| Workshop | `Mount`、`Module_Next/Prev`（±4.00,0,0）、`Door_Front`（4.00,0,0）、`Drive_Shaft`（−1.00,−3.08,1.45）、`Chimney`（−2.80,−2.20,7.00） | Drive_Shaft = 外墙飞轮轴，可对 `PowerUnit` Shaft_Out |
| Tavern | `Mount`、`Module_Next/Prev`（±3.00,0,0）、`Door_Front`（3.00,0,0）、`Sign`（5.00,1.80,3.05）、`Chimney`（−2.40,−2.20,7.60） | 门廊入口 / 悬挑招牌 / 烟囱 |
| Factory | `Mount`、`Module_Next/Prev`（±6.00,0,0）、`Door_Front`（6.00,0,0）、`Gantry`（8.35,0,7.05）、`Chimney`（−5.00,2.80,9.60） | Gantry = 吊车梁下吊点 |
| Reef | `Mount`、`Top`（0.60,−0.40,2.48）、`Mooring_Ring`（1.80,2.36,0.92） | Top = 灯塔落座面（4.6 m 基座完整覆盖） |
| Wreck | `Mount`、`Deck`（−2.00,−0.15,0.60）、`Mast`（0.90,−0.13,0.53） | Deck 可站立甲板；Mast 为断桅接口（桅穿过龙骨） |
| Lighthouse | `Mount`、`Door`（1.50,0,0.90）、`Gallery`（1.60,0,9.80）、`Lamp`（0,0,10.60） | Lamp 为灯室光源点、Gallery 为环廊站位 |
| Buoy | `Mount`、`Lamp`（0,0,2.65）、`Bell`（0,−0.45,1.85）、`Chain`（0.55,0,0.35） | 灯 / 钟 / 锚链接口 |

### 10.3 装配配方

- **建筑街区**：Root 全部 z=0；相邻建筑 `Module_Next/Prev` 对齐，间距 = 体量 X 长（仓库 8.00 / 工坊 8.00 / 酒馆 6.00 / 厂房 12.00）；正面 +X 同向，把整排绕 Z 旋转 90° 即正面朝街；雨棚 / 门廊 / 吊车梁仍在各自模块内。
- **灯塔落在礁石 Top**：礁石 Root 放水线 z=0；灯塔 Root = 礁石 Root + (0.60,−0.40,2.48)；礁石石砌压顶（circumradius 2.66）完整覆盖灯塔基座（circumradius 2.488），16 个采样点 0 gap / 0 外挑。
- **海岸小景**：礁石 + 残骸 + 浮标 Root 都在水线 z=0；残骸在礁石 +X 侧 6–9 m、可绕 Z 旋转 20–30°；浮标放航道侧。
- **工坊动力接口**：把 `PowerUnit` 的 `Shaft_Out` 对准工坊 `Drive_Shaft`（−1.00,−3.08,1.45），形成外墙飞轮与蒸汽机的同轴视觉关系。
- **堆叠 / 通行**：礁石 `Top` 也可放残骸或后续 `environment_kit` 件；残骸 `Deck` / `Mast` 留给登船探索与断桅修补。

### 10.4 工具链（批次 3）

| 环节 | 命令 |
| --- | --- |
| 工单 | `tools/modeling/briefs/sn_kit_batch3.json` |
| 生成器 | `tools/modeling/generators/kit_batch3_generator.py` |
| 干跑 | `python tools/modeling/generators/dryrun_kit_batch3.py` |
| Blender 构建 | `runpy.run_path(.../kit_batch3_generator.py, run_name="__main__")` |
| 导出 GLB | `runpy.run_path(.../export_kit_batch3_glb.py, run_name="__main__")` |
| GLB 自检 | `python tools/modeling/generators/verify_kit_batch3_glb.py` |
| 预览渲染 | `runpy.run_path(.../render_kit_batch3_preview.py, run_name="__main__")` |
| 目录导出 | `python tools/modeling/generators/gen_kit_catalog.py`（合并三批） |

共享贴图运行时副本新增 `assets/models/{architecture,environment}/shared_materials/` 与对应 Core 目录；本批不新增贴图。

### 10.5 预览

- [建筑 lineup](screenshots/kits/kit_architecture_lineup.png)
- [环境 lineup](screenshots/kits/kit_environment_lineup.png)
- [仓库 + 工坊 + 酒馆 + 厂房街区拼装](screenshots/kits/kit_assembly_town.png) / [近景](screenshots/kits/kit_assembly_town_detail.png)
- [礁石 + 灯塔 + 残骸 + 浮标海岸拼装](screenshots/kits/kit_assembly_coast.png) / [灯室近景](screenshots/kits/kit_assembly_coast_detail.png)
- 单件 3/4 与侧视：`kit_<slug>_{three_quarter,side}.png`（warehouse / workshop / tavern / factory / reef / wreck / lighthouse / buoy）

### 10.6 批次 3 边界

- 建筑是**可拼装体量 + 立面节奏**，不做室内（无楼板 / 家具 / 隔墙）；室内留给后续设施与 `machinery_kit` 摆放。
- 环境件是**可复用单体**：礁石不生成程序化岛链、残骸不带动画、灯塔灯室只给 `Lamp` 接口（光束 / VFX 在 Godot 侧做）。
- 环境件 Root 在水线，礁石 / 残骸 / 浮标有水下部分；场景摆放时把 Root 放到水面高度，不要按 zmin=0 落地。
- 建筑 `Module_Next/Prev` 只约定位移（X 方向体量边），不做自动吸附 / 碰撞；本批同样不登记 manifest、不接运行时装配。
