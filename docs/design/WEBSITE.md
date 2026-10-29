# 官网设计契约（Steam Navigator Official Site）

> 状态：Active（已实现，站点位于 `website/`）。目标是为《蒸汽航海 / Steam Navigator》做一个**简单、可直接部署**的静态官网。
> 本文是页面结构、视觉 token、图片槽位、百科数据格式与验收标准的唯一契约；实现位于仓库根目录 `website/`。

## 1. 目标与红线

- 交付物：零依赖静态站点（HTML / CSS / 原生 JS），无需构建步骤即可用任意静态服务器部署。
- 页面仍是纯静态；**游玩数据接收端**是可选伴随服务（`website/server/telemetry.mjs`，零依赖 Node，见 [TELEMETRY.md](TELEMETRY.md) §4），不参与页面渲染，静态托管方案可以不带它。
- 页面：首页、游戏信息、游戏百科、开发日志、下载、开发团队（页脚入口，内容占位）。
- **主页红线（用户需求）**：`index.html` 的主体内容禁止出现开发 / 调试相关资料。
  - 禁止：开发、调试、测试、原型、MVP、版本号、更新日志、开发者、GitHub、Godot、模组、引擎、构建、诊断、日志、文档、代码、内测、体验版、`dev`、`build`、`debug`、`changelog`。
  - 允许的例外：导航栏与页脚中指向 `devlog.html` 的「开发日志」链接，以及页脚中的「开发团队」入口；它们只是导航，团队内容放在独立子页面。
  - 首页只讲游戏世界、玩法、画面、获取方式；版本号 / 构建状态 / 更新记录只能出现在下载页与开发日志页。
- 子页面允许：游戏下载、游戏信息、游戏百科、开发日志、开发团队。下载页与开发日志页可以出现版本号、更新说明、平台与构建信息；开发团队页当前为占位。
- 禁止在站内伪造数据：游戏事实以 `dev_mods/core/content/*.json`、`dev_mods/core/localization/zh_CN.json`、`CHANGELOG.md` 为准；下载链接使用真实 GitHub Release 资产。
- 所有页面默认简体中文；不引入外部字体 / CDN / 第三方 JS，断网也能完整显示（系统字体栈）。

## 2. 产品事实（写文案时使用）

- 游戏名：蒸汽航海 / Steam Navigator；类型：蒸汽朋克航海贸易模拟；单人。
- 平台：Windows x64、Linux x64；语言：简体中文（可切换英文，站内只宣传中文）。
- 最新公开版本与下载资产：**以 GitHub Releases 为准**，由 `website/tools/build-release-data.mjs` 调 GitHub Releases API 生成
  `website/assets/data/release-data.js`，下载页与开发日志页用 `assets/js/release.js` 自动填充；HTML 里不再手写版本号。
  - 发布页：`https://github.com/xs-www/SteamNavigator/releases`
  - 当前生成结果（`v0.2.0-dev.4-fixed`，预发布）：Windows ≈80 MB、Linux ≈71 MB、`SHA256SUMS.txt`；
    具体直链、日期与字节数以生成文件为准。
  - **日期时区**：`published_at` 保留 GitHub 的 UTC 时间；`date` 按站点时区计算（默认 `Asia/Shanghai`，
    可用 `SN_RELEASE_TIME_ZONE` 或 `--time-zone` 覆盖），同时输出 `date_time_zone`；下载页 / 开发日志页再用
    `release.js` 按访客本地时区显示 `YYYY-MM-DD`。不要直接截取 UTC 日期——晚间发布（如 `22:18Z`）
    在 UTC+8 / UTC+11 已是次日，会被显示成前一天。
