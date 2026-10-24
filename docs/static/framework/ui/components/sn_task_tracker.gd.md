# `framework/ui/components/sn_task_tracker.gd`

> 作用：HUD 任务追踪条（阶段 4.6 Phase A）——显示 `task.view.active_task` 的类别、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNTaskTracker` | L1 |

标题与当前步骤（进度 / 目的地 / 还差多少），并提示还有几个其它任务。非阻塞、
不拦截点击，位置由 Shell 摆放。

- 关键依赖：`task.view` 的 Task / Step 字段、本地化回调

## 契约与约束
- 纯展示：不查状态、不发信号；只按 step.kind 选择文案模板。
- 名称字段（货物 / 港口）先用 `_tr` 翻译内容 key，再填进框架模板。
- 只显示当前任务；完整列表在委托页 / 后续任务页。

## 皮肤与节点约束（UI 贴图层）
- 面板用 `SNPanel` 钢框纹理；类别/其它任务数取 `text.muted`、标题与步骤取
  `text.light`、前导记号取 `brass.highlight`，统一 `SNSkin.color(token)`，
  不再保留颜色常量。
- `TaskTrackerBox` / `TaskIcon` / `TaskCategory` / `TaskTitle` / `TaskStep` /
  `TaskMore` 节点名、字号（11/12/13/14）与步骤文案模板不变
  （test_story_ui 按 `TaskStep` 名字读文本）。

模块索引：[framework/ui](../README.md)
