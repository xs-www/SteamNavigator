# `.github/workflows/release.yml`

> 作用：`v*` tag 触发的发布流水线：测试 → 生成物检查 → SDK runtime/draft 校验 → 导出 Windows/Linux → 打包标准便携目录 → GitHub Release。

- 类型：项目配置/数据文件

## 契约与约束

- 发布前运行 `sdk/validate.gd --mode=runtime`；core manifest 声明的内容 / 本地化 / 资产缺失或存在运行时不加载的草案内容时直接失败。
- SDK 示例门禁：1.0 / 混合示例走 runtime 校验，`draft_weapons_pack` 与 `story_pack_iron_tide` 只走 `--mode=draft`。
- 草案发布拦截：`sdk/pack_mod.gd --release` 对草案内容必须失败（退出码 1），确保不可发布内容不会被误打包。
- 发布前运行 `gen_content_types.mjs --check`，防止框架常量或编辑器类型目录落后于 `content_types.json`。
- 发布前运行 `gen_static_docs.mjs --check`，防止源码注释、sidecar 或符号位置变化后漏提交 `docs/static`。
- Windows/Linux 压缩包统一为顶层 `SteamNavigator/`，内含 exe、`mods/core-*.snavmod.zip` 与 `config/config.json`。
- `core-*.snavmod.zip` 同时作为独立 Release 资产，并参与 `SHA256SUMS.txt`。
