# 船体帆索部件库契约（`rig_kit`，M0-4）

> 状态：Active（2026-10-22）
> 工单：[sn_rig_kit_batch1.json](../../tools/modeling/briefs/sn_rig_kit_batch1.json)
> 机器可读目录：[rig_kit_catalog.json](../../tools/modeling/rig_kit_catalog.json)
> 验收记录：[RIG_KIT_ACCEPTANCE.md](../archive/RIG_KIT_ACCEPTANCE.md)
> 相关：[WEAPON_SOCKET_CONTRACT.md](WEAPON_SOCKET_CONTRACT.md) · [KIT_ASSET_LIBRARY.md](KIT_ASSET_LIBRARY.md) · [MODELING_WORKFLOW.md](MODELING_WORKFLOW.md) §11.18

## 1. 目的

把原先焊死在船体生成器里的**桅杆 / 横桁 / 斜桁 / 帆杠 / 艏斜桁 / 帆面 / 索具**收敛成
一套参数化部件库 `rig_kit`，并交付两类产物：

1. **12 件独立套件资产** `SN_Rig_*`（可单独摆放、按 socket 拼装，3,774 tri）；
2. **3 艘船改用同一份源码生成**：明轮货轮 `SN_Paddle_Freighter`、纵帆船
   `SN_Schooner_Fame`、铁甲舰 `SN_Ironclad` 的帆索几何不再各自维护，而是调用
   `rig_kit.py` 的部件函数；**逐对象顶点 / 面 digest 与重构前完全一致**。

本批**不做运行时换装**：船体 GLB 内仍然只有“焊死”的帆索网格 + 空接口节点；
运行时的 `ShipVisualAssembler` / 布料风动留待后续批次（见 §8）。

## 2. 套件资产表（12 件）

| 资产 | 用途 | 尺寸 X×Y×Z (m) | tri | datum（Root 原点） |
| --- | --- | --- | ---: | --- |
| `SN_Rig_Mast_Sail` | 帆船桅杆（下桅/顶桅/上桅、桅顶平台、横担、帆箍、顶珠） | 1.87 × 2.90 × 21.50 | **448** | 桅座甲板 `z=0`，+Z 向上 |
| `SN_Rig_Mast_Steam` | 蒸汽船桅杆（下桅/上桅、桅帽、铁箍、桅冠） | 0.72 × 0.72 × 11.18 | **144** | 桅座甲板 `z=0` |
| `SN_Rig_Yard` | 横桁 + 收帆卷 + 两端铁帽 | 0.48 × 6.94 × 0.48 | **72** | 桁中心 `(0,0,0)`，桁沿 Y |
| `SN_Rig_Gaff` | 斜桁（收分 + 桅杆夹钳 + 黄铜箍） | 5.46 × 0.50 × 2.06 | **72** | 夹钳/跟部在原点，peak 朝 +X |
| `SN_Rig_Boom` | 帆杠（收分 + 夹钳 + 黄铜箍） | 6.24 × 0.50 × 0.52 | **72** | tack/夹钳在原点，clew 朝 +X |
| `SN_Rig_Bowsprit` | 艏斜桁 + 绑扎铁箱 + 端部铁帽 + 甲板安装块 | 4.52 × 0.52 × 2.65 | **72** | 甲板安装点 `z=0`，桁朝 +X 上翘 |
| `SN_Rig_Sail_Gaff` | 斜桁帆（帆腹/5 道帆缝/主缩帆带/4 条帆缘绳） | 5.98 × 0.64 × 8.24 | **756** | 帆脚 tack 在原点 |
| `SN_Rig_Sail_Square` | 方帆（帆腹/2 道帆缝/4 条帆缘绳） | 0.62 × 6.04 × 5.64 | **624** | 帆脚中心在原点，帆顶朝 +Z |
| `SN_Rig_Sail_Jib` | 艏三角帆（帆腹/5 道帆缝/3 条帆缘绳） | 5.04 × 0.47 × 7.24 | **578** | tack 在原点 |
| `SN_Rig_Shrouds` | 左右各 4 根侧支索 + 9 道绳梯 + 8 块甲板链板 | 2.59 × 2.55 × 7.26 | **568** | 甲板链板 `z=0` |
| `SN_Rig_Stays` | 4 根前后支索 + 桅顶眼板 + 4 套花篮螺栓 + 4 块甲板眼板 | 9.00 × 2.94 × 7.26 | **188** | 甲板眼板 `z=0` |
| `SN_Rig_Running` | 5 根动索 + 3 组滑车 + 2 个甲板羊角 | 5.09 × 6.83 × 7.22 | **180** | 甲板羊角 `z=0` |

