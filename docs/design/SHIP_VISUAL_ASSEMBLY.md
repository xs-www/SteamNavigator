# 船体运行时装配（`ShipVisualAssembler`）

> 状态：**已实现（2026-10-22，切片 `ship-visual-assembly`）** —— 装配计划解析、rig_kit 挂接、
> 武器挂载、船厂 / 港口 / 航行演出接线、11 条装配单测 + 8 张实机截图全部落地。
> 上游契约：[RIG_KIT_CONTRACT.md](RIG_KIT_CONTRACT.md)（`rig-kit@1` / `rig-sockets@1`）、
> [WEAPON_SOCKET_CONTRACT.md](WEAPON_SOCKET_CONTRACT.md)（`weapon-assembly@2` / `hull-sockets@1`）。
> 本文只写「运行时怎么装配、怎么回退、怎么验收」，节点名 / extras 的唯一真源仍是上面两份契约。

## 1. 目标与分层

游戏原先只把船体 GLB 整件挂进舞台，船体里焊死的桅帆索与已交付的 12 件 `SN_Rig_*`
套件、14 个武器 socket 从不参与运行时装配。本切片把三方接起来：

```text
Core 内容（manifest 资源键 + hulls.json.data.rig_plan）
  → ShipVisualPlan.resolve()          纯数据：hull / rig / weapons 解析成物理路径
  → ShipVisualAssembler.assemble()    节点：实例化 hull → 挂 rig_kit → 挂武器 → 返回报告
      ├─ ShipRigAssembly               rig socket 发现 / SN_Mount 对齐 / 烘焙节点替换 / 快照
      └─ ShipWeaponAssembly/Mount      武器 class 门禁 / 对齐 / 瞄准后坐炮口 / 净空复核
```

| 层 | 文件 | 职责 |
| --- | --- | --- |
| 计划解析 | `framework/services/ship_visual_plan.gd` | 读 hull 定义 / `rig_plan` / weapon loadout，经 `AssetService.find_key()` + `resolve()` 得到路径；缺内容只记 `warnings` |
| 装配入口 | `framework/ui/stages/ship_visual_assembler.gd` | 实例化船体、执行 rig 与武器装配、返回 `visual` / `report` / `snapshot` |
| rig 规则 | `framework/ui/stages/ship_rig_assembly.gd` | socket 排序 / `SN_Mount` 对齐 / 隐藏烘焙节点 / 确定性快照 |
| 武器规则 | `framework/ui/stages/ship_weapon_assembly.gd` + `ship_weapon_mount.gd` | class 硬门禁、安装对齐、机制节点、净空软判定（自 `weapon-assembly-demo` 分支移植） |
| 回归 | `framework/tests/cases/test_ship_visual_assembler.gd`（11 例）+ `test_ship_weapon_assembly.gd`（14 例） | 见 §8 |
| 截图 | `tools/godot/capture_ship_assembly.gd` | 窗口化 1440×900，真实船厂 / 港口 / 航行演出场景 |

表现层只消费路径：`PortViewQuery` / `ShipyardViewQuery` 在 `ship.visual` 里给出计划，
Shell 的港口舞台 payload 透传，`ShipyardStage` / `PortStage` 命中计划才调用装配器；
旧存档 / 旧 ViewModel 没有 `visual` 字段时继续走原来的 `hull_model_path` / `hull_tier` 回退链。

## 2. 输入计划（`ShipVisualPlan.resolve`）

```gdscript
ShipVisualPlan.resolve(hub, assets, {
    "hull_id": "core:hull/large_efficient",   # → hull 定义的 information.model
    "hull_model_path": "",                     # ViewModel 已解析路径可直用
    "hull_tier": 3,
    "weapon_loadout": [                        # 可选；也接受 {socket: asset_key} 字典
        {"socket": "SN_Socket_Weapon_Port_1", "asset": "model.weapon.broadside"},
    ],
}) -> {
    "hull":    {"id", "model_key", "model_path", "tier"},
    "rig":     {"mode": "replace"|"baked", "kind": "sail"|"steam", "mount_kinds",
                "hide_nodes", "mast_path", "yard_path", "sail_path", "per_mast_paths", "yaw_deg"},
    "weapons": {"slots": [{"socket", "asset_key", "asset_path", "class"}]},
    "warnings": ["hull_definition_missing:...", ...],
}
```

