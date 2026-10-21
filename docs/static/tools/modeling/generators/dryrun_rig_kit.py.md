# `tools/modeling/generators/dryrun_rig_kit.py`

> 作用：`rig_kit` 套件（12 件 `SN_Rig_*`）的**纯 Python 干跑**——不进入 Blender，

- 类型：项目配置/数据文件

直接从 `rig_kit_batch1_generator.build_geometry()` 校验：
命名 / 集合前缀 / tri 预算 / bbox 与 z 基准 / 材质白名单 / 网格健康（闭合件
边界边与非流形边 = 0，单层帆面允许边界边）/ Mount + Socket 契约 / 坐标落在包围盒内 /
mesh 名与 socket 名不重名。任何一项失败返回非 0 退出码。

用法：`python tools/modeling/generators/dryrun_rig_kit.py`

模块索引：[tools](../../README.md)
