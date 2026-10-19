# `tools/capture_ui.ps1`

> 作用：`tools/ui_snapshot.gd` 的 PowerShell 包装：窗口 1440×900 跑真实渲染截图，并校验产物新鲜度。

- 类型：项目配置/数据文件

## 契约与约束

- 引擎解析顺序：`-GodotBin` > `$env:GODOT_BIN` > 本机默认路径；找不到直接抛错。
- 默认 seed 5201、输出 `res://docs/design/screenshots`、额外分类 `cargo_modules,misc`；`-SkipRefit` 只截正常态；`-Damage boiler:0.5` 额外生成受损状态截图并要求它们新鲜。
- 检查每张期望截图存在且比本次运行新，旧图/缺图把退出码改为 1；完整日志写入 `.godot-ui-snapshot.log`。
- 脚本保持 ASCII，兼容 Windows PowerShell 5.1 解析。

模块索引：[tools](./README.md)
