<!-- @static-doc
作用：官网使用说明：本地预览、目录结构、内容边界、版本更新清单、百科数据生成与部署方式。

## 契约与约束
- 站点零依赖、无构建步骤；预览用 `node website/tools/serve.mjs`。
- 首页禁止开发 / 调试信息；版本信息只允许出现在下载页与开发日志页。
- `assets/data/wiki-data.js` 为生成物，不得手改；图片说明见 `assets/img/MANIFEST.md`。
- 生产镜像为 nginx alpine 单 worker 静态站；Compose 默认限制 32 MB 内存，只把端口绑定到 127.0.0.1，公网入口交给 Cloudflare Tunnel。
@end-static-doc -->

# 蒸汽航海 官方网站

《蒸汽航海 / Steam Navigator》的零依赖静态官网。纯 HTML / CSS / 原生 JS，无需构建步骤，放到任意静态托管即可访问。

## 本地预览

```powershell
node website/tools/serve.mjs
# 打开 http://127.0.0.1:4173/
```

换端口：`node website/tools/serve.mjs 4174`。
不要直接双击 `index.html`：浏览器对 `file://` 的脚本与资源限制不同，可能导致部分交互失效，预览请走本地服务器。

## 目录

```text
website/
├── index.html          首页（只讲游戏，不放开发/调试信息）
├── game.html           游戏信息：世界、玩法循环、特色、港口、势力
├── wiki.html           游戏百科：搜索 + 分类筛选
├── devlog.html         开发日志：版本时间线与下一阶段
├── download.html       下载：平台、版本、需求、安装、FAQ
├── favicon.svg
├── assets/
│   ├── css/site.css    设计系统 + 全站样式 + 响应式
│   ├── js/site.js      导航、滚动揭示、灯箱、页脚年份
│   ├── js/wiki.js      百科渲染 / 搜索 / 分类 / 深链接
│   ├── data/wiki-data.js  由 Core 内容生成的百科数据
│   └── img/            官网图片（含 MANIFEST.md 来源记录）
├── tools/
│   ├── build-wiki-data.mjs  Core 内容 → wiki-data.js
│   ├── serve.mjs            本地预览服务器
│   └── ci.ps1               本地 CI：构建 / 冒烟 / 部署
├── deploy/
│   ├── Dockerfile          nginx alpine 生产镜像（非 root / 单 worker）
│   └── nginx.conf          静态站 nginx 配置（gzip / 缓存 / 健康检查）
├── docker-compose.yml      低内存运行 + 可选 Cloudflare Tunnel
├── .env.example            Cloudflare Tunnel token 示例
├── .gdignore               阻止 Godot 导入站点目录
└── README.md
```

## 内容边界

- **首页**不出现开发 / 调试信息：没有版本号、更新日志、测试状态、Godot / GitHub / 模组等开发者词汇。
- 版本号、更新说明、构建信息只出现在 `download.html` 与 `devlog.html`。
- 导航与页脚中的「开发日志」链接是允许的（用户明确要求该子页面存在）。
- 修改页面后请按 `docs/design/WEBSITE.md` §1 的禁用词表自查首页。

## 更新发布版本

新版本发布后需要同步三处：

1. `download.html`：版本号、日期、文件大小、下载链接、校验文件链接（共 4 个 GitHub Release 链接 × 平台）。
2. `devlog.html`：在 `.timeline` 顶部追加一条 `log-entry`，更新页头「最新版本 / 最近更新」。
3. 首页不写版本，因此无需改动。

下载链接使用真实 GitHub Release 资产：
`https://github.com/xs-www/SteamNavigator/releases/download/<tag>/<filename>`。
发版后可运行 `pwsh` 或 `curl -I` 抽查链接是否为 200。

## 百科数据

`assets/data/wiki-data.js` 是从游戏内容生成的，不要手改：

```powershell
node website/tools/build-wiki-data.mjs
```

来源（只读）：`dev_mods/core/content/*.json`、`dev_mods/core/localization/zh_CN.json`。
输出格式见 `docs/design/WEBSITE.md` §6；改完内容 JSON 后重新生成即可。

## 图片

`assets/img/` 的 JPG 由 `docs/design/screenshots/` 与 `assets/ui/banners/` 裁切压缩而来，来源、尺寸与处理方式记录在 `assets/img/MANIFEST.md`。
修改图片时保持文件名与目标尺寸不变，避免破坏页面布局。

## Docker 镜像

生产镜像只包含静态页面与 nginx，不包含游戏本体、Node 或构建工具。镜像内 nginx 以非 root 用户运行，单 worker，容器内监听 8080。

```bash
docker build -f website/deploy/Dockerfile -t steam-navigator-website:local website
docker run --rm -p 127.0.0.1:8088:8080 \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=8m \
  --memory 32m --cpus 0.25 --pids-limit 64 \
  --cap-drop ALL --security-opt no-new-privileges \
  steam-navigator-website:local
# 打开 http://127.0.0.1:8088/ 或 curl http://127.0.0.1:8088/healthz
```

需要 Docker Compose v2（`docker compose` 子命令）。用 Compose 本地跑：