- 版本数据生成：`node website/tools/build-release-data.mjs`（`--check` 校验是否落后于 GitHub）。
  - 部署钩子：`website/tools/ci.ps1` 构建镜像前自动刷新；`.github/workflows/website-release-data.yml` 在 Release 发布后自动提交更新。
  - **运行时自动更新（主力）**：Compose 的 `site-api` 服务（`website/server/site_api.mjs`，容器内 8092，只读）
    服务端缓存 GitHub Releases（默认 5 分钟），下载页 / 开发日志页先渲染静态数据、再请求同域 `/api/site/release`
    刷新。**发布 Release 后无需重新部署网站**，最迟约 5 分钟线上显示最新版本；GitHub 不可用时依次回退旧缓存、
    镜像内 `release-data.js`。`GITHUB_TOKEN` 只用于服务端调用，不下发浏览器。
  - **最新 Windows 安装包镜像**：`site-api` 后台把最新 Release 的 windows.zip 流式下载到卷
    `release-downloads`（校验字节数 + SHA256SUMS），暴露 `/downloads/<tag>/<file>` 由 nginx 直接下发
    （Range / 30 天缓存）；新版本成功后删除旧 tag，**只保留最新版**，历史版本由前端回退 GitHub 直链。
    校验清单条目兼容裸文件名与发布流程实际写出的 `dist/release/<文件名>` 路径；清单缺失 / 请求失败 /
    缺少目标条目时**不提供镜像**（`available=false`，前端回退 GitHub），不得跳过 SHA 校验。
    进程重启后对已有文件重新计算 SHA-256，同大小的损坏副本会被删除并重新下载，不能只凭文件大小复用。
- 世界观关键词：蒸汽朋克、群岛、浓雾、煤烟、黄铜与铸铁、港口城邦、商会 / 皇家海军 / 海盗团、遗迹与失落的航路。
- 核心玩法关键词：动态行情与港口库存、造船厂与模块改装、程序生成海图与线索探索、锅炉策略、蒸汽舰炮与舰队、基地生产链、遗迹远征、自动贸易。
- 五个港口模板：铁港、香料港、自由镇、渔村、玻璃港。
- 四个船体：效率型小型、标准中型、效率型大型、性能型大型。
- 三种势力：商人公会、皇家海军、海盗团。
- 七种普通商品：铁矿石、黄铜、纺织品、香料、木材、玻璃器皿、委托货箱；补给：煤、淡水；材料：锅炉钢板、精密齿轮、密封胶。

### 文案语气

- 沉浸、克制、有画面感；用「航程 / 海图 / 锅炉 / 舷炮 / 码头」等世界内词汇。
- 不堆形容词，不用「史无前例」「颠覆」等营销词，不用感叹号连发。
- 首页标题短句化；正文每段 1–3 行。子页面可以更长。

## 3. 信息架构

```text
website/
├── index.html          首页（无开发/调试信息）
├── game.html           游戏信息：世界、玩法循环、特色、港口、势力
├── wiki.html           游戏百科：可搜索 / 可筛选的内容条目
├── devlog.html         开发日志：版本时间线 + 下一阶段
├── download.html       下载：平台、版本、配置、安装、FAQ
├── team.html           开发团队：页脚入口的团队与致谢占位页
├── assets/
│   ├── css/site.css    单一样式表（设计系统 + 全站组件 + 响应式）
│   ├── js/site.js      导航、滚动、揭示动画、图片灯箱、页脚年份
│   ├── js/wiki.js      百科渲染 / 搜索 / 分类筛选 / 深链接
│   ├── js/release.js   版本信息填充（静态数据 + /api/site/release 刷新）
│   ├── data/wiki-data.js  由 tools/build-wiki-data.mjs 生成
│   ├── data/release-data.js  由 tools/build-release-data.mjs 从 GitHub Releases 生成（勿手改）
│   └── img/            官网图片（见 §5）
├── tools/
│   ├── build-wiki-data.mjs  Core 内容 → wiki-data.js
│   ├── build-release-data.mjs  GitHub Releases → release-data.js
│   ├── serve.mjs            零依赖本地预览服务器（同时挂载 /api/telemetry/）
│   └── ci.ps1               本地 CI：构建 / 冒烟 / 部署
├── server/
│   ├── telemetry.mjs        游玩日志接收端（校验 / 限流 / 落盘 / 保留），契约见 TELEMETRY.md
│   └── site_api.mjs         只读内容 API（服务端缓存 GitHub Releases），运行时自动更新版本
├── tests/
│   ├── telemetry.test.mjs   接收端 node:test 用例
│   ├── site-api.test.mjs    内容 API node:test 用例（缓存 / 降级 / fallback）
│   └── release-data.test.mjs 版本数据生成器 node:test 用例
├── deploy/
│   ├── Dockerfile          nginx alpine 生产镜像（非 root / 单 worker）
│   ├── Dockerfile.telemetry 接收端镜像（node:22-alpine / 非 root / 8090）
│   ├── Dockerfile.site-api  内容 API 镜像（node:22-alpine / 非 root / 8092）
│   └── nginx.conf          静态站 nginx 配置（gzip / 缓存 / 健康检查 / /api/telemetry/ + /api/site/ 反代）
├── .gdignore          防止 Godot 导入站点目录
├── .data/             本地预览的日志落盘目录（gitignore，不入库）
└── README.md           预览 / 部署 / 生成说明
```

