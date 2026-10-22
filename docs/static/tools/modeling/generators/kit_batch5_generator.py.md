# `tools/modeling/generators/kit_batch5_generator.py`

> 作用：模型素材库批次 5（M1-2：`base_kit` 基地生产建筑）的参数化生成器与 Blender

- 类型：项目配置/数据文件

装配入口。

5 件模块化资产：SN_Base_Sawmill（锯木厂）/ Smelter（冶炼炉）/ Foundry（铸造车间）/
Stockyard（仓库堆场）/ Defense_Tower（防御塔）。沿用批次 1–4 的契约：每件 Root +
Mount 空节点 + 语义接口（Module_Next/Prev、Drive_Shaft、Log_Input、Timber_Output、
Coal/Ore_Input、Molten_In/Out、Pour_Point、Hoist、Scale、Storage、Gate_In、
Weapon_Mount、Searchlight、Flag、Magazine、Ladder_Foot、Chimney），Root extras 写
kit_family / part_role / datum / module_x/y / module_grid / production / 体量预算。

工单：`tools/modeling/briefs/sn_kit_batch5_base_kit.json`
约定：1 unit = 1 m；+X 前向、+Z 向上；全部为地面件，根在体量底面中心（zmin=0）。
材质：共享贴图 `SN_Tex_*`（本批不新增贴图），UV 由
`sn_shared_materials.apply_collection()` 按世界空间盒式投影写入。
立面 / 屋顶工具复用批次 3，基础盒体 / 壁灯复用批次 4，保证与既有 kit 同一语言。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_kit_batch5.py`
- 导出 GLB：`python tools/modeling/generators/export_kit_batch5_glb.py`

模块索引：[tools](../../README.md)