- 资源键一律走 `AssetService.find_key()`（裸键 → 第一个声明该键的已挂载模组）→ `resolve()`，
  所以 `model.rig.*` / `model.weapon.*` 由 Core manifest 提供、第三方模组可覆盖；
- 也接受 `res://` / `user://` 直接路径（工具 / 测试用）；
- `rig.mode == "replace"` 只有在内容声明了 `hulls.json.data.rig_plan` 时出现；
  计划里任一必需套件解析不到会整体降级 `baked`，避免「隐藏了烘焙桅却没装上套件」的空船。

## 3. 内容字段：`data.rig_plan`

`schemas/hull.schema.json` 新增 `$defs/rig_plan`（先加 schema 再改内容）：

```json
"rig_plan": {
  "kind": "sail",                       // sail | steam，选套件族并进报告
  "mount_kinds": ["mast", "yard"],      // 要填充的船体 socket 类型（缺省 [mast]）
  "hide_nodes": ["SN_PF_Mast_Fore", "SN_PF_Mast_Main", "SN_PF_Yards"],
  "mast_asset": "model.rig.mast_steam",
  "yard_asset": "model.rig.yard",
  "sail_asset": "model.rig.sail_square",
  "per_mast_assets": [],                // 每个桅点额外挂的索具套件（默认空）
  "yaw_deg": 0.0
}
```

Core 当前配置（`dev_mods/core/content/hulls.json`，按实测尺寸做 **1:1 替换**）：

| 船体 | kind | mount_kinds | 套件 | 隐藏的烘焙节点 |
| --- | --- | --- | --- | --- |
| `core:hull/medium_standard`（双桅纵帆船） | sail | mast | `model.rig.mast_sail` ×2 | `SN_SF_Mast_Fore` / `SN_SF_Mast_Main` |
| `core:hull/large_efficient`（明轮货轮） | steam | mast + yard | `model.rig.mast_steam` ×2 + `model.rig.yard` ×2 | `SN_PF_Mast_Fore` / `SN_PF_Mast_Main` / `SN_PF_Yards` |
| `core:hull/small_efficient`（明轮客船） | —（不配） | — | — | 无 rig socket，保留烘焙件 |
| `core:hull/large_performance`（铁甲舰） | —（不配） | — | — | 单 mesh 整船，烘焙帆索无法单独隐藏 |

为什么只替换桅 / 桁：三艘船的 GLB 里**已有焊死的帆索几何**（M0-4 交付时保留了整船网格），
直接再挂套件会双层。实测 kit 尺寸与烘焙件吻合的只有这两处：

- PF 烘焙桅高 11.38 m ≈ `Mast_Steam` 11.18 m；kit 内部桁位 +8.2 m 落在船体坐标 z≈12.6，
  对烘焙桁中心 12.8 / 甲板 4.4 一致；
- SF 烘焙桅高 21.5 m = `Mast_Sail` 21.5 m（X/Y/Z 包围盒逐轴一致）；
- kit 帆面（`Sail_Square` 5.62 m 高）远小于 SF 烘焙方帆（13.3 m 高），IC 又是单 mesh，
  所以整桅帆重挂会明显改变船型 —— 本切片按用户决策只做 1:1 替换，其余保留烘焙件。
- `shrouds` / `stays` / `running` / `gaff` / `boom` / 帆面套件仍可由 `rig_plan` 驱动
  （`per_mast_assets` / `sail_asset`），留给没有烘焙帆索的模组船与后续批次。

