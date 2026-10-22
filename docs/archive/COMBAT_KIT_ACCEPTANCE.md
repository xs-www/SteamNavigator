# `combat_kit` 敌舰（M2-1）验收记录

> 批次：9（2026-10-22）｜工单：[`sn_combat_kit_batch1.json`](../../tools/modeling/briefs/sn_combat_kit_batch1.json)
> 生成器：[`combat_kit_generator.py`](../../tools/modeling/generators/combat_kit_generator.py)｜机器目录：[`combat_kit_catalog.json`](../../tools/modeling/combat_kit_catalog.json)
> 契约：[WEAPON_SOCKET_CONTRACT.md §11](../../docs/design/WEAPON_SOCKET_CONTRACT.md)（甲板 socket §8 / 炮门 §9）
> 相关：[KIT_ASSET_LIBRARY.md §14](../../docs/design/KIT_ASSET_LIBRARY.md) · [MODELING_WORKFLOW.md §11.22](../../docs/design/MODELING_WORKFLOW.md) · [MODELING_BACKLOG.md §1](../../docs/design/MODELING_BACKLOG.md)

## 1. 范围

阶段 2 自动战斗需要「3 类敌人」。本批交付 **4 艘敌舰 / 3 类敌人**（Light ×2 / Medium ×1 / Heavy ×1），
复用现有船体骨架（同一套「横剖面站 + 剖面轮廓」放样）与 `rig_kit` / `ship_parts` 部件库，
**不新增贴图、不烘炮**：

| 资产 | 类别 | archetype | tri / 预算 | mesh | 节点 | 武器 socket | 炮门 socket | GLB |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| `SN_Enemy_Pirate_Sloop` | Light | `pirate_sloop` | 8 678 / 9 000 | 15 | 20 | 3 | 0 | 620 424 B |
| `SN_Enemy_Merchant_Armed` | Medium | `armed_merchantman` | 11 746 / 12 000 | 18 | 27 | 6 | 0 | 828 600 B |
| `SN_Enemy_Ironclad_Raider` | Heavy | `ironclad_raider` | 7 440 / 7 800 | 12 | 25 | 4 | 8 | 532 268 B |
| `SN_Enemy_Gunboat` | Light | `gunboat` | 3 460 / 3 600 | 10 | 14 | 3 | 0 | 254 488 B |
| **合计** | **3 类** | | **31 324 / 32 400** | **55** | **86** | **16** | **8** | **2 235 780 B** |

## 2. 交付物

| 类别 | 文件 |
| --- | --- |
| 运行时 GLB | `assets/models/combat/SN_Enemy_*.glb`（4）+ `dev_mods/core/assets/models/combat/` 同名副本 |
| 共享贴图 | `assets/models/combat/shared_materials/` 与 Core 副本各 11 张 PNG（每艘 GLB 外部引用 8 张；无新增贴图） |
| 面板 / 材质 | `shared_materials.spec.json` 的 `runtime_dirs` 追加 `combat` 两条；材质全部 `SN_Tex_*` |
| 生成 / 工具 | `combat_kit_generator.py` / `dryrun_combat_kit.py` / `sn_enemy_weapon_sockets.py` / `sn_enemy_gun_ports.py` / `glb_enemy_sockets.py` / `export_combat_kit_glb.py` / `verify_combat_kit_glb.py` / `render_combat_kit_preview.py` / `gen_combat_kit_catalog.py` |
| 目录 | `tools/modeling/combat_kit_catalog.json`（schema `steam-navigator/combat-kit@1`） |
| Godot 守护 | `framework/tests/cases/test_combat_kit_assets.gd`（注册于 `test_runner.gd`） |
| 预览 | `.design/combat/preview/` 8 张单件 3/4 + side（本地产物）与 `docs/design/screenshots/combat/combat_lineup.png` |
| 工作台 | `.design/SN_Asset_Workbench.blend`（4 个 `SN_Enemy_*_Prototype` 集合，y=-110 空走廊；导出脚本保存） |

## 3. 验收证据