合计 **3,774 tri / 7,050 预算**。全部资产：

- 材质只用共享贴图 `SN_Tex_*`（Wood / Wood_Dark / Wood_Deck / Metal / Iron / Brass /
  Canvas_Shade），GLB `images[].uri` 外部化为 `shared_materials/<texture>.png`；
- 桅、桁、索具是闭合壳体；**帆面是单层开放曲面 + `doubleSided` 材质**（`closed=false`），
  干跑允许边界边、其他健康项仍必须为 0；
- 每件 Root 下唯一一个 `SN_Mount`，其余为 `SN_Socket_*` 空节点。

## 3. 单位、坐标与 GLB

- 1 unit = 1 m；Blender `+X` 前向、`+Z` 向上；glTF 导出 `+Y` 向上，
  世界尺寸映射为 `(Blender X, Blender Z, Blender Y)`；
- 套件按 §2 的 datum 摆放；船体侧 socket 坐标 = **船体坐标**（Root 在工作台的摆位不影响）；
- 对象命名 `SN_Rig_<Part>_Body` / 网格名带资产前缀；接口节点在 BLEND 内带前缀
  （如 `SN_Rig_Mast_Sail_Socket_Yard_Lower`），GLB 导出后由 `glb_rig_kit.standardize()`
  归一化为标准名（避免同一 Blender 工作台全局重名与 `.001`）。

## 4. 接口契约

### 4.1 标准名（GLB）

| 标准名 | 语义 | 出现位置 |
| --- | --- | --- |
| `SN_Mount` | 部件自身的装配挂点（Root 原点，+X 前向 / +Z 向上） | 每件套件资产 |
| `SN_Socket_Mast_*` | **船体上的桅杆安装点**；`*` = `Fore` / `Main` / `Mizzen` | 3 艘船的 GLB |
| `SN_Socket_Yard_*` | 横桁 / 斜桁安装点（桅上的桁位）；`*` = 桅键或 `Fore_Lower` 等 | 套件桅杆 / 船体 |
| `SN_Socket_Sail_*` | 帆面挂点；后缀 `Head` / `Peak` / `Tack` / `Clew` / `Jib_Tack` | 套件桅杆/桁/帆 / 船体 |

> 说明：`SN_Socket_Mast_*` 是**船体侧**的接收点（桅杆 Root 的 `SN_Mount` 对齐到这里）；
> 桅杆资产本身不会再提供 `SN_Socket_Mast`，而是提供 `SN_Socket_Yard_*` / `SN_Socket_Sail_*`。
> 三者共同构成 backlog 里的 `SN_Socket_Mast/Yard/Sail` 接口族。

### 4.2 套件接口表

