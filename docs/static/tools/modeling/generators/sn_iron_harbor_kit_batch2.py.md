# `tools/modeling/generators/sn_iron_harbor_kit_batch2.py`

> 作用：铁港建筑套件第二批的 Blender 装配/自检/导出 harness：把 4 个纯 Python 生成器的 Part 变成单 mesh 对象、按栋写共享 trim sheet 材质与 UV、逐栋自检、导出内容 GLB、出预览图。

- 类型：项目配置/数据文件

## 契约与约束

- `BUILDINGS` 是唯一配置表：生成器文件、资产名、工作台摆放（y=150 一排）、目标尺寸、三角面上下限，以及**本栋采样哪一档 trim sheet cell**（同 6 材质槽、不同 cell = 同一套共享贴图下的建筑差异，不增贴图）。
- `build_all()` 只删除本集合内这 4 个 `SN_HT_*_LOD0` 对象，旧 `SN_Harbor_Town` 占位资产原样保留；`report_all()` 逐栋校验 tri 预算/尺寸/落地/轴心/材质槽/调色板/网格健康/UV/贴图，并用全场景 digest 回归证明没有动其它对象。
- `export_all()` 逐栋把 object.location 临时归零后单对象导出到 `dev_mods/core/assets/models/props/SN_HT_<Name>.glb`（内嵌贴图）；**旧 GLB 只在备份不存在时复制一次**，绝不覆盖；`restore_legacy()` 一次还原 4 个旧资产。
- `render_previews()` 每栋 3 张（3/4 街道 / +X 正交正视 / 屋顶）到 `docs/design/screenshots/iron_harbor_architecture/`；渲染前必须 `view_layer.update()`（新建对象的 `matrix_world` 在 depsgraph 求值前是单位矩阵，会导致取景跑到原点、渲出纯背景），并且只保留当前一栋可见，临时相机/太阳/世界背景在 `finally` 里还原。

模块索引：[tools](../../README.md)
