# `tools/modeling/generators/sn_ship_weapon_sockets.py`

> 作用：M0-3「船侧武器安装点」——4 艘可玩船（明轮货轮 / 明轮客船 / 纵帆船 / 铁甲舰）的

- 类型：项目配置/数据文件

`SN_Socket_Weapon*` 空节点规格表 + Blender 侧就地补齐 / 实测净空 / 只读自检。

## 契约（武器装配规范 v2 的船体侧，见 WEAPON_SOCKET_CONTRACT.md）
- 只加空节点，**不改任何几何**：本脚本前后会对 4 个集合做 mesh / 三角面快照比对。
- BLEND 内节点名带资产前缀（`SN_PF_` / `SN_PS_` / `SN_IC_` / `SN_SF_`），避免 4 艘船并排时
  的全局对象重名；GLB 导出后由 `glb_ship_sockets.standardize()` 归一化为
  `SN_Socket_Weapon_*`（与武器 v2 的 BLEND 前缀 → GLB 标准名做法一致）。
- 节点是 Root 的空子节点：+X = 武器炮口/前向；侧舷点 rotZ ±90° 让 +X 指向舷外，艏点 0°、艉点 180°。
- 原点落在甲板安装面（down-ray 实测 deck top），因此不同船的 socket z 不同。
- 节点 extras：`socket_class` / `clearance_r` / `clearance_h` / `clearance_x` / `clearance_y` /
  `mount_scale` / `socket_index`；Root extras 增加 `weapon_socket_count` 与 `socket_spec`
  （`weapon_sockets` 名字列表由 GLB 后处理写入，Blender IDProperty 不支持字符串数组）。

## clearance 语义（实测口径，声明值不得高于实测值）
- `clearance_r`：安装面以上 0.12 m，16 向水平射线的最小自由距离（m），最坏方向净空；
- `clearance_x` / `clearance_y`：在 socket 自身局部坐标下，+X/-X 与 +Y/-Y 两对方向自由距离的最小值；
  侧舷点 local +X 指向舷外（炮管方向）、local Y 沿船体纵轴（炮列方向），因此侧舷炮用 cx/cy 判适配；
- `clearance_h`：从安装面向上首个遮挡高度（m）；露天按 20 m 封顶；
- 炮管/炮口允许越出舷外，武器 `envelope_*` 不计入 clearance。

## 规格表口径
- 每个 socket 声明 `x/y（船体局部 m）、rot_z、socket_class` 与**保守声明**的 clearance（比实测低 0.05 m）；
- `apply_sockets()` 实测 z 与净空，先断言「实测 >= 声明 - TOL」再写节点；不达标直接抛错，不静默降级；
- `verify_scene()` 只读复核节点名 / 父级 / 局部坐标 / 旋转 / extras / 根 extras / 集合无害回归；
- 纯 Python 部分（规格校验、期望 GLB 节点名）不 import bpy，供 `dryrun` / GLB 验收脚本复用。

用法：
  Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
  纯 Python： python tools/modeling/generators/sn_ship_weapon_sockets.py --check

模块索引：[tools](../../README.md)