| 资产 | 接口节点（GLB 标准名） |
| --- | --- |
| `SN_Rig_Mast_Sail` | `SN_Mount`、`SN_Socket_Yard_Lower`、`SN_Socket_Yard_Upper`、`SN_Socket_Sail_Head`、`SN_Socket_Sail_Tack`、`SN_Socket_Deadeye_Port` / `SN_Socket_Deadeye_Starboard` |
| `SN_Rig_Mast_Steam` | `SN_Mount`、`SN_Socket_Yard`、`SN_Socket_Stay_Fore`、`SN_Socket_Stay_Aft` |
| `SN_Rig_Yard` | `SN_Mount`、`SN_Socket_Sail`、`SN_Socket_Brace_Port` / `SN_Socket_Brace_Starboard` |
| `SN_Rig_Gaff` | `SN_Mount`、`SN_Socket_Sail_Peak`、`SN_Socket_Halyard` |
| `SN_Rig_Boom` | `SN_Mount`、`SN_Socket_Sail_Clew`、`SN_Socket_Sheet` |
| `SN_Rig_Bowsprit` | `SN_Mount`、`SN_Socket_Jib_Tack`、`SN_Socket_Stay_Fore` |
| `SN_Rig_Sail_Gaff` | `SN_Mount`、`SN_Socket_Sail_Head`、`SN_Socket_Sail_Peak`、`SN_Socket_Sail_Clew` |
| `SN_Rig_Sail_Square` | `SN_Mount`、`SN_Socket_Yard`、`SN_Socket_Sheet_Port` / `SN_Socket_Sheet_Starboard` |
| `SN_Rig_Sail_Jib` | `SN_Mount`、`SN_Socket_Sail_Head`、`SN_Socket_Sail_Clew` |
| `SN_Rig_Shrouds` | `SN_Mount`、`SN_Socket_Mast_Top`、`SN_Socket_Chainplate_Port` / `SN_Socket_Chainplate_Starboard` |
| `SN_Rig_Stays` | `SN_Mount`、`SN_Socket_Mast_Top`、`SN_Socket_Bowsprit_Tip` |
| `SN_Rig_Running` | `SN_Mount`、`SN_Socket_Mast_Top`、`SN_Socket_Sail_Clew` |

接口节点全部是无 mesh 的空节点；每个节点 extras 至少写
`socket_spec = "rig-sockets@1"`、`socket_role`；船体侧 socket 另写
`socket_kind`（mast/yard/sail）、`mast_key`。

### 4.3 Root extras

套件 Root（`SN_Rig_<Part>_Root`）：

| 字段 | 说明 |
| --- | --- |
| `asset` / `version` / `units` / `forward` / `up` | 资产标识与坐标约定 |
| `kit_family = "rig_kit"` / `part_role` / `type` | 部件族与角色 |
| `datum` / `mount_frame` | 装配基准说明 |
| `base_footprint_x/y` + `footprint_kind` | 甲板占地；帆/桁/索具为 `none`（0.0） |
| `envelope_x/y` / `height` / `bbox_target` / `tri_budget` | 尺寸与预算 |
| `rig_spec = "rig-kit@1"` | 部件库版本 |
| `rig_sockets` / `rig_socket_count` / `rig_socket_spec` | socket 名单与数量（**仅 GLB JSON 层写入**；Blender IDProperty 不支持字符串数组，BLEND Root 只有源字段 `socket_count` / `socket_spec`） |
| 角色字段 | 桅杆 `mast_class` / `mast_height`；桁 `yard_length` / `stowed`；帆 `sail_area_m2` / `cloth` 等 |

船体 Root 额外写 `rig_sockets` / `rig_socket_count = 该船 socket 数`（PF 6 / SF 7 / IC 9，
三船合计 22）/ `rig_socket_spec`，与既有 `weapon_sockets` 并存。

### 4.4 船体侧 socket（22 个，零几何）

坐标 = 船体坐标（Root 在工作台的摆位不影响），`z` 为该点甲板实测高度：

| 船 | socket | 局部坐标 (x, y, z) |
| --- | --- | --- |
| `SN_Paddle_Freighter` | `SN_Socket_Mast_Fore` | (22.80, 0, 4.40) |
| | `SN_Socket_Yard_Fore` | (23.10, 0, 12.80) |
| | `SN_Socket_Sail_Fore` | (23.10, 0, 12.71) |
| | `SN_Socket_Mast_Main` | (−23.80, 0, 4.10) |
| | `SN_Socket_Yard_Main` | (−23.50, 0, 13.60) |
| | `SN_Socket_Sail_Main` | (−23.50, 0, 13.51) |
| `SN_Schooner_Fame` | `SN_Socket_Mast_Fore` | (4.60, 0, 2.575) |
| | `SN_Socket_Mast_Main` | (−1.80, 0, 2.608) |
| | `SN_Socket_Yard_Fore` | (3.945, 0, 17.571) |
| | `SN_Socket_Yard_Main` | (−2.328, 0, 12.044) |
| | `SN_Socket_Sail_Fore` | (4.532, 0, 4.124) |
| | `SN_Socket_Sail_Main` | (−1.887, 0, 4.156) |
| | `SN_Socket_Sail_Jib` | (5.55, 0, 4.20) |
| `SN_Ironclad` | `SN_Socket_Mast_Fore/Main/Mizzen` | (15/−10/−20, 0, 4.60) |
| | `SN_Socket_Yard_Fore/Main/Mizzen` | (15/−10/−20, 0, 13.8/14.4/12.6) |
| | `SN_Socket_Sail_Fore/Main/Mizzen` | (15/−10/−20, 0, 13.54/14.14/12.34) |