导航顺序：首页（Logo）· 游戏信息 · 游戏百科 · 开发日志 · 下载（高亮按钮）。开发团队只从页脚进入，不占顶部导航。
页脚：品牌 + 一句简介 + 站内链接（含「开发团队」入口）+ 下载链接 + 署名与版权（首页页脚不放开发内容，只放导航与版权）。
不造假的社交账号；只链真实发布页（下载页 / 开发日志页）。

## 4. 视觉系统

### 色彩（CSS 变量名固定）

| Token | 值 | 用途 |
| --- | --- | --- |
| `--ink-950` | `#050f11` | 页面底色 |
| `--petrol-900` | `#082025` | 区块底色 |
| `--petrol-800` | `#0d2f34` | 卡片 / 面板 |
| `--petrol-700` | `#144347` | 抬升面 |
| `--brass-500` | `#c59a54` | 主强调、边线 |
| `--brass-300` | `#e7cf9a` | 高亮文字、CTA 悬停 |
| `--copper-500` | `#a4553f` | 次强调、警示 |
| `--paper-200` | `#d9c9a6` | 正文亮色、纸面 |
| `--text` | `#ece1c5` | 正文 |
| `--muted` | `#9fb0a8` | 次要文字 |
| `--good` | `#7fb79a` | 正向状态 |
| `--line` | `rgba(197,154,84,.24)` | 分隔线 / 边框 |

- 背景允许：深色径向渐变、细网格、胶片颗粒（SVG feTurbulence data URI）、蒸汽薄雾（低透明度径向渐变 + 缓慢漂移动画）。
- 装饰母题：黄铜细线、铆钉角、罗盘玫瑰、双线边框、做旧纸标签、角落刻度。避免可爱风 / 圆角卡片 / 大色块渐变。

### 字体与排版

```css
--font-display: "Noto Serif SC", "Source Han Serif SC", "Songti SC", "STSong", "SimSun", Georgia, serif;
--font-body: "Noto Sans SC", "Source Han Sans SC", "PingFang SC", "Microsoft YaHei", system-ui, sans-serif;
--font-label: "Cascadia Mono", "Consolas", "Courier New", monospace;
```

- 首页主标题：中文 64–96 px（移动端 40–56），细字距 `0.06em`；英文小标 `letter-spacing:.42em`。
- 区块 kicker：11 px、全大写 / 中文细字距、黄铜色。
- 正文：15–17 px，行高 1.8；最大阅读宽度 68ch。
- 标题层级：h1 > h2 > h3；不跳级。所有页面只有一个 h1。

### 布局与响应式

- 内容容器：`min(1200px, 92vw)`；文字块 `68ch`。
- 断点：`1100px`（两列变单列）、`860px`（导航折叠）、`600px`（标题与卡片压缩）。
- 导航在 ≤860px 变为全屏抽屉（按钮带 `aria-expanded`）。
- 卡片网格使用 `repeat(auto-fit, minmax(...))`；移动端不横向滚动。
- 支持 `prefers-reduced-motion`：关闭所有位移/视差/自动动画。

## 5. 图片槽位（art 任务契约）

输出目录：`website/assets/img/`。统一 JPEG（渐进式，quality 按目标体积自适应），文件命名固定；删除源图中的调试 UI（顶部 `诊断日志 / 刷新 / 框架就绪 / 版本号` 与底部 `开发团队 / 版本`）。

