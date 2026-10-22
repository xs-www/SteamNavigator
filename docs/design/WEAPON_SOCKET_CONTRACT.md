# 武器装配规范 v2（可拼接舰载武器）

> 状态：武器侧 v2 已执行（2026-10-22）；船体侧安装点 M0-3 已执行（4 艘可玩船 14 个 socket，见 §8）；
> 炮门 socket + 穿壳炮 casemate gun 已执行（铁甲舰 12 个炮门，见 §9）
> 适用：舰载武器批次 1–2（8 件）、model kit 的武器部件（`SN_Weapon_Cannon/GunCarriage/Turret/Pedestal`）、船体 / 甲板安装点
> 旧版（按资产前缀命名 Pivot）见 git 历史；本文件替代 v1 作为唯一接口真源。

## 1. 目标与层级

把武器从“每件一套自定义 Pivot”改成**可拼接的统一装配图**：

```text
Hull / Compartment                船体 / 舱段
  SN_Socket_Weapon                船体提供的安装点（可带 _Port / _Starboard / _1..N 后缀）
    SN_Mount                      武器根下的通用安装帧（+X 前向、Z 向上、z=0 安装面）
      [Weapon Base]               炮架 / 炮塔底座 / 基座（可选，独立资产）
        SN_Pivot_Yaw              水平旋转节点（可选）
          [Weapon Body]           炮管 / 炮身（可选，独立资产）
            SN_Pivot_Pitch        俯仰节点（可选）
              SN_Recoil           后坐平移节点（可选，沿 -X）
                SN_Muzzle         炮口特效位置（可选，可索引 _1..N）
```

- **只认标准节点名**，不认资产 ID；装配 / 战斗层按名字找节点。
- 节点是否出现由武器的 `assembly_profile` 决定（§3），不是所有武器都必须有全部节点。
- 现有 `SN_Weapon_<Name>_Root` 仍是资产根（每件独立 GLB 的根）；标准节点挂在根下，名字不再带资产前缀。

## 2. 标准节点

| 节点 | 所属层 | 轴 / 原点 | 必填 | 说明 |
| --- | --- | --- | --- | --- |
| `SN_Socket_Weapon` | Hull | 原点在甲板安装面（down-ray 实测 deck top）；+X = 武器炮口/前向（侧舷点 rotZ ±90° 指向舷外，艏点 0°、艉点 180°） | 船体侧 | 安装点；多安装位用 `SN_Socket_Weapon_Port` / `_Starboard` / `_Port_1..N` / `_Bow` / `_Stern`；节点 extras 与船体侧净空口径见 §8 |
| `SN_Mount` | Weapon | 根原点，z=0 | ✅ | 通用安装帧，与 Root 同变换；装配只对齐它 |
| `SN_Pivot_Yaw` | Weapon Base | 绕 Z | 可选 | 水平回转；固定舷侧炮可省略 |
| `SN_Pivot_Pitch` | Weapon Body | 绕 Y | 可选 | 俯仰；多联装用 `SN_Pivot_Pitch_1..N` |
| `SN_Recoil` | Weapon Body | 沿 -X 平移 | 可选 | 后坐节点；多联装用 `SN_Recoil_1..N`；炮身网格父级挂在这里 |
| `SN_Muzzle` | Weapon Body | 在炮口端面中心 | 可选 | VFX / 命中点；多联装用 `SN_Muzzle_1..N` |
| `SN_Anchor_1..4` | Weapon Base | 底座四角 | 可选 | 拉索 / 链环 / 地脚锚点 |

约定：