明轮客船 `SN_Paddle_Steamer` 无桅帆索（只有旗杆），本批不建 socket。

每条船侧 socket 的 extras（数值字段统一带 `rig_` 前缀，避免与 `socket_kind` /
`mast_key` / `socket_index` 混淆）：`socket_kind`、`mast_key`、`socket_index`、
`socket_spec`；桅点另有 `rig_height` / `rig_deck_z`，桁点 `rig_yard_z` /
`rig_yard_length` / `rig_stowed`，帆点 `rig_yard_z` / `rig_sail_area_m2` /
`rig_stowed`。`rig_yard_z` 统一为**船体坐标 z**（与 socket `local[2]` 相同；SF 后倾船的
桅局部高度不写在该字段），`rig_height` 是桅顶相对甲板的高度。

## 5. 装配关系

```text
船体 Root
  └─ SN_Socket_Mast_Fore（空节点）
       ← SN_Rig_Mast_Sail.Root：SN_Mount 对齐 socket（+Z 向上）
            ├─ SN_Socket_Yard_Lower ← SN_Rig_Yard.Root：SN_Mount（桁沿 Y）
            │     └─ SN_Socket_Sail      ← SN_Rig_Sail_Square.Root：SN_Mount
            ├─ SN_Socket_Yard_Upper ← SN_Rig_Gaff.Root：SN_Mount
            │     └─ SN_Socket_Sail_Peak ← SN_Rig_Sail_Gaff.Root：SN_Mount
            └─ SN_Socket_Deadeye_*  ← SN_Rig_Shrouds.Root：SN_Socket_Mast_Top
```

- 桅杆 / 艏斜桁 / 索具按甲板点落座；横桁、帆、桁按各自的 `SN_Mount` 对齐到上游 socket；
- 帆面是单层双面网格，模型侧只交付静态形状；风动/布料留给 Godot 侧（§8）；
- 本批 **不要求** 运行时真的执行这些装配：socket 是模型侧契约，`rig_kit_catalog.json`
  是机器可读的装配数据源。

## 6. 参数化部件库与船体替换

`tools/modeling/generators/rig_kit.py`（纯 Python，不 import bpy）分层：

| 层 | 内容 |
| --- | --- |
| `RigBuilder` | Part 适配器：统一 `add(vf, material)`，兼容 SF/PF 的 `add(vf, mat)` 与铁甲舰的 `add(verts, faces, mat)`（`legacy=True`）；基本体由调用方模块提供，保证逐位一致 |
| 通用积木 | `rope / ropes / spar / spar_jaws / brass_band / block` |
| 帆面 | `quad_surface / tri_surface / square_surface / gaff_sail / tri_sail / square_sail`（帆腹、帆缝、缩帆带、帆缘绳） |
| 船型部件 | `schooner_mast / schooner_spars / schooner_headsails / schooner_standing_rigging / schooner_running_rigging`、`steamer_mast / steamer_yard / steamer_bowsprit / steamer_rigging`、`ironclad_masts / ironclad_rigging / ironclad_flag` |
| 独立套件 | `rig_kit_batch1_generator.py` 用同一批函数 + 套件参数生成 12 件 GLB |

船型生成器只保留**布局**（桅位、后倾、帆角、锚点），几何全部调用 `rig_kit`：