| 文件名 | 源文件 | 处理 | 用途 |
| --- | --- | --- | --- |
| `hero-main.jpg` | `assets/ui/banners/main_menu_harbor.png` | 1600×900, q84, ≤420 KB | 首页 Hero |
| `og-cover.jpg` | 同上 | 1200×630 center crop, q82, ≤260 KB | Open Graph / 分享图 |
| `port-hero.jpg` | `docs/design/screenshots/port_stage/port_stage_preview.png` | 1440×900, q82, ≤260 KB | 游戏信息页 Hero / 首页世界 |
| `port-terminal.jpg` | `docs/design/screenshots/architecture/grand_terminal_three_quarter.png` | 1600×900, q82, ≤220 KB | 世界 / 港口 |
| `ship-schooner.jpg` | `docs/design/screenshots/ship_assembly/shipyard_schooner_hero.png` | 1440×900, q82, ≤240 KB | 船只 / 画廊 |
| `ship-ironclad.jpg` | `docs/design/screenshots/ship_assembly/shipyard_ironclad.png` | 1440×900, q82, ≤240 KB | 战斗 / 舰队 |
| `ship-paddle.jpg` | `docs/design/screenshots/paddle_steamer_three_quarter.png` | 16:10 内裁后放大到 1440×900, q82, ≤240 KB | 画廊 |
| `chart.jpg` | `docs/design/screenshots/sea_chart/sea_chart_explored.png` | 1440×900, q82, ≤220 KB | 探索 / 海图 |
| `market-ui.jpg` | `docs/design/screenshots/market_station.png` | 裁掉顶部 136 px、底部 44 px → 1440×720, q82, ≤220 KB | 贸易实机 |
| `shipyard-ui.jpg` | `docs/design/screenshots/skin/1440x900/shipyard_refit.png` | 裁掉顶部 142 px、底部 44 px → 1440×714, q82, ≤260 KB | 改装实机 |
| `combat-lineup.jpg` | `docs/design/screenshots/combat/combat_lineup.png` | 保持原比例，1600×600, q82, ≤220 KB | 战斗 |
| `base-kit.jpg` | `docs/design/screenshots/kits/kit_base_assembly.png` | 保持原比例，1600×871, q82, ≤260 KB | 基地 |
| `ruins.jpg` | `docs/design/screenshots/kits/kit_wreck_three_quarter.png` | 保持原比例，宽 ≤1600, q82, ≤200 KB | 遗迹 / 远征 |
| `harbor-diorama.jpg` | `docs/design/screenshots/harbor_diorama_schooner.png` | 保持原比例，宽 ≤1600, q82, ≤240 KB | 画廊 / 尾图 |

- 若某源图不存在或裁切后不可用，允许选择同主题的替代图，但必须在 `website/assets/img/MANIFEST.md` 记录实际来源与理由。
- 所有输出必须用 `read_image` 目检：无调试按钮、无版本号、无开发者署名、无明显裁切残字。
- 额外输出 `MANIFEST.md`：文件名、源路径、最终尺寸、体积、裁切区域、检查结论。
- 图片是站点的一部分，允许入库；总大小目标 ≤ 4 MB。
- 仓库只提交 `website/assets/img/` 的成品 JPG；`docs/design/screenshots/` 仍作为本地生成物不入库，换图时从本地源重新裁切。

## 6. 百科数据格式（wiki 任务契约）

生成脚本：`website/tools/build-wiki-data.mjs`（Node ≥18，零依赖）。
输入：`dev_mods/core/content/*.json` + `dev_mods/core/localization/zh_CN.json`。
输出：`website/assets/data/wiki-data.js`，内容为：

```js
window.SN_WIKI_DATA = {
  updated: "2026-10-24",
  categories: [
    { id: "world", label: "世界", heading: "世界与海域", icon: "compass", intro: "……" }
  ],
  entries: [
    {
      id: "region-start-haven",       // 稳定 slug，仅用于锚点，不展示
      category: "world",              // categories 中的 id
      title: "起始港湾",
      kind: "海域",                   // 条目标签，展示
      description: "战役起点的安全海岸，设施齐备、风险最低。",
      tags: ["安全", "新手"],
      stats: [["类型", "沿海"], ["规模", "中型"]], // 0–4 项，展示为定义列表
      link: "game.html#world"         // 可选，站内相关页
    }
  ]
};
```

- 分类固定 11 个（id / label / heading / icon）：
  `world` 世界、`port` 港口、`goods` 商品与贸易、`ships` 船只、`modules` 模块与改装、`voyage` 航行、`combat` 战斗、`fleet` 舰队、`base` 基地与生产、`ruins` 遗迹与秘宝、`glossary` 术语。
