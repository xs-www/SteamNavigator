# 武器内容 Schema 2.0（`weapons`，D1 active）

> 状态：**active 2.0（2026-10-23 D1 提升）**，运行时按类型注册表加载，`CombatOps` / `CombatService` 已消费；编辑器 / CLI / SDK / Core 全链可用
> Schema：[schemas/v2/weapon.schema.json](../../schemas/v2/weapon.schema.json) · 类型登记：[content_types.json](../../content_types.json)
> 上游契约：[WEAPON_SOCKET_CONTRACT.md](WEAPON_SOCKET_CONTRACT.md)（装配 v2）· [RIG_KIT_CONTRACT.md](RIG_KIT_CONTRACT.md)（帆索 socket）· [SHIP_WEAPON_SOCKETS_ACCEPTANCE.md](../archive/SHIP_WEAPON_SOCKETS_ACCEPTANCE.md)（14 个武器 socket 实测值）
> 数据侧：[hull.schema.json](../../schemas/v2/hull.schema.json) · [hulls.json](../../dev_mods/core/content/hulls.json) · [weapons.json](../../dev_mods/core/content/weapons.json) · [runtime manifest](../../dev_mods/core/manifest.json) · 战斗规则真源：[SNBattleSim/js/catalog.mjs](../../SNBattleSim/js/catalog.mjs) · 运行时：[CombatOps](../../framework/domain/combat/combat_ops.gd) / [CombatService](../../framework/domain/combat/combat_service.gd)

## 1. 定位

`weapons` 是 Content Schema 2.0 的**战斗内容运行时类型**（D1），把一个舰载武器拆成三组数据：

| 组 | 回答的问题 | 对齐的真源 |
| --- | --- | --- |
| 战斗 | 打多远、多疼、多久一轮、什么弹道 | SNBattleSim `BUILTIN_WEAPONS` / `normalizeWeapon()` |
| 装配 | 能装在什么船位、有哪些运动节点、多大 | [WEAPON_SOCKET_CONTRACT.md](WEAPON_SOCKET_CONTRACT.md) `weapon-assembly@2` |
| 经济 | 几级、多重、多少钱、打造配方 | 运行时 `module_common`（tier / weight / purchase_price / craft_* / materials） |

边界：

- **运行时已加载**：`weapons` 在 `content_types.json.types` 中（`schema_version: "2.0"`，capability `content.combat.v1`），`ContentCompiler` 会校验并注册 `content/weapons.json`；D1 的 `CombatOps.player_weapon_rows()` 用 `hull_data.weapon_sockets` 与武器内容解析玩家武器，`combat.resolve` 据此结算。
- **GLB 仍是当前视觉装配事实**：武器 12 件 GLB 的 Root extras 与船体 4 个 GLB 的 socket extras 仍是 `ShipVisualAssembler` 的视觉装配来源；`hull_data.weapon_sockets` / `rig_sockets` 是内容侧镜像（战斗结算已读武器 socket，视觉装配切换留后续）。
- **D1 战斗规则已实现**：自动结算（抽象回合、伤害/护甲/穿甲、状态、撤退、战利品）已由 `CombatOps` / `CombatService` 落地；**不负责**实时战术、空间/弹道、部位伤害与弹药/煤耗（后续切片）。
- 其余战斗类型 `damage_types / combat_abilities / enemy_archetypes / encounter_tables / loot_tables` 已随 D1 一并 active 2.0，不再是 roadmap。

### 1.1 编辑器模板「舰载武器包」

模板保留为新建项目的快捷方式；D1 起 Core `dev_mods/core/content/weapons.json` 已内置同 5 件武器：

- 入口：新建模组对话框选「舰载武器包」（`TEMPLATES.weapons`）；或 `node SNModMaker/tools/content.mjs new --mod <dir> --id <id> --name <name> --template weapons`。
- 产物：`store.applyTemplate('weapons')` 一次生成 **5 条 `weapons` 定义**到 `content/weapons.json`（`schema_version: "2.0"`），每条 `information.model = asset://core/model.weapon.<local_id>`，并把 capability `content.combat.v1` 去重写入 `manifest.capabilities`。
- 数据来源：战斗数值照 `SNBattleSim/js/catalog.mjs` 的 `BUILTIN_WEAPONS`；装配字段照各 GLB Root extras（`weapon-assembly@2`）；经济字段为本项目补齐（模拟器无经济概念）；模型引用 Core 的 `model.weapon.*` 资源键（§7）。