## 4. 装配行为

1. **实例化船体**：`ContentAssetLoader.instantiate_model()`；`res://` 已导入资源优先
   `ResourceLoader`（保留项目 import 设置），打包模组的原始 GLB 走原始加载器。
2. **找 socket**：`ShipRigAssembly.find_sockets(hull)` 按名字前缀 `SN_Socket_Mast/Yard/Sail_*`
   收集，按 extras `socket_index` → 节点名排序；extras 缺失时用名字前缀推断 kind。
3. **对齐套件**：套件 `SN_Mount` 的世界变换被对齐到 socket 帧（原点 + 基向量），
   可选 `yaw_deg` 绕 socket 局部 +Y 旋转；套件自身不缩放。缺 `SN_Mount` 的套件会被释放并记 `mount_failed`。
4. **全有或全无**：计划声明的挂件只要有一件失败（缺 socket / 缺 GLB / 加载或对齐失败），
   就释放已挂套件、保留原船（`rig.mode=baked`、`fallback=rig_mount_failed`）。
5. **替换烘焙件**：全部成功后按 `hide_nodes` 逐个 `find_named` → 从父级摘下 → 立即 `free()`
   （不是 `queue_free()`，避免同帧港口舞台的静态合批把被替换网格烘进批次）。
6. **武器**：逐件尽力 —— 按计划顺序找 `SN_Socket_Weapon_*`，读武器 Root extras，
   `weapon_class == socket_class` 硬门禁（`Modular` kit 件拒绝），
   `ShipWeaponAssembly.mount()` 对齐 `SN_Mount` 并返回 `ShipWeaponMount`；
   单件失败只记 `weapons.skipped[{socket, reason}]`，不影响 rig 与其它武器。
7. **命名稳定**：`Rig_<kind>_<socket>`、`Rig_aux_<socket>_<asset>`、`Weapon_<socket>`；
   同一计划重复装配的 `snapshot()`（相对路径 + 量化 1e-4 的位置/基向量）完全相同。
8. **返回**：`{"visual": Node3D|null, "report": {...}, "snapshot": [...]}`。

`report` 关键字段：`hull_path` / `hull_asset` / `fallback` / `rig{mode,kind,mounted,skipped,hidden,missing_hide}` /
`weapons{mounted,skipped,mounts}` / `triangles`。`hull_asset` 从 GLB Root extras 读，供测试与调试核对。

## 5. 回退矩阵

| 缺失 / 异常 | 行为 | 报告 |
| --- | --- | --- |
| 计划 hull 路径缺失 / 实例化失败 | 计划 `fallback_model_path` → `SN_Ship_Prototype.glb` | `fallback=hull_fallback_model` |
| 连回退船体都加载失败 | 装配返回 `visual=null`，舞台保留原 2D 程序化占位 | `fallback=no_hull` |
| hull 无 `rig_plan`（客船 / 铁甲舰 / 旧内容） | 不隐藏、不改船，`rig.mode=baked` | — |
| 计划挂件缺 socket / 缺 GLB / 对齐失败 | 整体回退保留烘焙帆索 | `fallback=rig_mount_failed` + `rig.skipped` |
| 武器 socket 不存在 / 缺模型 / class 不匹配 / `Modular` | 跳过该件，其余照常 | `weapons.skipped[{socket,reason}]` |
| 旧存档 / 旧 ViewModel（无 `ship.visual`） | 舞台走原 `hull_model_path` → `hull_tier` → `Prototype` → 2D 占位 | — |
| 资源键未注册（模组缺资产） | 计划降级 `baked` / 武器槽 `asset_missing`，并写 `warnings` | — |

## 6. 舞台接入