- 条目来源与期望数量：
  - world：5 个区域 + 6 个海上地点（`regions.json`、`sites.json`）。
  - port：5 个港口模板（设施与规模来自 `port_templates.json` 的 data）。
  - goods：12 个物品 + 2 条贸易策略（重量 / 基准价 / 分类来自 `items.json`、`trade_policies.json`）。
  - ships：4 个船体 + 4 个舰队船型（航速 / 载重 / 耐久 / 货舱槽来自 `hulls.json`、`ship_archetypes.json`）。
  - modules：12 个模块（分类 / 等级 / 重量 / 价格 / 关键效果来自 `modules.json`）。
  - voyage：3 种锅炉策略 + 2 个航行事件 + 2 个船员岗位 + 3 条航道 + 2 种气候（`boiler_strategies` / `voyage_events` / `crew_roles` / `route_templates` / `weather_profiles`）。
  - combat：5 件武器 + 4 种伤害类型 + 4 类敌舰 + 4 个战斗能力 + 2 张遭遇表（`weapons` / `damage_types` / `enemy_archetypes` / `combat_abilities` / `encounter_tables`）。
  - fleet：3 名舰长 + 2 套阵型 + 2 条战术（`captains` / `formations` / `fleet_doctrines`）。
  - base：2 个基地点 + 5 栋建筑 + 5 条升级 + 3 条配方 + 3 个工人工种（`base_sites` / `buildings` / `building_upgrades` / `production_recipes` / `worker_roles`）。
  - ruins：2 类遗迹 + 4 个房间 + 3 件遗物 + 3 个远征事件 + 2 张危险表（`ruin_archetypes` / `room_templates` / `relics` / `expedition_events` / `hazard_tables`）。
  - glossary：10–12 条手写术语（载重、货舱、耐久、锅炉策略、风险、声望、线索、迷雾、时间、槽位、委托、舰队）。
- 文案来自 `zh_CN.json` 的 `description`；禁止直接展示 `core:` ID、schema / `content_type` / `schema_version` / capability 等实现字段。
- 数字展示要玩家可读（如重量 `22`、价格 `380` 金币、航速 `14` 节；数值原样，不做换算猜测）。
- 条目按分类内顺序稳定排序；生成结果必须可重复（相同输入 → 相同输出）。
- 生成脚本运行 `node website/tools/build-wiki-data.mjs` 通过；输出文件用 `node --check` 校验语法。
- 不得修改 `dev_mods/core/` 下的内容，只读。

## 7. 验收标准

1. 5 个页面均可在 `http://127.0.0.1:<port>/` 正常打开；无 404（图片 / CSS / JS）。
2. 首页可见文本（去掉导航与页脚链接文字后）不含 §1 的禁用词；不含版本号。
3. 下载页的 3 个外链可访问（HTTP 200），平台卡片显示真实文件大小量级；版本号 / 发布日期 / 文件大小 / 下载直链与 GitHub 最新 Release 一致（`node website/tools/build-release-data.mjs --check` 通过）。Runtime：部署后 `GET /api/site/release` 返回 200，`data.latest.tag` 等于 GitHub 最新 Release；发布新 Release 后 ≤5 分钟（服务端缓存 TTL）页面无需重新部署即可显示新版本。Windows 镜像：`data.downloads.windows.available=true` 后页面 Windows 按钮指向 `/downloads/<tag>/...`（HEAD 200、Range 206、只保留最新 tag），不可用时回退 GitHub。
4. 百科页：分类筛选、搜索、空结果提示、深链接（`#entry-id` / `#cat-id`）可用；条目数 ≥ 60。
5. Chrome headless 截图 1440×900、1024×768、390×844 无横向滚动、无重叠、导航可用。
6. 控制台无 JS 报错；图片均有 `alt`；按钮/链接键盘可达；灯箱可用 `Esc` 关闭。
7. `prefers-reduced-motion` 下无强迫动画。
8. 站点无外部网络依赖（字体 / CDN / 统计脚本）；下载外链除外。
9. 游玩数据接收端：`GET /api/telemetry/health` 返回 200；合法会话 `POST /api/telemetry/session` 返回 204 并在数据目录生成对应文件与 `index.ndjson`；`node --test website/tests/telemetry.test.mjs` 全绿。接收端契约见 [TELEMETRY.md](TELEMETRY.md)。
10. 版本数据：`node --test website/tests/release-data.test.mjs website/tests/site-api.test.mjs` 全绿；`node website/tools/build-release-data.mjs --check` 通过；GitHub API 不可达时部署仍能用上一次生成的数据启动（脚本保留旧文件），`site-api` 仍能回退静态数据。

