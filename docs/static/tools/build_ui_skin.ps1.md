# `tools/build_ui_skin.ps1`

> 作用：UI 皮肤一键生成 / 一致性门禁。先运行 `tools/ui/build_ui_skin.gd` 把 `docs/design/` 的控件图集与图标图集裁成 `assets/ui/skin/<skin>/` 运行纹理 + skin.json，再运行 `tools/ui/build_ui_theme.gd` 从 skin.json 生成纹理化 Theme。

- 类型：项目配置/数据文件

## 用法
```powershell
pwsh ./tools/build_ui_skin.ps1              # 重新生成 sn_v1 皮肤与 Theme
pwsh ./tools/build_ui_skin.ps1 -Check       # 逐字节校验已提交的运行纹理/skin.json/Theme 与母版一致
pwsh ./tools/build_ui_skin.ps1 -Skin sn_v1  # 指定皮肤 id
```

## 契约
- 换肤文档：`docs/design/UI_SKIN_PIPELINE.md`。只换同名同尺寸运行贴图时不需要本脚本；改母版、九宫格参数或整套皮肤时必须运行并提交产物。
- `-Check` 不写仓库文件，差异打印到 stderr 并以退出码 1 结束；CI / 提交前必须通过。
- Godot 可执行文件优先级：`-GodotBin` > `$env:GODOT_BIN` > 本机 Steam 安装路径。
- 脚本保持 ASCII-only，兼容 Windows PowerShell 5.1。

模块索引：[tools](./README.md)
