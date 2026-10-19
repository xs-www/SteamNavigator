# `dev_mods/core`

> 官方 MVP 内容包：港口、商品、船只、模块、策略、岗位、委托、事件、地图与本地化；模块含打造配方/工时/费用，tier1 为仅金币配方（materials 为空）。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `assets/icons/coal.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/icons/money.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/icons/water.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/ports/iron_harbor_banner.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/boilers.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/cabins.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/cargo_modules.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/contracts.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/events.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/goods.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/hulls.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/map_profiles.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/materials.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/navigation_modules.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/port_archetypes.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/roles.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/safety_modules.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/starting_builds.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/strategies.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `localization/en.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `localization/zh_CN.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `manifest.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |

## 模块契约

- `manifest.json` 声明 required=true，内容文件 15 个，本地化 zh_CN/en。
- tier≥2 模块带 `craft_cost`；所有模块可带 `materials`/`craft_time_hours` 供 CraftOps 读取。
- 两个造船厂港口（iron_harbor/free_town）市场限量出售精密齿轮，保证大型船材料在当局地图可获得。
- 框架不得引用这里的具体 ID；所有引用由 Schema/交叉校验保证。
- 修改数值只改 JSON，不改框架。
