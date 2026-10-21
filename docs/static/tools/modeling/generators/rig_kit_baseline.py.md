# `tools/modeling/generators/rig_kit_baseline.py`

> 作用：`rig_kit` 船体帆索重构的纯 Python 几何基线工具——加载 3 艘有桅帆索的船

- 类型：项目配置/数据文件

（SN_Paddle_Freighter / SN_Schooner_Fame / SN_Ironclad）的 `build_all_geometry()`，
逐对象记录顶点 / 面 / 三角面 / 材质计数 / 父级，并生成 SHA-256 digest。

为什么需要它：M0-4 要求 3 艘船改由 `rig_kit` 部件库参数化生成，但**几何必须与重构前
逐对象逐位一致**。Blender 装配（Pivot 位移 / 原点扣除 / 法线重算）不改顶点与面，
因此纯 Python 的 `build_all_geometry()` 输出就是可靠基线；重构前后各跑一次并对比
`BASELINE` 即可在进 Blender 之前抓住任何 0.1 mm 漂移。

用法：
- 记录（重构前，写入 `.design/rig_kit/baseline_<asset>.json`）：
  `python tools/modeling/generators/rig_kit_baseline.py --capture`
- 对比（重构后，与基线逐对象比较）：
  `python tools/modeling/generators/rig_kit_baseline.py --compare`
退出码 0 表示 0 差异；非 0 会打印差异对象与字段。

模块索引：[tools](../../README.md)
