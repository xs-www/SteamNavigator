# `tools/modeling/generators/kit_batch1_generator.py`

> 作用：模型素材库批次 1（武器套件 + 船体部件）的参数化生成器与 Blender 装配入口。

- 类型：项目配置/数据文件

8 件模块化资产：SN_Weapon_Cannon / GunCarriage / Turret / Pedestal 与
SN_ShipPart_Deck / Mast / Funnel / HatchCover。每件资产都提供固定的 Mount 空节点
与接口空节点（Trunnion / Socket / Exhaust / Hinge 等），Root 节点 extras 写
kit_family / part_role / footprint / height，供后续搭船/搭场景按 socket 拼装。

工单：`tools/modeling/briefs/sn_kit_batch1.json`
约定：1 unit = 1 m；+X 前向、+Z 向上；地面类部件根在底面中心 z=0；
火炮是俯仰子件，根 = 耳轴轴心（Mount 在原点），由炮架 Trunnion_L/R 接收。
材质：共享贴图 `SN_Tex_*`（见 `sn_kit_materials.py`）+ 世界空间盒式 UV。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_kit_batch1.py`
- 导出 GLB：`python tools/modeling/generators/export_kit_glb.py`

模块索引：[tools](../../README.md)
