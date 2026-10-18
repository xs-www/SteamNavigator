# `framework/bootstrap/app_bootstrap.gd`

> 作用：SceneTree Autoload：在首场景加载前执行 Bootstrap，并保存 context/report 供 UI 读取。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `is_ready_for_scene() -> bool` | L22 |

## 契约与约束

- 检测到 `--script` 或用户参数 `--run-tests` 时直接返回，避免测试同时触发 Autoload 加载。
- 主场景通过 `AppContext.get_active()` 取组合根；若 Autoload 尚未完成则短暂等待重试。

模块索引：[framework/bootstrap](./README.md)
