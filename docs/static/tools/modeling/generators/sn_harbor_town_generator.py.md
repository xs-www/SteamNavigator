# `tools/modeling/generators/sn_harbor_town_generator.py`

> 作用：港口街景第一批 10 件的参数化几何唯一真源：顶部 `ITEMS` 参数表（名称/布局/tri 预算/目标包围盒）+ 各 `build_*` 纯几何函数，负责在 Blender 集合 `SN_Harbor_Town` 重建 10 件 `SN_HT_*` 单 mesh 对象。

- 类型：项目配置/数据文件

## 契约与约束

- `ITEMS` 与工单一一对应；`COLLECTION="SN_Harbor_Town"`、`PREFIX="SN_HT_"`、`ROW_Y=110`；重跑只删除/重建本集合内 `SN_HT_` 对象，不碰其他集合与既有对象。
- 几何函数（box/prism/roof_slab/sweep/loft 等）为纯 Python、不 import bpy，可 `dryrun_props.py` 离线干跑；`build_all()`/`report()` 才在 Blender 内执行。
- `PALETTE` 限 12 个材质；`NEW_MATERIALS`（SN_Brick/SN_Plaster/SN_Glass_Dark）已存在则复用；`_make_object()` 按材质槽顺序写入面索引、`use_smooth=false`，轴心=底面中心。
- `report()` 输出逐件 tri/尺寸误差/zmin/材质/网格健康、集合布局与 234 对象基线回归 digest（`BASELINE_DIGEST=4fe3f250…`）；Builder 只读自检、不保存/不导出。
- 质检记录：Builder 6204 tri；Verifier R1 修复 Rowboat 压条悬空、Tavern 挂灯脱开、Office 塔身暗板过厚后复验 passed=true；场景 244 objects / 223 mesh。

模块索引：[tools](../../README.md)
