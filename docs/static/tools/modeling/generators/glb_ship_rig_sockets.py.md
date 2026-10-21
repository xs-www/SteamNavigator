# `tools/modeling/generators/glb_ship_rig_sockets.py`

> 作用：M0-4 船体帆索 socket 的 GLB 后处理（纯 Python）——把 BLEND 内带资产前缀的

- 类型：项目配置/数据文件

`SN_PF_Socket_Mast_Fore` / `SN_SF_Socket_Yard_Main` / `SN_IC_Socket_Mast_Fore`
归一化为契约标准名 `SN_Socket_Mast|Yard|Sail_*`，并把名单作为 `rig_sockets`
数组写进船体 Root 节点的 extras。

只处理 Mast/Yard/Sail 三类节点：M0-3 武器 socket（`SN_Socket_Weapon_*`）与船体
既有通用 socket（`SN_Socket_Engine/Cabin/...`）原样保留。为什么需要后处理：
3 艘船并排在同一工作台，标准名会撞 Blender 全局命名空间（静默加 `.001`）；
Blender IDProperty 也不支持字符串数组，所以名单只能在 GLB JSON 层写入
（与 `glb_ship_sockets.py` 同构）。

用法：`glb_ship_rig_sockets.standardize(path, asset)`，在贴图外部化之后调用。

模块索引：[tools](../../README.md)