- `SN_Pivot_Pitch` 的父级是 `SN_Pivot_Yaw`（若有）；`SN_Recoil` 的父级是 `SN_Pivot_Pitch`；`SN_Muzzle` 的父级是 `SN_Recoil`（无 Recoil 时挂 Pitch/Yaw/Mount）。
- 炮身 / 炮管 / 复进机网格挂在 `SN_Recoil` 下，底座 / 摇架 / 护盾挂在 `SN_Pivot_Yaw` 或 `SN_Mount` 下。
- 没有某节点时，运行时按 §5 的 fallback 链找最近祖先（例如无 `SN_Pivot_Pitch` 时 Muzzle 挂 Yaw）。

## 3. 可选性（`assembly_profile`）

| profile | 节点组合 | 典型武器 |
| --- | --- | --- |
| `fixed` | `SN_Mount`（+ Anchor） | 载人箭塔、固定炮座 |
| `pitch_only` | Mount + Pitch + Recoil + Muzzle | 固定舷侧炮（不回转） |
| `yaw_pitch` | Mount + Yaw + Pitch + Recoil + Muzzle | 甲板炮 / 重炮 / 弩炮 / 鱼叉 / 迫击炮 |
| `yaw_pitch_multi` | Mount + Yaw + Pitch_1..N + Recoil_1..N + Muzzle_1..N | 多联装 / 侧舷炮列（若需要整列回转） |
| `yaw_only` | Mount + Yaw（+ Muzzle） | 仅回转、炮身固定的塔炮 |
| `base_only` | Mount + Yaw（+ Trunnion 接口） | 炮架 / 炮塔底座 / 基座（等待 Body） |
| `port_pitch` | Mount + Pitch + Recoil + Muzzle（**无 Yaw**） | 穿船壳炮（casemate gun）§9 |

## 4. 现有资产映射（v2 目标）

| 资产 | profile | Mount | Yaw | Pitch | Recoil | Muzzle | Anchors |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `SN_Weapon_DeckGun` | yaw_pitch | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| `SN_Weapon_HeavyCannon` | yaw_pitch | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| `SN_Weapon_Mortar` | yaw_pitch | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| `SN_Weapon_Repeater` | yaw_pitch_multi | ✅ | ✅ | ✅ | `SN_Recoil` | `SN_Muzzle`（6 管，`muzzle_count=6`） | — |
| `SN_Weapon_Broadside` | pitch_only（固定舷侧） | ✅ | — | `SN_Pivot_Pitch_1..4` | `SN_Recoil_1..4` | `SN_Muzzle_1..4` | — |
| `SN_Weapon_Ballista` | yaw_pitch | ✅ | ✅ | ✅ | ✅ | ✅ | 4 |
| `SN_Weapon_ArrowTower` | fixed | ✅ | — | — | — | — | 4 |
| `SN_Weapon_HarpoonLauncher` | yaw_pitch | ✅ | ✅ | ✅ | ✅ | ✅ | 4 |
| `SN_Weapon_Cannon`（kit 炮身） | pitch_only | `SN_Mount`（耳轴帧） | — | ✅ | ✅ | ✅ | — |
| `SN_Weapon_GunCarriage`（kit 炮架） | base_only | ✅ | ✅ | — | — | — | — |
| `SN_Weapon_Turret`（kit 炮塔） | yaw_only | ✅ | ✅ | — | — | ✅ | 4 |
| `SN_Weapon_Pedestal`（kit 基座） | base_only | ✅ | ✅ | — | — | — | 4 |
| `SN_Weapon_CasemateGun`（穿壳炮） | port_pitch | ✅ | — | ✅ | ✅ | ✅ | — |
| `SN_ShipPart_Deck` | — | — | — | — | — | — | `SN_Socket_Weapon_Port/Starboard` |

## 5. Root extras（机器可读）

