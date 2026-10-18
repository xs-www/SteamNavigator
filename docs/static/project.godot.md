# `project.godot`

> 作用：Godot 项目入口：主场景、Autoload、窗口、渲染与框架扫描配置。

- 类型：项目配置/数据文件

## 契约与约束

- `run/main_scene` 指向 `framework/ui/shell/main.tscn`。
- `AppBootstrap` Autoload 在场景加载前启动内容加载；`--script` 测试模式下自行跳过。
- `framework/mods/scan_roots` 默认依次为 `res://dev_mods`、`user://mods_dev`、`user://mods`。
- `config/features` 声明 4.4 兼容；实际验证引擎为 4.7.2。
