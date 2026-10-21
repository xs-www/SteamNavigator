# `framework/application/queries/story_view.gd`

> 作用：新手剧情 / 教学系统的只读查询（`story.view`）。输出剧情卡、目标条、功能 /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `StoryViewQuery` | L1 |
| `execute(_params: Dictionary, context) -> Dictionary` | L18 |

商品 / 模块解锁与动作锁，供 Shell 做功能门禁与剧情 UI；不输出 counters / flags
等内部数值。

- 关键依赖：`StoryService`、`GameState.ensure_story()`

## 契约与约束
- 只在 `QueryBus` 的克隆上执行，只读、不推进阶段、不发事件。
- 未启用剧情 / 旧存档（`completed=true`）时返回 `enabled` 与全开字段，Shell 据此
  不做门禁。
- 字段形状见 `docs/design/STORY_TUTORIAL.md` §6。

模块索引：[framework/application](../README.md)