```json
{
  "assembly_spec": "weapon-assembly@2",
  "weapon_class": "Light | Medium | Heavy | Tower | Side",
  "assembly_profile": "yaw_pitch",
  "socket": "SN_Socket_Weapon",
  "mount": "SN_Mount",
  "pivot_yaw": "SN_Pivot_Yaw",
  "pivot_pitch": "SN_Pivot_Pitch",
  "recoil": "SN_Recoil",
  "muzzle": "SN_Muzzle",
  "has_yaw": true,
  "has_pitch": true,
  "has_recoil": true,
  "has_muzzle": true,
  "yaw_axis": "Z",
  "pitch_axis": "Y",
  "recoil_axis": "-X",
  "muzzle_count": 1,
  "yaw_limit_deg": [-180, 180],
  "pitch_limit_deg": [-5, 45],
  "base_footprint_x": 1.2,
  "base_footprint_y": 1.2,
  "envelope_x": 4.0,
  "envelope_y": 1.4,
  "height": 1.6,
  "swept_radius": 2.6,
  "anchor_count": 0
}
```

船体 socket 节点 extras（机器可读，见 §8）：

```json
{
  "socket_spec": "hull-sockets@1",
  "socket_index": 1,
  "socket_class": "Side | Light | Medium | Heavy | Tower",
  "clearance_r": 1.85,
  "clearance_x": 1.90,
  "clearance_y": 4.10,
  "clearance_h": 20.0,
  "mount_scale": 1.0,
  "note": "前甲板左舷：舷墙内 1.9 m 净空（人类可读备注，装配忽略）"
}
```

船体 Root extras 额外写：`weapon_sockets`（按 socket_index 顺序的标准节点名数组）、`weapon_socket_count`、`socket_spec`。

> **内容侧镜像（2026-10-22）**：`schemas/hull.schema.json` 的 `hull_data` 已新增可选 `weapon_sockets` / `rig_sockets` 数组，字段与本节 GLB extras 同口径；Core `dev_mods/core/content/hulls.json` 已回填 4 艘船（14 个武器 socket + 22 个帆索 socket）。该镜像供编辑器查看 / 编辑 / 校验，以及后续数据驱动装配使用；**运行时装配现阶段仍以 GLB 节点 extras 为准**（`ShipVisualAssembler` 未接入）。字段口径、镜像与 GLB 的坐标 / 索引差异见 [WEAPON_CONTENT_SCHEMA.md](WEAPON_CONTENT_SCHEMA.md) §6。

装配 fallback：

1. 找 `SN_Socket_Weapon*` → 按 `weapon_class == socket_class` 过滤；
2. 武器 Root 对齐 socket，缩放 `mount_scale`；
3. 战斗层：`yaw = find("SN_Pivot_Yaw")`，`pitch = find("SN_Pivot_Pitch*")`，`muzzle = find("SN_Muzzle*")`，`recoil = find("SN_Recoil*")`；缺哪个就跳过对应运动 / 特效；
4. 多联装按索引配对 `Pitch_i / Recoil_i / Muzzle_i`；
5. 缺模型 / 缺 socket / class 不匹配 → 跳过并记录，不阻断玩法；
6. 同 class 多个 socket 时用 clearance 择优（见 §8.3）。

## 6. 迁移计划（v1 → v2）

**状态：2026-10-22 已执行**（8 件舰载武器 + 4 件 kit 武器部件 + 甲板 socket；船体侧 M0-3 的 4 艘船 14 个 socket 也已执行，见 §8）。

现有资产尚未登记 Core manifest、也未接运行时 `ShipVisualAssembler`（grep 确认 framework / dev_mods / tools/godot 无旧节点名依赖），因此采用**干净改名**而不是兼容别名：

