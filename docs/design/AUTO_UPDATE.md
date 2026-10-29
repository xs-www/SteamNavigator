# 游戏内自动更新（Auto Update）契约

> 状态：Active（v0.2.0-dev.5 起随包发布）。本文是实现与发布流程的共同契约；游戏内更新器按此文档实现，网站/发布流水线也必须产出本文定义的清单与接口。

## 1. 目标

玩家安装一次便携包后，不再需要“下载整包 → 手动解压 → 覆盖文件夹”：

- **内容更新**（只换 `mods/core-*.snavmod.zip`）：只下载约 40 MB，重启生效。
- **本体更新**（换 `SteamNavigator.exe`）：自动下载 Windows 包（约 84 MB）、自动解压、自动替换、重启生效。
- 所有下载都校验 SHA-256/字节数；失败保留旧版本，可重试；不阻塞正常启动。

## 2. 分发约束

- 便携布局：`SteamNavigator.exe`（内嵌 PCK）、`mods/core-*.snavmod.zip`、`config/config.json`（见 `docs/static_headers/export_presets.cfg.md`）。
- 框架/引擎代码在 exe 里，因此**框架变更必须替换 exe**；内容（JSON/贴图/模型）在 core 包里，可单独替换。
- Windows 允许重命名正在运行的 exe（已实测）；更新器用“旧 exe 改名 → 新 exe 落到原名 → 重启”完成自替换。
- 安装目录必须可写；不可写（如 Program Files）时提示玩家换到可写目录，不做提权。

## 3. 发布清单 `update-manifest.json`

由发布流水线在打包后生成，作为 Release 资产上传、并打入 `SHA256SUMS.txt`。

```json
{
  "schema": 1,
  "tag": "v0.2.0-dev.5",
  "published_at": "2026-10-30T05:00:00Z",
  "platforms": {
    "windows": {
      "engine": { "path": "SteamNavigator.exe", "size": 115334344, "sha256": "<64 hex>" },
      "core": { "path": "mods/core-1.0.0.snavmod.zip", "size": 40686034, "sha256": "<64 hex>" },
      "package": { "name": "SteamNavigator-v0.2.0-dev.5-windows.zip", "size": 84384563, "sha256": "<64 hex>" }
    }
  }
}
```

约定：

- `schema` 固定 `1`；客户端遇到未知 schema 只能提示“请手动更新”，不得猜测字段。
- `published_at` 是本次构建时间（UTC，`YYYY-MM-DDTHH:MM:SSZ`），只用于阻止降级，不参与版本号比较。
- `engine.sha256` = 包内 `SteamNavigator.exe` 的 SHA-256；`core.sha256` = 包内 core zip 的 SHA-256；`package.sha256` = 平台 ZIP 的 SHA-256。
- 清单只描述文件，不描述安装路径；客户端只允许写入 `SteamNavigator.exe`、`mods/`、`config/install.json` 三个位置。
- Windows 之外暂不产出 `platforms` 条目；客户端缺失 `platforms.windows` 时视为不提供自动更新。

## 4. 网站接口 `GET /api/site/update`

同源只读接口，由 `website/server/site_api.mjs` 提供（缓存/降级与 `/api/site/release` 一致）。成功返回：

```json
{
  "ok": true,
  "data": {
    "tag": "v0.2.0-dev.5",
    "published_at": "2026-10-30T05:00:00Z",
    "manifest": { "...": "update-manifest.json 原文" },
    "files": {
      "package": {
        "url": "/downloads/v0.2.0-dev.5/SteamNavigator-v0.2.0-dev.5-windows.zip",
        "size": 84384563,
        "sha256": "<64 hex>",
        "fallback_url": "https://github.com/.../SteamNavigator-v0.2.0-dev.5-windows.zip"
      },
      "core": {
        "url": "/downloads/v0.2.0-dev.5/core-1.0.0.snavmod.zip",
        "size": 40686034,
        "sha256": "<64 hex>",
        "fallback_url": "https://github.com/.../core-1.0.0.snavmod.zip"
      }
    }
  }
}
```

- `url` 是**相对路径**（同源镜像）；镜像未就绪时为空字符串，客户端使用 `fallback_url`（GitHub 直链）。
- `sha256`/`size` 必须来自清单，且与 `SHA256SUMS.txt` 的对应条目一致；不一致时接口不得返回该文件（`url` 为空 + fallback 仍可用，但客户端校验清单后仍会拒绝）。
- 清单不可用、SHA 不匹配或 Release 数据不可用时返回 `503 { "ok": false, "error": "..." }`；客户端静默失败（自动检查）或显示错误（手动检查）。
- 镜像文件：`update-manifest.json`、最新 Windows 平台 ZIP、最新 `core-*.snavmod.zip`，仍写入 `release-downloads` 卷、只保留最新 tag；`/downloads/<tag>/<file>` 由 nginx 提供（Range/缓存策略不变）。

## 5. 本地状态

- `config/install.json`（exe 旁，随发布包生成，更新成功后由客户端重写）：

```json
{
  "schema": 1,
  "tag": "v0.2.0-dev.5",
  "published_at": "2026-10-30T05:00:00Z",
  "engine_sha256": "<64 hex>",
  "core_sha256": "<64 hex>",
  "updated_at": "2026-10-30T06:12:00Z"
}
```

