# `tools/godot/capture_voyage_presentation.gd`

> 作用：航行演出（海图系统阶段 3）的真实渲染截图工具。窗口模式挂载真正的

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L42 |
| `OUT_DIR` | L43 |
| `WINDOW` | L44 |
| `SEED` | L45 |
| `WATCHDOG_SECONDS` | L46 |
| `READY_TIMEOUT_SECONDS` | L47 |
| `TMP_PREFIX` | L48 |
| `EARLY_SAMPLE_MIN` | L51 |
| `EARLY_SAMPLE_MAX` | L52 |
| `EARLY_MAX_SHIFT_METERS` | L53 |
| `YAW_TOLERANCE` | L55 |
| `DEPARTURE_MIN_PITCH_DEG` | L57 |
| `HIGH_SHOT_MIN_PITCH_DEG` | L58 |
| `CHART_NEAR_MIN_SCALE` | L59 |
| `CHART_STEADY_TOLERANCE` | L60 |
| `ROUTE_MAX_DISTANCE` | L62 |
| `ROUTE_ENDPOINT_TOLERANCE` | L63 |
| `SHOTS` | L65 |
| `_init() -> void` | L82 |

`main.tscn`，用真实命令开一局、真实发出 `voyage.start`，然后按演出自身的
里程碑抓图：离港转艏 / 3D 离港 / 高位镜头 / 出航云层 / 海图近景 / 海图稳态 /
海图航行 / 入港推近 / 3D 入港 / 抵达结算。

用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
  godot --path . --resolution 1440x900 --script res://tools/godot/capture_voyage_presentation.gd

输出（1440×900，写入 `docs/design/screenshots/voyage_presentation/`）：
  voyage_departure_turn.png    离港早期：船艏已原地转向出海方向，船还在泊位（F1）
  voyage_departure_3d.png      3D 离港：船沿出海方向驶离泊位、镜头上升
  voyage_departure_high.png    离港末段：≈83° 近垂直高位镜头（F2）
  voyage_departure_clouds.png  出航云层盖住高位镜头
  voyage_chart_near.png        海图刚接管、云层仍在散开：近景（F2，frame_scale > 2）
  voyage_chart_steady.png      云层散尽：稳态取景铺满整窗（F2/F3，frame_scale ≈ 1）
  voyage_at_sea.png            航行中：船 icon 压在金色航线折线上（F4）
  voyage_arrival_approach.png  入港云层下：海图取景正在推近（F2，veil ≥ 0.6，frame_scale > 2）
  voyage_arrival_3d.png        3D 入港：镜头下降、船从海侧驶入泊位
  voyage_arrival.png           抵达结算页

## 契约与约束
- 不想猜帧数：按演出自身的状态（阶段名 / `_presentation.veil` / 舞台
  `voyage_progress()` / `ship_yaw()` / `camera_pitch_deg()` / 海图
  `get_frame_scale()`）轮询里程碑，拿不到就以退出码 1 结束。
- **硬性数值断言**（验收反馈 F1–F4 的回归锁）：
  F1 离港 beat 20%–30% 位移 < 0.1 m 且艏向明显偏离驻泊 yaw；离港末帧艏向 =
     出海方向（< 0.05 rad）；入港首帧艏向与之相同（接缝），末段回到驻泊 yaw。
  F2 离港末帧相机俯角 ≥ 80°；海图接管近景 `frame_scale > 2`，稳态 ≈ 1；入港前
     海图推近 `frame_scale > 2`。
  F3 航行页海图尺寸铺满窗口（宽 ≥ 窗口宽-1，高 ≥ 窗口高-顶栏-航程条），不在
     ScrollContainer 内；稳态 base_zoom = 小世界 cover（真实对局 160×160 世界
     → ×9，不受手动缩放 ZOOM_MAX 限制），世界矩形覆盖整个 chart，航线不被裁。
  F4 演出航线 > 2 点、两端 = 起终港世界坐标（< 0.01）、任意进度船位离折线
     < 1 世界单位。
- 先写 `res://tmp_voyage_*`，全部成功后才移入 `docs/`，失败不留半套。
- 纯色/近纯色画面视为"读到未绘制纹理"，判失败；写完 PNG 会读回再验一次。
- 120 s 看门狗兜底：脚本错误会让协程中断而不退出，避免窗口挂住。

模块索引：[tools](../README.md)
