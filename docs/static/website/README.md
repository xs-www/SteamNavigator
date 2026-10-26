# `website`

> 游戏官网静态站点：首页、游戏信息、游戏百科、开发日志与下载；百科数据由 Core 内容生成，官网图片来自游戏画面裁切与压缩。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `.env.example` | 本地部署配置示例：Cloudflare Tunnel token 与宿主机端口；真实 `.env` 已被 .gitignore 忽略。 | 本页 |
| `.gdignore` | 阻止 Godot 导入官网静态目录。 | 本页 |
| `README.md` | 官网使用说明：本地预览、目录结构、内容边界、版本更新清单、百科数据生成、游玩数据接收端联调、本地数据看板与生产部署。 | [查看](./README.md.md) |
| `assets/css/site.css` | 官网唯一设计系统与全站样式：色彩/排版 token、导航、Hero、卡片、百科、下载、页脚、响应式与动效降级。 | [查看](./assets/css/site.css.md) |
| `assets/data/wiki-data.js` | 官网百科数据：由 `website/tools/build-wiki-data.mjs` 从 Core 内容生成，禁止手改。 | 本页 |
| `assets/img/MANIFEST.md` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/base-kit.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/chart.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/combat-lineup.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/harbor-diorama.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/hero-main.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/market-ui.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/og-cover.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/port-hero.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/port-terminal.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/ruins.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/ship-ironclad.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/ship-paddle.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/ship-schooner.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/img/shipyard-ui.jpg` | 官网图片资产：游戏画面裁切、压缩与质检结果；来源与裁切记录在 `website/assets/img/MANIFEST.md`。 | 本页 |
| `assets/js/release.js` | 官网版本信息填充脚本：读取 `assets/data/release-data.js`（由 `tools/build-release-data.mjs` 从 GitHub Releases 生成）， | [查看](./assets/js/release.js.md) |
| `assets/js/site.js` | 官网全站交互（导航抽屉、滚动状态、滚动揭示、图片灯箱、页脚年份、Hero 视差）。 | [查看](./assets/js/site.js.md) |
| `assets/js/wiki.js` | 渲染官网游戏百科：分类导航、实时搜索、条目卡片、结果计数与深链接。 | [查看](./assets/js/wiki.js.md) |
| `deploy/Dockerfile` | 官网生产镜像：nginx alpine 运行静态页面，单 worker、非 root、8080 端口，面向低内存自托管与 Cloudflare Tunnel。 | [查看](./deploy/Dockerfile.md) |
| `deploy/Dockerfile.dashboard` | 本地「游玩数据看板」镜像：node:22-alpine 跑 `tools/telemetry_dashboard.mjs`，只读挂载遥测数据卷，在容器 8091 提供看板页面。 | [查看](./deploy/Dockerfile.dashboard.md) |
| `deploy/Dockerfile.telemetry` | 游玩数据接收端生产镜像：node:22-alpine 跑零依赖 `server/telemetry.mjs`，非 root、8090 端口、`/data` 数据卷。 | [查看](./deploy/Dockerfile.telemetry.md) |
| `deploy/nginx.conf` | 官网镜像内的 nginx 配置：单 worker、8080 端口、gzip、静态缓存、健康检查、基础安全响应头，以及 /api/telemetry/ 反代。 | [查看](./deploy/nginx.conf.md) |
| `devlog.html` | 开发日志页：版本时间线、已交付系统与下一阶段方向；允许出现版本号与开发状态。 | [查看](./devlog.html.md) |
| `docker-compose.yml` | 官网 Docker Compose：低内存静态站容器 + 游玩数据接收端容器 + 可选 Cloudflare Tunnel 容器。 | [查看](./docker-compose.yml.md) |
| `download.html` | 下载页：真实 GitHub Release 资产、平台卡片、运行需求、安装步骤与 FAQ。 | [查看](./download.html.md) |
| `favicon.svg` | 官网 favicon：黄铜罗盘 / 菱形边框，呼应游戏蒸汽朋克罗盘母题。 | [查看](./favicon.svg.md) |
| `game.html` | 游戏信息页：世界观、玩法循环、核心特色、五座港口与三大势力，向玩家解释游戏内容。 | [查看](./game.html.md) |
| `index.html` | 官网首页：Hero、玩法特色、世界港口、画面画廊与下载 CTA。首页禁止出现版本号、开发/调试、测试与构建信息。 | [查看](./index.html.md) |
| `server/telemetry.mjs` | 游玩数据（telemetry）接收端：校验客户端上传的会话 JSON、按来源限流、写入会话文件与索引，并做 180 天保留清理。 | [查看](./server/telemetry.mjs.md) |
| `tests/release-data.test.mjs` | 官网 Release 版本数据生成器（`tools/build-release-data.mjs`）的 Node 测试：覆盖 latest/stable 选择、 | [查看](./tests/release-data.test.mjs.md) |
| `tests/telemetry-dashboard.test.mjs` | 本地游玩数据看板（`tools/telemetry_dashboard.mjs`）的 Node 测试（node:test，零第三方依赖）： | [查看](./tests/telemetry-dashboard.test.mjs.md) |
| `tests/telemetry.test.mjs` | 游玩数据接收端 Node 测试（node:test，零第三方依赖）：覆盖 health、合法/非法上传、存储与索引、限流、令牌、方法/路径错误与 180 天保留清理。 | [查看](./tests/telemetry.test.mjs.md) |
| `tools/build-release-data.mjs` | 从 GitHub Releases API 生成官网的版本数据文件 `website/assets/data/release-data.js`（`window.SN_RELEASE_DATA`）， | [查看](./tools/build-release-data.mjs.md) |
| `tools/build-wiki-data.mjs` | 把 Core 内容 JSON（`dev_mods/core/content/*.json`）与中文文案（`dev_mods/core/localization/zh_CN.json`）编译成官网百科数据 `website/assets/data/wiki-data.js`。 | [查看](./tools/build-wiki-data.mjs.md) |
| `tools/ci.ps1` | 官网本地 CI：构建生产镜像，以生产资源限制跑容器冒烟，通过后用 Docker Compose 部署到本机。 | [查看](./tools/ci.ps1.md) |
| `tools/serve.mjs` | 零依赖本地静态预览服务器，用于开发与验收官网（不对公网部署）；同时挂载游玩数据接收端方便游戏端联调。 | [查看](./tools/serve.mjs.md) |
| `tools/telemetry_dashboard.mjs` | 本地「游玩数据看板」：零依赖 Node 服务，在 127.0.0.1:8091 提供单页前端，只读展示遥测接收端落盘在 | [查看](./tools/telemetry_dashboard.mjs.md) |
| `wiki.html` | 游戏百科页：分类导航、搜索、条目卡片与深链接，数据由生成脚本提供。 | [查看](./wiki.html.md) |

## 模块契约

- 零依赖、无构建步骤、无 CDN / 外部字体；本地预览 `node website/tools/serve.mjs`，生产环境交给任意静态托管。
- 首页禁止出现开发 / 调试 / 测试 / 版本号 / GitHub / Godot / 模组等信息；版本与构建信息只允许出现在下载页与开发日志页。
- 下载页只使用真实 GitHub Release 资产；发版后同步下载页版本、日期、体积与链接，并更新开发日志。
- 百科数据由 `website/tools/build-wiki-data.mjs` 从 `dev_mods/core` 生成，页面不得手改 `assets/data/wiki-data.js` 或展示 `core:` ID。
- 图片必须裁掉调试 UI 与开发者署名，来源、裁切与体积记录在 `website/assets/img/MANIFEST.md`。
- 页面在无 JS 时仍可阅读；`prefers-reduced-motion` 下关闭动画。
