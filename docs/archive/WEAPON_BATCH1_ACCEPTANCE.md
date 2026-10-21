# 武器独立建模 · 批次 1 验收记录

> 日期：2026-10-21
> 范围：把武器从船体资产里独立出来的第一批 5 件；纯资产交付，不接战斗逻辑、不改 Core manifest、不改船体。
> 工单：[sn_weapon_batch1.json](../../tools/modeling/briefs/sn_weapon_batch1.json)
> 资产映射：[ASSET_MAP.md](../design/ASSET_MAP.md#3d-舰载武器五件套2026-10-21)

## 1. 交付清单

| 资产 | GLB | tri | 包围盒 L×W×H (m) | 材质数 | Pivot |
| --- | --- | ---: | --- | ---: | --- |
| `SN_Weapon_DeckGun` | `assets/models/weapons/SN_Weapon_DeckGun.glb` | 1456 | 2.815 × 1.410 × 1.613 | 4 | Yaw + Pitch |
| `SN_Weapon_HeavyCannon` | `assets/models/weapons/SN_Weapon_HeavyCannon.glb` | 1768 | 4.800 × 2.200 × 2.200 | 6 | Yaw + Pitch |
| `SN_Weapon_Mortar` | `assets/models/weapons/SN_Weapon_Mortar.glb` | 1460 | 3.200 × 2.200 × 2.617 | 6 | Yaw + Pitch |
| `SN_Weapon_Repeater` | `assets/models/weapons/SN_Weapon_Repeater.glb` | 1820 | 2.855 × 1.600 × 1.862 | 4 | Yaw + Pitch |
| `SN_Weapon_Broadside` | `assets/models/weapons/SN_Weapon_Broadside.glb` | 3200 | 2.235 × 8.000 × 2.057 | 7 | 1 Yaw + 4 Pitch |

- 合计 **9,704 tri** / 预算 18,700。
- 全部 zmin = 0；根空物体在炮座底面中心；+X 炮口、+Z 向上。
- 侧弦炮列沿 Y 排 4 门炮、炮口 +X，上船时 Root 绕 Z 旋转 -90°。
- 共享贴图全部 `SN_Tex_*`，GLB `images[].uri = shared_materials/<texture>.png`；`assets/models/weapons/shared_materials/` 与 `dev_mods/core/assets/models/weapons/shared_materials/` 两处副本。
- 源码/脚本：`weapon_kit.py`、`sn_weapon_materials.py`、`sn_weapon_batch1_generator.py`、`dryrun_weapon_batch1.py`、`export_weapon_glb.py`、`verify_weapon_glb.py`、`render_weapon_preview.py`。

## 2. 验收证据

| 检查 | 结果 |
| --- | --- |
| 纯 Python 干跑 `dryrun_weapon_batch1.py` | ALL WEAPONS OK（命名 / tri / bbox / zmin / 网格健康 / 材质 / 贴图 / Pivot） |
| Blender Builder（Blender MCP） | 5 个集合幂等重建；45 对象；无 traceback；未保存 / 未导出 / 未用 BMH |
| 独立 Verifier（只读） | R1 发现侧弦炮列 4 根炮管与炮车颊板/弧齿全部堆在 y=0；Lead 修 `_broadside_gun` 的 gun_y 平移、`cheek_pair(y_center)`、弧齿 y 偏移；Builder 重建后 R2 **passed** |
| Verifier R2 复验 | 炮管世界 y = ±2.7/±0.9；颊板/弧齿逐炮到位；飞轮在 -Y、6 炮口可见；蒸汽助力筒存在；材质/UV/网格健康/场景回归全过 |
| GLB 结构自检 `verify_weapon_glb.py` | 5/5 ALL OK：节点/网格/tri/尺寸/材质/doubleSided/外部贴图 URI/贴图字节/UV/TEXCOORD_0/落地 |
| 场景回归 | 非武器对象 298 个名称 SHA-256 与磁盘基线一致；Camera=2、Light=1、无新增 FONT |
| 预览 | `docs/design/screenshots/weapons/` 下 10 张单件图 + `weapon_batch1_lineup.png` |

## 3. 非阻断观察 / 设计选择

- 迫击炮炮口用深色玻璃盘 + 黄铜口沿模拟“洞口”（低模不开真实内膛）；机关连发炮 6 个炮口为黄铜端面。
- 侧弦炮列每门炮 2 片护盾（共 8 片），不是 4 片整板；工单措辞已同步为“4 组炮盾（每组 2 片）”。
- 迫击炮蒸汽助力筒位于 -Y 侧，标准 3/4 会被颊板部分遮挡，属布局选择；侧视可见。
- 本批不登记 `model.weapon.*`，不接 `weapons` 内容类型与挂载 socket；等战斗内容 Schema 2.0 落地后再做。

## 4. 本地源文件

- 工作台：`.design/SN_Asset_Workbench.blend`（5 个 `SN_Weapon_*_Prototype` 集合，摆位 y=320/330/340/350/360）
- 备份：`.design/weapons/backup_glb/`
- 预览原图：`.design/weapons/preview/`

## 武器批次 1 · 装配规范 v2 迁移（2026-10-22）

按用户要求把武器改成可拼接装配规范 v2：节点统一为 `SN_Socket_Weapon` / `SN_Mount` / `SN_Pivot_Yaw` / `SN_Pivot_Pitch` / `SN_Recoil` / `SN_Muzzle`（可选层，固定武器可缺 Yaw 或 Pitch）；炮身网格挂 `SN_Recoil`（-X 后坐），`SN_Muzzle` 在炮口端面。BLEND 内因多资产并排使用资产前缀名，GLB 导出后由 `glb_weapon_nodes.standardize()` 归一化为标准名（mesh / Root 名不变）；Root extras 升到 `weapon-assembly@2`。资产已重建、GLB 重导并同步 Core；`verify_weapon_glb.py` / `verify_weapon_batch2_glb.py` 全部通过。契约见 [WEAPON_SOCKET_CONTRACT.md](../design/WEAPON_SOCKET_CONTRACT.md)。
