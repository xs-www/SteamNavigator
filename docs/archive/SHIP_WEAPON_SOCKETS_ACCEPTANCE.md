# 船侧武器安装点 M0-3 验收（4 艘可玩船 · 14 个 SN_Socket_Weapon* 空节点）

> 状态：**已验收**（2026-10-22）
> 需求来源：[MODELING_BACKLOG.md](../design/MODELING_BACKLOG.md) M0-3 —— 「4 艘船各加 2–4 个 `SN_Socket_Weapon*` 空节点 + `socket_class / clearance_*` extras；不要求整块甲板，空节点即可」
> 接口契约：[WEAPON_SOCKET_CONTRACT.md](../design/WEAPON_SOCKET_CONTRACT.md) §8
> 工单/派发：本批无独立 JSON 工单（规格表即工单），Builder 子代理执行 + 独立 Verifier 只读复核

## 1. 结论

| 项目 | 结果 |
| --- | --- |
| 船体 | 4 / 4（`SN_Paddle_Freighter` / `SN_Paddle_Steamer` / `SN_Schooner_Fame` / `SN_Ironclad`） |
| 安装点 | **14 个空节点**（PF 4 / PS 3 / SF 3 / IC 4，每船 2–4 个） |
| 几何 | **零改动**：逐船 mesh / 三角面 / 材质 / 对象名快照前后一致（PF 39/12200、PS 32/11764、SF 29/13174、IC 1/8830；合计 45 968 tri） |
| 场景 | objects 693 → 707（+14，全部 EMPTY）；mesh 445 不变；camera / light / collection 数不变 |
| GLB | 4/4 重导；节点数 46→50 / 35→38 / 32→35 / 1→5；`verify_ship_weapon_sockets_glb.py` **4/4 ALL OK** |
| 回归 | 批次 B GLB 验收 `verify_legacy_uv_b_glb.py` **21 files / 0 failures**；Godot 资产 / socket 测试 **11/11 通过** |
| 契约 | `WEAPON_SOCKET_CONTRACT.md` §8；BLEND 前缀名 → GLB 标准名；Root 写 `weapon_sockets` |

## 2. 安装点清单（声明值来自实测，声明一律低于实测 0.05 m）

| 船体 | GLB 内节点 | `socket_class` | BLEND 名（工作台） | 船体局部 (x, y, deck_z) | rotZ | clearance_r / x / y / h (m) |
| --- | --- | --- | --- | --- | --- | --- |
| `SN_Paddle_Freighter` | `SN_Socket_Weapon_Port_1` | Side | `SN_PF_Socket_Weapon_Port_1` | (13.0, 2.3, 3.34) | +90° | 0.75 / 1.90 / 4.10 / 20.0 |
| | `SN_Socket_Weapon_Starboard_1` | Side | `SN_PF_Socket_Weapon_Starboard_1` | (13.0, −2.3, 3.34) | −90° | 0.75 / 1.90 / 4.10 / 20.0 |
| | `SN_Socket_Weapon_Port_2` | Light | `SN_PF_Socket_Weapon_Port_2` | (−14.0, 2.2, 3.25) | +90° | 1.45 / 1.90 / 6.35 / 20.0 |
| | `SN_Socket_Weapon_Starboard_2` | Light | `SN_PF_Socket_Weapon_Starboard_2` | (−14.0, −2.2, 3.25) | −90° | 1.45 / 1.90 / 6.35 / 20.0 |
| `SN_Paddle_Steamer` | `SN_Socket_Weapon_Port_1` | Light | `SN_PS_Socket_Weapon_Port_1` | (9.6, 0.8, 1.91) | +90° | 1.00 / 1.35 / 1.35 / 20.0 |
| | `SN_Socket_Weapon_Starboard_1` | Light | `SN_PS_Socket_Weapon_Starboard_1` | (9.6, −0.8, 1.91) | −90° | 1.00 / 1.35 / 1.35 / 20.0 |
| | `SN_Socket_Weapon_Stern` | Medium | `SN_PS_Socket_Weapon_Stern` | (−9.0, 0.4, 3.42) | 180° | 1.75 / 8.00 / 8.00 / 20.0 |
| `SN_Schooner_Fame` | `SN_Socket_Weapon_Port_1` | Light | `SN_SF_Socket_Weapon_Port_1` | (−8.6, 1.4, 3.08) | +90° | 1.05 / 1.05 / 2.35 / 20.0 |
| | `SN_Socket_Weapon_Starboard_1` | Light | `SN_SF_Socket_Weapon_Starboard_1` | (−8.6, −1.4, 3.08) | −90° | 1.05 / 1.05 / 2.35 / 20.0 |
| | `SN_Socket_Weapon_Bow` | Medium | `SN_SF_Socket_Weapon_Bow` | (10.0, 0.2, 2.89) | 0° | 1.10 / 1.10 / 1.25 / 20.0 |
| `SN_Ironclad` | `SN_Socket_Weapon_Port_1` | Heavy | `SN_IC_Socket_Weapon_Port_1` | (13.5, 3.1, 4.60) | +90° | 1.90 / 1.90 / 7.30 / 20.0 |
| | `SN_Socket_Weapon_Starboard_1` | Heavy | `SN_IC_Socket_Weapon_Starboard_1` | (13.5, −3.1, 4.60) | −90° | 1.90 / 1.90 / 7.30 / 20.0 |
| | `SN_Socket_Weapon_Port_2` | Medium | `SN_IC_Socket_Weapon_Port_2` | (−17.5, 2.6, 4.60) | +90° | 1.90 / 1.90 / 3.35 / 20.0 |
| | `SN_Socket_Weapon_Starboard_2` | Medium | `SN_IC_Socket_Weapon_Starboard_2` | (−17.5, −2.6, 4.60) | −90° | 1.90 / 1.90 / 3.35 / 20.0 |

