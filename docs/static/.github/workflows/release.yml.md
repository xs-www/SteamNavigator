# `.github/workflows/release.yml`

> 作用：`v*` tag 触发的发布流水线：测试与生成物门禁 → 导出 Windows/Linux → 打包标准便携目录 → 生成自动更新清单 → 解压 ZIP 原生启动冒烟 → 发布 GitHub Release 并同步官网版本数据。

- 类型：项目配置/数据文件

## 契约与约束

- 发布前运行 `sdk/validate.gd --mode=runtime`；core manifest 声明的内容 / 本地化 / 资产缺失或存在运行时不加载的草案内容时直接失败。
- SDK 示例门禁：2.0 示例（含 D1 `example_weapons` 与 D2 `example_fleet`）走 runtime 校验，`story_pack_iron_tide` 只走 `--mode=draft`。
- 草案发布拦截：`sdk/pack_mod.gd --release` 对草案内容必须失败（退出码 1），确保不可发布内容不会被误打包。
- 发布前运行 `gen_content_types.mjs --check`，防止框架常量或编辑器类型目录落后于 `content_types.json`。
- 发布前运行 `gen_static_docs.mjs --check`，防止源码注释、sidecar 或符号位置变化后漏提交 `docs/static`。
- 发布前运行 `tools/tests/release_smoke.test.mjs` 与 `tools/tests/update_manifest.test.mjs`：冒烟工具决定 ZIP 能否发布，清单生成器决定客户端能否自动更新，解析 / 哈希逻辑必须回归。
- `build`（Ubuntu）在打包后、上传 artifact 前运行 `check_release_smoke.mjs --platform linux`；`smoke-windows`（windows-latest）下载同一份 artifact 再跑 `--platform windows`，`publish` 依赖两者都通过才创建 Release。Windows 包只能在原生 Windows 上验证，不能在 Linux runner 上跑。
- `check_release_smoke.mjs` 解压最终 ZIP 并用隔离的 `APPDATA` / `HOME` 等用户目录原生启动包内可执行文件：要求退出码 0、无 `SCRIPT ERROR` / 其他 `ERROR`（`ERROR: N resources still in use at exit` 这类引擎退出期资源计数除外），且 stdout 出现 `[release-smoke] main-menu-ready`。Godot 在脚本预加载失败时仍可能返回 0，因此退出码不能单独作为通过条件（`v0.2.0-dev.4` 即 0 退出但主菜单未加载）。
- `publish` 下载 artifact 后先 `sha256sum -c dist/release/SHA256SUMS.txt` 再上传，避免跨 job 传输损坏的文件被发布。
- Windows/Linux 压缩包统一为顶层 `SteamNavigator/`，内含 exe、`mods/core-*.snavmod.zip`、`config/config.json` 与 `config/install.json`。
- `core-*.snavmod.zip` 同时作为独立 Release 资产，并参与 `SHA256SUMS.txt`。
- `Stage portable release layout` 在打包前为每个平台写 `config/install.json`（`schema=1`、tag、UTC `published_at`、该平台 exe 的 SHA-256、core 包的 SHA-256）：游戏内更新器用它判断本地版本，避免每次启动重算 115 MB exe。`check_release_smoke.mjs` 会校验它和包内实际文件一致。
- 自动更新清单：`Package release assets` 之后、Linux 冒烟之前运行 `node tools/build_update_manifest.mjs --tag "$GITHUB_REF_NAME" --published-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --engine dist/build/windows/SteamNavigator.exe --core "$(ls dist/mods/*.snavmod.zip)" --package dist/release/SteamNavigator-${GITHUB_REF_NAME}-windows.zip --output dist/release/update-manifest.json`。清单契约见 `docs/design/AUTO_UPDATE.md` §3：`schema=1`、`published_at` 为 UTC `YYYY-MM-DDTHH:MM:SSZ`，位置字段为**便携布局**（`engine.path` 为 exe 裸名、`core.path` 为 `mods/<core 文件名>`、`package.name` 为 ZIP 文件名）；CLI 缺参 / 文件不存在 / 时间非法时 stderr + exit 1。
- `SHA256SUMS.txt` 在清单生成后一次写出：`sha256sum dist/release/*.zip dist/release/update-manifest.json dist/mods/*.snavmod.zip`。清单**不包含自身哈希**（避免自引用），但必须出现在 sums 中，这样 `publish` 的 `sha256sum -c` 会同时校验清单。
- 上传 artifact 与 Release 资产都包含 `dist/release/update-manifest.json`：artifact 路径为 `dist/release/*`，`publish` 的 `files:` 显式列出清单；`smoke-windows` 下载的 artifact 也因此带上清单。
- `SHA256SUMS.txt` 的条目是 `dist/release/<文件名>` 形式的发布目录相对路径；`site_api` 镜像校验按 basename 匹配，发布路径变更时两侧测试必须同步。
- `site_api` 镜像 `update-manifest.json` + 最新 Windows ZIP + `core-*.snavmod.zip` 并提供 `GET /api/site/update`；清单的 package / core 哈希必须与 `SHA256SUMS.txt` 一致，否则不提供更新数据。发布门禁运行 `website/tests/site-api-update.test.mjs`。
- 带 `-dev.` 的 tag 自动标记 prerelease；发布成功后在同一 job 内同步 `website/assets/data/release-data.js`（`GITHUB_TOKEN` 创建的 Release 不会触发独立的 Website Release Data Sync workflow）。
