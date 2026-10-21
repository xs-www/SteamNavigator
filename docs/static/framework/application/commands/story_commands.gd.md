# `framework/application/commands/story_commands.gd`

> 作用：新手剧情 / 教学系统的命令包装：`story.advance`（剧情卡继续）、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `StoryCommands` | L1 |
| `advance(_params: Dictionary, context) -> Dictionary` | L18 |
| `skip(_params: Dictionary, context) -> Dictionary` | L24 |
| `observe(params: Dictionary, context) -> Dictionary` | L30 |

`story.skip`（跳过整段教程）、`story.observe`（Shell 转发成功命令 / UI 事件）。
只做参数校验与领域服务转交，状态推进在 `StoryService` / CommandBus 事务内完成。

- 关键依赖：`StoryService`、`Result`

## 契约与约束
- 只在 `CommandBus` 的 GameState 克隆上执行；失败返回 `Result.fail`，成功返回
  `Result.ok(payload, events)`，领域事件由总线发布。
- `story.observe` 的参数 `{event, data}`：`event` 为 `cmd:<command>` /
  `ui:<event>`；未知事件只是不推进，不会报错。

模块索引：[framework/application](../README.md)
