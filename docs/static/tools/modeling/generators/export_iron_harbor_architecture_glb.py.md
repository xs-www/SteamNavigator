# `tools/modeling/generators/export_iron_harbor_architecture_glb.py`

> 作用：把 `SN_HT_Warehouse_Long_LOD0` 装配进 PortStage 的导出/还原工具：备份旧内容 GLB → 单对象导出（带内嵌 trim sheet 贴图）到内容路径 → 保留候选副本；`restore_legacy_glb()` 还原。

- 类型：项目配置/数据文件

## 契约与约束

- 内容路径 `dev_mods/core/assets/models/props/SN_HT_Warehouse_Long.glb`；备份与候选在 `.design/buildings/iron_harbor/`（`_legacy.glb` / `_R1.glb`），备份只在缺失时复制，绝不覆盖。
- 导出前把 object.location 临时归零（几何为局部坐标、轴心=底面中心），导出后还原；glTF Y-up、单对象、无相机灯光，与 `export_town_glb.py` 同参数。材质用默认实现：6 个材质各带一张 512² baseColor 贴图，贴图**内嵌**进 GLB（因此单文件 1.4 MB 级；Godot 会把内嵌图**解包**成 GLB 同级的 `<glb>_<image>.png`，那是构建产物，已在 `.gitignore`）。
- PortStage 经 `ResourceLoader.load()` 读取已导入场景，替换 GLB 后必须 `godot --headless --path . --import` 刷新缓存，否则仍渲旧模型；M1 起内容路径已装带贴图版本，回滚用 `restore_legacy_glb()` + 再 import（旧备份 sha256 `2576e3db…`）。

模块索引：[tools](../../README.md)
