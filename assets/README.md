# Runtime Assets

游戏运行时实际加载的资源放在这里，路径统一使用 `res://assets/...`。

## 分工

| 路径 | 用途 | 归属 |
| --- | --- | --- |
| `assets/ui/` | 主菜单、HUD、通用 UI 装饰、图标、Theme、九宫格 | 框架表现层 |
| `assets/audio/` | 通用 UI / 经济 / 航行音效与环境音乐 | 框架表现层 |
| `assets/fonts/` | 需要随游戏分发的字体 | 框架表现层 |
| `dev_mods/core/assets/ports/` | 港口专属横幅、港口插画 | Core 内容模组 |
| `.design/` | 美术原型、源文件、参考图 | 本地设计资料，**不参与构建** |

## 约定

- 文件名使用 `snake_case`，不带空格。
- `.design/` 里的图不能直接给游戏加载；确认后复制到 `assets/` 或 `dev_mods/core/assets/`。
- 全局 UI 资源不要放进 Core 内容模组；港口/商品等**内容专属**资源放在 `dev_mods/core/assets/`。
- 图片使用 PNG；音频使用 WAV/OGG；字体使用 `.ttf`/`.otf`。
- Godot 生成的 `.import`/`.uid` 由 `.gitignore` 排除，不提交。

## 当前生产资产

- `assets/ui/banners/main_menu_harbor.png` — 主菜单概念背景
- `assets/ui/tokens.json` — UI 设计 token
- `assets/audio/sfx/economy/pickup_gold_00.wav` — 购买/拾取金币音效
- `dev_mods/core/assets/ports/iron_harbor_banner.png` — 铁港横幅

详细来源与映射见 [docs/design/ASSET_MAP.md](../docs/design/ASSET_MAP.md)。
