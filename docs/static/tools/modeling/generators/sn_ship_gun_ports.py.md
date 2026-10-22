# `tools/modeling/generators/sn_ship_gun_ports.py`

> 作用：船体侧**炮门安装点** `SN_Socket_GunPort_*` 的规格表 + Blender 就地补齐 / 实测 / 只读自检

- 类型：项目配置/数据文件

—— 穿船壳炮（casemate gun）模块的挂载基准，与甲板武器 socket（`SN_Socket_Weapon_*`，
原点在甲板面）**语义不同**：本类 socket 的原点在**炮门平面中心**，`+X` = 炮膛轴线（舷外）。

## 当前范围
- `SN_Ironclad`：每舷 6 个炮门、两舷共 12 个（x = ±3.5 / ±10.5 / ±17.5，z 1.30–3.20）；
- 其它船体本轮不补：它们没有炮门开口，需要先做「炮门舱段 / port cassette」适配件，
  否则炮管会直接从完好的船壳板里长出来（见 WEAPON_SOCKET_CONTRACT.md §9 边界）。

## 契约
- 只加空节点、**不改几何**：apply 前后对集合做 mesh / tri / 对象名快照比对；
- BLEND 内名字带资产前缀（`SN_IC_Socket_GunPort_Port_1`），GLB 导出后由
  `glb_gun_ports.standardize()` 归一化为 `SN_Socket_GunPort_Port_1` 并写 Root `gun_port_sockets`；
- 节点旋转：Blender XYZ 欧拉 `(0, rot_y, rot_z)`，把模块局部 `+X` 转到炮膛轴线
  （`rot_z` 含 12° 前外张、`rot_y` 含 1.7° 上抬，由 `sn_ironclad_generator.gun_port_pose()` 给出）；
- 节点 extras（机器可读）：`socket_spec / socket_index / side_index / port_class / port_w / port_h /
  sill_z / deck_z / inboard_depth / outboard_clearance / lid / lid_hinge_z /
  elev_min_deg / elev_max_deg / traverse_deg / mount_scale / note`；
- 实测口径：`inboard_depth` 从炮门平面内侧 0.20 m 沿 -X 射线量门内自由纵深（封顶 8 m），
  `outboard_clearance` 从门外 0.15 m 沿 +X 量舷外自由距离（封顶 8 m）；声明值不得高于实测。

用法：
  Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
  纯 Python： python tools/modeling/generators/sn_ship_gun_ports.py --check

模块索引：[tools](../../README.md)
