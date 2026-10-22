# `tools/godot/capture_ship_assembly.gd`

> 作用：`ShipVisualAssembler` 的实机截图工具（窗口化 1440×900）：用真实 Core 内容解析 4 艘船的视觉装配计划，在真实 `ShipyardStage` / `PortStage` 场景里逐张抓图（船厂 4 艘 + 装配近景 + 港口停泊 + 航行离港 + 航行入港），每张都自检 hull / rig / 武器装配数量后才写盘。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SHIPYARD_STAGE_SCENE` | L16 |
| `PORT_STAGE_SCENE` | L17 |
| `OUT_DIR` | L18 |
| `WINDOW` | L19 |
| `SETTLE_FRAMES` | L20 |
| `SETTLE_SECONDS` | L21 |
| `VOYAGE_BEAT_SECONDS` | L22 |
| `DEPARTURE_CAPTURE_PROGRESS` | L23 |
| `ARRIVAL_CAPTURE_PROGRESS` | L24 |
| `WATCHDOG_SECONDS` | L25 |
| `TMP_PREFIX` | L26 |
| `FREIGHTER_LOADOUT` | L28 |
| `SHIPS` | L38 |
| `SHOTS` | L90 |
| `_init() -> void` | L110 |

- 关键依赖：`Bootstrap`（真实 Core 内容）、`ShipVisualPlan`（计划解析，不在工具里写死物理路径）、`ShipyardStage` / `PortStage`（游戏内真实舞台）

## 契约与约束
- 必须窗口化运行（headless 下 viewport 纹理为空），固定 1440×900；`--resolution` 与脚本内 `window_set_size` 同时设置。
- 船体 / 套件 / 武器路径全部由 `ShipVisualPlan.resolve()` 从 Core manifest + `hulls.json.rig_plan` 解析，截图即验证「内容驱动的装配」而不是硬编码资产。
- 每张截图前断言：`stage.has_ship()`、rig 报告 `mode` 与 `mounted` 数量、武器 `mounted` 数量符合预期；不满足则 `[FAIL]` 且不提交半套图。
- 截图先写 `res://tmp_*`，全部成功后才移入 `docs/design/screenshots/ship_assembly/`；任何失败退出码 1 并清理临时文件。
- 航行演出用 `begin_departure()` / `begin_arrival()` + `advance_voyage(delta)` 手动步进到固定进度，不依赖帧率。

模块索引：[tools](../README.md)