1. 生成器：`sn_weapon_batch1_generator.py` / `sn_weapon_batch2_generator.py` 的 `_pivot_specs` 改为标准节点；炮身网格父级从 `PITCH` 改挂 `RECOIL`；新增 `SN_Muzzle` / `SN_Recoil` 空节点与 v2 extras。
2. kit：`kit_batch1_generator.py` 的 Cannon/GunCarriage/Turret/Pedestal 改用同一标准名；`SN_ShipPart_Deck` 的 `Socket_Weapon_Port/Starboard` 改为 `SN_Socket_Weapon_Port/Starboard`。
3. 导出：BLEND 里节点名带资产前缀（避免多资产并排时的全局重名），`glb_weapon_nodes.standardize()` 在 GLB 导出后把节点归一化为 `SN_Mount` / `SN_Pivot_*` / `SN_Recoil` / `SN_Muzzle` / `SN_Anchor_*` / `SN_Socket_Weapon_*`；mesh / Root 名保持不变。
4. 干跑 / 自检 / 目录：更新 `dryrun_weapon_batch1/2`、`dryrun_kit_batch1`、`kit_catalog.json`、`verify_*_glb.py` 的期望节点名。
5. 已重建并重导 13 件（8 武器 + 4 kit 武器部件 + 甲板）；`verify_weapon_glb.py` 5/5、`verify_weapon_batch2_glb.py` 3/3、`verify_kit_glb.py` 8/8 全部通过。

## 7. 待决

1. `Broadside` 是否保留整列 Yaw（当前有 Yaw 结构）还是按「固定舷侧」去掉 Yaw；本表暂定 `pitch_only`。
2. `SN_Muzzle` 是否允许一节点多炮口（`muzzle_count`）还是强制一炮口一节点；本表采用「主炮口单节点 + 多联装索引」。
3. 多安装位命名：**已定** —— 两舷用 `SN_Socket_Weapon_Port` / `_Starboard`（多排时 `_Port_1..N` / `_Starboard_1..N`），艏/艉用 `_Bow` / `_Stern`；M0-3 已按此落地（§8）。
4. 武器 Base 与 Body 分离时（kit 炮架 + 炮身），`SN_Pivot_Pitch` 应该只在 Body 上，Base 只保留 `SN_Pivot_Yaw` + Trunnion 接口。
5. **（M0-3 验收 F1，亟待武器侧修）** 武器批次 1 的 `base_footprint_x/y` 当前等于整机 bbox，不能当底座占地用；
   需要给武器 extras 补真实 `mount_pad_x` / `mount_pad_y`（底座/平台网格 bbox），并重导 5 件武器 +
   回归 `verify_weapon_glb.py`。在此之前 §8.3 的底座判据以网格实测为准。

## 8. 船体侧安装点（M0-3 落地，2026-10-22）

**状态：已执行。** 4 艘可玩船各 2–4 个 `SN_Socket_Weapon*` 空节点，共 **14 个**；只加空节点、不改几何
（逐船 mesh / 三角面 / 材质 / 对象名快照前后一致：PF 39/12200、PS 32/11764、SF 29/13174、IC 1/8830）。

### 8.1 资产对照

| 船体 | Root | 安装点 | socket_class | 船体局部坐标 (x, y, deck z) | rotZ |
| --- | --- | --- | --- | --- | --- |
| `SN_Paddle_Freighter`（55 m 明轮货轮） | `SN_PF_Root` | `_Port_1` / `_Starboard_1` | Side | (13.0, ±2.3, 3.34) | ±90° |
| | | `_Port_2` / `_Starboard_2` | Light | (−14.0, ±2.2, 3.25) | ±90° |
| `SN_Paddle_Steamer`（24 m 明轮客船） | `SN_PS_Root` | `_Port_1` / `_Starboard_1` | Light | (9.6, ±0.8, 1.91) | ±90° |
| | | `_Stern` | Medium | (−9.0, 0.4, 3.42) | 180° |
| `SN_Schooner_Fame`（33 m 双桅纵帆船） | `SN_SF_Root` | `_Port_1` / `_Starboard_1` | Light | (−8.6, ±1.4, 3.08) | ±90° |
| | | `_Bow` | Medium | (10.0, 0.2, 2.89) | 0° |
| `SN_Ironclad`（60 m 舷侧炮铁甲舰） | `SN_Ironclad` | `_Port_1` / `_Starboard_1` | Heavy | (13.5, ±3.1, 4.60) | ±90° |
| | | `_Port_2` / `_Starboard_2` | Medium | (−17.5, ±2.6, 4.60) | ±90° |

