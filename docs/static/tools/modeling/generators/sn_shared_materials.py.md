# `tools/modeling/generators/sn_shared_materials.py`

> 作用：共享贴图材质库（材质名 ↔ 贴图 / tile_m / PBR 参数），以及 Blender 侧的材质绑定、

- 类型：项目配置/数据文件

世界空间盒式 UV 投影与验收；纯 Python 数据可在 Blender 外读取。

真源：`docs/design/textures/shared_materials/shared_materials.spec.json`
（由 `tools/art/gen_shared_material_textures.py` 生产 512² 无缝贴图）。
模型生成器只按材质名引用；贴图作为外部共享资源 `shared_materials/<texture>.png`
随 core 模组发布，多件资产在 Godot 里共享同一个 `Texture2D`。

约定：
- 1 unit = 1 m；每个材质有 `tile_m`（一张贴图覆盖多少米），UV 用世界坐标 / tile_m，
  采样器 REPEAT，因此任意大面都连续平铺、没有接缝。
- UV 投影按面法线主轴的盒式投影：X 面用 (Y,Z)、Y 面用 (X,Z)、Z 面用 (X,Y)。
- Blender 材质节点：Image Texture(sRGB, Linear, REPEAT) → Principled Base Color；
  Roughness / Metallic 来自 spec；背面剔除关闭（低模薄板双面）。
- bpy 只在函数内部 import；纯数据段可被 dryrun / 工具直接加载。

用法（Blender MCP / runpy）：
  import sn_shared_materials as sm
  sm.build_materials()
  report = sm.apply_collection(bpy.data.collections["SN_Mega_Gantry_Prototype"])

模块索引：[tools](../../README.md)
