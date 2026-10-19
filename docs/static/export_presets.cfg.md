# `export_presets.cfg`

> 作用：Godot 导出预设：Windows / Linux 发布预设、PCK 内嵌与导出过滤规则。

- 类型：项目配置/数据文件

## 契约与约束

- `binary_format/embed_pck=true`：发布产物是单个 exe，资源随 PCK 内嵌。
- `exclude_filter` 额外排除 `dev_mods`、`dev_scenes`、`framework/tests`，避免把开发态松散 core 半导出进发布版。
- 发布包的标准目录（exe + `mods/` + `config/`）由 `.github/workflows/release.yml` 在导出后组装。