| local_id | 名称 | `model` 键 | `weapon_class` | `assembly_profile` |
| --- | --- | --- | --- | --- |
| `deck_gun` | 甲板速射炮 | `model.weapon.deck_gun` | Light | yaw_pitch |
| `heavy_cannon` | 重型舰炮 | `model.weapon.heavy_cannon` | Heavy | yaw_pitch |
| `mortar` | 曲射迫击炮 | `model.weapon.mortar` | Heavy | yaw_pitch |
| `repeater` | 机关连发炮 | `model.weapon.repeater` | Medium | yaw_pitch |
| `broadside` | 侧弦炮列 | `model.weapon.broadside` | Side | pitch_only |

| local_id | tier | weight | purchase_price | craft_cost / 工时(h) | `materials` |
| --- | ---: | ---: | ---: | --- | --- |
| `deck_gun` | 1 | 9 | 380 | 170 / 4 | `[]` |
| `heavy_cannon` | 3 | 20 | 1200 | 520 / 10 | timber×6、boiler_plate×3、precision_gear×1 |
| `mortar` | 3 | 16 | 1100 | 470 / 9 | timber×5、boiler_plate×3 |
| `repeater` | 2 | 11 | 620 | 260 / 6 | timber×2、boiler_plate×1 |
| `broadside` | 2 | 22 | 820 | 340 / 7 | timber×4、boiler_plate×2 |

> **Core 已落盘**：D1 起 `dev_mods/core/content/weapons.json` 已含这 5 件武器（`core:weapon/*`），运行时正常校验并注册；「舰载武器包」模板仍保留给新项目复制同款起点。

## 2. 文件外壳与类型登记

```json
{
  "schema_version": "2.0",
  "content_type": "weapons",
  "definitions": [
    {
      "id": "core:weapon/deck_gun",
      "name_key": "weapon.core.deck_gun.name",
      "enabled": true,
      "information": { "model": "model.weapon.deck_gun" },
      "data": { "kind": "direct", "damage": 12, "range": 245 }
    }
  ]
}
```

| 位置 | 约束 |
| --- | --- |
| `schema_version` | `const "2.0"` |
| `content_type` | `const "weapons"` |
| `definitions` | 数组、`minItems: 1`；外壳走 `common.schema.json#/$defs/definition` |
| `definitions[].id` | `^[a-z][a-z0-9_]{2,31}:[a-z_]+/[a-z0-9_]+$`（如 `core:weapon/deck_gun`、`my_mod:weapon/long_nine`） |
| `definitions[].data` | `weapon_data`，`additionalProperties: false`（写错字段名会被 Schema 拒绝） |
| `definitions[].information.model` | 模型资源键，现有候选为 `model.weapon.*`（§7）；不是武器数值字段 |

`content_types.json` 登记（编辑器元数据）：

| 字段 | 值 |
| --- | --- |
| `key` / `singular` / `key_prefix` | `weapons` / `weapon` / `weapon` |
| 标签 | 舰载武器（en: Weapons），缩写 `WN`，色 `#e2685e` |
| `group` | `combat`（编辑器归入「战斗」分组；`content_types.json` 的 group 定义） |
| `default_file` | `content/weapons.json` |
| `schema_version` | `2.0`（与 Schema `const` 一致） |
| `capability` | `content.combat.v1`（active 类型；使用该内容需在 `manifest.capabilities` 声明，否则编辑器给 `capability_undeclared` 警告） |

## 3. `data` 字段（三组）

必填 15 项：战斗 10 + 装配 2（`weapon_class`、`assembly_profile`）+ 经济 3（`tier`、`weight`、`purchase_price`）；可选 `damage_type` 引用 `damage_types`（缺省时运行时按普通动能命中处理）。

### 3.1 战斗

| 字段 | 类型 / 范围 | 必填 | 说明 |
| --- | --- | --- | --- |
| `kind` | enum：`direct` / `artillery` / `broadside` | ✅ | 开火行为，与模拟器 `weapon.kind` 同义 |
| `damage` | number 1–120 | ✅ | 单发/单目标伤害 |
| `range` | number 60–700 | ✅ | 最大射程（米） |
| `min_range` | number 0–400 | ✅ | 最小射程；必须 `< range`（编辑器语义校验） |
| `cooldown` | number 0.25–20 | ✅ | 两轮齐射间隔（秒） |
| `accuracy` | number 0.05–0.98 | ✅ | 命中率 |
| `projectile_speed` | number 60–900 | ✅ | 弹速（米/秒） |
| `splash` | number 0–100 | ✅ | 溅射半径（米），0 = 单体 |
| `arc_deg` | number 30–360 | ✅ | 射界 / 炮口覆盖角（度） |
| `salvo` | integer 1–8 | ✅ | 单次开火弹药数（多联装/炮列） |
| `damage_type` | `id_ref` → `damage_types` | — | D1 伤害类型引用；缺省按普通动能命中，`damage_types.armor_pierce` 决定穿甲 |
| `color` | string `^#[0-9a-fA-F]{6}$` | — | 弹道 / 炮口特效基色 |

