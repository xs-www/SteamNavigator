# `tools/modeling/generators/glb_ship_sockets.py`

> 作用：船侧武器 socket 的 GLB 后处理（纯 Python）——把 BLEND 内带资产前缀的

- 类型：项目配置/数据文件

`SN_PF_Socket_Weapon_Port_1` 这类节点归一化为契约标准名 `SN_Socket_Weapon_Port_1`，
并把本次 socket 名单作为 `weapon_sockets` 列表写进船体 Root 节点的 extras。

## 为什么需要后处理
- 4 艘船在同一个 Blender 工作台里并排，`SN_Socket_Weapon_Port_1` 这类标准名会撞全局对象命名空间
  （Blender 静默加 `.001`）；所以 BLEND 内统一带资产前缀，导出后再归一化，做法与
  `glb_weapon_nodes.py`（武器 v2）完全一致。
- Blender 的 IDProperty 不支持字符串数组，`weapon_sockets` 列表只能在 GLB JSON 层写入
  （Blender 侧只保留 `weapon_socket_count` / `socket_spec`）。

## 契约
- 每个 socket 节点必须存在且唯一、名字以 `SN_Socket_Weapon_` 开头、且是 Root 节点的子节点；
- Root extras：`weapon_sockets`（按 socket_index 顺序的名字数组）、`weapon_socket_count`、
  `socket_spec = "hull-sockets@1"`；其余既有 extras（asset / version / …）原样保留；
- mesh / Root 名字不变，BIN chunk 不受影响（只重写 JSON chunk）。

用法：`glb_ship_sockets.standardize(path, asset)`，在贴图外部化之后调用。

模块索引：[tools](../../README.md)
