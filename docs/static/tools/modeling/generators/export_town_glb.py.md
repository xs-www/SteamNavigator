# `tools/modeling/generators/export_town_glb.py`

> 作用：把 Blender 工作台 `SN_Harbor_Town` 集合的 10 件 `SN_HT_*` 逐件导出为单对象 GLB，写入 `dev_mods/core/assets/models/props/`（内容资产随 core 模组发布）。

- 类型：项目配置/数据文件

## 契约与约束

- 在 Blender 内经 `execute_blender_code` 执行；调用 `export_harbor_town()`；Builder 从不保存/导出，因此工作台保持干净，由 Lead 验收后运行。
- 逐件临时把 `object.location` 归零（几何已是局部坐标、轴心在底面中心）→ `export_scene.gltf`（GLB、Y-up、只导出选中、应用变换、不含相机/灯光/附加数据）→ `finally` 还原位置与选择。
- 输出 `dev_mods/core/assets/models/props/SN_HT_<Name>.glb`；返回 `{ok, collection, out_dir, items[], total_tris}`，逐件含 tri 与字节数；缺文件时 `ok=false`。

模块索引：[tools](../../README.md)
