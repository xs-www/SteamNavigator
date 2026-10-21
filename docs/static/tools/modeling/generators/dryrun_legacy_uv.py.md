# `tools/modeling/generators/dryrun_legacy_uv.py`

> 作用：旧资产 UV 迁移 A 的纯 Python 预检（不进 Blender）——校对 37 件目标清单、

- 类型：项目配置/数据文件

旧材质 -> `SN_Tex_*` 映射是否全部落在共享材质 spec 内、贴图真源是否存在，
并用 `.design/legacy_uv/baseline.json`（迁移前 GLB 快照）核对基线数与待迁移事实。

用法：
  python tools/modeling/generators/dryrun_legacy_uv.py
  python tools/modeling/generators/dryrun_legacy_uv.py --baseline <baseline.json>

通过标准：输出 ALL OK 并返回 0；否则列出失败项并返回 1。
注意：基线 JSON 是本地产物（.design/ 被 gitignore），缺失时只做静态契约检查。

模块索引：[tools](../../README.md)
