# `tools/modeling/generators/dryrun_legacy_uv_b.py`

> 作用：旧资产 UV 迁移 B 的纯 Python 预检（不进 Blender）——校对船模块 / 船 / 旧小镇

- 类型：项目配置/数据文件

目标清单、旧材质 -> `SN_Tex_*` 映射是否全部落在共享材质 spec 内、运行时贴图目录是否
齐备，并用 `.design/legacy_uv_b/baseline.json`（迁移前 GLB 快照）核对基线事实。

用法：
  python tools/modeling/generators/dryrun_legacy_uv_b.py

通过标准：输出 ALL OK 并返回 0；否则列出失败项并返回 1。
基线 JSON 是本地产物（.design/ 被 gitignore），缺失时只做静态契约检查。

模块索引：[tools](../../README.md)
