# `tools/modeling/generators/verify_kit_glb.py`

> 作用：模型素材库批次 1 的 GLB 结构与共享贴图自检（纯 Python，不进 Blender）。

- 类型：项目配置/数据文件

期望值直接从 `kit_batch1_generator.py` 的纯几何生成器推导（parts / tri / bbox /
socket 名），因此本脚本验证的是「导出完整性」：节点/网格/三角面/尺寸/材质/UV/
外部共享贴图 URI 与授权 PNG 字节一致、根节点 extras 字段齐全；几何内容本身由
dryrun 与独立 Verifier 负责。

用法：
    python tools/modeling/generators/verify_kit_glb.py
通过标准：每件 ALL OK，否则返回非 0 退出码。

模块索引：[tools](../../README.md)
