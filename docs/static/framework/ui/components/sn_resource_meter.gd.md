# `framework/ui/components/sn_resource_meter.gd`

> 作用：煤水、耐久与载重共用的标签化资源存量条。

- 关键依赖：`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNResourceMeter` | L2 |

## 契约与约束

- 当前值在 0 到最大值之间显示；最大值最低为 0.1，避免无效 ProgressBar 范围。
- 色调只切换 Theme variation，名称、数值、单位与安全提示保持同一信息结构。

模块索引：[framework/ui](../README.md)