## 8. 协作与写入边界

- Lead：`website/*.html`、`website/assets/css/`、`website/assets/js/site.js`、`website/assets/js/wiki.js`、`website/README.md`、`website/deploy/`、`website/docker-compose.yml`、`docs/design/WEBSITE.md`。
- art 任务：只写 `website/assets/img/`。
- wiki 任务：只写 `website/tools/build-wiki-data.mjs`、`website/assets/data/`。
- telemetry 任务：只写 `website/server/`、`website/tests/`、`website/deploy/Dockerfile.telemetry` 与本文档 §10 契约涉及的 nginx / compose / README 段落；契约先改 [TELEMETRY.md](TELEMETRY.md)。
- 版本数据任务：只写 `website/tools/build-release-data.mjs`、`website/assets/data/release-data.js`、`website/assets/js/release.js`、`.github/workflows/website-release-data.yml` 与下载/开发日志页的数据属性；不手改生成文件。
- 内容 API 任务：只写 `website/server/site_api.mjs`、`website/tests/site-api*.test.mjs`、`website/deploy/Dockerfile.site-api` 与 compose / nginx 的 `/api/site/`、`/downloads/` 段落；只读、不接触遥测数据，token 不进响应；Windows 镜像只保留最新 tag。
- QA：只写 `tmp/website-qa/`。
- 所有人不改 `dev_mods/`、`framework/`、`docs/static/`；站点目录加 `.gdignore`，避免 Godot 导入。

## 9. 实现状态