### 3.2 装配

| 字段 | 类型 / 范围 | 必填 | 说明 |
| --- | --- | --- | --- |
| `weapon_class` | enum：`Light` / `Medium` / `Heavy` / `Tower` / `Side` / `Modular` | ✅ | 与船体 socket `socket_class` 做**硬门禁**；`Modular` 是 kit 部件（炮身/炮架/炮塔/基座），不是可直接挂载的完整武器 |
| `mount_class` | enum：`Light` / `Medium` / `Heavy` / `Tower` / `Side` | — | 安装帧类别；缺省与 `weapon_class` 相同 |
| `assembly_profile` | enum：`yaw_pitch` / `yaw_pitch_multi` / `pitch_only` / `fixed` / `base_only` / `yaw_only` | ✅ | 机构层组合，决定 GLB 里该出现哪些 `SN_Pivot_*` / `SN_Recoil` / `SN_Muzzle` |
| `has_yaw` / `has_pitch` / `has_recoil` / `has_muzzle` | boolean | — | 与 `assembly_profile` 冗余但便于运行时查询；编辑器校验一致性 |
| `muzzle_count` | integer 1–8 | — | 炮口数；>1 时 `has_muzzle` 必须为 true |
| `envelope_x` / `envelope_y` | number 0–20 | — | GLB Root `envelope_*`（米），含炮管整机长度；**不计入净空判定** |
| `height` | number 0–20 | — | 甲板面以上总高（米）；装配时要求 `height ≤ socket.clearance_h` |
| `mount_scale` | number 0.1–10 | — | 装配统一缩放；与 socket extras `mount_scale` 同口径 |

各 profile 的节点组合（详见 [WEAPON_SOCKET_CONTRACT.md §3](WEAPON_SOCKET_CONTRACT.md)）：

| profile | 节点组合 | 典型 |
| --- | --- | --- |
| `fixed` | `SN_Mount`（+Anchor） | 载人箭塔、固定炮座 |
| `pitch_only` | Mount + Pitch + Recoil + Muzzle | 固定舷侧炮、kit 炮身 |
| `yaw_pitch` | Mount + Yaw + Pitch + Recoil + Muzzle | 甲板炮 / 重炮 / 迫击炮 / 鱼叉 |
| `yaw_pitch_multi` | Mount + Yaw + Pitch_1..N + Recoil_1..N + Muzzle_1..N | 多联装 / 侧舷炮列 |
| `yaw_only` | Mount + Yaw（+ Muzzle） | 仅回转的塔炮 |
| `base_only` | Mount + Yaw（+ Trunnion 接口） | 炮架 / 炮塔底座（等待 Body） |

### 3.3 经济

| 字段 | 类型 / 范围 | 必填 | 说明 |
| --- | --- | --- | --- |
| `tier` | integer 1–3 | ✅ | 与 `module_common` 一致 |
| `weight` | number 0–200 | ✅ | 重量（对应模拟器 `weapon.mass`），计入船体载重 |
| `purchase_price` | number ≥0 | ✅ | 购买价 |
| `craft_cost` | number ≥0 | — | 打造费（金币） |
| `craft_time_hours` | number ≥0 | — | 打造工时（小时） |
| `materials` | array of `{ id, amount }` | — | `id` 为定义 ID（`id_ref`），`amount ≥ 0.1`；与 `craft_material` 同形，运行时 `CraftOps` 可直接消费 |

> `materials` 元素与 v1 的 `craft_material` 一致（`id` + `amount`），不是 `item`；三条经济字段与 `module_common` 同名同义。

## 4. SNBattleSim → `weapons` 映射与内置武器对照

模拟器是纯战斗规则试验台，`normalizeWeapon()` 只认战斗字段并做 clamp；内容的装配/经济字段对它是未知字段，被忽略。

