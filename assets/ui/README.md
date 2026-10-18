# UI Assets

## 目录

```text
assets/ui/
  banners/       主菜单等全屏背景
  icons/         24×24 通用图标（SVG/PNG）
  theme/         Godot Theme .tres
  nine_slice/    面板/按钮九宫格纹理
  tokens.json    颜色、字号、间距、动效节奏
```

## 当前

- `banners/main_menu_harbor.png`：1672×941，主菜单背景。建议用 `TextureRect`，`expand_mode = IGNORE_SIZE`，`stretch_mode = KEEP_ASPECT_COVERED`。
- `tokens.json`：来自 `.design/tokens.json`，明天做 `SteamNavigatorTheme.tres` 时作为唯一数值来源。

## 规划

- `theme/steam_navigator_theme.tres`：目标 Theme 文件。
- `icons/`：商品、设施、风险、声望、按钮图标，统一 24×24。
- `nine_slice/`：面板/按钮纹理，角区 16px，内容边距 20px。

港口专属图不放在这里，见 `dev_mods/core/assets/ports/`。
