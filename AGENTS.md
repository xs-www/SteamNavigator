# Steam Navigator — Agent 工作指南

## 环境

- **Godot 路径**: `C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- **Godot 版本**: 4.7.2 stable（通过 Steam 安装）
- **运行测试**: `$env:GODOT_BIN = "C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"; pwsh ./tools/test.ps1`

## 协作规则

- 改代码前先读 `README.md` 和 `docs/static/` 下的静态文档，禁止一上来通读全部代码文件。
- 改完代码后按 `code-static-documentation` 技能更新 `docs/static/` 并尝试更新 `todo.md`。
- 代码审查未通过时，明确需求和失败原因，禁止以通过测试为目的进行 Debug。
- 新增命令/查询必须经 `FrameworkApi` 注册，并补测试。
- 数值改动先改 Core JSON（`dev_mods/core/content/`），不在框架里写死。
