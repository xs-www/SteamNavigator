作用：`v*` tag 触发的发布流水线：测试与生成物门禁 → 导出 Windows/Linux → 打包标准便携目录 → 解压 ZIP 原生启动冒烟 → 发布 GitHub Release 并同步官网版本数据。

## 契约与约束

- 发布前运行 `sdk/validate.gd --mode=runtime`；core manifest 声明的内容 / 本地化 / 资产缺失或存在运行时不加载的草案内容时直接失败。
- SDK 示例门禁：2.0 示例（含 D1 `example_weapons` 与 D2 `example_fleet`）走 runtime 校验，`story_pack_iron_tide` 只走 `--mode=draft`。
- 草案发布拦截：`sdk/pack_mod.gd --release` 对草案内容必须失败（退出码 1），确保不可发布内容不会被误打包。
- 发布前运行 `gen_content_types.mjs --check`，防止框架常量或编辑器类型目录落后于 `content_types.json`。
- 发布前运行 `gen_static_docs.mjs --check`，防止源码注释、sidecar 或符号位置变化后漏提交 `docs/static`。
- 发布前运行 `tools/tests/release_smoke.test.mjs`：冒烟工具本身决定 ZIP 能否发布，解析逻辑必须回归。
- `build`（Ubuntu）在打包后、上传 artifact 前运行 `check_release_smoke.mjs --platform linux`；`smoke-windows`（windows-latest）下载同一份 artifact 再跑 `--platform windows`，`publish` 依赖两者都通过才创建 Release。Windows 包只能在原生 Windows 上验证，不能在 Linux runner 上跑。
- `check_release_smoke.mjs` 解压最终 ZIP 并用隔离的 `APPDATA` / `HOME` 等用户目录原生启动包内可执行文件：要求退出码 0、无 `SCRIPT ERROR` / 其他 `ERROR`（`ERROR: N resources still in use at exit` 这类引擎退出期资源计数除外），且 stdout 出现 `[release-smoke] main-menu-ready`。Godot 在脚本预加载失败时仍可能返回 0，因此退出码不能单独作为通过条件（`v0.2.0-dev.4` 即 0 退出但主菜单未加载）。
- `publish` 下载 artifact 后先 `sha256sum -c dist/release/SHA256SUMS.txt` 再上传，避免跨 job 传输损坏的文件被发布。
- Windows/Linux 压缩包统一为顶层 `SteamNavigator/`，内含 exe、`mods/core-*.snavmod.zip` 与 `config/config.json`。
- `core-*.snavmod.zip` 同时作为独立 Release 资产，并参与 `SHA256SUMS.txt`。
- `SHA256SUMS.txt` 的条目是 `dist/release/<文件名>` 形式的发布目录相对路径；`site_api` 镜像校验按 basename 匹配，发布路径变更时两侧测试必须同步。
- 带 `-dev.` 的 tag 自动标记 prerelease；发布成功后在同一 job 内同步 `website/assets/data/release-data.js`（`GITHUB_TOKEN` 创建的 Release 不会触发独立的 Website Release Data Sync workflow）。