| 入口 | 接线 | 保留的旧行为 |
| --- | --- | --- |
| 船厂 3D 舞台 `ShipyardStage` | `ship.visual` 命中 → `ShipVisualAssembler.assemble()`；失败回到原路径 | `hull_model_path` / `hull_tier` / `SN_Ship_Prototype` 回退、相机取景、水面泡沫、升沉 |
| 港口舞台 `PortStage` | `_rebuild_ship()` 优先计划装配，随后照旧 `ship_visual_is_rigid()` + `_batch_ship_visual()`（装配出的 rig / 武器都是 opaque 静态网格，可烘焙） | 旧 ViewModel 单船体路径、`ship_fallback` 整船回退、站位泊位/泡沫逻辑 |
| 航行演出（离港 / 入港） | 与港口停泊共用同一个 `PortStage._rebuild_ship()`，演出只移动 `_ship_root`，不改装配 | `VoyagePresentation` 状态机、`begin_departure()` / `begin_arrival()` 语义、接缝不变量 |
| Shell | `_port_stage_payload()` 透传 `ship.visual`（旧存档无该键 → 不传） | 设施 / 街景 / banner / 合批逻辑不变 |
| ViewModel | `PortViewQuery` / `ShipyardViewQuery` 的 `ship.visual`；`ShipyardViewQuery._empty_view()` 也带空计划 | 原有 ship 字段全部保留 |

只读访问器：`ShipyardStage.assembly_report()` / `rig_report()` / `weapon_mounts()`；
`PortStage.ship_assembly_report()` / `ship_rig_report()`。
港口舞台会做静态合批，**合批后报告里的节点引用会失效**（字符串字段仍可读）。

## 7. 截图（1440×900，真实场景）

命令：

```powershell
$env:GODOT_BIN = "C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
& $env:GODOT_BIN --path . --resolution 1440x900 --script res://tools/godot/capture_ship_assembly.gd
```

截图工具用真实 `bootstrap_core()` 解析计划（不写死资产路径），在真实 `ShipyardStage` /
`PortStage` 场景里逐张自检 `has_ship()` / `rig.mounted` / `weapons.mounted` 数量后才写盘；
先写 `res://tmp_*`，全部成功后移入 `docs/design/screenshots/ship_assembly/`。

| 截图 | 内容 |
| --- | --- |
| [shipyard_steamer.png](screenshots/ship_assembly/shipyard_steamer.png) | 24 m 明轮客船：烘焙帆索 + 3 件武器（Light×2 / Medium×1） |
| [shipyard_schooner.png](screenshots/ship_assembly/shipyard_schooner.png) | 33 m 双桅纵帆船：2 根套件帆桅替换烘焙桅 + 3 件武器 |
| [shipyard_freighter.png](screenshots/ship_assembly/shipyard_freighter.png) | 55 m 明轮货轮：2 蒸汽桅 + 2 横桁替换，4 个武器槽全装 |
| [shipyard_ironclad.png](screenshots/ship_assembly/shipyard_ironclad.png) | 60 m 铁甲舰：单 mesh 烘焙帆索 + 4 件重/中武器 |
| [shipyard_schooner_hero.png](screenshots/ship_assembly/shipyard_schooner_hero.png) | 纵帆船装配后近景：套件桅杆 + 烘焙帆/索具 + 甲板武器 |
| [port_moored.png](screenshots/ship_assembly/port_moored.png) | 港口停泊：`PortStage` 装配后的玩家船（含 rig 替换与武器） |
| [voyage_departure.png](screenshots/ship_assembly/voyage_departure.png) | 航行演出 · 3D 离港：同一装配结果驶离泊位 |
| [voyage_arrival.png](screenshots/ship_assembly/voyage_arrival.png) | 航行演出 · 3D 入港：同一装配结果驶入泊位 |

实测（截图工具日志，含 `hull + rig + weapons` 全部三角面）：