| SNBattleSim（`catalog.mjs`） | 内容 `data` | 说明 |
| --- | --- | --- |
| `kind` | `kind` | 同枚举（默认 `direct`） |
| `damage` | `damage` | 同范围 1–120 |
| `range` | `range` | 同范围 60–700 |
| `minRange` | `min_range` | 模拟器最后 `min(minRange, range - 1)`；内容由编辑器语义校验 |
| `cooldown` | `cooldown` | 同范围 0.25–20 |
| `accuracy` | `accuracy` | 同范围 0.05–0.98 |
| `projectileSpeed` | `projectile_speed` | 同范围 60–900 |
| `splash` | `splash` | 同范围 0–100 |
| `arc` | `arc_deg` | 模拟器字段名无 `_deg` |
| `salvo` | `salvo` | 同范围 1–8 |
| `color` | `color` | 模拟器回退 `#8fe3ff`；内容 Schema 只接受 `#RRGGBB` |
| `mass` | `weight` | **范围不一致**：模拟器 clamp 1–80，内容 0–200 |
| `id` / `name` | `definitions[].id` / `name_key` | 进入内容外壳，不在 `data` |
| — | `weapon_class` … `mount_scale` | 模拟器无对应概念（装配层） |
| — | `tier` / `purchase_price` / `craft_*` / `materials` | 模拟器无对应概念（经济层） |

5 件内置武器（`BUILTIN_WEAPONS`）数值：

| id | 名称 | kind | damage | range | min_range | cooldown | accuracy |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| `deck_gun` | 甲板速射炮 | direct | 12 | 245 | 0 | 1.65 | 0.72 |
| `heavy_cannon` | 重型舰炮 | direct | 30 | 355 | 35 | 4.2 | 0.61 |
| `mortar` | 曲射迫击炮 | artillery | 24 | 430 | 105 | 5.1 | 0.58 |
| `repeater` | 机关连发炮 | direct | 7 | 185 | 0 | 0.72 | 0.76 |
| `broadside` | 侧弦炮列 | broadside | 8 | 285 | 20 | 5.4 | 0.64 |

| id | projectile_speed | splash | arc_deg | salvo | weight（=mass） | color |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `deck_gun` | 360 | 0 | 260 | 1 | 9 | `#ffd37a` |
| `heavy_cannon` | 285 | 8 | 150 | 1 | 20 | `#ff9a63` |
| `mortar` | 175 | 34 | 360 | 1 | 16 | `#f3c8ff` |
| `repeater` | 430 | 0 | 300 | 1 | 11 | `#fff0a4` |
| `broadside` | 330 | 0 | 76 | 4 | 22 | `#ffcf87` |

编辑器「新增武器」的默认值直接取 `deck_gun` 的战斗数值，并补装配/经济默认：`weapon_class=Light`、`assembly_profile=yaw_pitch`、`has_*=true`、`muzzle_count=1`、`envelope_x=2.815` / `envelope_y=1.41` / `height=1.613`、`mount_scale=1.0`、`tier=1`、`weight=9`、`purchase_price=380`、`craft_cost=170`、`craft_time_hours=4`、`materials=[]`。可直接作为新武器骨架，再改数值与模型键。

## 5. 装配契约 ↔ 内容字段

| GLB Root extras（`weapon-assembly@2`） | 内容字段 | 落位 |
| --- | --- | --- |
| `weapon_class` | `weapon_class` | ✅ 直接同名 |
| `assembly_profile` | `assembly_profile` | ✅ 直接同名 |
| `has_yaw` / `has_pitch` / `has_recoil` / `has_muzzle` | 同名字段 | ✅ 直接同名 |
| `muzzle_count` | `muzzle_count` | ✅ 直接同名 |
| `envelope_x` / `envelope_y` / `height` | 同名字段 | ✅ 直接同名 |
| `assembly_spec` / `socket` / `mount` / `pivot_yaw` / `pivot_pitch` / `recoil` / `muzzle` | — | 常量 / 由 `assembly_profile` 推导，不进内容 |
| `yaw_axis` / `pitch_axis` / `recoil_axis` | — | 坐标约定常量（Z / Y / -X） |
| `yaw_limit_deg` / `pitch_limit_deg` | — | 契约 §5 示例字段，**现有 12 件 GLB 均未导出**；内容 Schema 亦无对应字段（待决） |
| `base_footprint_x` / `mount_pad_x` | — | 无内容字段；batch1 的 `base_footprint` = 整机 bbox（F1，不能当底座占地），`mount_pad_*` 尚未落地 |
| `swept_radius` / `anchor_count` | — | 无内容字段（部分资产有，运行时若需要需补） |
| socket extras `mount_scale` | `mount_scale` | 装配缩放；武器 Root extras 本身不写该键 |

装配判定顺序（与契约一致）：`weapon_class == socket_class` 硬门禁 → `height ≤ clearance_h` → 底座实际 bbox ≤ `clearance_x/y`（`envelope_*` 允许越出舷外）→ 同 class 多 socket 时按净空择优。

## 6. 船体安装点：GLB extras ↔ 内容镜像

