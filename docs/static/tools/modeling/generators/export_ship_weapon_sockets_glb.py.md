# `tools/modeling/generators/export_ship_weapon_sockets_glb.py`

> 作用：M0-3 / M0-4 船侧 socket 的 GLB 归档导出（Blender 内执行，验收通过后由 Lead 运行）——

- 类型：项目配置/数据文件

4 艘船（明轮货轮 / 明轮客船 / 纵帆船 / 铁甲舰）重新导出 GLB，保留 Root extras 与新增
武器 socket / 帆索 socket 空节点，外部化共享贴图为 `shared_materials/<texture>.png`，
备份旧 GLB，同步 Core 副本，最后依次调 `glb_ship_sockets.standardize()`（武器）与
`glb_ship_rig_sockets.standardize()`（PF/SF/IC 的 Mast/Yard/Sail），把 BLEND 前缀名
归一化为 `SN_Socket_Weapon_*` / `SN_Socket_Mast|Yard|Sail_*` 并写入对应 Root 列表。

导出方式按根节点类型区分：
- 多节点船体（PF / PS / SF）：根节点归零后导出整个集合（`export_extras=True`）；
- 单 mesh 铁甲舰：根 mesh 归零，连同其 socket 子空节点一起导出（`export_extras=True`）；
  这是本轮新增——批次 B 的铁甲舰导出是 `export_extras=False`，没有子节点。

前置条件：`sn_ship_weapon_sockets.verify_all()` 必须通过（只读复核场景里的 socket）。
目标目录：`assets/models/ships/` + `dev_mods/core/assets/models/ships/`；旧 GLB 备份到
`.design/ship_sockets/backup_glb/`，导出报告写 `.design/ship_sockets/export_report.json`。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
