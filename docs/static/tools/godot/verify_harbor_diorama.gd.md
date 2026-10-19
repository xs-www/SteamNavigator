# `tools/godot/verify_harbor_diorama.gd`

> 作用：港口样片验收（只读）：场景可加载、水面使用自定义着色器、浮船随波运动、未接入主场景。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `_init() -> void` | L20 |

## 契约与约束

- 先 `await process_frame` 再实例化并检查，保证 `_ready` 已执行、船的基础位姿已缓存。
- 手动以 1/30 s 推进 `bobbing_boat._process` 60 次，避免依赖真实帧率与帧数。
- 失败退出码 1；只读，不写场景/资源。

模块索引：[tools](../README.md)
