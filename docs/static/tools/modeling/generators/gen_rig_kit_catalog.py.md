# `tools/modeling/generators/gen_rig_kit_catalog.py`

> 作用：从 `rig_kit_batch1_generator`（12 件套件）与 `sn_ship_rig_sockets`（3 艘船

- 类型：项目配置/数据文件

22 个船侧 socket）的纯 Python 真源导出机器可读目录
`tools/modeling/rig_kit_catalog.json`，供运行时装配（后续 `ShipVisualAssembler`）、
Godot 测试与文档交叉核对使用；不手写尺寸 / socket 坐标，避免第二套数据。

用法：`python tools/modeling/generators/gen_rig_kit_catalog.py`
通过标准：写出 JSON 并打印资产 / socket / tri 统计；不修改其它文件。

模块索引：[tools](../../README.md)
