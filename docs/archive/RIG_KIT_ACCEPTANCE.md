# 船体帆索部件库 `rig_kit` 验收（M0-4，2026-10-22）

> 结论：**通过**。12 件 `SN_Rig_*` 套件 + 3 艘船参数化替换 + 22 个船体侧帆索 socket
> 全部交付；3 艘船重构前后逐对象几何 digest **0 差异**；GLB 自检 12/12 + 船舶 4/4 +
> 批次 B 回归 21 files 0 failures；Godot 新增 3 例 + 全量 **377 passed / 0 failed**
> （独立 Verifier 第二轮 `passed=true`，7/7 问题关闭）。
>
> 契约：[RIG_KIT_CONTRACT.md](../design/RIG_KIT_CONTRACT.md) ·
> 工单：[sn_rig_kit_batch1.json](../../tools/modeling/briefs/sn_rig_kit_batch1.json) ·
> 机器目录：[rig_kit_catalog.json](../../tools/modeling/rig_kit_catalog.json) ·
> Backlog：[MODELING_BACKLOG.md](../design/MODELING_BACKLOG.md) · 流程：[MODELING_WORKFLOW.md §11.18](../design/MODELING_WORKFLOW.md)

## 1. 范围与决策

用户 2026-10-22 选择：

1. **A · 套件 + 3 艘船改用部件库**：交付独立 12 件套件，同时把 `SN_Paddle_Freighter` /
   `SN_Schooner_Fame` / `SN_Ironclad` 焊死的帆索改为调用 `rig_kit.py` 参数化生成；
   硬约束是**逐对象几何 digest 不变**（tri / mesh 数不透支）。
2. **A · 运行时装配本批不实现**：只交付 assets + `rig_kit_catalog.json` + socket 契约；
   `ShipVisualAssembler` 仍留在 todo。

明轮客船 `SN_Paddle_Steamer` 没有帆索（仅旗杆），本批不重建、不加 rig socket。

## 2. 交付物

| 类别 | 文件 |
| --- | --- |
| 部件库（纯 Python） | `tools/modeling/generators/rig_kit.py`（RigBuilder + 通用积木 + 帆面 + 3 型船部件函数） |
| 套件生成器 | `tools/modeling/generators/rig_kit_batch1_generator.py`（12 件布局 / 接口 / Root extras） |
| 材质视图 | `tools/modeling/generators/sn_rig_materials.py` |
| 干跑 | `tools/modeling/generators/dryrun_rig_kit.py`（12 件，0 failures） |
| 几何基线 | `tools/modeling/generators/rig_kit_baseline.py`（`--capture` / `--compare`） |
| 船体 socket | `tools/modeling/generators/sn_ship_rig_sockets.py`（22 个，零几何） |
| GLB 归一化 | `glb_rig_kit.py`（套件）/ `glb_ship_rig_sockets.py`（船体） |
| 导出 | `export_rig_kit_glb.py` / `export_ship_weapon_sockets_glb.py`（扩展 rig socket） |
| 自检 | `verify_rig_kit_glb.py` / `verify_ship_weapon_sockets_glb.py`（扩展 rig socket） |
| 目录 | `tools/modeling/rig_kit_catalog.json`（由 `gen_rig_kit_catalog.py` 生成） |
| Godot 测试 | `framework/tests/cases/test_rig_kit.gd`（3 例，已注册 `test_runner.gd`） |
| 资产 | `assets/models/rig/` 12 GLB + `shared_materials/`（11 PNG）、4 艘船 GLB 重导；Core 副本同步 |
| 文档 | [RIG_KIT_CONTRACT.md](../design/RIG_KIT_CONTRACT.md)、本文、ASSET_MAP / WORKFLOW / BACKLOG / README / todo 更新 |

## 3. 12 件套件（G0 纯几何 = 3,774 tri / 预算 7,050）

