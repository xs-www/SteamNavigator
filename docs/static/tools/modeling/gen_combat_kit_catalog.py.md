# `tools/modeling/gen_combat_kit_catalog.py`

> 作用：从 `combat_kit_generator.py` 的纯 Python 数据段生成机器可读的敌舰套件目录

- 类型：项目配置/数据文件

`tools/modeling/combat_kit_catalog.json`（schema `steam-navigator/combat-kit@1`）。
目录是「运行时 / 装配层 / 文档」读取敌舰规格的唯一入口，字段全部来自生成器真源，
不在本脚本里写死任何 tri / bbox / socket 数字：

- 每艘：`asset` / `enemy_class` / `enemy_archetype` / `collection` / `root` /
  `tri_budget` / `tris`（`report()` 纯几何实算）/ `objects` / `bbox`（实算尺寸）+
  `bbox_target` / `bbox_tol`（工单目标）/ `materials`（`SN_Tex_*` 白名单结果）/
  `glb` / `core_glb` / `shared_materials`（assets 与 core 两个运行时目录）；
- `weapon_sockets`：按 `socket_index` 顺序的 `SN_Socket_Weapon_*` 规格（class / 位置 /
  deck_z / 净空 / mount_scale / note），契约 `hull-sockets@1`；`deck_z` 优先取已导出 GLB
  的节点 translation（实测甲板面），未导出时回退生成器解析值并标 `deck_z_source`；
- `gun_ports`：铁甲舰 8 个 `SN_Socket_GunPort_*` 规格（含解析炮门平面中心 `center`、
  port_class / 口径 / 门内纵深 / 舷外净空 / 俯仰极限），契约 `hull-gunports@1`；其余 3 艘为空；
- 顶层：schema / version / 单位与轴向 / 生成器与工单路径 / 类别目录 / shared_materials
  目录 / `total_tri` / `total_objects` / `enemy_classes` / socket 契约版本。

用法：
    python tools/modeling/gen_combat_kit_catalog.py

写盘口径：`json.dump(..., ensure_ascii=False, indent=1)` + 末尾换行；重复运行幂等。

模块索引：[tools](../README.md)
