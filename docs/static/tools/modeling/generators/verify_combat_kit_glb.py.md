# `tools/modeling/generators/verify_combat_kit_glb.py`

> 作用：`combat_kit` 敌舰套件（M2-1，4 艘 `SN_Enemy_*.glb`）的 **GLB 独立只读验收**

- 类型：项目配置/数据文件

（纯 Python，不进 Blender / 不调用 MCP）。资产真源是
`tools/modeling/generators/combat_kit_generator.py` 的纯 Python 数据段
（`SHIP_CONFIGS` / `WEAPON_SOCKETS` / `GUN_PORTS` / `report()`）；本脚本只读
`assets/models/combat/` 与 `dev_mods/core/assets/models/combat/` 两处产物，逐件核对：

- **结构非空**：节点 / 网格 / 图元数 > 0；网格数 = 生成器对象数
  `report(asset)["objects"]`（每艘是多节点船，root 不是单 mesh）；
- **三角面**：GLB accessor 实算 tri 与 `report(asset)["tris"]` 完全一致，且 ≤ tri_budget；
- **世界 bbox**：按节点层级合成 TRS 后的 glTF Y-up 包围盒，与
  `SHIP_CONFIGS[asset]["bbox"]`（Blender Z-up）逐轴误差 ≤ `bbox_tol`（轴序重排 x,z,y；
  容差同样重排为 tol_x, tol_z, tol_y）；另核 glTF Y 轴 min/max = 生成器 z_min / z_max，
  证明轴心落在水线中心而不是工作台摆位；
- **贴图 / UV**：每个图元有 `TEXCOORD_0` 且数量等于 POSITION；所有材质名 `SN_Tex_*`、
  `doubleSided=true`、每个材质都有 baseColorTexture；
- **外部共享贴图**：`images[].uri` 全部形如 `shared_materials/<texture>.png`、无内嵌图、
  文件存在且与 `docs/design/textures/shared_materials/tiles/<texture>.png` 授权 tile
  逐字节一致；assets 与 dev_mods/core 两处 GLB / shared_materials PNG 副本一致；
- **root extras 契约**：`asset` / `combat_kit="enemy-ships@1"` / `enemy_class` /
  `enemy_archetype` / `weapon_sockets` / `weapon_socket_count` / `socket_spec`；铁甲舰另有
  `gun_port_sockets` / `gun_port_socket_count` / `gun_port_socket_spec`；
- **socket 节点**：名字与 `ck.expected_weapon_socket_names()` /
  `ck.expected_gun_port_names()` 完全一致、无 .001 / 重名、父级是 root、无 mesh、
  glTF translation = Blender (x, y, z) → (x, z, -y)、关键 extras 与 generator 规格一致
  （socket_class / clearance_* / mount_scale / socket_spec；炮门为 port_class / port_w /
  port_h / sill_z / deck_z / lid / elev_* / traverse_deg 等）。

## 判定口径
- 甲板 socket 的水平坐标（glTF x / z）容差 `SOCKET_POS_TOL = 0.01`；垂直坐标（glTF y）
  容差 `SOCKET_DECK_TOL = 0.03`：socket 的 z 由 Blender 侧 down-ray 实测甲板面写入，
  与解析 `deck_top()` 在艉楼等抬高甲板处（`build_raised_deck` 的 0.85 折减拱度）
  差 ≤ 0.015 m，口径与 `sn_ship_weapon_sockets.Z_TOL` 一致，避免把正确产物判失败；
- 炮门 socket 原点是解析的炮门平面中心（`ck.raider_gun_port_pose()`），三轴统一
  `SOCKET_POS_TOL`；
- tri / bbox 用生成器纯几何期望，不写死数字；`bbox` 只比较尺寸（尺寸是工单契约），
  轴心由 z_min / z_max 复核。

## 用法
    python tools/modeling/generators/verify_combat_kit_glb.py
    python tools/modeling/generators/verify_combat_kit_glb.py --asset=SN_Enemy_Gunboat

通过标准：每件 ALL OK 并输出 `verify_combat_kit_glb: 4/4 ALL OK`，否则非 0 退出。

模块索引：[tools](../../README.md)
