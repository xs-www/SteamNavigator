# `tools/modeling/generators/export_casemate_glb.py`

> 作用：casemate gun 模块化的 **GLB 归档导出**（Blender 内执行，验收通过后由 Lead 运行）：

- 类型：项目配置/数据文件

- 导出独立炮模块 `SN_Weapon_CasemateGun.glb`（标准节点名 + 外部共享贴图 + Core 副本）；
- 重导空炮门版 `SN_Ironclad.glb`（保留 Root extras 与 4 武器 socket + 9 帆索 socket +
  12 炮门 socket），依次做贴图外部化 → 武器 socket 归一化 → 帆索 socket 归一化 →
  炮门 socket 归一化，并把名单写进 Root extras；
- 覆盖前备份旧 GLB，Core 副本与共享贴图同步，最后保存工作台 .blend。

前置条件（任一不满足直接抛错，不静默降级）：
- `sn_ship_gun_ports.verify_all()` / `sn_ship_weapon_sockets.verify_ship()` /
  `sn_ship_rig_sockets.verify_ship()` 场景复核通过；
- 场景里存在 `SN_Ironclad` 网格与 `SN_Weapon_CasemateGun_Prototype` 集合。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
