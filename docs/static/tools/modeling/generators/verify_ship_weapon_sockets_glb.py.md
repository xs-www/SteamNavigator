# `tools/modeling/generators/verify_ship_weapon_sockets_glb.py`

> 作用：M0-3 / M0-4 船侧 socket 的 **GLB 独立验收**（纯 Python，不进 Blender/Godot）——

- 类型：项目配置/数据文件

核对 4 艘船 GLB 的几何不变量（节点/网格/图元/三角面/世界尺寸/材质/UV/外部贴图），
以及新增 socket 空节点（标准名、Root 子级、extras、局部坐标/朝向、Root
`weapon_sockets` 与 `rig_sockets` 列表）。

## 判定口径
- 几何必须与「迁移后基线」逐项一致：三角面 / 网格数 / 图元数 / 世界尺寸取自
  `verify_legacy_uv_b_glb.EXPECTED`（批次 B 已验收值）；socket 只允许新增**无 mesh 的空节点**，
  因此节点数 = 基线节点数 + socket 数，mesh 数不变；
- 外部贴图：每个 `images[].uri` 必须是 `shared_materials/<texture>.png`、文件存在且与
  `docs/design/textures/shared_materials/tiles/<texture>.png` 逐字节一致；Core 副本与 assets 一致；
- socket 节点：标准名 `SN_Socket_Weapon_*`、无 mesh、是 Root 直接子节点；
  extras 必须与 `sn_ship_weapon_sockets.SHIPS` 声明值完全一致；
  glTF 局部 translation 必须等于 (x, deck_z, -y)（Blender Z-up → glTF Y-up）；
  +X 朝向必须等于 Blender rot_z 旋转后的艏向/舷向；
- Root extras：`weapon_sockets` 列表顺序 = 规格 socket_index 顺序，数量与 `weapon_socket_count` 一致。

用法：`python tools/modeling/generators/verify_ship_weapon_sockets_glb.py [--asset NAME]`
通过标准：每艘船 `ALL OK`；否则返回非 0 退出码。

模块索引：[tools](../../README.md)
