# `SNBattleSim/js/fsm_editor.mjs`

> 作用：渲染独立 FSM 工作台，支持状态拖放、端口拉线、空白处快速建状态、Delete 删除及按选中状态过滤的聚合转移编辑。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `mountFsmEditor(root, initialFsm, onChange)` | L16 |

## 契约与约束
- 状态定义可从外部以 application/x-snbattle-fsm-action 拖入画布。
- 选中状态后只显示该状态的出向转移；每条转移可使用 all/any 聚合最多 8 个条件。
- Delete 只在非表单焦点下删除当前状态；删除状态会同时删除关联转移。

模块索引：[SNBattleSim](../README.md)