```bash
cd website
docker compose up -d --build
docker compose ps
curl -fsS http://127.0.0.1:8088/healthz
```

## 本地 CI：构建、冒烟、部署

不需要远程 registry，也不依赖远程 runner。所有步骤在本机 Docker 上完成：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File website/tools/ci.ps1
```

脚本会依次执行：

1. 构建 `steam-navigator-website:local` 镜像（构建上下文只包含 `website/`）。
2. 启动临时容器（`127.0.0.1:18080`，32 MB 内存、只读文件系统、0.25 CPU、丢弃 capabilities），检查：
   - `/healthz` 返回 `ok`
   - 首页、游戏信息、百科、CSS 可访问
   - 未知路径返回 404
   - HTML 为 `no-cache`，`assets/` 为 7 天缓存
   - CSS 启用 gzip
3. 任一项失败：打印容器日志并退出，不部署。
4. 全部通过：执行 `docker compose up -d --build website`，再读取 Compose 实际映射的宿主机端口并检查 `/healthz`，打印容器内存占用。

常用参数：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File website/tools/ci.ps1 -SkipDeploy      # 只构建 + 冒烟，不部署
powershell -NoProfile -ExecutionPolicy Bypass -File website/tools/ci.ps1 -SkipSmoke       # 跳过冒烟，仅部署（不建议）
powershell -NoProfile -ExecutionPolicy Bypass -File website/tools/ci.ps1 -SmokePort 18081 # 自定义冒烟端口
```

部署完成后更新 Cloudflare Tunnel（如果还没有启动）：

```powershell
cd website
Copy-Item .env.example .env
# 编辑 .env，填入 TUNNEL_TOKEN
docker compose --profile tunnel up -d
```

之后每次改官网，只需重跑上面的 CI 命令，本机容器会被重新构建并替换。
如果已安装 PowerShell 7，也可以用 `pwsh ./website/tools/ci.ps1`；脚本兼容 Windows PowerShell 5.1（文件带 UTF-8 BOM）。

## Cloudflare Tunnel

Compose 默认把宿主机 8088 绑定到 `127.0.0.1`（容器内 8080，可用 `.env` 的 `WEBSITE_PORT` 修改），公网入口推荐走 Cloudflare Tunnel，不需要在路由器/防火墙开放端口。

### 方式 A：cloudflared 也放在 Compose 里（推荐）

1. 复制 `.env.example` 为 `.env`，填入 Cloudflare Zero Trust 创建的 Tunnel token。
2. 启动带 tunnel profile 的 Compose：

```bash
cd website
docker compose --profile tunnel up -d
```

3. 在 Cloudflare Zero Trust → Networks → Tunnels 的 Public Hostname 中添加：
   - 域名：`game.example.com`（换成你的域名）
   - Service：`http://website:8080`
4. 在 Cloudflare DNS 中确认该域名由 Tunnel 接管，通常向导会自动创建 CNAME；开启代理（橙色云）。
5. SSL/TLS 模式按 Tunnel 向导默认即可（通常 Full）；TLS 在 Cloudflare 边缘终止，源站只走本地 HTTP。

### 方式 B：cloudflared 跑在宿主机

在宿主机安装 cloudflared 并运行 Tunnel，Public Hostname 的 Service 填：

```text
http://127.0.0.1:8088
```

### 缓存与安全头

- `assets/` 由 nginx 返回 `Cache-Control: max-age=604800`，Cloudflare 默认会缓存静态资源。
- HTML 返回 `Cache-Control: no-cache`，发布新版后入口页会重新校验。
- nginx 已附带 `X-Content-Type-Options` / `X-Frame-Options` / `Referrer-Policy` / `Permissions-Policy`。
- 如果使用 Cloudflare Cache Rules，可对 `/assets/*` 设置更长的 Edge TTL，对 HTML 设置为不缓存。

## 内存与资源

| 容器 | 限制 | 实测/说明 |
| --- | --- | --- |
| `website` | 32 MB / 0.25 CPU | 静态 nginx 空闲约 2–3 MiB；16 MB 也能启动，32 MB 留出并发余量 |
| `cloudflared` | 64 MB | Cloudflare 官方镜像；只在启用 `tunnel` profile 时启动 |

如果出现 OOM 或 502，把 `docker-compose.yml` 的 `mem_limit` 提到 48m；静态站通常不需要更高。

## 静态托管替代方案

如果不想维护 Docker，也可以把 `website/` 直接发布到 Cloudflare Pages 或任意静态托管：所有站内链接都是相对路径，不需要 Node 构建。Docker + Tunnel 方案适合已有服务器、想自己控制运行环境的情况。

## 验收

```powershell
node website/tools/serve.mjs
# 另开终端
# 首页禁用词自查（导航与页脚中的「开发日志」链接除外，需人工排除）
Select-String -Path website/index.html -Pattern '开发|调试|测试|原型|MVP|版本|GitHub|Godot|模组|引擎|构建|诊断|日志|文档|代码|dev|build|debug|changelog'
```

浏览器检查：1440×900 / 1024×768 / 390×844 无横向滚动；百科搜索、分类、`#entry-*` / `#cat-*` 深链接可用；灯箱可用 Esc 关闭。
