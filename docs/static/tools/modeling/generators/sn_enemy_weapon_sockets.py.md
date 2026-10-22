# `tools/modeling/generators/sn_enemy_weapon_sockets.py`

> 作用：`combat_kit` 敌舰（4 艘：海盗单桅 / 炮艇 / 武装商船 / 铁甲舰变体）甲板武器安装点

- 类型：项目配置/数据文件

`SN_<PFX>_Socket_Weapon_<suffix>` 的 Blender 就地补齐 / 实测 / 只读复核 / 纯 Python 自检。
数据真源是 `combat_kit_generator`（本文件不抄任何坐标 / 净空数字）：
`SHIP_CLASS_ORDER`、`SHIP_CONFIGS[asset]`（root / collection / prefix）、`WEAPON_SOCKETS[asset]`、
`blend_weapon_socket_name()` / `glb_weapon_socket_name()` / `expected_weapon_socket_names()`。

## 契约（WEAPON_SOCKET_CONTRACT.md §8，`hull-sockets@1`）
- 只加空节点、不改几何：apply 前后对集合做 mesh / 三角面 / 对象名 / 材质快照比对；
- BLEND 内节点名带资产前缀（`SN_ES_` / `SN_EG_` / `SN_EM_` / `SN_ER_`），4 艘船同场景并排时
  不会撞 Blender 全局对象命名空间；GLB 导出后由 `glb_enemy_sockets.normalize()` 归一化为
  `SN_Socket_Weapon_*`；
- 节点是 Root 的空子节点（`parent = root`、`matrix_parent_inverse` 单位阵、XYZ 欧拉），
  原点在**实测甲板安装面**：+X = 炮口/前向，侧舷点 rotZ ±90° 让 +X 指向舷外；
- 节点 extras：`socket_spec / socket_index / socket_class / clearance_r / clearance_x /
  clearance_y / clearance_h / mount_scale / note`；
- Root extras：`weapon_socket_count`、`socket_spec`（`weapon_sockets` 名字数组由 GLB 后处理写，
  Blender IDProperty 不支持字符串数组）；既有 Root extras 原样保留。

## 实测口径（声明值不得高于实测值，脚本内断言、不静默降级）
- 安装面 z：从上方对甲板面 down-ray，跳过桅/帆索/烟囱等非甲板对象；要求与
  `WEAPON_SOCKETS[asset][i]["deck_z"]` 的差 ≤ `Z_TOL`（0.03 m），否则记 failure；
- 净空原点 = 安装面 + 0.12 m；
- `clearance_r`：16 向水平射线的最小自由距离（m），单向 8 m 封顶（无命中按 8）；
- `clearance_x` / `clearance_y`：socket 局部 +X/-X、+Y/-Y 两向距离取小（侧舷点 local +X 朝舷外，
  local Y 沿船体纵轴）；声明值与实测差超过 `CLEARANCE_TOL`（0.06 m）记 failure；
- `clearance_h`：从安装面向上首个遮挡高度（m），20 m 封顶。

## 幂等 / 边界
- 重跑只删除本资产前缀（`<PFX>Socket_Weapon_`）的空节点，绝不触碰其它船的 socket、
  炮门节点或几何；节点一律挂到 `SHIP_CONFIGS[asset]["collection"]`；
- `verify_ship()` 只读复核节点名 / 父级 / 局部坐标 / 旋转 / extras / Root extras / 实测值；
- 纯 Python 部分（`check()`、期望 GLB 名单）不 import bpy，供 `--check` 与 GLB 验收复用。

用法：
  Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
  纯 Python： python tools/modeling/generators/sn_enemy_weapon_sockets.py --check

模块索引：[tools](../../README.md)
