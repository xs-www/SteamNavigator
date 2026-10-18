# `framework/ui/components/sn_section_header.gd`

> 作用：章节标题组合控件：眉题、标题和可选右侧说明。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSectionHeader` | L2 |

## 契约与约束

- 内部子节点只创建一次，运行时和 `@tool` 编辑器预览共享同一同步路径。
- detail 为空时隐藏右侧标签，标题区自动占满剩余宽度。

模块索引：[framework/ui](../README.md)
