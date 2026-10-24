# `tools/modeling/generators/export_grand_harbour_terminal_glb.py`

> 作用：`SN_Grand_Harbour_Terminal` 大型航站楼（architecture 类别）的 GLB 归档导出：

- 类型：项目配置/数据文件

把工作台集合 `SN_GHT_Grand_Harbour_Terminal_Prototype` 导出为
`assets/models/architecture/SN_Grand_Harbour_Terminal.glb`，同步
`dev_mods/core/assets/models/architecture/` 运行时副本，并用
`glb_shared_textures.externalize_glb(..., prefer_authored=True)` 把内嵌贴图
外部化为 `shared_materials/<texture>.png`；最后写入 `.design/terminal/build_report.json`
（从 Blender 集合**只读**统计的实际 tri / 节点 / bbox / 材质 / sign tri，供
`verify_grand_harbour_terminal_glb.py` 验收读取）并保存工作台。

约定（见 MODELING_WORKFLOW §8 / §12）：
- 数据源：`sn_grand_harbour_terminal_generator` 的 `ASSET` / `COLLECTION` /
  `ROOT_NAME` / `TARGET_SIZE` / `TRI_BUDGET` / `TRI_FLOOR` / `WORKBENCH_POS`；
  导出前**不**重建（先由 Lead / Builder 执行 `build_all()`）；
- 导出前把根空物体 location 临时归零、只选集合内对象，导出后还原（轴心即 root
  datum；glTF +Y up，进入 Godot 后尺寸 = Blender (X, Z, Y)）；
- 覆盖前把旧 GLB 备份到 `.design/architecture/backup_glb/`（旧文件不存在则跳过）；
- 共享贴图：`sn_shared_materials.texture_report()` 的全部授权 tile 复制到两处
  `architecture/shared_materials/`（条数不写死，随 spec 增长）；
- 全部完成后 `bpy.ops.wm.save_mainfile()` 保存工作台。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
    report = export_all()

模块索引：[tools](../../README.md)