节点 extras（与 GLB 一致）：`socket_spec = "hull-sockets@1"`、`socket_index`（1..N）、`socket_class`、
`clearance_r`、`clearance_x`、`clearance_y`、`clearance_h`、`mount_scale = 1.0`，另有人类可读 `note`
（装配忽略，下游白名单请跳过）；全部节点 `no mesh`、父级为船体 Root、无 `.001` 后缀。
Root extras：`weapon_sockets`（顺序数组）、`weapon_socket_count`、`socket_spec`；铁甲舰是单 mesh Root，
其 Root extras 另补 `asset / version / units / pivot / forward_axis`（2026-10-22 独立验收后补），与其余 3 艘对齐。

实测值（脚本当场射线测量，与声明值对比）：

| 船体 | local_z | 实测 clearance_r / x / y / h |
| --- | --- | --- |
| PF | 3.340 / 3.341 / 3.254 / 3.254 | 0.769 / 1.91 / 4.14(4.12) / 20.0；1.489 / 1.947 / 6.37(6.41) / 20.0 |
| PS | 1.914 / 1.914 / 3.420 | 1.018 / 1.392 / 1.36(1.54) / 20.0；1.775 / 8.0 / 8.0 / 20.0 |
| SF | 3.076 / 3.076 / 2.886 | 1.10 / 1.10 / 2.41 / 20.0；1.163 / 1.163 / 1.29 / 20.0 |
| IC | 4.600 ×4 | 1.929 / 1.929 / 7.33 / 20.0；1.914 / 1.914 / 3.38 / 20.0 |

## 3. GLB 交付

| 资产 | 节点 | mesh | tri | 文件 | sha256（前 12） |
| --- | --- | --- | --- | --- | --- |
| `SN_Paddle_Freighter` | 46→50（+4 socket） | 39 | 12200 | 848,184 B（828.3 KB） | `44454a501f4f` |
| `SN_Paddle_Steamer` | 35→38（+3） | 32 | 11764 | 835,380 B（815.8 KB） | `d5225d8e05de` |
| `SN_Schooner_Fame` | 32→35（+3） | 29 | 13174 | 953,180 B（930.8 KB） | `c9ec7af1fb2f` |
| `SN_Ironclad` | 1→5（+4，Root 是 mesh） | 1 | 8830 | 608,392 B（594.1 KB） | `fc34ab12d6dd` |

- 4 个 GLB 同时写入 `assets/models/ships/` 与 `dev_mods/core/assets/models/ships/`（逐字节一致）；
- 外部贴图仍为 `shared_materials/<texture>.png`，与授权 tile 逐字节一致；
- 旧 GLB 备份：`.design/ship_sockets/backup_glb/`；导出报告：`.design/ship_sockets/export_report.json`。

## 4. 验证证据

1. **Blender 场景（Builder 执行 + 独立 Verifier 只读复核）**
   - apply：`spec_failures=[]`，4/4 `passed=true`，`failures=[]`，`removed=[]`（未删既有对象）；
   - verify：4/4 `passed=true`，`failures=[]`；无 `.001`；Root `weapon_socket_count` = 4/3/3/4；
   - 几何快照：PF 39 mesh / 12200 tri、PS 32 / 11764、SF 29 / 13174、IC 1 / 8830，材质与对象名不变。
2. **GLB（纯 Python）**
   - `python tools/modeling/generators/verify_ship_weapon_sockets_glb.py` → `ALL OK` ×4；
   - 检查项：节点 / 网格 / 图元 / tri / 世界尺寸（PF 59.53×19.52×14.10、PS 24.56×10.47×8.74、SF 33.44×26.82×6.88、IC 60.13×28.64×18.00 m）/ 材质集合 / 每图元 UV / doubleSided / 外部贴图字节 / Core 副本哈希；socket 父子、`translation = (x, deck_z, −y)`（Blender Z-up → glTF Y-up）、+X 朝向、extras、Root `weapon_sockets` 顺序。
   - 批次 B 回归：`verify_legacy_uv_b_glb.py` → 21 files / 0 failures（节点期望已含本批 socket）。
