# `framework/ui/screens/flow/clue_log_screen.gd`

> 作用：线索列表页（阶段 4.4.4）。只读展示 `clue.list` 查询的输出：全部 active 线索

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ClueLogScreen` | L1 |
| `close_requested (signal)` | L21 |
| `clue_selected (signal)` | L23 |
| `TEXT` | L25 |
| `MUTED` | L26 |
| `BRASS` | L27 |
| `TEAL` | L28 |
| `GREEN` | L29 |
| `RED` | L30 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L35 |

（类型 / 来源 / 等级 / 剩余时效 / 分级披露内容 / 可调查状态）与折叠的过期历史；
点击条目回到海图并选中该线索，关闭返回海图。页面不查询后端、不执行命令。

- 关键依赖：`clue.list` 查询的 ViewModel、`SNSectionHeader`、`SNSeaChartPanel.compass_key`
  （八方位换算复用面板的纯函数）。

## 契约与约束
- `bind(vm, translate)` 注入数据；文案全部来自本地化键，键缺失时回退中文/键名。
- 不自行计算规则：等级文案、剩余时效、行情区间全部来自查询层裁剪后的字段；
  任何等级都不会拿到 `target_port_id` / `credibility` / 真实 `search_zone`。
- 整张卡片是一个按钮：`clue_selected(clue_id)` 由 Shell 转成「回海图并选中」。
- 过期历史只读 `vm.expired`，灰显并标注 `ui.clue.expired`；不参与 active 计数。
- 空态（active + expired 都为空）显示 `ui.clue.list.empty` 引导文案。

模块索引：[framework/ui](../../README.md)
