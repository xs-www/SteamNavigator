# `tools/modeling/generators/kit_batch2_generator.py`

> 作用：模型素材库批次 2（P1：机械 / 货物 / 码头）的参数化生成器与 Blender 装配入口。

- 类型：项目配置/数据文件

10 件模块化资产：SN_Machinery_GearSet / Winch / PowerUnit，SN_Cargo_Crate /
CoalScuttle / Tank / Pallet，SN_Dock_Structure / Jetty / Mooring。沿用批次 1 的
契约：每件资产 Mount 空节点 + 语义接口（Shaft_In/Out、Drum_Pivot、Stack_Top、
Module_Next/Prev、Socket_Mooring…），Root extras 写 kit_family / part_role /
datum / footprint / height。

工单：`tools/modeling/briefs/sn_kit_batch2.json`
约定：1 unit = 1 m；+X 前向、+Z 向上；machinery/cargo 与 dock 系缆设施根在底面
z=0；码头结构与栈桥根在水线 z=0（栈桥桩到 z=-1.30），+Y 朝水域。
材质：共享贴图 `SN_Tex_*`（含新增 `SN_Tex_Coal`），见 `sn_kit_materials.py`。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_kit_batch2.py`
- 导出 GLB：`python tools/modeling/generators/export_kit_batch2_glb.py`

模块索引：[tools](../../README.md)
