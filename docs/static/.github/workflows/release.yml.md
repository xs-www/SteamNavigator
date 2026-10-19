# `.github/workflows/release.yml`

> 作用：`v*` tag 触发的发布流水线：测试 → core 校验 → 导出 Windows/Linux → 打包标准便携目录 → GitHub Release。

- 类型：项目配置/数据文件

## 契约与约束

- 发布前运行 `sdk/validate.gd`；core manifest 声明的内容 / 本地化 / 资产缺失时直接失败。
- 发布前运行 `gen_content_types.mjs --check`，防止框架常量或编辑器类型目录落后于 `content_types.json`。
- Windows/Linux 压缩包统一为顶层 `SteamNavigator/`，内含 exe、`mods/core-*.snavmod.zip` 与 `config/config.json`。
- `core-*.snavmod.zip` 同时作为独立 Release 资产，并参与 `SHA256SUMS.txt`。