| 资产 | 尺寸 X×Y×Z (m) | tri | 材质数 | 节点 = 1 root + 1 mesh + sockets |
| --- | --- | ---: | ---: | --- |
| `SN_Rig_Mast_Sail` | 1.87 × 2.90 × 21.50 | 448 | 4 | 9 |
| `SN_Rig_Mast_Steam` | 0.72 × 0.72 × 11.18 | 144 | 2 | 6 |
| `SN_Rig_Yard` | 0.48 × 6.94 × 0.48 | 72 | 3 | 6 |
| `SN_Rig_Gaff` | 5.46 × 0.50 × 2.06 | 72 | 2 | 5 |
| `SN_Rig_Boom` | 6.24 × 0.50 × 0.52 | 72 | 2 | 5 |
| `SN_Rig_Bowsprit` | 4.52 × 0.52 × 2.65 | 72 | 3 | 5 |
| `SN_Rig_Sail_Gaff` | 5.98 × 0.64 × 8.24 | 756 | 2 | 6 |
| `SN_Rig_Sail_Square` | 0.62 × 6.04 × 5.64 | 624 | 2 | 6 |
| `SN_Rig_Sail_Jib` | 5.04 × 0.47 × 7.24 | 578 | 2 | 5 |
| `SN_Rig_Shrouds` | 2.59 × 2.55 × 7.26 | 568 | 2 | 6 |
| `SN_Rig_Stays` | 9.00 × 2.94 × 7.26 | 188 | 3 | 5 |
| `SN_Rig_Running` | 5.09 × 6.83 × 7.22 | 180 | 2 | 5 |

- 桅 / 桁 / 索具为闭合壳体（边界边 / 非流形边 / 退化面 / 孤立点 = 0）；
  三种帆面为**单层开放曲面 + doubleSided**（允许边界边，干跑单独判定）；
- 材质全部为共享贴图 `SN_Tex_*`，GLB `images[].uri` 外部化且与授权 tile 逐字节一致；
  12 件合计 308.3 KB；
- 每件唯一 `SN_Mount`，接口节点 GLB 标准名（`SN_Socket_Yard_*` / `SN_Socket_Sail_*` / …），
  Root extras 含 `kit_family = "rig_kit"`、`rig_spec = "rig-kit@1"`、
  `rig_sockets` / `rig_socket_count` / `rig_socket_spec`。

## 4. 3 艘船参数化替换（digest 硬约束）

| 船 | 替换函数 | 重构前对象 / tri | 重构后 | digest |
| --- | --- | --- | --- | --- |
| `SN_Paddle_Freighter` | `build_mast` / `build_yards` / `build_bowsprit` / `build_rigging` → `rig_kit.steamer_*` | 39 / 12,200 | 39 / 12,200 | **SAME** |
| `SN_Schooner_Fame` | 6 个帆索函数 → `rig_kit.schooner_*` | 28 / 12,994 | 28 / 12,994 | **SAME** |
| `SN_Ironclad` | `build_masts` / `build_rigging` → `rig_kit.ironclad_*` | 1 / 8,830 | 1 / 8,830 | **SAME** |

`rig_kit_baseline.py --compare` 逐对象比较 `verts / faces / tri / parent / 材质计数 /
bbox / SHA-256`，结果 **3/3 SAME**。Blender 重建后同样满足：PF 39 mesh / 12,200 tri、
SF 29 / 13,174（Blender 侧对象口径含文字铭牌等，与纯几何基线口径不同）、IC 1 / 8,830；
PS 未重建（32 / 11,764）。

重建后按顺序重跑：武器 socket `apply_all()`（14）→ rig socket `apply_all()`（22）→
批次 B 材质/UV 迁移（4 艘船 / 101 mesh / 全 `SN_Tex_*` / UV loops == loops）。

## 5. 船体侧 rig socket（22 个，零几何）

| 船 | 数量 | 名称 |
| --- | ---: | --- |
| `SN_Paddle_Freighter` | 6 | `SN_Socket_Mast_Fore/Main`、`SN_Socket_Yard_Fore/Main`、`SN_Socket_Sail_Fore/Main` |
| `SN_Schooner_Fame` | 7 | 上述 6 个 + `SN_Socket_Sail_Jib` |
| `SN_Ironclad` | 9 | `SN_Socket_Mast/Yard/Sail × Fore/Main/Mizzen` |

- 全部是 Root 直接子节点、无 mesh；局部坐标直接来自 3 艘船参数表（不射线）；
- 节点 extras：`socket_kind` / `mast_key` / `socket_index` / `socket_spec`，桅点另有
  `height` / `deck_z`，桁点 `yard_z` / `yard_length` / `stowed`，帆点 `yard_z` /
  `sail_area_m2` / `stowed`；
- Root extras：`rig_sockets`（有序）/ `rig_socket_count` / `rig_socket_spec = "rig-sockets@1"`，
  与 `weapon_sockets` 并存；
