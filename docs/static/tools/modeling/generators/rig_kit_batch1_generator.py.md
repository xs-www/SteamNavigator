# `tools/modeling/generators/rig_kit_batch1_generator.py`

> 作用：M0-4 `rig_kit` 船体帆索部件库的**独立套件生成器**（12 件 `SN_Rig_*`）与

- 类型：项目配置/数据文件

Blender 装配入口。几何全部来自 `rig_kit.py` 的同一份部件函数（与 3 艘船共源），
本文件只提供「套件布局」：每件资产的尺寸参数、材质白名单、Root datum、
`SN_Mount` / `SN_Socket_Mast|Yard|Sail` 接口点与 Root extras。

套件清单：
  SN_Rig_Mast_Sail（帆船桅杆，含桅顶平台/横担/帆箍）
  SN_Rig_Mast_Steam（蒸汽船桅杆）
  SN_Rig_Yard（横桁 + 收帆卷）
  SN_Rig_Gaff（斜桁） / SN_Rig_Boom（帆杠）
  SN_Rig_Bowsprit（艏斜桁）
  SN_Rig_Sail_Gaff / SN_Rig_Sail_Square / SN_Rig_Sail_Jib（三种帆面）
  SN_Rig_Shrouds（侧支索绳梯） / SN_Rig_Stays（前后支索） / SN_Rig_Running（动索）

契约：`docs/design/RIG_KIT_CONTRACT.md`；工单 `tools/modeling/briefs/sn_rig_kit_batch1.json`。
约定：1 unit = 1 m；+X 前向、+Z 向上；材质只用共享贴图 `SN_Tex_*`。
GLB 导出后由 `glb_rig_kit.standardize()` 把带前缀的接口节点归一化为
`SN_Mount` / `SN_Socket_*`，并把 socket 名单写进 Root extras（Blender IDProperty
不支持字符串数组）。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_rig_kit.py`
- 导出 GLB：`runpy.run_path(export_rig_kit_glb.py)`

模块索引：[tools](../../README.md)
