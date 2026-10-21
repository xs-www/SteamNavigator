# `framework/ui/components/sn_story_objective.gd`

> 作用：新手剧情 / 教学系统的非阻塞目标条（阶段 4.5）：顶部居中的小面板，显示

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNStoryObjective` | L1 |

当前剧情目标文案与进度（`故事目标（2/4）`）。不锁输入、不遮挡操作。

- 关键依赖：`story.view.objective` 的 `text_key / progress / target`、本地化回调

## 契约与约束
- `bind(text_key, progress, target, translate)` 只显示，不推进剧情、不发信号。
- `mouse_filter = IGNORE`：目标条不拦截点击；位置由 Shell 负责摆放。
- 进度 `target <= 0` 时只显示目标文案。

模块索引：[framework/ui](../README.md)
