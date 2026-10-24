# `tools/modeling/generators/sn_grand_harbour_terminal_generator.py`

> 作用：大型港口航站楼 SN_Grand_Harbour_Terminal 的参数化生成器（纯 Python 几何 +

- 类型：项目配置/数据文件

Blender 装配入口）。参照铁港参考图的中央钟楼、三拱门廊、铜绿屋面、连续拱廊与
海堤广场，生成 132 m 宽 × 72 m 深 × 56.5 m 高的单件地标建筑。

契约：
- 1 unit = 1 m；+X 为正面（港池/固定机位方向），+Y 为建筑长轴，+Z 向上。
- 根节点 SN_GHT_Root 在平台中心地面 (z=0)；所有几何在根局部坐标中生成。
- 15 个 mesh：Quay_Base / Quay_Stairs / Quay_Balustrade / Plaza_Furniture /
  Central_Block / Central_Entrance / Portico / Wings / Wing_Arcades /
  Wing_Windows / Pavilions / Roofs / Tower / Tower_Clock / Details；
  Blender 侧另加 SN_GHT_Sign（黄铜文字铭牌，纯几何干跑不计入）。
- 材质全部为共享贴图 SN_Tex_*（含新增 SN_Tex_Copper_Green），由
  sn_shared_materials.apply_collection(space="root") 统一写节点与 UV。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_grand_harbour_terminal.py`

模块索引：[tools](../../README.md)
