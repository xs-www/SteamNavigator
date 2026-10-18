# `framework/ui`

> 展示层。包含可玩外壳、共享 Godot Theme、可复用控件与独立 UI Kit 展示场景。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `components/README.md` | 框架源文件：README.md | 本页 |
| `components/sn_badge.gd` | 紧凑状态徽标：中性、成功、警告和危险四种语义色。 | [查看](./components/sn_badge.gd.md) |
| `components/sn_badge.tscn` | 框架源文件：sn_badge.tscn | 本页 |
| `components/sn_button.gd` | 可复用语义按钮：在 Inspector 中选择主操作、次操作、危险或幽灵样式。 | [查看](./components/sn_button.gd.md) |
| `components/sn_button.tscn` | 框架源文件：sn_button.tscn | 本页 |
| `components/sn_panel.gd` | 可复用界面表面：基础、高架与内嵌三种层级。 | [查看](./components/sn_panel.gd.md) |
| `components/sn_panel.tscn` | 框架源文件：sn_panel.tscn | 本页 |
| `components/sn_resource_meter.gd` | 煤水、耐久与载重共用的标签化资源存量条。 | [查看](./components/sn_resource_meter.gd.md) |
| `components/sn_resource_meter.tscn` | 框架源文件：sn_resource_meter.tscn | 本页 |
| `components/sn_section_header.gd` | 章节标题组合控件：眉题、标题和可选右侧说明。 | [查看](./components/sn_section_header.gd.md) |
| `components/sn_section_header.tscn` | 框架源文件：sn_section_header.tscn | 本页 |
| `shell/main.gd` | 可玩 UI 外壳：共享 Theme 的主菜单、总览/市场/委托/船厂/补给/情报/出航、抵达结算、海图与诊断。 | [查看](./shell/main.gd.md) |
| `shell/main.tscn` | 框架源文件：main.tscn | 本页 |
| `showcase/ui_kit_showcase.gd` | 独立 UI Kit 展示与视觉冒烟场景，集中实例化全部可复用控件和状态。 | [查看](./showcase/ui_kit_showcase.gd.md) |
| `showcase/ui_kit_showcase.tscn` | 框架源文件：ui_kit_showcase.tscn | 本页 |

## 模块契约

- UI 只识别 Query/Command 与定义类型，不识别 core 内容。
- 公共视觉状态优先进入 Theme variation；业务页面只负责布局与数据绑定。
