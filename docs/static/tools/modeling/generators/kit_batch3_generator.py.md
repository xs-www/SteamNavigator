# `tools/modeling/generators/kit_batch3_generator.py`

> 作用：模型素材库批次 3（P2：建筑 / 环境）的参数化生成器与 Blender 装配入口。

- 类型：项目配置/数据文件

8 件模块化资产：SN_Arch_Warehouse / Workshop / Tavern / Factory，SN_Env_Reef /
Wreck / Lighthouse / Buoy。沿用批次 1–2 的契约：每件资产 Mount 空节点 + 语义接口
（Module_Next/Prev、Door_Front、Hoist、Drive_Shaft、Gantry、Top、Lamp…），Root
extras 写 kit_family / part_role / datum / footprint / height / waterline。

工单：`tools/modeling/briefs/sn_kit_batch3.json`
约定：1 unit = 1 m；+X 前向、+Z 向上；建筑根在体量底面 z=0，环境件根在水线 z=0
（礁石到 z=-3.0、残骸船底到 z=-1.6、浮标吃水裙到 z=-0.7），灯塔由礁石 Top 托起。
材质：共享贴图 `SN_Tex_*`（本批不新增贴图），见 `sn_kit_materials.py`。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_kit_batch3.py`
- 导出 GLB：`python tools/modeling/generators/export_kit_batch3_glb.py`

模块索引：[tools](../../README.md)
