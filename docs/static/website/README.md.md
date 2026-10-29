# `website/README.md`

> 作用：官网使用说明：本地预览、目录结构、内容边界、版本更新清单、百科数据生成、游玩数据接收端联调、本地数据看板、运行时内容 API 与生产部署。

- 类型：项目配置/数据文件

契约与约束
- 站点零依赖、无构建步骤；预览用 `node website/tools/serve.mjs`（同时提供本地 `/api/telemetry/*` 接收端）。
- 首页禁止开发 / 调试信息；版本信息只允许出现在下载页与开发日志页。
- `assets/data/wiki-data.js` 为生成物，不得手改；图片说明见 `assets/img/MANIFEST.md`。
- `assets/data/release-data.js` 为生成物（GitHub Releases → 版本 / 日期 / 大小 / 下载直链），不得手改；
下载页与开发日志页通过 `assets/js/release.js` 的 `data-release` / `data-release-link` 契约自动填充，
运行时还会请求同域 `/api/site/release` 刷新到 GitHub 最新 Release（无需重新部署）。
- `site-api` 同时提供游戏内自动更新接口 `GET /api/site/update`：镜像最新 Release 的 `update-manifest.json`、
Windows zip 与 `core-*.snavmod.zip`，只返回通过 `SHA256SUMS.txt` 交叉校验的清单数据（契约
`docs/design/AUTO_UPDATE.md` §4）。
- 生产为三个镜像：nginx alpine 静态站（非 root / 8080）+ node 22 游玩数据接收端（非 root / 8090 / `/data` 数据卷）
+ node 22 只读内容 API（非 root / 8092 / 服务端缓存 GitHub Releases）；可选 `telemetry-dashboard` 看板镜像
（非 root / 8091 / 只读数据卷，`--profile dashboard`）。
- Compose 默认限制静态站 32 MB、接收端 64 MB、内容 API 48 MB，只把网站端口绑定到 `127.0.0.1`，公网入口交给
Cloudflare Tunnel；看板同样只绑定 `127.0.0.1:8091`，不是官网页面。
- 游玩数据接收端契约是 `docs/design/TELEMETRY.md` §3/§4：不改 schema、路由、状态码与存储路径。

模块索引：[website](./README.md)