- `class` 有意混编：船队整体覆盖 `Side / Light / Medium / Heavy`，玩家可按武器 class 选船；
- 侧舷点 rotZ ±90° 让 socket 的 **+X 指向舷外**（炮口方向），local Y 沿船体纵轴（炮列方向）；艏点 0°、艉点 180°；
- z 是**该点甲板的实测高度**（船甲板有拱度/升高甲板，同一艘船不同安装点 z 不同）。

### 8.2 extras 与命名

- BLEND 内节点名带资产前缀（`SN_PF_Socket_Weapon_Port_1` 等），避免 4 艘船同工作台并排时的
  全局对象重名；GLB 导出后由 `glb_ship_sockets.standardize()` 归一化为标准名（做法同武器 v2）；
- 节点 extras：`socket_spec = "hull-sockets@1"`、`socket_index`、`socket_class`、`clearance_r`、
  `clearance_x`、`clearance_y`、`clearance_h`、`mount_scale`、`note`；
- `note` 是**人类可读备注（中文，装配忽略、非白名单字段）**，用于在工作台里解释该点的选点理由；
  下游只按前 8 个键做装配判断，白名单校验请忽略 `note`；
- Root extras：`weapon_sockets`（按 socket_index 顺序的名字数组）、`weapon_socket_count`、`socket_spec`
  （Blender IDProperty 不支持字符串数组，`weapon_sockets` 由 GLB 后处理写入；Blender 侧只保留计数与 spec）；
  铁甲舰是单 mesh Root，另由 `sn_ship_weapon_sockets.py` 的 `root_extras` 补齐
  `asset / version / units / pivot / forward_axis`，与其他 3 艘多节点船体的 Root extras 对齐（2026-10-22 验收后补）；
- 内容侧镜像：`hull_data.weapon_sockets` / `rig_sockets` 已回填 4 艘船（14 + 22，字段同本节 extras），运行时仍读 GLB，见 [WEAPON_CONTENT_SCHEMA.md](WEAPON_CONTENT_SCHEMA.md) §6。

### 8.3 净空（clearance）口径

安装面以上 **0.12 m** 处实测，声明值一律不高于实测值（脚本内断言，不静默降级）：

| 字段 | 口径 |
| --- | --- |
| `clearance_r` | 16 向水平射线的最小自由距离（m）；最坏方向净空，适合做粗筛 |
| `clearance_x` | socket 局部 +X / −X 两向自由距离的较小值；侧舷点的 +X 是舷外（炮管方向） |
| `clearance_y` | socket 局部 +Y / −Y 两向自由距离的较小值；侧舷点沿船体纵轴（炮列方向） |
| `clearance_h` | 从安装面向上首个遮挡高度（m）；露天按 20 m 封顶 |

装配时建议：

1. 先按 `weapon_class == socket_class` 过滤（硬门禁）；
2. 再用 `height ≤ clearance_h` 判高度；**炮管/炮口允许越出舷外**，武器 `envelope_*` 不计入 clearance；
3. 底座/炮列占地要用**底座或平台网格的实际 bbox**判：`mount_pad_x/2 ≤ clearance_x`、
   `mount_pad_y/2 ≤ clearance_y`；同 class 多个 socket 时按可用净空从大到小择优
   （例如 `Side` 炮列优先 `clearance_y` 大的点）。