`schemas/v2/hull.schema.json`（active 2.0）在 `hull_data` 新增两个**可选**数组；Core `hulls.json` 已回填并随运行时校验。D1 的 `CombatOps.player_weapon_rows()` / `unmounted_sockets()` 已消费 `weapon_sockets`；`rig_sockets` 仍主要供视觉装配与后续数据驱动使用：

| 数组 | 每项必填 | 可选字段 |
| --- | --- | --- |
| `weapon_sockets` | `name`（`^SN_Socket_Weapon`）、`socket_class`（Light/Medium/Heavy/Tower/Side）、`socket_index`（0–64） | `position`（3 个数）、`clearance_r/x/y`（0–30）、`clearance_h`（0–40）、`mount_scale`、`note` |
| `rig_sockets` | `name`（`^SN_Socket_`）、`socket_kind`（mast/yard/sail）、`socket_index`（0–64） | `mast_id`、`position`、`rig_height`、`rig_deck_z`、`rig_yard_z`、`rig_yard_length`、`rig_stowed`、`rig_sail_area_m2`、`note` |

与 GLB extras 的口径差异（接入运行时时必须显式转换）：

| 维度 | GLB extras（权威资产侧） | 内容镜像（`hulls.json`） |
| --- | --- | --- |
| 坐标 | glTF Y-up，`translation = (x, deck_z, −y)` | Blender 船体局部 `position = [x, y, deck_z]` |
| `weapon_sockets[].socket_index` | 1..N（PS 1/2/3） | 0..N−1（PS 0/1/2） |
| `rig_sockets[].socket_index` | 0..N−1，按桅序编排 | 0..N−1，但铁甲舰按 kind 分组重排（见 §11） |
| 帆索桅键 | `mast_key`，首字母大写（`Fore`/`Main`/`Mizzen`） | `mast_id`，小写（`fore`/`main`/`mizzen`） |
| `socket_spec` | 有（`hull-sockets@1` / `rig-sockets@1`） | 无（由数组名隐含） |
| `note` | 有，中文、装配忽略 | 可选，同义 |

### 6.1 4 艘船的武器 socket（14 个）

数值即 Core `hulls.json` 回填值，来源为 [SHIP_WEAPON_SOCKETS_ACCEPTANCE.md](../archive/SHIP_WEAPON_SOCKETS_ACCEPTANCE.md) §2 的实测/声明值（声明一律不高于实测）。

| 内容船体（`core:hull/…`） | GLB 模型 | socket | class | `position` (x, y, deck_z) | clearance r / x / y / h |
| --- | --- | --- | --- | --- | --- |
| `small_efficient` | `SN_Paddle_Steamer` | `SN_Socket_Weapon_Port_1` | Light | (9.6, 0.8, 1.91) | 1.00 / 1.35 / 1.35 / 20.0 |
| | | `SN_Socket_Weapon_Starboard_1` | Light | (9.6, −0.8, 1.91) | 1.00 / 1.35 / 1.35 / 20.0 |
| | | `SN_Socket_Weapon_Stern` | Medium | (−9.0, 0.4, 3.42) | 1.75 / 8.00 / 8.00 / 20.0 |
| `medium_standard` | `SN_Schooner_Fame` | `SN_Socket_Weapon_Port_1` | Light | (−8.6, 1.4, 3.08) | 1.05 / 1.05 / 2.35 / 20.0 |
| | | `SN_Socket_Weapon_Starboard_1` | Light | (−8.6, −1.4, 3.08) | 1.05 / 1.05 / 2.35 / 20.0 |
| | | `SN_Socket_Weapon_Bow` | Medium | (10.0, 0.2, 2.89) | 1.10 / 1.10 / 1.25 / 20.0 |
| `large_efficient` | `SN_Paddle_Freighter` | `SN_Socket_Weapon_Port_1` | Side | (13.0, 2.3, 3.34) | 0.75 / 1.90 / 4.10 / 20.0 |
| | | `SN_Socket_Weapon_Starboard_1` | Side | (13.0, −2.3, 3.34) | 0.75 / 1.90 / 4.10 / 20.0 |
| | | `SN_Socket_Weapon_Port_2` | Light | (−14.0, 2.2, 3.25) | 1.45 / 1.90 / 6.35 / 20.0 |
| | | `SN_Socket_Weapon_Starboard_2` | Light | (−14.0, −2.2, 3.25) | 1.45 / 1.90 / 6.35 / 20.0 |
| `large_performance` | `SN_Ironclad` | `SN_Socket_Weapon_Port_1` | Heavy | (13.5, 3.1, 4.60) | 1.90 / 1.90 / 7.30 / 20.0 |
| | | `SN_Socket_Weapon_Starboard_1` | Heavy | (13.5, −3.1, 4.60) | 1.90 / 1.90 / 7.30 / 20.0 |
| | | `SN_Socket_Weapon_Port_2` | Medium | (−17.5, 2.6, 4.60) | 1.90 / 1.90 / 3.35 / 20.0 |
| | | `SN_Socket_Weapon_Starboard_2` | Medium | (−17.5, −2.6, 4.60) | 1.90 / 1.90 / 3.35 / 20.0 |

