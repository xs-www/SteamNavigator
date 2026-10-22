# `tools/modeling/generators/glb_gun_ports.py`

> 作用：**炮门 socket 的 GLB 后处理**（纯 Python）——把 BLEND 内带资产前缀的

- 类型：项目配置/数据文件

`SN_IC_Socket_GunPort_Port_1` 归一化为契约标准名 `SN_Socket_GunPort_Port_1`，
并把 12 个炮门名单按 `socket_index` 顺序写进铁甲舰 Root 节点的
`gun_port_sockets` extras（附 `gun_port_socket_count` / `gun_port_socket_spec`）。

## 为什么不复用 `glb_ship_sockets.py`
甲板武器 socket（`SN_Socket_Weapon_*`）与炮门 socket（`SN_Socket_GunPort_*`）是两套语义：
前者原点在甲板安装面、后者原点在炮门平面中心；名字前缀不同，Root 列表也必须分开，
否则装配层无法区分“这门炮是坐在甲板上还是穿在船壳里”。

## 契约
- 每个炮门节点必须存在且唯一、是 Root 直接子节点、不带 mesh；
- 节点 extras 原样保留（由 `sn_ship_gun_ports.apply_ship()` 写入 Blender IDProperty，
  导出时 `export_extras=True` 带出）；
- 只重写 JSON chunk，BIN chunk 不动。

用法：`glb_gun_ports.standardize(path, "SN_Ironclad")`，在贴图外部化与
`glb_ship_sockets` / `glb_ship_rig_sockets` 之后调用。

模块索引：[tools](../../README.md)
