# 武器独立建模 · 批次 2 验收记录

> 日期：2026-10-21
> 范围：舰载弩炮 / 载人箭塔 / 蒸汽鱼叉发射器；纯模型侧交付，不接游戏逻辑、不登记 manifest。
> 工单：[sn_weapon_batch2.json](../../tools/modeling/briefs/sn_weapon_batch2.json)
> Socket 契约：[WEAPON_SOCKET_CONTRACT.md](../design/WEAPON_SOCKET_CONTRACT.md)
> 资产映射：[ASSET_MAP.md](../design/ASSET_MAP.md#3d-舰载特殊武器三件套2026-10-21)

## 1. 交付清单

| 资产 | GLB | tri | 包围盒 L×W×H (m) | 材质数 | mount_class | Pivot |
| --- | --- | ---: | --- | ---: | --- | --- |
| `SN_Weapon_Ballista` | `assets/models/weapons/SN_Weapon_Ballista.glb` | 1956 | 5.04 × 3.05 × 2.20 | 8 | Heavy | Yaw + Pitch + Mount + 4 Anchor |
| `SN_Weapon_ArrowTower` | `assets/models/weapons/SN_Weapon_ArrowTower.glb` | 3428 | 3.80 × 3.80 × 6.55 | 8 | Tower | Mount + 4 Anchor（fixed） |
| `SN_Weapon_HarpoonLauncher` | `assets/models/weapons/SN_Weapon_HarpoonLauncher.glb` | 1908 | 4.60 × 1.84 × 2.28 | 5 | Medium | Yaw + Pitch + Mount + 4 Anchor |

- 合计 **7,292 tri** / 预算 14,500；全部 zmin = 0。
- 共享贴图 `SN_Tex_*` 外部化；GLB `images[].uri = shared_materials/<texture>.png`；dev 与 core 两处副本。
- Root `extras`：`mount_class / pivot_profile / mount_frame / base_footprint_x/y / envelope_x/y / height / swept_radius / anchor_count`（数值型）。
- 工具：`weapon_kit.py`（新增 ladder/railing）、`sn_weapon_materials.py`（三件白名单）、`sn_weapon_batch2_generator.py`、`dryrun_weapon_batch2.py`、`export_weapon_batch2_glb.py`、`verify_weapon_batch2_glb.py`、`render_weapon_batch2_preview.py`。

## 2. 验收证据

| 检查 | 结果 |
| --- | --- |
| 纯 Python 干跑 `dryrun_weapon_batch2.py` | ALL WEAPONS OK（命名 / tri / bbox / zmin / 网格健康 / 材质 / Mount / Anchor / Yaw-Pitch） |
| Blender 构建（Blender MCP） | 3 集合，38 对象（16 mesh + 22 empty）；无 traceback；批次 1 五件未被改动 |
| 独立 Verifier R1 | 发现：①弩炮 +X 侧 2 块护角块悬空（底板 x 只到 1.40，块在 1.60）；②鱼叉绞盘在 +Y 侧被压力罐/摇架遮挡（3/4 可见率 7%）；③GLB Root extras 未导出；④footprint 用整件 bbox 与 class 上限冲突；⑤缺 swept_radius |
| 修复 | ①护角块移到 x=1.20；②绞盘移到 -Y 侧（y≈-0.92..-0.66）；③导出改 `export_extras=True`；④拆 base_footprint / envelope；⑤补 swept_radius（弩炮/鱼叉 3.2，箭塔 0） |
| GLB 结构自检 `verify_weapon_batch2_glb.py` | 3/3 ALL OK：节点/网格/tri/尺寸/材质/外部贴图/UV/落地 + Root extras 全字段 |
| 场景回归 | 非武器对象名集 SHA-256 与基线一致；Camera=2、Light=1；无 FONT；无预览临时对象 |

## 3. 不规则形态 Socket 结论

- **只标准化 Mount 帧 + 底座接口 + 净空包络**；塔身、弩臂、鱼叉上部轮廓自由，不从外形匹配。
- 弩炮/鱼叉：`Heavy`/`Medium` 圆形 collar（Ø2.2 / Ø1.6）+ Yaw→Pitch；`swept_radius=3.2` 描述回转包络。
- 箭塔：`Tower` 方形 mount pad 3.0×3.0 + `fixed`；4 个 `Anchor` 对底座拉索点。
- 船体 socket 只提供甲板安装面、朝向与净空；不含武器外形。
- 详见 [WEAPON_SOCKET_CONTRACT.md](../design/WEAPON_SOCKET_CONTRACT.md)。

## 4. 非阻断观察

- 弩炮/鱼叉的 Anchor 目前只是底座角落空节点（箭塔有可见锚链板）；船体若要拉索，建议补可见地脚环。
- 鱼叉压力罐与绞盘分居 -Y/+Y 两侧，3/4 主要读到压力罐与鱼叉；绞盘在侧视/后视更清楚。
- 本批不登记 `model.weapon.*`，不接游戏侧；socket 契约接入前需要 Hull 侧提供 `SN_Socket_Weapon_*`。

## 5. 预览 / 源文件

- `docs/design/screenshots/weapons/weapon_batch2_lineup.png`
- `docs/design/screenshots/weapons/weapon_{ballista,arrow_tower,harpoon_launcher}_{three_quarter,side}.png`
- 工作台：`.design/SN_Asset_Workbench.blend`（摆位 y=380/400/420）
- 备份：`.design/weapons/backup_glb/`

## 武器批次 2 · 装配规范 v2 迁移（2026-10-22）

按用户要求把武器改成可拼接装配规范 v2：节点统一为 `SN_Socket_Weapon` / `SN_Mount` / `SN_Pivot_Yaw` / `SN_Pivot_Pitch` / `SN_Recoil` / `SN_Muzzle`（可选层，固定武器可缺 Yaw 或 Pitch）；炮身网格挂 `SN_Recoil`（-X 后坐），`SN_Muzzle` 在炮口端面。BLEND 内因多资产并排使用资产前缀名，GLB 导出后由 `glb_weapon_nodes.standardize()` 归一化为标准名（mesh / Root 名不变）；Root extras 升到 `weapon-assembly@2`。资产已重建、GLB 重导并同步 Core；`verify_weapon_glb.py` / `verify_weapon_batch2_glb.py` 全部通过。契约见 [WEAPON_SOCKET_CONTRACT.md](../design/WEAPON_SOCKET_CONTRACT.md)。