| 环节 | 结果 |
| --- | --- |
| 纯 Python 干跑 | `python tools/modeling/generators/dryrun_combat_kit.py` → **4 ships / 31 324 tri / classes ['Heavy','Light','Medium'] ALL OK**（命名 / 父级 / 含 Pivot 变换的 bbox / 网格健康 / 材质白名单 / socket + 炮门契约） |
| Builder R0 | 4 集合 / 62 对象（55 mesh + 7 empty）/ 31 324 tri；逐艘 bbox 与 target 最大偏差 **0.031 m**（容差 0.9 m）；网格健康四项全 0；材质全 `SN_Tex_*`、UV loops == loops；非本批 983 对象名 SHA-256 与基线逐位一致；Camera=2 / Light=1 |
| 工作台摆位（R1–R3） | R1 y=240 消除 AABB 交叠；R3 整排挪到 y=-110，AABB 与既有对象零交叠、4 艘 3/4 + 正视无遮挡；三次重建 tri / bbox / UV / 材质逐位不变 |
| socket 落盘（M0-3 / M0-6 复用） | `APPLY_WEAPON` / `APPLY_GUNPORT` / `VERIFY_WEAPON` / `VERIFY_GUNPORT` **全 passed，0 failures**；16 武器 socket + 8 炮门 socket，均为 EMPTY、无 data、父级 / extras / Root count 全对；apply 前后 mesh / tri 不变；objects 1045 → **1069** |
| GLB 导出 | 4 个 GLB 节点 20 / 27 / 25 / 14（合计 86）、图元 36 / 46 / 33 / 26（合计 141）；images 各 8 张 `shared_materials/<texture>.png`；assets 与 Core 逐字节一致；合计 **2 235 780 B**；旧 GLB 备份在 `.design/combat/backup_glb/`；glTF `scenes[].extras` 已剥掉 MCP 会话元数据；工作台保存 |
| GLB 验收 | `python tools/modeling/generators/verify_combat_kit_glb.py` → **4/4 ALL OK**（tri / 世界 bbox（含轴心）/ 每图元 TEXCOORD_0 / 材质 doubleSided / 外部 PNG 与授权 tile 逐字节一致 / 双副本 / root extras / socket 坐标 `(x, z, -y)` 与 extras） |
| 机器目录 | `python tools/modeling/gen_combat_kit_catalog.py` → assets=4 / tri=31 324 / objects=55 / sockets=16 / gun_ports=8 |
| Godot 运行时 | `test_combat_kit_assets.gd`：**5 例全 PASS**（4 GLB 加载 / 31 324 tri / UV + 共享贴图 / root extras + 武器 socket / 铁甲舰 8 炮门）；全量 headless 见 §5 |
| 独立 Verifier | 只读复核（场景 + GLB + 视觉）见 §6 |
| 预览 | 8 张单件 3/4 + side（1280×800）+ 1 张 lineup（1920×720）：4 艘在水面、间距按 x 顺序、无建筑入镜 |

## 4. 契约摘要（机器可读字段）

- 轴心：水线中心（x=0 船中、z=0 水线、吃水为负 z），+X 船首、+Z 向上，1 unit = 1 m。
- 甲板 socket（`hull-sockets@1`）：`SN_Socket_Weapon_*`，原点 = down-ray 实测甲板面；
  `socket_index` / `socket_class` / `clearance_r/x/y/h` / `mount_scale` / `note`；
  Root `weapon_sockets`（按 index 名字数组）/ `weapon_socket_count` / `socket_spec`。
- 炮门 socket（`hull-gunports@1`，仅铁甲舰变体）：`SN_Socket_GunPort_Port/Starboard_1..4`，
  原点 = 炮门平面中心、`+X` = 炮膛轴线；`port_class=Medium` / `port_w=2.05` / `port_h=1.95` /
  `sill_z=1.30` / `deck_z=3.66` / `inboard_depth=1.10` / `outboard_clearance=6.00` /
  `lid="top"` / `lid_hinge_z=3.43` / `elev_*` / `traverse_deg=0` / `mount_scale=1.0`；
  Root `gun_port_sockets` / `gun_port_socket_count` / `gun_port_socket_spec`。
- 敌舰 Root extras：`combat_kit="enemy-ships@1"` / `enemy_class` / `enemy_archetype` /
  `baked_weapons=false` / `weapon_socket_spec`（+ 铁甲舰 `gun_port_socket_spec`）。
- 武器复用：甲板炮位由运行时 `ShipVisualAssembler` 按 class 挂载；铁甲舰炮门复用
  `SN_Weapon_CasemateGun`（`port_pitch`，108 tri / 7 节点）。

## 5. 全量回归

- 全量 Godot headless：**463 passed / 0 failed / 463 total**（含本批新增 `test_combat_kit_assets.gd` 5 例；既有套件无回归）。
- 既有资产：本批未修改 4 艘可玩船 / kit / 建筑 / 铁港道具的任何 GLB；`git status` 中旧资产 GLB 无改动。
- 场景：工作台 1069 对象（983 既有 + 86 新节点）、Camera=2、Light=1、collections 77、materials 30；
  非本批对象名 SHA-256 `6d3f1f6ce0208152e77c1fc7b8d4a53e95e2368ce457eb8bfba098f4f1da49d1`。

## 6. 独立 Verifier

独立 Verifier 只读复核（不修改场景 / 文件）：场景集合 / 对象 / tri / bbox / 材质 / UV /
父级 / socket extras 与实测净空、GLB 结构 / 贴图字节 / 双副本 / root extras / socket 坐标、
4 艘 3/4 + 正视视觉（轮廓、比例、穿插 / 浮空）与 `git status` 旧资产回归。

