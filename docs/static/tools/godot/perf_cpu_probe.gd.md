# `tools/godot/perf_cpu_probe.gd`

> 作用：CPU 侧性能取证探针（headless）：启动链路分阶段耗时、`run.start` worldgen

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L31 |
| `SEA_CHART_VIEW_SCRIPT` | L32 |
| `STEADY` | L33 |
| `STANDARD_STRATEGY` | L34 |
| `ZIP_SCAN_ROOT` | L35 |
| `SAVE_SUBDIR` | L36 |
| `OUTPUT_LOOSE` | L37 |
| `OUTPUT_ZIP` | L38 |
| `WATCHDOG_SECONDS` | L39 |
| `SEEDS` | L42 |
| `BOOT_RUNS` | L43 |
| `ZIP_BOOT_RUNS` | L44 |
| `QUERY_ITERS` | L45 |
| `COMMAND_ITERS` | L46 |
| `SAVE_ITERS` | L47 |
| `PAGE_ITERS` | L48 |
| `STEADY_FRAMES` | L49 |
| `PAGE_STEADY_FRAMES` | L50 |
| `PRESENTATION_STEADY_FRAMES` | L51 |
| `_init() -> void` | L65 |

分布、命令/查询 p50/p95 与 GameState 深拷贝成本、存档/自动存档开销、每页
`_rebuild_ui` 成本与查询次数、交互端到端卡顿（命令 + 整页重建）、空闲
steady-state 每帧 CPU / 对象数增长，以及 `.snavmod.zip`（release 路径）与
loose `dev_mods` 的启动/首屏对比。

- 关键依赖：`Bootstrap`、`AppContext`、`CommandBus`/`QueryBus`、`CampaignFactory`、
  `SaveService`、`framework/ui/shell/main.tscn`、`Performance`

## 契约与约束
- 只读：不修改 `framework/` / `project.godot` / `dev_mods`；存档写 `user://perf_saves`。
- 不抢 GPU：必须 `--headless`；draw calls / GPU 时间不在本工具口径内。
- 不改源码做计数：查询/命令的**处理器**耗时用运行时 `register()` 包一层 Callable 统计
  （`QueryBus`/`CommandBus` 的 `_handlers` 是普通字典）。`execute()` 里的
  `GameState.clone()` 不在 handler 计时内，因此每页另外用 `state.clone()` 实测值补上。
- 每帧 CPU 用 `await process_frame` 的墙钟间隔做口径：headless 没有 vsync/渲染，
  这个间隔就是整帧 CPU。`Performance.TIME_PROCESS` 在 headless + `--fixed-fps 60`
  下会返回一个不随帧变化的陈旧值（原样写进 JSON 但不作结论依据）。
- zip 模式必须最后跑：`ProjectSettings.load_resource_pack` 挂了就卸不掉。
- 输出：stdout 摘要 + `res://.design/perf/cpu_probe_loose.json`（`--mode=zip` 时
  `cpu_probe_zip.json`）。任何阶段异常都不静默：写进 `notes` 并继续下一阶段。
- 复现命令（仓库根目录）：
  `godot --headless --path . --fixed-fps 60 --script res://tools/godot/perf_cpu_probe.gd -- --mode=all`
  `godot --headless --path . --script res://tools/godot/perf_cpu_probe.gd -- --mode=boot`
  `godot --headless --path . --script res://tools/godot/perf_cpu_probe.gd -- --mode=zip --zip=release/SteamNavigator/mods`

模块索引：[tools](../README.md)
