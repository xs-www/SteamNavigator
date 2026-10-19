# 原生工作区：在编辑器里直接改 `dev_mods/core`

> 版本：2026-10
> 适用：SNModMaker + 本地服务（`node SNModMaker/tools/serve.mjs`）
> 目标：把游戏原生模组目录（默认 `dev_mods/`）当作编辑器工作区，保存直接写回磁盘，不导出 ZIP。

## 1. 启动

```powershell
node SNModMaker/tools/serve.mjs
# 打开 http://127.0.0.1:8099/ → 项目 → 最近项目
```

本地服务默认把仓库的 `dev_mods/` 作为工作区根。可用环境变量改到其他目录：

```powershell
$env:SNMODMAKER_WORKSPACE_ROOT = "D:\desktop\sisi_apps\SteamNavigator\dev_mods"
```

## 2. 打开与保存

- 「最近项目」的磁盘区分两段：`mods/`（编辑器自己的项目副本）和 **工作区**（`dev_mods/<id>`，行尾标「工作区」）。
- 点工作区行打开 `core` 后，编辑定义/本地化与编辑普通项目完全一致。
- 保存（`Ctrl+S` 或 1.6 秒自动保存）**直接写回 `dev_mods/core/`**：
  - 修改/新增定义：写回对应 `content/*.json`；
  - 删除定义：从文件里移除；内容文件被从 manifest 删除时，磁盘文件也会删除；
  - 新增内容文件：按所选类型创建并加入 manifest；
  - 本地化：写回 `localization/*.json`。
- **资产（`assets/**`）不会被改写**：工作区打开时只读取 manifest 的资产键与路径，保存时不会把 GLB/PNG 二进制写回；新添加的资源（带 dataUrl）才会写入。

## 3. 边界与注意

- 工作区行没有「删除」按钮；服务端也拒绝 `DELETE /api/workspace/<id>`，避免误删整个原生模组。
- 保存沿用编辑器的 JSON 序列化（2 空格缩进），第一次保存会重排该文件的格式；内容本身不变。需要逐行最小 diff 时，用 `SNModMaker/tools/content.mjs` 的 `set/add` 系列。
- 工作区保存前不跑 Godot 校验；编辑器的 Schema 校验只覆盖结构。写回后建议跑：

  ```powershell
  node SNModMaker/tools/content.mjs validate --mod dev_mods/core --godot
  # 或
  $env:GODOT_BIN="..."; & $env:GODOT_BIN --headless --path . --script res://sdk/validate.gd
  ```

- 资产键使用 `dev_mods/core/manifest.json` 的声明；新增模型请放到 `dev_mods/core/assets/models/<类别>/` 再刷新编辑器项目库。发布前跑 `pwsh tools/pack_core.ps1`。
- 工作区与 `SNModMaker/mods/<id>` 是两个命名空间：即使二者同名 `core` 也不会互相遮蔽（工作区走 `/api/workspace/<id>`，普通磁盘项目走 `/api/projects/<id>`）。

## 4. 相关实现

- 服务端：[`tools/serve.mjs`](tools/serve.mjs) 的 `listWorkspaces / readWorkspaceProject / saveWorkspaceProject` 与 `/api/workspace/<id>`。
- 客户端：[`js/io.js`](js/io.js) 的 `getWorkspaceProject / putWorkspaceProject`；[`js/app.js`](js/app.js) 的项目库「工作区」行、`openWorkspaceProject()` 与 `flushDiskSave()` 分流。
- 冒烟：`node SNModMaker/tests/workspace-smoke.mjs`（打开、删定义、加内容文件、删本地化、资产不被改写、禁止整体删除）。
