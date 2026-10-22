# `tools/godot/capture_story_act3.gd`

> 作用：阶段 4.5.5「船厂 / 客舱 / 旅客」真实渲染截图工具（窗口模式）。走完教学前

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L22 |
| `OUT_DIR` | L23 |
| `WINDOW` | L24 |
| `SEED` | L25 |
| `STEADY_BUILD` | L26 |
| `WATCHDOG_SECONDS` | L27 |
| `CARGO_HOLD` | L28 |
| `SMALL_CABIN` | L29 |
| `SHOTS` | L31 |
| `_init() -> void` | L41 |

三段，在第三港抓三张 1440×900 截图：只上架 1 人客舱的船厂、卸货舱并装好客舱后的
船厂、以及自动接取的第三主线旅客委托。

用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
  godot --path . --resolution 1440x900 --script res://tools/godot/capture_story_act3.gd

输出（1440×900，写入 `docs/design/screenshots/story/`）：
  tutorial_shipyard_cabin.png       第三港船厂：候选只剩小型客舱
  tutorial_shipyard_refit.png       卸下货舱、装好客舱后的船厂
  tutorial_passenger_contract.png   第三主线：送 1 名旅客

## 契约与约束
- 全程用真实 Shell / 真实命令推进；探索出航 / 结算用领域命令并补发 Shell 的
  `cmd:explore.start` / `ui:arrival_settled` 观测，不伪造渲染数据。
- 硬性断言：第三港船厂候选只有 `core:module/small_cabin`；客舱安装后
  `passenger_capacity = 1`；第三主线 `main_03` 含 1 名旅客且无货箱。

模块索引：[tools](../README.md)