| 船体 | rig | 挂件 | 武器 | 三角面 |
| --- | --- | ---: | ---: | ---: |
| 明轮客船 | baked | 0 | 3/3 | 16,496 |
| 双桅纵帆船 | replace（隐藏 2 桅） | 2 | 3/3 | 17,906 |
| 明轮货轮 | replace（隐藏 2 桅 + 桁） | 4 | 4/4 | 21,512 |
| 铁甲舰 | baked | 0 | 4/4 | 16,006 |

## 8. 测试

```powershell
pwsh ./tools/test.ps1
# 或隔离套件
& $env:GODOT_BIN --headless --path . --script res://framework/tests/test_runner.gd -- --suite=ship_visual_assembler
& $env:GODOT_BIN --headless --path . --script res://framework/tests/test_runner.gd -- --suite=ship_weapon_assembly
```

| 套件 | 例数 | 覆盖 |
| --- | ---: | --- |
| `test_ship_visual_assembler` | 11 | 4 艘船计划解析 / rig_plan 内容驱动 / 武器 loadout 归一化与缺失告警 / 4 艘船装配与隐藏节点 / 确定性快照 / `SN_Mount` 对齐（<1e-3 m）/ 武器 class 正反例与 `Modular` 拒绝 / 缺 hull、缺套件、缺 socket 回退 / 船厂 + 港口舞台接线（含合批） |
| `test_ship_weapon_assembly` | 14 | 武器运行时层（自 `weapon-assembly-demo` 分支移植）：socket 排序、Root extras、class 门禁、对齐、`mount_scale`、机制节点、多联装、瞄准 / 后坐、净空软判定 |

全量 headless：**402 passed / 0 failed**（切片内实测；旧 377 例 + 新增 25 例）。

## 9. 已知边界

1. **武器还没有正式玩法内容**：`weapons` 内容类型仍是 Schema 2.0 草案，`state.ship` 里没有已装武器，
   所以游戏内 `weapon_loadout` 当前为空 —— 装配器与舞台透传已就绪，武器内容落地后直接接上；
   截图工具注入的是**预览 loadout**（只作为装配证据，不改存档 / 玩法数值）。
2. **只做 1:1 帆索替换**：PF / SF 只换实测吻合的桅 / 桁；整桅帆重挂（kit 帆面尺寸与烘焙件不一致）
   与铁甲舰单 mesh 的帆索拆分留给后续建模批次。
3. **合批后武器不可动**：港口舞台把玩家船烘进 `ShipBatches`，`ShipWeaponMount` 的瞄准 / 后坐句柄
   随之失效；未来战斗层接入时需要给「可动武器」留不合批的旁路。船厂舞台不做合批，句柄保持有效。
4. **无 LOD / 无布料**：套件无 LOD1，帆面仍是静态低模（见 [RIG_KIT_CONTRACT.md](RIG_KIT_CONTRACT.md) §8）。
5. **不读 catalog 做装配决策**：`tools/modeling/rig_kit_catalog.json` 是建模侧机器目录，不进发布包；
   运行时以内容 `rig_plan` + GLB extras 为准，catalog 缺失不影响装配（本切片未新增 catalog 读取）。
6. **客船无 rig socket**：`SN_Paddle_Steamer` 不建 rig socket，只参与武器装配。
7. **炮门 gun-port socket 尚未接入**：本切片只装配甲板 `SN_Socket_Weapon_*`；铁甲舰 12 个
   `SN_Socket_GunPort_*`（casemate gun，见 [WEAPON_SOCKET_CONTRACT.md](WEAPON_SOCKET_CONTRACT.md) §9）
   的运行时装配留待后续批次。
8. **铁甲舰使用合并后的空炮门船体**：合并 LOD1 / casemate 批次后 `SN_Ironclad.glb` 是空炮门版
   （8158 tri），本切片截图已按合并后资产重拍。

## 10. 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-10-22 | 建立运行时装配切片：`ShipVisualPlan` / `ShipVisualAssembler` / `ShipRigAssembly`，移植武器运行时层，接入船厂 / 港口 / 航行演出，新增 11 例装配测试与 8 张实机截图 |