- **核心资产 24 项全通过**：场景 1069 对象 = 983 旧 + 86 本批；tri 31 324；bbox 与 catalog
  逐位一致（含 Pivot 变换）；材质全 `SN_Tex_*`；UV loops 全等；网格健康四项全 0；非本批
  983 对象名 SHA-256 与基线一致；16 + 8 个 socket extras 逐字段一致、射线实测甲板 z / 净空 /
  炮门内外净空；GLB 自写解析 4/4（nodes / mesh / prims / tri / Y-up bbox / TEXCOORD_0 /
  doubleSided / 外部贴图字节 / 双副本 / root extras / socket 坐标）；视觉无浮空、无破面、
  4 个 class 轮廓可辨。
- **首轮揪出 5 项文档 / 数据级问题**（无一项需要重建几何）：F1 验收记录缺失（当时文件尚未
  落盘）、F2 merchant bbox 目标三处不一致、F3 `SN_EM_Socket_Weapon_Stern` 声明净空比实测高
  0.02 m、F4 catalog deck_z 用解析值、F5 GLB scene extras 残留 MCP 会话元数据。
- **处置**：F1 补本文件并在 archive README 登记；F3 声明改 0.80（实测 0.83）后 socket 刷新 +
  重导；F2 生成器 bbox 对齐 brief 并重跑 catalog；F4 catalog 优先读 GLB 节点实测 deck_z
  （保留 `deck_z_analytic` / `deck_z_tolerance`）；F5 导出脚本剥掉 `scenes[].extras` 的
  `blendermcp*` 并重导（4 GLB 各 −40 B，合计 2 235 780 B）。复验结论见
  [MODELING_WORKFLOW.md §11.22](../../docs/design/MODELING_WORKFLOW.md)。

## 7. 过程发现（可复用教训）

1. **工作台摆位要先扫描空走廊**：AABB 零交叠不代表 look 干净；固定机位会被邻排建筑透视遮挡。
   先用只读 bbox / Y-band 扫描选行（本批最终 y=-110），再重建。
2. **纯 Python `report()` 必须复刻 Pivot 装配变换**：merchant 主桅在 Pivot 下，`report()` 原先
   把局部 z 当世界 z，z_max 少 0.33 m；补 `world_vertices()` 后 GLB 验收 4/4 通过（与 §11.9 同源）。
3. **socket 声明值先做纯 Python 射线预演**：socket-tools 在 Builder 之前预演出 7 处「声明高于
   实测」，Lead 据此把 `clearance_h / r / cx` 调保守并挪开 raider 艏平台，Builder 一次 apply 全绿。
4. **脚本路径 dirname 层数**：预览 / 导出脚本 `WORKDIR` 少一层会把产物写进 `tools/.design` /
   `tools/docs`；Builder 在导出前主动停手报告（未污染 GLB），修 `dirname(dirname(dirname(HERE)))`
   后重跑并清理错目录。
5. **LIVE Blender 模块缓存**：重建 / socket / 导出前均需 `importlib.reload`。
6. **不烘炮是刻意选择**：与 M0-3 / M0-6 的「船体只给 socket、武器独立模块」一致，避免敌舰
   武器与玩家武器资产分叉。

## 8. 已知边界 / 后续

- 敌人内容 Schema（`enemy_archetypes` / `encounter_tables` / `loot_tables`）仍为 `planned`；
  本批不登记 Core manifest、不接 AI / 遭遇表。
- 运行时武器挂载：`ShipVisualAssembler` 已能按 socket + `socket_class` 挂武器，但敌舰还未接入
  船舶装配入口；`gun_port` 运行时装配仍未接线（同 M0-6 边界）。
- LOD1 未做；4 艘敌舰不带 LOD1 / 远景低模，按 M0-5 派生流程后续补。
- 海盗旗 / 武装商船旗使用现有共享贴图材质（`SN_Tex_Wood_Dark` / `SN_Tex_Canvas_Shade` /
  `SN_Tex_Iron_Red`），没有新增帆布图案贴图；如需骷髅旗等图案，需先扩共享贴图 spec。
- 木甲板 / 帆面是单层开放件：边界边 > 0 属预期；闭合件网格健康四项全 0。
- 涂装口径：sloop 船身用共享贴图 `SN_Tex_Wood_Dark`（均值 58/40/26，近黑深棕）、merchant 主船身
  用 `SN_Tex_Wood`（均值 125/84/54，中棕），不是新调色板；brief / 验收文字已按共享贴图读感描述。
- 观感优化（非阻塞，后续批次可做）：炮艇艏装甲炮盾只高出舷墙约 0.25–0.3 m，侧视被舷墙遮住大半，
  可整体抬高 0.15–0.25 m 增强「装甲炮盾」辨识；铁甲舰空炮门的深色炮口板在强光下读作棕色木门板，
  可换 `SN_Tex_Glass_Dark` 强化「空炮门」黑洞感；预览图未随最后一次重导重渲染（几何零变化，
  渲染的是 Blender 场景而非 GLB，结论仍有效）。
