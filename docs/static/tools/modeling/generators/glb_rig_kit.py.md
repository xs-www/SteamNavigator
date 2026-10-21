# `tools/modeling/generators/glb_rig_kit.py`

> 作用：`rig_kit` 独立套件（12 件 `SN_Rig_*`）的 GLB 接口节点归一化（纯 Python）——

- 类型：项目配置/数据文件

BLEND 内为避免工作台重名用 `SN_Rig_Mast_Sail_Socket_Yard_Lower` 这类带前缀名，
导出后统一归一化为契约标准名 `SN_Mount` / `SN_Socket_Mast|Yard|Sail_*`，
并把 socket 名单写进 Root extras（`rig_sockets` / `rig_socket_count` /
`rig_socket_spec`）。Blender IDProperty 不支持字符串数组，所以名单只能在 GLB
JSON 层写，做法与 `glb_ship_sockets.py` / `glb_weapon_nodes.py` 一致。

用法：`glb_rig_kit.standardize(path, asset)`，在贴图外部化之后调用。

模块索引：[tools](../../README.md)
