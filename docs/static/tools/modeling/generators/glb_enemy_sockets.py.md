# `tools/modeling/generators/glb_enemy_sockets.py`

> 作用：`combat_kit` 敌舰 GLB 的 **socket 后处理（纯 Python）**——把导出时仍带 BLEND 资产前缀的

- 类型：项目配置/数据文件

`SN_ES_Socket_Weapon_Port_1` / `SN_ER_Socket_GunPort_Port_1` 归一化为契约标准名
`SN_Socket_Weapon_Port_1` / `SN_Socket_GunPort_Port_1`，确保 socket 是 Root 的直接空子节点，
并把 socket 名单写进 Root extras；最后按 `combat_kit_generator` 的期望集合做完备性校验。

## 为什么需要后处理
- 4 艘敌舰在同一个 Blender 工作台并排建，`SN_Socket_Weapon_Port_1` 这类标准名会撞 Blender
  全局对象命名空间（静默加 `.001`）；所以 BLEND 内统一带资产前缀（`SN_ES_` / `SN_EG_` /
  `SN_EM_` / `SN_ER_`），导出后再归一化（做法同 `glb_ship_sockets.py` / `glb_gun_ports.py`）；
- Blender 的 IDProperty 不支持字符串数组，`weapon_sockets` / `gun_port_sockets` 名单只能在
  GLB JSON 层写入（Blender 侧只保留 `weapon_socket_count` / `gun_port_socket_count` 与 spec）。

## 契约
- 期望集合**完全一致**：`ck.expected_weapon_socket_names(asset)` +
  `ck.expected_gun_port_names(asset)`；缺 / 多 / 重名 / 改名后重名都直接失败，**失败不写盘**
  （抛 RuntimeError，保留可诊断报告，不落半成品）；
- 每个 socket 节点必须存在且唯一、是 Root 的直接子节点、不带 mesh；
- Root extras：`weapon_sockets`（按 socket_index 顺序的名字数组）、`weapon_socket_count`、
  `socket_spec = "hull-sockets@1"`；有炮门的资产（当前只有 `SN_Enemy_Ironclad_Raider`）再写
  `gun_port_sockets` / `gun_port_socket_count` / `gun_port_socket_spec = "hull-gunports@1"`；
  没有炮门的资产会清掉残留的 `gun_port_*` extras；其余既有 extras 原样保留；
- mesh / Root 名字不变；**只重写 JSON chunk，BIN chunk 原样保留**（写盘后回读比对 BIN 字节）。

用法：`python tools/modeling/generators/glb_enemy_sockets.py <path.glb> <asset>`，
或在导出脚本里 `import glb_enemy_sockets; glb_enemy_sockets.normalize(path, asset)`。

模块索引：[tools](../../README.md)