3. **Godot（headless）**
   - `framework/tests/cases/test_ship_weapon_sockets.gd`：2 例（运行时空节点 / GLB JSON extras），资产相关 4 个套件合计 11/11 通过；
   - 既有 `test_legacy_uv_assets_b` / `test_stage_host` 等资产回归不受影响。

### 4.4 独立 Verifier（`qa-ship-sockets`，只读，2026-10-22）

- 场景：14/14 socket 全部 EMPTY、父级正确、无 `.001` / 重名，8 项机器 extras 值与规格一致；
  Root `weapon_socket_count` = 4/3/3/4；BLEND 未保存（`is_dirty=false`）。
- 几何：逐集合自己统计 39/12200、32/11764、29/13174、1/8830，场景 445 mesh；与
  `.design/ship_sockets/backup_glb/` 的 4 个 pre-socket 备份逐 GLB 对比，**BIN chunk 逐字节相同**、
  网格 / 三角面 / 材质 / 贴图 / 非 socket 节点列表全同 → 只多了 14 个空节点。
- GLB：独立解析（不依赖验收脚本）核对父子、`translation=(x, deck_z, −y)` 误差 ≤0.02、
  前向 +X 与 rot_z 一致 14/14、Root `weapon_sockets` 顺序、assets/Core sha256、30 个外部贴图 URI 三方字节一致。
- 视觉 / 落点：4 艘船外观与世界尺寸无回归；空节点不出现在 material 截图中，改用只读射线复核：
  14/14 命中声明的甲板对象、deck z 偏差 ≤0.005 m、上方 40 m 无遮挡、16 向净空 14/14 ≥ 声明值。
- **Verifier 判定 `passed=false` 的 3 项（均为契约 / 文档层，资产本体无需返工）与处理**：
  - **F1（medium，契约）**：`§8.3` 原用武器 `base_footprint` 当底座占地，但武器批次 1 的
    `base_footprint` 实际等于整机 bbox（= `envelope`），会误杀 PS/SF 的 4 个 Light 点与 IC 的 Heavy 点。
    → **已修契约**：§8.3 改为按底座/平台网格 bbox 判、明确 `envelope_*` 不计入 clearance，并记录该已知偏差；
    武器侧补真实 `mount_pad_*` 字段列入契约 §7 待决 5（不在 M0-3 范围）。
  - **F2（low，契约）**：extras 实际导出 `note`（人类可读备注）未写入契约。→ **已修**：§5 / §8.2 补
    `note` 说明（装配忽略、白名单跳过）。
  - **F3（low，文档）**：`ASSET_MAP.md` 4 艘船行仍是 M0-3 前的对象数。→ **已修**：PF 50 节点、PS 38、SF 35、
    IC 5 节点；同时补上 GLB 尺寸 / sha256 与脚本行。
  - Verifier 另记录（非 M0-3 引入）铁甲舰 Root extras 缺 `asset / version / units / forward_axis` →
    **已补**（见 §2），并重导 GLB。
- **复验**：修完后 `verify_ship_weapon_sockets_glb.py` 4/4 ALL OK、`verify_legacy_uv_b_glb.py` 21 files /
  0 failures；Godot 资产 / socket 套件 11/11；全量 headless 套件 **369 passed / 0 failed**（该次运行在
  socket 主交付物导出后跑通；此后仅给铁甲舰 Root 补 5 个 extras 字段并重导，资产相关套件已在新 GLB 上复验 11/11）。
  备注：本机 headless 偶发在 UI 舞台套件中途异常退出（同一命令多次运行退出点不同、无 `[FAIL]`），属环境不稳，
  与 M0-3 资产无关联；判定以跑通的 369/0 全量结果 + 资产套件复验为准。

## 5. 脚本与真源

| 环节 | 文件 |
| --- | --- |
| 规格真源 + 就地补齐 / 实测 / 自检 | `tools/modeling/generators/sn_ship_weapon_sockets.py`（`--check` 纯 Python 规格自检） |
| GLB 名称归一化 + Root extras | `tools/modeling/generators/glb_ship_sockets.py` |
| 导出（4 GLB / 外部贴图 / Core 副本 / 备份） | `tools/modeling/generators/export_ship_weapon_sockets_glb.py` |
| GLB 独立验收 | `tools/modeling/generators/verify_ship_weapon_sockets_glb.py` |
| Godot 运行时守护 | `framework/tests/cases/test_ship_weapon_sockets.gd` |

## 6. 边界与后续

- 运行时 `ShipVisualAssembler` / 战斗层尚未接入：本批只交付安装点契约与资产，装配按契约 §5 / §8.3 取名与筛选；
- 小船甲板拥挤，PS / SF 的 `clearance_r` 只有 1.0–1.2 m —— 这是真实净空，不应为提高数值而改声明；
  需要更大炮位的武器走后续 `rig_kit`（M0-4）/ 模块化甲板批次；
- socket 只保证安装面、朝向与净空，不含碰撞体、炮门动画与索具避让；
- 遗留 `SN_Ship_Prototype` 仍是旧纯色材质，未加 socket（不在本批 4 艘可玩船范围）。
