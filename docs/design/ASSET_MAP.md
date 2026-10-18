# Asset Map

## 决策

- `.design/` 继续作为**本地美术原型/源文件**，由 `.gitignore` 排除，不参与构建。
- 全局表现层资源进入 `assets/`（`res://assets/...`）。
- 内容专属资源进入 `dev_mods/core/assets/`，由 Core 模组 manifest 声明。
- 音频按用途分 `ui/`、`economy/`、`music/`。

## 本次落地

| 来源 | 运行时路径 | 说明 |
| --- | --- | --- |
| `.design/assets/main-menu-harbor.png` | `assets/ui/banners/main_menu_harbor.png` | 主菜单背景，1672×941 |
| `.design/assets/iron-harbor-banner.png` | `dev_mods/core/assets/ports/iron_harbor_banner.png` | 铁港横幅，2172×724；manifest 键 `banner.port.iron_harbor` |
| `.design/tokens.json` | `assets/ui/tokens.json` | UI token |
| `270408__littlerobotsoundfactory__pickup_gold_00.wav` | `assets/audio/sfx/economy/pickup_gold_00.wav` | 购买/金币音效 |

## 为什么这样分

- 主菜单背景属于**框架表现层**，所有内容包共用。
- 铁港横幅属于**港口内容**，未来可能随模组/港口扩展，放在 Core 资产目录。
- 购买音效是**通用经济反馈**，不绑定具体港口或商品。
- `.design` 里的 HTML/CSS/JS 是原型，不直接进入 Godot 导出包。

## 明天 UI 更新的入口

1. `assets/ui/theme/steam_navigator_theme.tres`（待建）
2. `assets/ui/tokens.json`
3. `assets/ui/banners/main_menu_harbor.png`
4. `assets/audio/sfx/economy/pickup_gold_00.wav`
5. `dev_mods/core/assets/ports/iron_harbor_banner.png`

所有路径均以 `res://` 开头在 Godot 中使用。
