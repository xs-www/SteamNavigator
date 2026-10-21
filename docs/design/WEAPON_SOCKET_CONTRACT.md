# 武器装配规范 v2（可拼接舰载武器）

> 状态：规范草案（2026-10-22），待按 §6 迁移现有资产
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
| `SN_Socket_Weapon` | Hull | +X 前向、z=甲板面 | 船体侧 | 安装点；多安装位用 `SN_Socket_Weapon_Port` / `_Starboard` / `_1..N` |
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

船体 socket 额外写：`socket_class`、`clearance_r`、`clearance_h`、`mount_scale`；多安装位同时写 `weapon_sockets` 列表。

装配 fallback：

1. 找 `SN_Socket_Weapon*` → 按 `weapon_class == socket_class` 过滤；
2. 武器 Root 对齐 socket，缩放 `mount_scale`；
3. 战斗层：`yaw = find("SN_Pivot_Yaw")`，`pitch = find("SN_Pivot_Pitch*")`，`muzzle = find("SN_Muzzle*")`，`recoil = find("SN_Recoil*")`；缺哪个就跳过对应运动 / 特效；
4. 多联装按索引配对 `Pitch_i / Recoil_i / Muzzle_i`；
5. 缺模型 / 缺 socket / class 不匹配 → 跳过并记录，不阻断玩法。

## 6. 迁移计划（v1 → v2）

**状态：2026-10-22 已执行**（8 件舰载武器 + 4 件 kit 武器部件 + 甲板 socket）。

现有资产尚未登记 Core manifest、也未接运行时 `ShipVisualAssembler`（grep 确认 framework / dev_mods / tools/godot 无旧节点名依赖），因此采用**干净改名**而不是兼容别名：

1. 生成器：`sn_weapon_batch1_generator.py` / `sn_weapon_batch2_generator.py` 的 `_pivot_specs` 改为标准节点；炮身网格父级从 `PITCH` 改挂 `RECOIL`；新增 `SN_Muzzle` / `SN_Recoil` 空节点与 v2 extras。
2. kit：`kit_batch1_generator.py` 的 Cannon/GunCarriage/Turret/Pedestal 改用同一标准名；`SN_ShipPart_Deck` 的 `Socket_Weapon_Port/Starboard` 改为 `SN_Socket_Weapon_Port/Starboard`。
3. 导出：BLEND 里节点名带资产前缀（避免多资产并排时的全局重名），`glb_weapon_nodes.standardize()` 在 GLB 导出后把节点归一化为 `SN_Mount` / `SN_Pivot_*` / `SN_Recoil` / `SN_Muzzle` / `SN_Anchor_*` / `SN_Socket_Weapon_*`；mesh / Root 名保持不变。
4. 干跑 / 自检 / 目录：更新 `dryrun_weapon_batch1/2`、`dryrun_kit_batch1`、`kit_catalog.json`、`verify_*_glb.py` 的期望节点名。
5. 已重建并重导 13 件（8 武器 + 4 kit 武器部件 + 甲板）；`verify_weapon_glb.py` 5/5、`verify_weapon_batch2_glb.py` 3/3、`verify_kit_glb.py` 8/8 全部通过。

## 7. 待决

1. `Broadside` 是否保留整列 Yaw（当前有 Yaw 结构）还是按「固定舷侧」去掉 Yaw；本表暂定 `pitch_only`。
2. `SN_Muzzle` 是否允许一节点多炮口（`muzzle_count`）还是强制一炮口一节点；本表采用「主炮口单节点 + 多联装索引」。
3. 多安装位命名：`SN_Socket_Weapon_Port/Starboard` 还是 `SN_Socket_Weapon_1..N`。
4. 武器 Base 与 Body 分离时（kit 炮架 + 炮身），`SN_Pivot_Pitch` 应该只在 Body 上，Base 只保留 `SN_Pivot_Yaw` + Trunnion 接口。