- GLB 节点数：PF 50→**56**、SF 35→**42**、IC 5→**14**、PS **38** 不变（无 rig socket）。

## 6. 验收结果

| 检查 | 结果 |
| --- | --- |
| `dryrun_rig_kit.py` | 12 件 / total 3,774 tri / **0 failures** |
| `rig_kit_baseline.py --compare` | **3/3 SAME**（逐对象 digest） |
| `verify_rig_kit_glb.py` | **12/12 ALL OK**（节点 / mesh / tri / 尺寸 / 基准 / 材质 / UV / 外部贴图 / Root extras / 接口契约） |
| `verify_ship_weapon_sockets_glb.py` | **4/4 ALL OK**（几何不变量 + 武器 socket + rig socket + Root extras） |
| `verify_legacy_uv_b_glb.py` | **21 files / 0 failures**（批次 B 回归） |
| Godot `test_rig_kit` | **3/3 PASS**（套件 Mount+Socket / Root extras / 船体 22 sockets） |
| Godot 资产回归 | `test_ship_weapon_sockets` 2/2、`test_legacy_uv_assets_b` 2/2 PASS |
| 全量 headless 回归 | **377 passed / 0 failed / 377 total**（401 s，退出码 0；含既有 4.5.x 剧情 / 探索 / 海图套件与新增 3 例 rig_kit） |
| Blender 场景 | 798 objects / 457 mesh / 338 empty / 2 camera / 1 light / 61 collections；`.001` 0；非 `SN_` 对象仅 Camera / DBG2_CAM / Light |
| 独立 Verifier | 见 §8（`.design/rig_kit/qa_report.json`） |

## 7. 过程发现（可复用教训）

1. **浮点累加顺序会破坏“逐位一致”**：帆面曲面里 `vnorm((fwd.x, 0, fwd.z))` 若拆成
   “先按 3D 长度除、再归一化”，最后几位不同，`SN_SF_Sails_Main` digest 立刻变化；
   重构必须用 digest 对比而不是目测。
2. **三艘船的基本体实现不同**：SF 用 `ship_parts.core`、PF 自带同构副本、IC 的
   `taper_cyl` 相位与 `Part.add` 签名都不同；`RigBuilder` 只统一“追加接口 + 材质键”，
   基本体由各船模块注入，才能在重构中保持逐位一致。
3. **socket 应用脚本必须用自己的前缀**：铁甲舰若用 `SN_` 当前缀，会把
   `SN_Rig_*_Socket_*` 套件接口当船体 socket 删除；改为 `SN_IC_`。
4. **GLB 后处理只处理 Mast/Yard/Sail 三类节点**：不能把 M0-3 武器 socket 与 PF 旧
   通用 socket（Engine/Cabin/…）算进“规格外”。
5. **重建船体前要重跑批次 B**：船体生成器仍输出旧纯色 `SN_*` 材质、无 UV；重建后
   必须 `migrate_all_b(("ships",))`，否则 GLB 会退回迁移前状态。
6. **Blender 会缓存纯 Python 模块**：Builder 每次执行前必须清理 `sys.modules` 并
   `importlib.invalidate_caches()`（与 §11.13 / §11.17 同源）。

## 8. 独立 Verifier（两轮）

- 独立只读复核报告：`.design/rig_kit/qa_report.json`（本地产物，不入库）。
- **第一轮（2026-10-22）**：`passed=false`，23 checks，**无 P1**；7 项为 4 contract + 3 P2，
  全部可执行门禁已绿。关键独立证据：从 git HEAD 抽出重构前的 3 个船体生成器重算
  digest，与 `.design/rig_kit/baseline_*.json` 3/3 完全一致；契约 §4.4 的 22 个坐标
  逐点比对 22/22；场景增量算术闭合（+12 mesh / +12 Root / +45 套件 socket /
  +22 船侧 socket）；world-space BVH 0 三角形相交。
- **第一轮问题与修复**：