- 缺失 `install.json` 时：客户端可计算本地 exe（`FileAccess.get_sha256(OS.get_executable_path())`）与 core zip 的 SHA-256 代替；只有两者都与清单一致才视为最新。
- 下载与暂存目录：`user://updates/<tag>/`（package.zip、core zip、staging/、apply.json）；成功应用后清理。
- 内容包暂存：exe 旁 `.sn-pending/`（不被 ModScanner 当作模组扫描）。

## 6. 客户端行为（`UpdateService` + `UpdateApplier`）

### 6.1 检查

- 触发：启动后延迟自动检查一次（`config/config.json` 的 `auto_check_updates`，默认 true；失败静默），以及主菜单状态行的「检查更新」按钮（显示错误）。
- `config/config.json` 新增 `update_endpoint`（默认 `https://steamnavigator.playthought.cn/api/site/update`）；编辑器/`--script` 测试模式不检查、不下载。
- 只有远端 `tag != 本地 tag` 或哈希不同才提示；远端 `published_at` 早于本地时视为“已是最新/不降级”。

### 6.2 决策

1. 本地 `engine_sha256 == 远端 engine.sha256` 且 `core_sha256 == 远端 core.sha256` → 无更新。
2. 仅 core 不同 → **内容更新**：下载 `files.core`。
3. engine 不同（无论 core）→ **本体更新**：下载 `files.package`，解压取新的 exe 与 core。
4. 清单不可用/校验失败 → 无更新/错误，不修改任何本地文件。

### 6.3 下载与校验

- HTTP(S) GET，支持进度、取消、超时；优先同源镜像 `url`，为空时用 `fallback_url`。
- 先写 `*.tmp`，完成后校验字节数与 SHA-256，再改名为正式文件；校验失败删除临时文件并报错。
- 断线重试最多 2 次；不做跨进程断点续传（镜像支持 Range，后续可加）。

### 6.4 应用

- **内容更新**：core 包放入 `mods/.sn-pending/` 并写 `apply.json`（目标文件、SHA）；下次启动在 Bootstrap 扫描前由 `UpdateApplier` 替换 `mods/core-*.snavmod.zip`、更新 `install.json`。
- **本体更新**：用 `ZIPReader` 解压包内 `SteamNavigator.exe` 与 `mods/core-*.snavmod.zip` 到 `user://updates/<tag>/staging/`；然后：
  1. 校验暂存 exe SHA；
  2. 把当前 `SteamNavigator.exe` 改名为 `SteamNavigator.exe.old`（运行中允许）；
  3. 将暂存 exe 复制到原名；失败则把 `.old` 改回并报错；
  4. 写 `config/install.json`；core 换包按内容更新流程暂存（避免运行中占用）；
  5. 提示“重启游戏生效”，提供「立即重启」按钮（启动新 exe 后旧进程退出）。
- 下次启动 `UpdateApplier` 清理 `SteamNavigator.exe.old`、应用 `.sn-pending` 内容、清理 `user://updates/` 旧目录。
- 任何一步失败都保留旧 exe/旧 core，并写入可读错误；不允许出现“exe 已删、新 exe 未就位”的中间状态（先备份改名，失败回滚）。

### 6.5 UI

- 主菜单状态行新增「检查更新」ghost 按钮（不改变原有五个入口按钮的文本/顺序/尺寸契约）。
- 发现更新时按钮文案携带版本号；点击打开更新对话框：版本说明、下载类型/大小、进度条、取消、失败原因、重启按钮。
- 文案走 `ui.update.*` 本地化键（zh_CN / en）。

## 7. 安全边界

- 清单与文件必须 HTTPS；校验和来自清单且必须与 Release 的 `SHA256SUMS.txt` 一致。
- 只写白名单路径（exe、`mods/core-*.snavmod.zip`、`config/install.json`），拒绝清单中的 `..`、绝对路径、其他目录。
- 不执行清单/压缩包内的脚本；解压只取 exe 与 core zip 两个已知条目，忽略其余（`config/` 永不覆盖玩家配置）。
- 失败不影响启动：启动链只应用已校验的 pending 文件，校验不过则忽略并告警。

## 8. 发布流水线

1. 现有步骤打平台 ZIP 与 core 包；在 `Stage portable release layout` 里为每个平台写 `config/install.json`（tag、构建时间、该平台 exe 与 core 包的 SHA-256），随平台 ZIP 一起发布；
2. 新增 `tools/build_update_manifest.mjs` 生成 `dist/release/update-manifest.json`；
3. `SHA256SUMS.txt` 必须包含清单本身（清单最后生成，不包含自身哈希，避免自引用）；
4. 上传 artifact / Release 资产都包含 `update-manifest.json`；
5. `publish` 下载 artifact 后 `sha256sum -c` 仍须通过；
6. `site-api` 镜像清单 + 平台 ZIP + core zip，并提供 `/api/site/update`。

## 9. 验收

- Node：清单生成器单测（哈希/字段/大小）、`site-api` 镜像与 `/api/site/update` 用例（清单缺失/SHA 不匹配/镜像未就绪/降级）。
- Godot：`UpdateService` 决策/校验/路径白名单单测；`UpdateApplier` 在临时目录完成 core 替换与 `.old` 清理；`gen_static_docs --check`、全量测试通过。
- 端到端：用上一版本包启动 → 检查更新 → 下载/校验 → 自替换/重启 → 新版本主菜单正常；内容更新只下 core 包并重启生效。
- 失败注入：断网、SHA 不匹配、安装目录不可写、`rename` 失败 → 旧版本仍可启动。
