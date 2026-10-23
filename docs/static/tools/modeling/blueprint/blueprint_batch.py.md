# `tools/modeling/blueprint/blueprint_batch.py`

> 作用：工业蓝图线稿的外层批处理 CLI；为每个 `.blend` / `.glb` 启动独立 Blender 后台进程，

- 类型：项目配置/数据文件

使单件导入或渲染失败不会污染、阻断其它模型，并汇总日志与 `batch_summary.json`。

## 契约与约束
- 文件输入直接写到 `--output`；目录输入按相对路径建立子目录，避免递归扫描时同名冲突。
- 每件模型拥有独立 `blueprint.log`；批次退出码在任一任务失败时为 1，但仍处理完整清单。
- 本脚本只依赖 Python 标准库；Blender 路径可显式传入或通过 `BLENDER_BIN` / PATH 发现。

模块索引：[tools](../../README.md)
