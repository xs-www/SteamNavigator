# `framework/bootstrap/app_bootstrap.gd`

> 作用：SceneTree Autoload：首场景加载前运行 Bootstrap 并保存 context / report；发布版还会先应用已校验的自动更新 pending（core 包替换 + exe 备份清理）。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `is_ready_for_scene() -> bool` | L32 |

## 契约与约束
- `--script` 测试 / `-- --run-tests` 时完全跳过（测试自行控制 Bootstrap）。
- 启动失败不抛异常：交给 `StartupReport` 与 Shell 的诊断界面；`is_ready_for_scene()` 只反映是否有可用 context。
- 自动更新应用失败只 `push_warning`，不得阻塞旧版本启动；编辑器构建不应用 `user://updates/pending`。

模块索引：[framework/bootstrap](./README.md)