合计 **14 个**：PS 3 / SF 3 / PF 4 / IC 4；class 覆盖 Light / Medium / Heavy / Side（无 Tower 船位）。

### 6.2 4 艘船的帆索 socket（22 个）

| 内容船体 | 数量 | socket 名单 |
| --- | ---: | --- |
| `small_efficient`（明轮客船） | 0 | 无帆索（只有旗杆） |
| `medium_standard`（纵帆船） | 7 | `Mast_Fore/Main`、`Yard_Fore/Main`、`Sail_Fore/Main/Jib` |
| `large_efficient`（明轮货轮） | 6 | `Mast_Fore/Main`、`Yard_Fore/Main`、`Sail_Fore/Main` |
| `large_performance`（铁甲舰） | 9 | `Mast/Yard/Sail × Fore/Main/Mizzen` |

合计 **22 个**；完整坐标与 `rig_*` extras 见 [RIG_KIT_CONTRACT.md §4.4](RIG_KIT_CONTRACT.md)。明轮客船不建 socket 是对资产事实的如实镜像，不是遗漏。

## 7. Core 资源键

`dev_mods/core/manifest.json` 已登记 **12 个 `model.weapon.*` + 12 个 `model.rig.*` + 4 个 `model.ship_part.*`**，全部指向 `assets/models/{weapons,rig,ship_parts}/SN_*.glb`（Core 本地副本存在，GLB 外贴图走 `shared_materials/`）。战斗结算不读这些键；`ShipVisualAssembler` 通过 manifest 解析 `model.weapon.*` 加载视觉 GLB（当前游戏内 loadout 主要来自截图预览注入，等待 player 装配入口），编辑器资源选择器同样使用这些候选键。

武器 12 件（8 件完整武器 + 4 件 kit 部件；class/profile 取自各 GLB Root extras）：

| 资源键 | GLB | `weapon_class` | `assembly_profile` | `muzzle_count` |
| --- | --- | --- | --- | ---: |
| `model.weapon.deck_gun` | `SN_Weapon_DeckGun.glb` | Light | yaw_pitch | 1 |
| `model.weapon.heavy_cannon` | `SN_Weapon_HeavyCannon.glb` | Heavy | yaw_pitch | 1 |
| `model.weapon.mortar` | `SN_Weapon_Mortar.glb` | Heavy | yaw_pitch | 1 |
| `model.weapon.repeater` | `SN_Weapon_Repeater.glb` | Medium | yaw_pitch | 1 |
| `model.weapon.broadside` | `SN_Weapon_Broadside.glb` | Side | pitch_only | 4 |
| `model.weapon.ballista` | `SN_Weapon_Ballista.glb` | Heavy | yaw_pitch | 1 |
| `model.weapon.arrow_tower` | `SN_Weapon_ArrowTower.glb` | Tower | fixed | 1 |
| `model.weapon.harpoon_launcher` | `SN_Weapon_HarpoonLauncher.glb` | Medium | yaw_pitch | 1 |
| `model.weapon.cannon` | `SN_Weapon_Cannon.glb` | Modular | pitch_only | 1 |
| `model.weapon.gun_carriage` | `SN_Weapon_GunCarriage.glb` | Modular | base_only | 1 |
| `model.weapon.turret` | `SN_Weapon_Turret.glb` | Modular | yaw_only | 1 |
| `model.weapon.pedestal` | `SN_Weapon_Pedestal.glb` | Modular | base_only | 1 |

帆索 12 件：`model.rig.{boom,bowsprit,gaff,mast_sail,mast_steam,running,sail_gaff,sail_jib,sail_square,shrouds,stays,yard}` → `SN_Rig_*.glb`。

船体部件 4 件：`model.ship_part.{deck,funnel,hatch_cover,mast}` → `SN_ShipPart_{Deck,Funnel,HatchCover,Mast}.glb`。

## 8. 编辑器操作

前置：`node SNModMaker/tools/serve.mjs` → <http://127.0.0.1:8099/>。

### 8.1 新建 / 编辑武器

