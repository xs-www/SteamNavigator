# `framework/ui/components/sn_task_tracker.gd`

> 作用：HUD 任务追踪条（阶段 4.6 Phase A）——显示 `task.view.active_task` 的类别、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNTaskTracker` | L1 |
| `TEXT` | L16 |
| `MUTED` | L17 |
| `BRASS` | L18 |

标题与当前步骤（进度 / 目的地 / 还差多少），并提示还有几个其它任务。非阻塞、
不拦截点击，位置由 Shell 摆放。

- 关键依赖：`task.view` 的 Task / Step 字段、本地化回调

## 契约与约束
- 纯展示：不查状态、不发信号；只按 step.kind 选择文案模板。
- 名称字段（货物 / 港口）先用 `_tr` 翻译内容 key，再填进框架模板。
- 只显示当前任务；完整列表在委托页 / 后续任务页。

模块索引：[framework/ui](../README.md)