> **2026-10-22 验收发现的已知偏差（F1）**：武器批次 1（`sn_weapon_batch1_generator.py:692-695`）
> 把 `base_footprint_x/y` 直接赋值为整机 bbox（= `envelope_*`）：DeckGun `2.8×1.4`、HeavyCannon
> `4.8×2.2`、Mortar `3.2×2.2`、Broadside `2.2×8.0`、Repeater `2.8×1.6`；而它们的真实底座网格更小
> （DeckGun 底座 ≈1.6×1.2、HeavyCannon 平台 ≈3.6×1.8）。因此**不要**用 batch1 的 `base_footprint`
> 做硬适配判据：按字面会误杀 PS/SF 的 4 个 Light 点（cx≈1.35/1.05）与 IC 的 Heavy 点（cx≈1.9）。
> 正确做法是读武器底座/平台网格 bbox（或等武器批次 1 补 `mount_pad_*` 字段，见 §7 待决 5）。
> M0-3 的 14 个 socket 数值无需因该偏差调整。

### 8.4 生产与验收链路

| 环节 | 文件 |
| --- | --- |
| 规格真源 + Blender 就地补齐 / 实测 / 自检 | `tools/modeling/generators/sn_ship_weapon_sockets.py`（`--check` 为纯 Python 规格自检） |
| GLB 后处理（前缀名归一化 + Root `weapon_sockets`） | `tools/modeling/generators/glb_ship_sockets.py` |
| 导出（重导 4 个 GLB + 外部贴图 + Core 副本） | `tools/modeling/generators/export_ship_weapon_sockets_glb.py` |
| GLB 独立验收（纯 Python，4/4 ALL OK） | `tools/modeling/generators/verify_ship_weapon_sockets_glb.py` |
| 独立只读复核 + 修 F1–F3 的验收记录 | [docs/archive/SHIP_WEAPON_SOCKETS_ACCEPTANCE.md](../archive/SHIP_WEAPON_SOCKETS_ACCEPTANCE.md) |
| Godot 运行时守护（节点为空、父级、extras） | `framework/tests/cases/test_ship_weapon_sockets.gd` |

旧 GLB 备份在 `.design/ship_sockets/backup_glb/`，导出报告 `.design/ship_sockets/export_report.json`。

### 8.5 边界

- 运行时 `ShipVisualAssembler` 尚未接入，本表只交付 socket 契约与资产；装配/战斗层按 §5 fallback 取名即可；
- 小船的甲板本身拥挤（PS/SF 的 `clearance_r` 只有 1.0–1.2 m），这是资产真实净空，不是测量误差；
  需要更宽炮位的武器请走模块化甲板批次（`rig_kit` 已于 M0-4 交付桅帆索部件与 `SN_Socket_Mast/Yard/Sail_*`，
  见 [RIG_KIT_CONTRACT.md](RIG_KIT_CONTRACT.md)），而不是抬高这里的声明值；
- socket 只保证安装面、朝向与净空，不提供碰撞体、炮门动画或索具避让。

## 9. 炮门 socket 与穿壳炮 casemate gun（2026-10-22）

**状态：已执行。** 铁甲舰 12 门舷侧炮从船体网格里拆成独立模块 `SN_Weapon_CasemateGun`，
船体侧改为 12 个 `SN_Socket_GunPort_*`；船体保留炮门框 / 深色炮口板 / 上翻炮门盖，
炮管与炮口箍由模块供给。GLB：`SN_Ironclad.glb` **26 节点 / 1 mesh / 8158 tri**（拆炮前 8830），
`SN_Weapon_CasemateGun.glb` **7 节点 / 2 mesh / 108 tri**。

### 9.1 为什么是第二套 socket（不复用 `SN_Socket_Weapon`）

| | `SN_Socket_Weapon`（甲板） | `SN_Socket_GunPort`（炮门） |
| --- | --- | --- |
| 原点 | 甲板安装面（down-ray 实测 deck top） | **炮门平面中心**（炮膛轴线 ∩ 船壳面） |
| `+X` | 炮口 / 前向；侧舷点 rotZ ±90° 指向舷外 | **炮膛轴线**（含船型的外张角与上抬角） |
| 可见件 | 整机（底座 / 炮架 / 炮盾 / 炮管） | 只有门外炮管；炮架 / 炮尾藏在船壳内 |
| 净空字段 | `clearance_r/x/y/h`（安装面以上） | `inboard_depth` / `outboard_clearance`（门内 / 舷外） |

