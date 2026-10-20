# `tools/godot/preview_voyage_presentation.gd`

> 作用：航行演出（海图系统阶段 3）的**实机演示**：窗口模式下自动开一局、发出真实的

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L21 |
| `WINDOW` | L22 |
| `STEADY_BUILD` | L23 |
| `STANDARD_STRATEGY` | L24 |
| `SETTLE_SECONDS` | L25 |
| `CYCLE_GAP_SECONDS` | L26 |
| `CYCLE_TIMEOUT_SECONDS` | L27 |
| `SEEDS` | L28 |
| `_init() -> void` | L38 |

`voyage.start`，然后让整段演出自己播完（3D 离港 → 云层 → 海图航行 → 事件/入港 →
抵达结算），结束后换一个种子重来，方便人工反复观察。不截图、不改存档。

用法（**必须窗口模式**，`--headless` 下什么都看不见）：
  godot --path . --resolution 1440x900 --script res://tools/godot/preview_voyage_presentation.gd

自动跑完限定时间后退出（用于无人值守的自检）：
  ... --script ... -- --demo-seconds=40

## 契约与约束
- 全部走真实命令与真实 Shell：没有预录动画，也不跳过任何演出阶段。
- 事件停在「等玩家决策」时自动选第一个方案，否则演示会卡住等点击。
- 单轮看门狗：一轮超过 `CYCLE_TIMEOUT_SECONDS` 还没回港，打印告警并重开，避免
  一次逻辑卡死让窗口永远停在半路。
- 关闭窗口即结束（不写存档、不改项目设置）。

模块索引：[tools](../README.md)
