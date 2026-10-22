# `tools/modeling/generators/install_lod1_kit_ships.py`

> 作用：LOD1 基础套件（M0-5）的安装器：把 `.design/lod1_kit_ships/out/<category>/`

- 类型：项目配置/数据文件

里已通过候选验收的 30 个 `SN_*_LOD1.glb` 复制进 `assets/models/<category>/` 与
`dev_mods/core/assets/models/<category>/` 两处运行时目录（覆盖前备份旧件），补齐每类
`shared_materials/` 的 11 张授权 tile，并生成机器计划
`tools/modeling/lod1_kit_ships_plan.json`（供 `gen_kit_catalog.py` 合并进 kit 目录）。

## 契约与约束
- 纯 Python、幂等：重复执行只重写相同字节；旧 LOD1 先备份到
  `.design/lod1_kit_ships/backup_glb/<category>/<file>.<timestamp>.glb`，不覆盖已有备份。
- 只安装候选 GLB 与共享贴图；不改 manifest / catalog / 文档（由收尾步骤分别处理）。
- 共享贴图只从 `docs/design/textures/shared_materials/tiles/` 复制；写入前逐字节比较，
  相同则跳过，避免无意义改动时间戳。
- 安装前必须存在全部 30 个候选 GLB；缺件直接失败，不部分安装。

## 重点逻辑
### `install()`
- 逐件读候选 GLB 的 `glb_world_bounds.world_bounds` / `glb_shared_textures.structure_report`
  得到 tri、bbox、材质与字节数，写入计划；随后复制 GLB 与 tile 到 dev / core 两处。
### `main()`
- `--candidate-dir` 可覆盖候选目录；`--report` 落盘安装报告；打印逐件安装结果。

模块索引：[tools](../../README.md)