- 6 个页面已落地：`index.html`、`game.html`、`wiki.html`、`devlog.html`、`download.html`、`team.html`（开发团队占位页）。
- 百科数据由 `website/tools/build-wiki-data.mjs` 生成，共 132 条（11 个分类）；`wiki.html` 支持搜索、分类、空结果与深链接。
- 图片 14 张（合计约 1.48 MB），来源与裁切见 `website/assets/img/MANIFEST.md`。
- 本地预览：`node website/tools/serve.mjs`（默认 `http://127.0.0.1:4173/`，同时提供 `/api/telemetry/`）。
- QA 使用 Chrome headless + Selenium 覆盖 1440/1024/768/390 四档、外链 HTTP 200、控制台/网络错误、灯箱与移动导航；临时报告在 `tmp/website-qa/`（不入库）。
- 生产镜像：`website/deploy/Dockerfile`（nginx 1.27 alpine、非 root、单 worker、8080）；`website/docker-compose.yml` 限制 32 MB 内存 / 0.25 CPU，只绑定 `127.0.0.1:8088`（容器内 8080），并带可选 `cloudflared` profile。
- 本地 CI：`website/tools/ci.ps1` 在本机构建镜像、以生产同款限制跑容器冒烟，通过后 `docker compose up -d --build website` 直接部署；不推任何 registry。
- Cloudflare：公网入口推荐 Cloudflare Tunnel；容器内 cloudflared 的 origin 填 `http://website:8080`，宿主机 cloudflared 填 `http://127.0.0.1:8088`。部署与缓存说明见 `website/README.md`。
- 游玩数据接收端（2026-10-27）：`website/server/telemetry.mjs` + `website/deploy/Dockerfile.telemetry` + compose `telemetry` 服务 + nginx `/api/telemetry/` 反代；数据卷 `website-telemetry-data`（`/data`），保留 180 天。契约见 [TELEMETRY.md](TELEMETRY.md)。
- 本地游玩数据看板（2026-10-27）：`website/tools/telemetry_dashboard.mjs` + `Dockerfile.dashboard` + compose `telemetry-dashboard`（`profiles: ["dashboard"]`，只发布到 `127.0.0.1:8091`），只读同一个数据卷；**不是官网页面**，不进入站点导航，也不随静态站发布。
- 版本数据自动同步（2026-10-27）：`website/tools/build-release-data.mjs` 从 GitHub Releases API 生成 `assets/data/release-data.js`（latest / stable / 平台直链 / 大小 / 日期），下载页与开发日志页通过 `assets/js/release.js` 的 `data-release` / `data-release-link` 契约自动填充；`ci.ps1` 部署前刷新，`.github/workflows/website-release-data.yml` 在 Release 发布后自动提交；网络失败保留旧数据。
- 运行时版本自动更新（2026-10-27）：新增只读 `site-api` 服务（`website/server/site_api.mjs` + `Dockerfile.site-api` + compose `site-api` + nginx `/api/site/` 反代），服务端缓存 GitHub Releases（默认 5 分钟、`Cache-Control: public, max-age=60, stale-while-revalidate=600`）；发版后网站无需重新部署即可在 ≤5 分钟内更新，失败时回退旧缓存 / 镜像内静态数据。`ci.ps1` 部署后检查 `/api/site/release`；`release-data.js` 单独 `no-cache`，避免浏览器/CDN 长期缓存旧版本。
- 最新 Windows 安装包镜像（2026-10-27）：`site-api` 后台流式下载最新 Release 的 windows.zip 到命名卷 `release-downloads`（SHA-256 + 字节数校验），`website` 只读挂载后由 nginx `/downloads/<tag>/<file>` 下发（Range、30 天缓存）；新版本就绪后清理旧 tag，只保留最新版，历史版本与镜像未就绪时回退 GitHub。`release.js` 缓存标识用 `?v=` 版本串，修改脚本时需同步更新。
- 镜像校验加固（2026-10-29，随 `v0.2.0-dev.4-fixed` 发布）：反馈「官网下载的 Windows 包打不开」排查发现镜像本身字节完整（与 GitHub 原包 SHA 一致），但旧校验逻辑只按裸文件名匹配 `SHA256SUMS.txt`，而发布流程写的是 `dist/release/<文件名>` 路径，导致镜像跳过 SHA 校验；进程重启后也只比较文件大小复用旧副本。修复为按 basename 匹配清单路径、清单缺失 / 请求失败 / 无目标条目时不提供镜像、已有文件重启后流式重算 SHA-256，坏副本删除重下；`site-api-mirror` 测试覆盖 `dist/release/` 路径、清单异常与重启复验。
- 发布日期时区（2026-10-27）：`build-release-data.mjs` 的 `date` 改为按站点时区（默认 `Asia/Shanghai`，`SN_RELEASE_TIME_ZONE` / `--time-zone` 可覆盖）从 `published_at` 计算，并输出 `date_time_zone`；`release.js` 用访客本地时区格式化日期。修复 `v0.2.0-dev.4`（`2026-10-26T22:18:39Z`）显示为 10-26 的问题（北京时间 / 悉尼时间均为 10-27）。

## 10. 游玩数据接收端（Telemetry ingest）

> 完整契约（载荷 schema、状态码、限流、保留、客户端行为）见 [TELEMETRY.md](TELEMETRY.md)；本节只约束官网侧边界。

- 路由只挂在同域 `/api/telemetry/`：`GET /health`、`POST /session`；官网页面本身不调用该接口，也不在页面里出现上传日志相关 UI。
- 生产由 nginx location `/api/telemetry/` 反代到 compose 内 `http://telemetry:8090`（`client_max_body_size 1m`，只允许 GET/POST）；静态文件的缓存、安全头与 `healthz` 行为不变。
- 接收端不记录客户端 IP；数据写入数据卷的 `sessions/<YYYY-MM-DD>/`（单会话 JSON + `index.ndjson` 摘要），保留 180 天。
- 本地预览 `website/tools/serve.mjs` 同样挂载该接口，数据写 `website/.data/telemetry/`（gitignore）；不带接收端也能单独部署静态页面。
- 查看数据的本地看板与官网解耦：`node website/tools/telemetry_dashboard.mjs`（默认 `127.0.0.1:8091`，读 `.data/telemetry/`）或 `docker compose --profile dashboard up -d`（只读挂载生产数据卷，同样只绑定 loopback）；看板不注册在站点导航 / 页脚，也不经过 nginx。
- 部署与备份（数据卷位置、令牌、保留期）说明维护在 `website/README.md`。
