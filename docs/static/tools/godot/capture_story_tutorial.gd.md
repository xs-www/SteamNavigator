# `tools/godot/capture_story_tutorial.gd`

> 作用：阶段 4.5.1 新手剧情框架的真实渲染截图工具（窗口模式）。开一局教程局

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L21 |
| `OUT_DIR` | L22 |
| `WINDOW` | L23 |
| `SEED` | L24 |
| `STEADY_BUILD` | L25 |
| `WATCHDOG_SECONDS` | L26 |
| `SHOTS` | L28 |
| `_init() -> void` | L37 |

（`run.start tutorial=true`，seed 20260421），挂出真实的剧情卡，再推进剧情展示
非阻塞目标条 / 功能门禁后的补给页入口，抓两张 1440×900 截图。

用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
  godot --path . --resolution 1440x900 --script res://tools/godot/capture_story_tutorial.gd

输出（1440×900，写入 `docs/design/screenshots/story/`）：
  tutorial_card.png       开局剧情卡：标题 / 多段正文 / 继续 / 跳过教程（导航仅总览）
  tutorial_objective.png  收起剧情卡后的非阻塞目标条 + 补给页入口（门禁仍锁海图）

## 契约与约束
- 用真实 Shell / 真实 `story.view` / `story.advance` 推进，不伪造渲染数据。
- 截图前强制 zh_CN、窗口 1440×900、`shell._settings_applied = true`，避免设置
  异步覆盖语言 / 分辨率导致两张图不一致。
- 只保存非空且尺寸正确的视口纹理；失败返回非零退出码。

模块索引：[tools](../README.md)
