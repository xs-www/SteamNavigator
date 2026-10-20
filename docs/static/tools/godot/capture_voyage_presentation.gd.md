# `tools/godot/capture_voyage_presentation.gd`

> 作用：航行演出（海图系统阶段 3）的真实渲染截图工具。窗口模式挂载真正的

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L25 |
| `OUT_DIR` | L26 |
| `WINDOW` | L27 |
| `SEED` | L28 |
| `WATCHDOG_SECONDS` | L29 |
| `READY_TIMEOUT_SECONDS` | L30 |
| `TMP_PREFIX` | L31 |
| `SHOTS` | L32 |
| `_init() -> void` | L44 |

`main.tscn`，用真实命令开一局、真实发出 `voyage.start`，然后按演出里程碑抓
三张图：云层盖住 3D 港口、海图上船只航行、抵达结算。

用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
  godot --path . --resolution 1440x900 --script res://tools/godot/capture_voyage_presentation.gd

输出（1440×900，写入 `docs/design/screenshots/voyage_presentation/`）：
  voyage_departure_3d.png    出航：船驶离泊位、镜头升到高位（还没盖云层）
  voyage_departure_clouds.png 云层盖住高位镜头（云层盖住 → 切海图的那一帧）
  voyage_at_sea.png          航行中：海图 + 航行船只 + 底部航程条
  voyage_arrival_3d.png      入港：目的港 3D 场景，镜头下降、船驶入泊位
  voyage_arrival.png         抵达结算页

## 契约与约束
- 不想猜帧数：按演出自身的状态（阶段名 / `_cloud_veil.cover` / 舞台
  `voyage_progress()`）轮询里程碑，拿不到就以退出码 1 结束。
- 先写 `res://tmp_voyage_*`，全部成功后才移入 `docs/`，失败不留半套。
- 纯色/近纯色画面视为"读到未绘制纹理"，判失败。
- 90 s 看门狗兜底：脚本错误会让协程中断而不退出，避免窗口挂住。

模块索引：[tools](../README.md)
