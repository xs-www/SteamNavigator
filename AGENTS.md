# Steam Navigator — Agent 工作指南

## 环境

- **Godot 路径**: `C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- **Godot 版本**: 4.7.2 stable（通过 Steam 安装）
- **运行测试**: `$env:GODOT_BIN = "C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"; pwsh ./tools/test.ps1`
- **Godot 导入隔离**: `SNModMaker/`（网页编辑器与本地工作区）、`.agents/`（Agent worktree）、`docs/`、`dist/`、`.design/`、`release/` 都不属于 Godot 内容，目录根部必须有 `.gdignore`。`.agents/` 被重建后要补一个空的 `.agents/.gdignore`，否则 Godot 会导入其中的仓库副本并报 GLB 外部贴图缺失。

## 协作规则

- 改代码前先读 `README.md` 和 `docs/static/` 下的静态文档，禁止一上来通读全部代码文件。
- 改完代码后按下方“静态文档”约定更新并检查 `docs/static/`，同时尝试更新 `todo.md`。
- `todo.md` 只保留 `In Progress` / `Pending` / `Recently Completed`（最近 10–15 项完成，更早历史交给 git）；每次打 `v*` tag 发布前把已完成项按版本归并进 `CHANGELOG.md`（只写有意义的变更 / 功能，不写流水账），并从 todo 移除。
- 代码审查未通过时，明确需求和失败原因，禁止以通过测试为目的进行 Debug。
- 新增命令/查询必须经 `FrameworkApi` 注册，并补测试。
- 数值改动先改 Core JSON（`dev_mods/core/content/`），不在框架里写死。

## 3D 建模

- 3D 资产/建模任务走 [MODELING_WORKFLOW.md](docs/design/MODELING_WORKFLOW.md) + Blender MCP（`execute_blender_code` / `look`）链路。
- **除非用户明确指定，否则不使用或考虑 BMH**（`D:\桌面\sisi_apps\BMH`，仍在开发中）：不运行 `bmh` 命令、不创建 BMH 任务、不安装其依赖，也不把 BMH 作为默认建模管线。

## 静态文档

- 重要源码在文件前 120 行维护 `@static-doc` 注释块，不再为新文件向 `tools/static_docs_data.mjs` 的 `FILE_DOCS` 添加条目。
- 注释块必须包含 `作用：...`（或 `role: ...`）；其余内容使用 Markdown。GDScript 用 `##`，JavaScript 用 `//`，Python/PowerShell 用 `#`。完整格式与示例见 `docs/static_headers/README.md`。
- JSON、`.tscn`、`.tres` 等不适合写注释的格式，使用镜像 sidecar：`docs/static_headers/<源码相对路径>.md`。sidecar 直接以 `作用：...` 开头，不写 `@static-doc` 标记。
- 文档来源优先级：源码 `@static-doc` > sidecar > 旧 `FILE_DOCS`。`FILE_DOCS` 只用于尚未迁移的旧文件；迁移后删除对应旧条目。
- 模块级简介/契约仍维护在 `MODULES`；不需要独立文档页的文件可由 `GROUPED_ROLES` 提供一句话职责。
- 修改代码及文档来源后运行 `node tools/gen_static_docs.mjs`，提交前必须运行 `node tools/gen_static_docs.mjs --check`。不要直接编辑生成产物 `docs/static/`。
- 生成器使用临时目录原子替换；若报告输入文件在生成期间变化，说明有并行代理正在写文件，应等待其稳定后重新生成，禁止覆盖或回退对方改动。