0. 想一次拿到 5 件：新建模组时选「舰载武器包」模板（或 CLI `new --template weapons`），生成结果见 §1.1；已有项目也可逐件「新增定义」。
1. 左侧「战斗」分组里选「舰载武器」（运行时 2.0 类型，带 2.0 徽标；分组来自 `content_types.json` 的 `combat`），点「新增定义」。
2. 侧栏会新建 `content/weapons.json` 并写 `schema_version: "2.0"`；表单按三组给出战斗 / 装配 / 经济字段，`kind`、`weapon_class`、`assembly_profile` 为带中文标签的枚举，`color` 以文本填写 `#RRGGBB`。
3. 「视觉资源」里选模型：候选来自 `manifest.assets` 的 `model.weapon.*`（§7）；也可直接输入资源键。
4. 补齐 `zh_CN` / `en` 文案，点「保存条目」提交多语言键事务。
5. 打开「校验」，修完 error / warning；导出时内容文件保持 `schema_version: "2.0"`。

### 8.2 编辑船体安装点

1. 打开「船体」定义；船体专属模块区之外新增 `weapon_sockets` / `rig_sockets` 表格（数组控件）。
2. 每行可增删，编辑 `name` / `socket_class`（或 `socket_kind`、`mast_id`）/ `socket_index` / `position` 三元数组 / `clearance_*` / `mount_scale` / `note`；重复的 `name` / `socket_index`、未知 class/kind、缺失必填会就地提示（Schema + 编辑器语义校验）。
3. 保存后 `hulls.json` 里就是普通 2.0 内容字段；运行时 Schema 校验通过，但视觉装配仍读 GLB extras，直到 `ShipVisualAssembler` 接入。

### 8.3 校验 / 导出行为

- 内容文件固定 `schema_version: "2.0"`，版本不符报 `schema_version_mismatch`；`weapons` 是 active 类型，不再产生 `draft_content` 警告；使用 `capability` 未写进 `manifest.capabilities` 时按 capability 去重报 `capability_undeclared`。
- ZIP / 目录导出与「导出并覆盖到发布包 mods/」对 `weapons` 内容正常放行（运行时支持）；只有剧情草案 / 未知类型 / 版本不符会被拦截。
- Content CLI（agent / CI）同一套类型清单：可直接从零新建武器项目（写 `content/weapons.json`，`schema_version: "2.0"`，并自动在 `manifest.capabilities` 声明 `content.combat.v1`）：
  ```powershell
  node SNModMaker/tools/content.mjs new --mod SNModMaker/mods/my_weapons --id my_weapons `
    --name "我的武器包" --template weapons
  ```
  `--draft` 只接受剩余剧情草案类型；`describe weapons` 看字段与骨架，`add --type weapons` 往既有项目再加一条，`validate --mod dev_mods/core --json` 复核 Core 导入。编辑器对 `map_configs.data.story.flow_id` 的假阳性引用错误已修复，Core 导入 **0 error**（warning 允许）。

## 9. 校验规则

三层，硬闸门在 Schema，其余为编辑器 / 测试守护：

| 层 | 规则 | 级别 |
| --- | --- | --- |
| Schema | `schema_version`/`content_type` const；`data` 必填 15 项；`enum`（kind / weapon_class / mount_class / assembly_profile）；数值 min/max；`color` `#RRGGBB`；`materials[].id` 为定义 ID 且 `amount ≥ 0.1`；`additionalProperties: false` 拒绝未知字段（如把模拟器 `mass` 直接写进 data） | error |
| 编辑器语义（草稿） | `min_range < range`；`assembly_profile` 与 `has_yaw/has_pitch` 一致（`yaw_pitch*` 需两者为 true，`pitch_only` 需 has_pitch 且非 has_yaw，`fixed` 不应带 pivot，`base_only`/`yaw_only` 不要求 muzzle）；`muzzle_count > 1` 时 `has_muzzle` 必须 true；`weapon_class = Modular` 提示「kit 部件不可直接挂载」 | error / warning |
| 编辑器语义（船体） | `weapon_sockets` / `rig_sockets` 内 `name` 重复、`socket_index` 重复 → error；名称前缀不符合 `SN_Socket_Weapon` / `SN_Socket_` → warning；`socket_class` / `socket_kind` 不在枚举 → warning（Schema 本身已报 enum error）；帆索点缺 `mast_id` → warning | error / warning |
| Godot 回归 | `framework/tests/cases/test_schema_v2_weapons.gd`：合法 direct / broadside 样例零错误；缺必填、越界、非法枚举、非法颜色、非法材料 ID、未知字段被拒；`weapons` 在 `content_types.json.types`、`ContentTypes.all()` 中且为 active 2.0；hull socket 镜像非法条目被拒、旧 hull 内容仍合法、Core 14 + 22 个镜像通过校验；`test_combat.gd` 覆盖武器引用 / 伤害类型 / 默认武器解析 | 测试 |