| 项 | 问题 | 修复 |
| --- | --- | --- |
| C1 | §4.4 船侧 extras 实际键名带 `rig_` 前缀，契约未带 | 契约改为 `rig_height / rig_deck_z / rig_yard_z / rig_yard_length / rig_stowed / rig_sail_area_m2` |
| C2 | §4.3 “rig_socket_count = 22” 实为每船 6/7/9 | 改为“该船 socket 数（PF6/SF7/IC9，合计 22）” |
| C3 | 套件 Root 的 `rig_*` 只在 GLB 层，契约未注明 | 契约补注：GLB JSON 层写 `rig_sockets/rig_socket_count/rig_socket_spec`，BLEND 层只有 `socket_count/socket_spec` |
| C4 | §4.2 接口表缺 `SN_` 前缀 | 12 行全部改为 `SN_Socket_*` 标准名 |
| P2-1 | Bowsprit/Stays/Running datum 声称 z=0，几何最低 0.75/0.432/0.5 m | 补甲板接触几何（安装块 / 4 块甲板眼板 / 2 个甲板羊角），zmin 全部 = 0；tri 60→72 / 140→188 / 156→180，total 3,690→**3,774**；重建重导并同步 SPECS / catalog / 契约 / brief |
| P2-2 | SF 的 `rig_yard_z` 取桅局部 z，PF/IC 取船体 z | 统一取 `mast_world()` 后的船体 z（实测 17.571 / 12.044 / 4.124 / 4.156），删除重复的 `rig_socket_index`，重导 4 艘船 |
| P2-3 | README/ASSET_MAP/todo 未注明 SF 12,994 口径 | 三处补注“纯帆索基线；整船 29 mesh / 13,174 含既有 `SN_SF_Nameplate`” |

- **第二轮（2026-10-22）**：`passed=true`，20 checks，7/7 关闭；门禁复跑全绿
  （baseline 3/3、dryrun 3,774/0、GLB 12/12 + 4/4 + 21/0、catalog 与仓库 JSON 相等、
  Godot 3/3 + 2/2 + 2/2）。仅余一条非阻断 P2 文档数字（§11.18 的 3,690/301.4 KB），
  已在本轮末期修正为 3,774 / 308.3 KB。

## 9. 已知边界 / 后续

1. 运行时 `ShipVisualAssembler` 未实现：本批只交付 assets + socket + 机器目录
   （todo 独立条目）。
2. 帆面为静态低模：无布料/风动；后续 Godot 侧用顶点动画 / SoftBody，模型侧保留
   `SN_Socket_Sail_*` 与单层拓扑。
3. 主桅三角顶帆尚未单独建 socket（`SN_Socket_Sail_Main` 取帆脚 tack），需要逐面装配时
   再细分 `*_Top`。
4. PS 无帆索：不建 rig socket，`SN_Socket_Mast` 族只覆盖 PF/SF/IC。
5. 12 件套件暂无 LOD1（backlog M0-5）。
6. 本批不登记 Core manifest 键；运行时读取路径为 `assets/models/rig/` + Core 副本。

## 10. 复现命令

```powershell
# 纯 Python
python tools/modeling/generators/dryrun_rig_kit.py
python tools/modeling/generators/rig_kit_baseline.py --compare
python tools/modeling/generators/sn_ship_rig_sockets.py --check
python tools/modeling/generators/gen_rig_kit_catalog.py
python tools/modeling/generators/verify_rig_kit_glb.py
python tools/modeling/generators/verify_ship_weapon_sockets_glb.py
python tools/modeling/generators/verify_legacy_uv_b_glb.py

# Godot（隔离套件）
$env:GODOT_BIN = "C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
& $env:GODOT_BIN --headless --path . --script res://framework/tests/test_runner.gd -- --suite=rig_kit
& $env:GODOT_BIN --headless --path . --script res://framework/tests/test_runner.gd -- --suite=weapon_sockets
& $env:GODOT_BIN --headless --path . --script res://framework/tests/test_runner.gd -- --suite=legacy_uv_assets_b
# 全量（本次 377 passed / 0 failed）
& $env:GODOT_BIN --headless --path . --script res://framework/tests/test_runner.gd

# Blender（单写者）
#   runpy.run_path(rig_kit_batch1_generator.py) → build_all_assets(); report()
#   runpy.run_path(sn_paddle_freighter_generator.py) / sn_schooner_fame_generator.py / sn_ironclad_generator.py
#   sn_ship_weapon_sockets.apply_all() → sn_ship_rig_sockets.apply_all()
#   sn_legacy_uv_migration.migrate_all_b(("ships",))
#   runpy.run_path(export_rig_kit_glb.py) / export_ship_weapon_sockets_glb.py
```
