# `tools/godot/capture_story_act0.gd`

> 作用：阶段 4.5.2「开局幕」真实渲染截图工具（窗口模式）。走完整教学首段：

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
| `SHOTS` | L29 |
| `_init() -> void` | L38 |

获船叙事 → 买 4 煤 2 水 → 补给受限 / 解锁海图 → 看海图并关闭 → 买够 10 煤 →
海图出航确认（默认极速）。抓「补给受限」与「首航确认」两张 1440×900 截图。

用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
  godot --path . --resolution 1440x900 --script res://tools/godot/capture_story_act0.gd

输出（1440×900，写入 `docs/design/screenshots/story/`）：
  tutorial_supply_hold.png  补给页 + 非阻塞目标条 + 补给限购状态（海图已解锁）
  tutorial_depart_fast.png  首航出航确认弹窗，锅炉策略默认「极速」

## 契约与约束
- 全程用真实 Shell / 真实命令推进（`story.advance`、`supply.buy_*`、海图开关、
  出航确认模型），不伪造渲染数据。
- 硬性断言：补给页确实被限购（煤舱不变）、目标阶段为 supply_hold / depart_brief、
  出航确认策略为 `core:strategy/fast`；失败返回非零退出码。
- 强制 zh_CN、窗口 1440×900、`_settings_applied = true`，避免设置异步覆盖。

模块索引：[tools](../README.md)