## 10. D1 运行时接入现状

1. **类型提升（已完成）**：`weapons` 已在 `content_types.json.types`（`schema` / `kind: definition` / `capability` / `schema_version: "2.0"`），`ContentTypes` 与 `ContentCompiler` 会加载 `content/weapons.json`。
2. **版本策略（已完成）**：运行时按类型 `schema_version` 接收 2.0，`weapons` envelope 固定 2.0。
3. **内容落地（已完成）**：`dev_mods/core/content/weapons.json` 已含 5 件 `core:weapon/*`（5 件内置武器的 1:1 映射），`information.model` 指向 `model.weapon.*`、本地化与 manifest `content` 条目已补齐。
4. **读取路径（已完成）**：`RegistryHub` 的 `ContentTypes.WEAPON` 注册表由 `CombatOps.player_weapon_rows()` / `_weapon_state()` 消费；船体 `hull_data.weapon_sockets` 决定玩家可用炮位，显式 `ship.weapon_loadout` 优先、否则按 socket class 选字母序第一件武器；`combat.resolve` 与 `combat.view` / `combat.log` 已注册。
5. **战斗结算（已完成）**：`CombatOps` 实现抽象回合、伤害/护甲/穿甲、状态效果、撤退、战利品 roll 与确定性随机流；`CombatService` 负责 `data.combat` 落盘与耐久/战利品事务（money → `player.money + stats.income`、item → 船上 cargo、module → 当前港 warehouse、weapon 掉落折成 salvage 金钱；市场出售与经济平衡未接）。战斗视图记录 unmounted sockets 与 loot diagnostics，跨引用校验要求敌舰每个 weapon socket class 能解析到武器。尚未接：空间/弹道、部位伤害、弹药/煤耗、航行遭遇自动触发。
6. **视觉装配（部分完成）**：`ShipVisualAssembler` 仍以 GLB Root extras 为装配事实；后续切片再切到「内容定装配 + GLB 定节点」，并补齐 `yaw_limit_deg` / `pitch_limit_deg` / `mount_pad_*` / `swept_radius` / `anchor_count` 等资产已产但内容未建模字段。

## 11. 已知边界 / 待对齐

1. **内容已生效，但玩家负重/装配入口未接**：战斗自动结算会从 `hull.weapon_sockets` + 武器内容解析默认武器；游戏内尚无「购买武器 / 装配到 socket」的 UI 与持久 loadout，`ship.weapon_loadout` 仍主要由预览注入。武器经济字段（`tier/purchase_price/craft_*`）尚未接入船厂。
2. **Weapon socket `socket_index` 偏移**：GLB extras 从 1 起，内容镜像从 0 起（4 艘船均如此）。转换公式：`content_index = glb_socket_index - 1`；接入运行时前建议二选一并写死。
3. **铁甲舰 rig socket 顺序**：GLB 按桅序交错编号（`Mast_Fore 0 / Yard_Fore 1 / Sail_Fore 2 / Mast_Main 3 …`），内容镜像按 kind 分组（`Mast_Fore 0 / Mast_Main 1 / Mast_Mizzen 2 / Yard_* 3–5 / Sail_* 6–8`）；PF / SF 两边一致。运行时若按 `socket_index` 配对，必须先统一。
4. **`mast_key` vs `mast_id`**：GLB 用大写 `Fore/Main/Mizzen`，内容用小写；大小写不敏感比较或转换后再用。
5. **两处坐标口径**：GLB `translation=(x, deck_z, −y)`，内容 `[x, y, deck_z]`；不要混用。
6. **装配契约 vs 资产**：`WEAPON_SOCKET_CONTRACT.md §4` 写 `SN_Weapon_Repeater` 为 `yaw_pitch_multi` / `muzzle_count=6`，其 GLB Root extras 实际是 `yaw_pitch` / `1`；本文按资产文件记录，接运行时前需定案（改资产或改契约）。
7. **武器底座字段 F1 未修**：batch1 的 `base_footprint_x/y` 等于整机 bbox，`mount_pad_*` 尚未落地；底座适配仍以网格实测为准。
8. **模拟器 `mass` 与内容 `weight` 范围不一致**：导入旧模拟器武器配置时 1–80 之外的重量会被内容 Schema 接受（0–200），但模拟器会 clamp；反之内容里 weight=0 的武器在模拟器会被抬到 1。
