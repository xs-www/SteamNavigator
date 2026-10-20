# `tools/godot/verify_harbor_diorama.gd`

> 作用：港口样片验收（只读）：场景可加载、新浮船 SN_Schooner_Fame 在场景且旧船已移除、无星条旗、水面使用自定义着色器、浮船随波运动、未接入主场景。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SCENE_PATH` | L13 |
| `BOAT_SCRIPT` | L14 |
| `WATER_SHADER` | L15 |
| `_init() -> void` | L20 |

## 契约与约束

- 先 `await process_frame` 再实例化并检查，保证 `_ready` 已执行、船的基础位姿已缓存。
- 手动以 1/30 s 推进 `bobbing_boat._process` 60 次，避免依赖真实帧率与帧数。
- 检查 `SN_Schooner_Fame` 实例存在、旧 `SN_Ship_Prototype` 不存在、纵帆船网格实例 >= 20 且名称不含 Flag。
- 失败退出码 1；只读，不写场景/资源。

模块索引：[tools](../README.md)