两种基准无法用同一个节点名表达：混用会让 §8.3 的甲板净空判据整体错位。
因此炮门 socket 独立命名、独立 Root 名单（`gun_port_sockets`），甲板 socket 保持不变。

### 9.2 节点契约

| 节点 | 所属 | 轴 / 原点 | 说明 |
| --- | --- | --- | --- |
| `SN_Socket_GunPort_Port_1..6` / `_Starboard_1..6` | Hull | 原点 = 炮门平面中心；`+X` = 炮膛轴线（舷外） | 船体提供的炮门安装点；当前只有铁甲舰有 |
| `SN_Mount` | Weapon | = Root（炮门平面中心） | 模块安装帧 |
| `SN_Pivot_Pitch` | Weapon | 绕 Y；`x = -0.15`（门内耳轴） | 俯仰；无 Yaw |
| `SN_Recoil` | Weapon | 沿 -X | 后坐平移 |
| `SN_Muzzle` | Weapon | 炮口端面中心 | VFX / 命中点 |

端口节点 extras（`socket_spec = "hull-gunports@1"`）：

```json
{
  "socket_spec": "hull-gunports@1",
  "socket_index": 1,
  "side_index": 1,
  "port_class": "Medium",
  "port_w": 1.9,
  "port_h": 1.9,
  "sill_z": 1.3,
  "deck_z": 4.6,
  "inboard_depth": 1.1,
  "outboard_clearance": 6.0,
  "lid": "top",
  "lid_hinge_z": 3.4,
  "elev_min_deg": -6.0,
  "elev_max_deg": 12.0,
  "traverse_deg": 0.0,
  "mount_scale": 1.0,
  "note": "人类可读备注，装配忽略"
}
```

- `sill_z` 是炮门下沿高度、`deck_z` 是该点甲板高度（铁甲舰均为 4.60），**不要**拿甲板 socket 的 z 口径套用；
- `inboard_depth`：从炮门平面内侧 0.20 m 沿 -X 射线量到的门内自由纵深（封顶 8 m）；铁甲舰实测 4.265–8.000 m，声明 1.10 m；
- `outboard_clearance`：从门外 0.15 m 沿 +X 量到的舷外自由距离（封顶 8 m）；铁甲舰实测 8.000 m，声明 6.0 m；
- 声明值一律不高于实测值（`sn_ship_gun_ports.apply_ship()` 内断言，不达标直接抛错）。

Root extras：`gun_port_sockets`（按 `socket_index` 顺序的名字数组）、`gun_port_socket_count`、
`gun_port_socket_spec`；与既有 `weapon_sockets` / `rig_sockets` 并列，互不覆盖。

### 9.3 装配 profile 与匹配规则

`port_pitch` = `Mount + Pitch + Recoil + Muzzle`（固定舷炮，无 Yaw）。
装配时按以下顺序判适配：

1. `weapon_class == port_class`（硬门禁，`SN_Weapon_CasemateGun` 声明 `Medium`）；
2. 武器 `port_w / port_h`（需要的最小开口）≤ 端口 `port_w / port_h`；
3. 武器 `breech_depth` ≤ 端口 `inboard_depth`（否则炮尾会从船壳内侧穿出）；
4. 武器 `elev_min/max_deg` ⊆ 端口 `elev_*`；
5. 炮管允许越出舷外，`envelope_x` 不计入净空；`outboard_clearance` 只约束锚架 / 撞角 / 艏斜桁这类可预见遮挡。

模块 Root extras 关键字段：`assembly_profile = port_pitch`、`has_yaw = false`、
`port_class = Medium`、`port_w/port_h = 1.9/1.9`、`muzzle_protrusion = 1.5407`、
`breech_depth = 0.95`、`trunnion_offset = 0.15`、`elev_min_deg = -6`、`elev_max_deg = 12`。