| 船 | 替换的生成器函数 |
| --- | --- |
| PF | `build_mast` / `build_yards` / `build_bowsprit` / `build_rigging` |
| SF | `build_masts_local` / `build_spars_local` / `build_sails_local` / `build_headsails_world` / `build_standing_rigging_world` / `build_running_rigging_world` |
| IC | `build_masts` / `build_rigging` |

**几何不变量**：`rig_kit_baseline.py --compare` 逐对象比较 `verts/faces/tri/parent/材质/
bbox/SHA-256`，重构前后必须 3/3 `SAME`。当前基线（`.design/rig_kit/baseline_*.json`）：
PF 39 对象 / 12,200 tri；SF 28 / 12,994（**纯帆索几何基线**；整船场景 / GLB 为
29 mesh / 13,174 tri，多出的 `SN_SF_Nameplate` 是既有文字铭牌，不属于 rig_kit）；
IC 1 / 8,830。

## 7. 生产链与验收

| 环节 | 命令 / 文件 |
| --- | --- |
| 工单 | `tools/modeling/briefs/sn_rig_kit_batch1.json` |
| 部件库 | `tools/modeling/generators/rig_kit.py` |
| 套件生成器 | `tools/modeling/generators/rig_kit_batch1_generator.py` |
| 材质视图 | `tools/modeling/generators/sn_rig_materials.py` |
| 干跑（纯 Python） | `python tools/modeling/generators/dryrun_rig_kit.py` |
| 船体几何基线 | `python tools/modeling/generators/rig_kit_baseline.py --capture/--compare` |
| 船侧 socket | `tools/modeling/generators/sn_ship_rig_sockets.py`（`--check` 纯 Python；Blender 内 `apply_all()`） |
| GLB 归一化 | `glb_rig_kit.py`（套件）/ `glb_ship_rig_sockets.py`（船体） |
| 导出 | `export_rig_kit_glb.py`（12 件）/ `export_ship_weapon_sockets_glb.py`（4 艘船） |
| GLB 自检 | `verify_rig_kit_glb.py`（12/12）/ `verify_ship_weapon_sockets_glb.py`（4/4，含 rig socket） |
| 目录 | `python tools/modeling/generators/gen_rig_kit_catalog.py` → `tools/modeling/rig_kit_catalog.json` |
| Godot 回归 | `framework/tests/cases/test_rig_kit.gd` + `test_ship_weapon_sockets.gd` |

Blender 构建顺序（Builder 执行，单写者）：
`build_all_assets()`（12 件）→ 重建 PF/SF/IC → `sn_ship_weapon_sockets.apply_all()` →
`sn_ship_rig_sockets.apply_all()` → `sn_legacy_uv_migration.migrate_all_b(("ships",))`
→ 只读复核。几何重建后必须重跑批次 B 材质/UV 迁移，否则会退回旧纯色材质。

## 8. 已知边界 / 后续

1. **运行时装配未接入**：`ShipVisualAssembler`（按 `rig_kit_catalog.json` 把 `SN_Rig_*`
   装到船体 socket）仍是 todo 独立条目；本批只交付资产、socket 与目录。
2. **帆面是静态低模**：无布料/顶点风动；后续可在 Godot 侧用顶点着色器或 `SoftBody`，
   模型侧保留 `SN_Socket_Sail_*` 四角挂点与单层拓扑。
3. **帆船三角顶帆的 `Sail_Main` 点**：当前 `SN_Socket_Sail_Main` 用帆脚 tack 位置，
   主桅上还有三角顶帆（未单独建点），需要逐面装配时再细分 `SN_Socket_Sail_Main_Top`。
4. **明轮客船无帆索**：不建 rig socket；`SN_Socket_Mast` 族只覆盖 PF/SF/IC。
5. **LOD**：12 件套件暂无 LOD1；远景低模属 backlog M0-5。
6. **武器底座字段 F1** 与 rig_kit 无关，仍按 [WEAPON_SOCKET_CONTRACT.md](WEAPON_SOCKET_CONTRACT.md) §7.5
   以网格实测为准。

## 9. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-22 | 建立契约：12 件套件 + 3 艘船参数化替换 + 22 个船体侧 socket；`rig_kit_catalog.json` v1.0 |
