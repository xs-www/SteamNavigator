# `tools/modeling/generators/export_combat_kit_glb.py`

> 作用：`combat_kit` 敌舰套件（M2-1）的 GLB 落盘导出（Blender 内执行，人工 / 独立

- 类型：项目配置/数据文件

Verifier 验收通过后由 Lead 触发）—— 4 艘敌舰各自从集合导出为独立 GLB：
- 导出前强制跑武器 socket / 炮门 socket 的场景只读复核，不通过拒绝导出；
- 根空物体归零后整集合导出（`export_extras=True`），保留 Root extras；
- 共享贴图外部化为 `shared_materials/<texture>.png`（授权 tile 字节）；
- `glb_enemy_sockets.normalize()` 把 BLEND 内带资产前缀的 socket 节点归一化为
  `SN_Socket_Weapon_*` / `SN_Socket_GunPort_*`，并写 Root 名单 extras；
- 旧 GLB（若存在）备份到 `.design/combat/backup_glb/`，同步 `dev_mods/core` 副本，
  最后保存工作台 `.design/SN_Asset_Workbench.blend`。

目标目录：`assets/models/combat/` + `dev_mods/core/assets/models/combat/`；
报告：`.design/combat/export_report.json`。

用法（已连 Blender、且 socket 已 apply 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
