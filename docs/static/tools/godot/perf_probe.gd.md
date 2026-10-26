# `tools/godot/perf_probe.gd`

> 作用：渲染侧性能测量工具（真实窗口渲染，非 headless）。加载 Core → 实例化真实 shell → 逐页导航并采样帧时间/Performance 监视器，输出 JSON + 控制台表格到 `.design/perf/`，用于量化「像素数 / MSAA / 3D 舞台 vs 2D UI」各自的成本结构。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L53 |
| `STEADY_BUILD` | L54 |
| `DEFAULT_SEED` | L55 |
| `DEFAULT_OUT` | L56 |
| `DEFAULT_SCREENS` | L57 |
| `DEFAULT_RESOLUTION` | L58 |
| `MIN_SAMPLE_FRAMES` | L60 |
| `DEFAULT_SAMPLE_SECONDS` | L61 |
| `MAX_SAMPLE_FRAMES` | L62 |
| `HITCH_FRAMES` | L64 |
| `LAYOUT_FRAMES` | L66 |
| `LAYOUT_SETTLE_SECONDS` | L67 |
| `STAGE_WAIT_SECONDS` | L68 |
| `STANDARD_STRATEGY` | L70 |
| `FLOW_DRIVE_STEP` | L71 |
| `FLOW_DRIVE_MAX_SECONDS` | L72 |
| `STAGE_STATIONS` | L74 |
| `PAGE_SCRIPT_PATHS` | L81 |
| `SHIP_STAGE_3D_PATH` | L88 |
| `SHIP_VIEW_PATH` | L89 |
| `SKIN_PATH` | L90 |
| `THEME_PATH` | L91 |
| `MONITOR_DEFS` | L93 |
| `BUDGET_60_MS` | L105 |
| `BUDGET_30_MS` | L106 |
| `HITCH_MS` | L107 |
| `_init() -> void` | L140 |

## 用法
```powershell
$godot = "C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
& $godot --path . --resolution 1440x900 --script res://tools/godot/perf_probe.gd -- `
    --out=.design/perf/render_A.json --resolution=1440x900 --msaa=2
```
必须窗口模式（不能加 `--headless`），否则 SubViewport/3D 不渲染、帧时间没有意义。
默认关闭 vsync 且 `Engine.max_fps = 0`：只有不锁帧才能量到「每帧真实成本」
（强机上锁 60fps 会让所有页面都显示 16.7ms，无法归因）。

## CLI（放在 `--` 之后）
- `--out=<path>`：输出 JSON（默认 `.design/perf/render_probe.json`；相对路径按项目根解析）
- `--resolution=1440x900`：窗口尺寸（同时决定像素数）
- `--msaa=0|1|2|3`：运行时覆盖 `rendering/anti_aliasing/quality/msaa_3d` 与所有
  SubViewport 的 `msaa_3d`（0=关，1=2x，2=4x，3=8x；项目默认 2 = 4x）。`-1`（默认）不覆盖。
- `--stage-msaa=0|1|2|3`：只覆盖 3D 舞台 SubViewport 的 MSAA（隔离舞台 MSAA 成本）
- `--no-stage`：页面稳定后隐藏所有 `SNStageHost`（SubViewport 转 UPDATE_DISABLED），
  隔离 3D 舞台成本，只留 2D UI
- `--screens=overview,market`：采样页子集；默认
  `main_menu,overview,market,shipyard,sea_chart,at_sea`
- `--sample-seconds=3.0`：每页稳态采样时长（默认 3s，且至少 120 帧）
- `--seed=5201`：固定种子（与 `tools/ui_snapshot.gd` / 测试一致）
- `--tag=A`：日志标签
- `--vsync=on|off`：默认 off（不锁帧量真实每帧成本）。on 用于观察真实 exe 的
  刷新率行为（默认 vsync enabled：错过一帧就是 33ms）
- `--debug`：逐帧打印 Performance 监视器原始值
- `--shots=<dir>`：每页稳态采样后抓一张 root 视口截图（验收 2D 布局是否随窗口变）
- `--isolate=overview,market`：同进程「舞台显示 N 帧 → 隐藏 N 帧」交替采样，
  用配对帧时间差隔离 3D 舞台成本（同进程内漂移抵消），配合 `--isolate-cycles` / `--isolate-frames`
- `--no-teardown`：跳过收尾（不拆 shell / 不 shutdown），直接 quit；
  用于复现「真实 exe 退出时 GLES3 清理阶段 0xc0000005」
- `--mount-zip=<path>`：模拟发布版（挂载 mod pack zip，从 zip 读原始 PNG/GLB）

## 采样口径
- 「hitch 窗口」：切页后立刻连续采样 120 帧，捕捉 UI 全量重建 / shader 编译 / 舞台装配
  的卡顿（每个页面 `_refresh()` 都会重建整棵页面树，见 main.gd `_rebuild_ui`）。
- 「稳态样本」：等舞台站位过渡结束 + 布局稳定后采样 `--sample-seconds` 且 ≥120 帧，
  记录帧时间分布 min/median/p95/p99/max、>16.7/>33.3/>100ms 帧数与 Performance 监视器。
- `at_sea` 页是航行演出页：`voyage.start` → 手动推进 `VoyagePresentation` 到云幕散开，
  再在演出继续播放的状态下采样；若演出提前结束（页面被卸载）则记录 `stopped_early`。
- 每页同时记录 SubViewport（尺寸 / MSAA / update_mode）、`SNStageHost` 状态、
  节点/Control 数量，用于审计「隐藏页面是否仍渲染 / 几个 SubViewport」。

## 退出码
0 = 请求的页面全部完成且有 ≥120 帧样本；1 = 有页面失败 / 样本不足 / 超时。
watchdog 默认 170 秒，防脚本协程中断导致窗口挂死。

模块索引：[tools](../README.md)
