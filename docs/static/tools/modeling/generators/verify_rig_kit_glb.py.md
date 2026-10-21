# `tools/modeling/generators/verify_rig_kit_glb.py`

> 作用：`rig_kit` 独立套件（12 件 `SN_Rig_*`）的 **GLB 独立验收**（纯 Python，

- 类型：项目配置/数据文件

不进 Blender）——期望值从 `rig_kit_batch1_generator.build_geometry()` 的纯几何推导：
节点 / 网格 / 三角面 / 世界尺寸（Y-up）/ 贴地基准 / 材质集合 / 每图元 UV /
外部共享贴图 URI 与授权字节 / Core 副本一致，以及接口契约：
`SN_Mount` + `SN_Socket_Mast|Yard|Sail_*` 节点存在且无 mesh、Root extras 含
`rig_sockets` / `rig_socket_count` / `rig_socket_spec` 与套件字段。

通过标准：12/12 `ALL OK`；否则返回非 0 退出码。
用法：`python tools/modeling/generators/verify_rig_kit_glb.py`

模块索引：[tools](../../README.md)
