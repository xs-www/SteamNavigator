# UI Assets（外部贴图皮肤）

> 运行期 UI 材质与图标的唯一来源。换同名同尺寸贴图即可整体换肤；完整流程见 [docs/design/UI_SKIN_PIPELINE.md](../../docs/design/UI_SKIN_PIPELINE.md)。

## 目录

```text
assets/ui/
  skin/sn_v1/            皮肤包（生成物，勿手改）
    nine_slice/*.png     控件九宫格纹理（源图集 0.5×）
    icons/*.png          128×128 图标（30 业务 + 4 派生 check_*）
    parts/*.png          固定比例配件（复选框、滑柄、挂钩、绳环、纸夹、蜡封）
    skin.json            样式/九宫格边距/颜色/字号/图标表（唯一数值来源）
  theme/steam_navigator_theme.tres   纹理化 Theme（由 skin.json 生成，勿手改）
  banners/main_menu_harbor.png       主菜单背景
  shipyard/blueprint_panel.png       船厂改装蓝图底板（StyleBoxTexture 九宫格）
  shipyard/ship_section.png          旧船纵剖图（无 blueprint_views 时回退）
  shipyard/ship_thumb_*.png          船体缩略图
  tokens.json                        旧原型 token 快照（已退役为历史参考）
```

## 生成与校验

```powershell
pwsh ./tools/build_ui_skin.ps1          # 图集 → 运行纹理 + skin.json + Theme
pwsh ./tools/build_ui_skin.ps1 -Check   # 校验已提交产物与母版一致（提交前必须通过）
& ./tools/test.ps1 -Suite ui_skin       # 皮肤契约测试
```

母版：[docs/design/ui_controls_v1/](../../docs/design/ui_controls_v1/)（控件）、[docs/design/ui_icons_v1/](../../docs/design/ui_icons_v1/)（图标）。母版更新后必须重新生成并提交运行纹理、`skin.json` 与 Theme 三者变化。

## 约定

- `skin/sn_v1/`、Theme 都是生成物，不要手改；要调边距/样式改生成器或母版。
- 换贴图：同名同尺寸覆盖 `skin/sn_v1/nine_slice/` 或 `icons/`，让 Godot 重新导入即可；改画布尺寸/角件比例需走生成器。
- 九宫格纹理不内嵌文字、数值、状态色；文字与状态由 Theme 控制。
- 港口/商品等内容专属图标仍走内容模组 `manifest.assets` 的 `icon.*`，不放全局皮肤。
- 全局 UI 资源不要放进 Core 内容模组；内容专属资源放在 `dev_mods/core/assets/`。
- 图片使用 PNG；Godot 生成的 `.import`/`.uid` 不提交（`.gdignore`/`.gitignore` 已有约定）。
