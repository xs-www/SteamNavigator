# `tools/modeling/generators/sn_enemy_gun_ports.py`

> 作用：`combat_kit` 敌舰**炮门安装点** `SN_<PFX>_Socket_GunPort_<suffix>` 的 Blender 就地补齐 /

- 类型：项目配置/数据文件

实测 / 只读复核 / 纯 Python 自检。目前只有 `SN_Enemy_Ironclad_Raider`（中央炮房 + 单烟囱
的铁甲舰变体）有 8 个舷侧空炮门：每舷 `Port_1..4` / `Starboard_1..4`。
数据真源是 `combat_kit_generator`（本文件不抄坐标 / 尺寸数字）：
`GUN_PORTS[asset]`、`gun_port_entries()`、`gun_port_pose_for()`、`blend_gun_port_socket_name()`、
`glb_gun_port_socket_name()` / `expected_gun_port_names()`、`SHIP_CONFIGS[asset]`（root / collection / prefix）。

## 契约（WEAPON_SOCKET_CONTRACT.md §9，`hull-gunports@1`）
- 与甲板 socket 是**两套语义**：本类原点在**炮门平面中心**（炮膛轴线 ∩ 船壳面），`+X` = 炮膛轴线
  （含船型外张角 `rot_z` 与上抬角 `rot_y`），不是甲板面；名字前缀不同、Root 名单
  `gun_port_sockets` 也独立于 `weapon_sockets`；
- 只加空节点、不改几何：apply 前后对集合做 mesh / 三角面 / 对象名快照比对；
- BLEND 内名字带资产前缀（`SN_ER_Socket_GunPort_Port_1`），GLB 后处理由
  `glb_enemy_sockets.normalize()` 归一化为 `SN_Socket_GunPort_Port_1`；
- Blender XYZ 欧拉 `(0, radians(rot_y_deg), radians(rot_z_deg))`，把模块局部 +X 转到炮膛轴线；
- 节点 extras：`socket_spec / socket_index / side_index / port_class / port_w / port_h /
  sill_z / deck_z / inboard_depth / outboard_clearance / lid / lid_hinge_z /
  elev_min_deg / elev_max_deg / traverse_deg / mount_scale / note`；
- Root extras（Blender 侧）：`gun_port_socket_count`、`gun_port_socket_spec`；字符串数组
  `gun_port_sockets` 只能在 GLB JSON 层写（Blender IDProperty 不支持字符串数组）。

## 实测口径（声明值不得高于实测值，脚本内断言、不静默降级）
- `inboard_depth`：从炮门平面中心沿 **-X（局部，门内）** 偏移 0.20 m 处向 -X 射线，8 m 封顶；
- `outboard_clearance`：从中心沿 **+X（局部，舷外）** 偏移 0.15 m 处向 +X 射线，8 m 封顶；
- 断言 `实测 >= 声明 - DECLARED_TOL`（0.06 m），不达标记 failure（不抛异常、不降级声明值）。

## 幂等 / 边界
- 重跑只删除本资产前缀（`<PFX>Socket_GunPort_`）的空节点，不触碰甲板 socket / 几何；
- 节点写进 `SHIP_CONFIGS[asset]["collection"]`，父级是该船 Root；
- `verify_ship()` 只读复核名字 / 父级 / 位姿 / extras / Root extras / 实测值；
- 纯 Python 部分（`check()`、期望 GLB 名单）不 import bpy。

用法：
  Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
  纯 Python： python tools/modeling/generators/sn_enemy_gun_ports.py --check

模块索引：[tools](../../README.md)