### 9.4 铁甲舰 12 个炮门（船体局部坐标，m）

| 端口 | x | y | z | rot_z | rot_y |
| --- | ---: | ---: | ---: | ---: | ---: |
| `_Port_1` | −17.414 | 5.073 | 2.262 | +77.869° | −1.720° |
| `_Port_2` | −10.414 | 5.838 | 2.262 | +77.869° | −1.720° |
| `_Port_3` | −3.414 | 6.178 | 2.262 | +77.869° | −1.720° |
| `_Port_4` | 3.586 | 6.165 | 2.262 | +77.869° | −1.720° |
| `_Port_5` | 10.586 | 5.722 | 2.262 | +77.869° | −1.720° |
| `_Port_6` | 17.586 | 4.736 | 2.262 | +77.869° | −1.720° |
| `_Starboard_1..6` | 同上 | 取负 | 同上 | −77.869° | −1.720° |

- 坐标由 `sn_ironclad_generator.gun_port_pose()` 从同一组炮门参数推导（不是手填），
  因此船体重建后 socket 不会漂；
- `rot_z = ±77.869°` 对应烘焙炮管的 12.13° 前外张，`rot_y = −1.720°` 对应 1.72° 上抬；
  模块本体不带外张角，换到别的船时由该船的炮门朝向决定；
- 12 个端口由 `sn_ship_gun_ports.py` 写入、`glb_gun_ports.py` 归一化并写 Root 名单。

### 9.5 交付与验收链路

| 环节 | 文件 |
| --- | --- |
| 模块参数化生成 + 装配 extras | `tools/modeling/generators/sn_casemate_gun_generator.py`（`port_pitch`） |
| 模块乾跑 + “装上去与烘焙炮管逐点重合”断言 | `tools/modeling/generators/dryrun_casemate_gun.py` |
| 炮门规格 + Blender 就地补齐 / 实测 / 自检 | `tools/modeling/generators/sn_ship_gun_ports.py`（`--check` 纯 Python） |
| GLB 后处理（前缀名归一化 + Root 名单） | `tools/modeling/generators/glb_gun_ports.py` |
| Blender 落盘（几何门禁 → 删炮管 → 建模块 → 三套 socket） | `tools/modeling/generators/apply_casemate_assets.py` |
| 导出（模块 + 空炮门铁甲舰 + Core 副本） | `tools/modeling/generators/export_casemate_glb.py` |
| GLB 独立验收（两个交付物） | `tools/modeling/generators/verify_casemate_glb.py` |
| Godot 运行时守护 | `framework/tests/cases/test_ship_gun_ports.gd` |
| 验收记录 | [CASEMATE_GUN_ACCEPTANCE.md](../archive/CASEMATE_GUN_ACCEPTANCE.md) |

### 9.6 边界

- **只有铁甲舰有炮门**。明轮货轮 / 明轮客船 / 纵帆船的船壳没有开口，直接挂炮门模块会让
  炮管从完好的船壳板里长出来；给它们装穿壳炮需要先做「炮门舱段 / port cassette」适配件
  （在船侧给出开口 + 暗腔，再套用本节的 socket 契约），列为后续批次；
- 炮门 socket 不提供碰撞体、炮门开合动画与索具避让；炮门盖在资产里是固定打开的；
- 空载读感 = 炮门框 + 木制深色炮口板 + 开着的门盖；深色板同时是模块门内隐藏段的遮挡面；
- `SN_Ironclad_LOD1.glb` 仍是拆炮前的旧件（LOD 切换未接线），重建 LOD1 列为后续项；
- 内容侧镜像（`hull.schema.json` 的 `gun_port_sockets`）本轮**未做**，运行时仍以 GLB 节点 extras 为准。

