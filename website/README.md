<!-- @static-doc
作用：官网使用说明：本地预览、目录结构、内容边界、版本更新清单、百科数据生成、游玩数据接收端联调、本地数据看板、运行时内容 API 与生产部署。

## 契约与约束
- 站点零依赖、无构建步骤；预览用 `node website/tools/serve.mjs`（同时提供本地 `/api/telemetry/*` 接收端）。
- 首页禁止开发 / 调试信息；版本信息只允许出现在下载页与开发日志页。
- `assets/data/wiki-data.js` 为生成物，不得手改；图片说明见 `assets/img/MANIFEST.md`。
- `assets/data/release-data.js` 为生成物（GitHub Releases → 版本 / 日期 / 大小 / 下载直链），不得手改；
  下载页与开发日志页通过 `assets/js/release.js` 的 `data-release` / `data-release-link` 契约自动填充，
  运行时还会请求同域 `/api/site/release` 刷新到 GitHub 最新 Release（无需重新部署）。
- 生产为三个镜像：nginx alpine 静态站（非 root / 8080）+ node 22 游玩数据接收端（非 root / 8090 / `/data` 数据卷）
  + node 22 只读内容 API（非 root / 8092 / 服务端缓存 GitHub Releases）；可选 `telemetry-dashboard` 看板镜像
  （非 root / 8091 / 只读数据卷，`--profile dashboard`）。
- Compose 默认限制静态站 32 MB、接收端 64 MB、内容 API 48 MB，只把网站端口绑定到 `127.0.0.1`，公网入口交给
  Cloudflare Tunnel；看板同样只绑定 `127.0.0.1:8091`，不是官网页面。
- 游玩数据接收端契约是 `docs/design/TELEMETRY.md` §3/§4：不改 schema、路由、状态码与存储路径。
@end-static-doc -->

# 蒸汽航海 官方网站

《蒸汽航海 / Steam Navigator》的零依赖静态官网。纯 HTML / CSS / 原生 JS，无需构建步骤，放到任意静态托管即可访问。
游玩数据接收端（`server/telemetry.mjs`）是同一目录下的零依赖 Node 服务，生产由 nginx 同域反代。

## 本地预览

```powershell
node website/tools/serve.mjs
# 打开 http://127.0.0.1:4173/
```

换端口：`node website/tools/serve.mjs 4174`。
不要直接双击 `index.html`：浏览器对 `file://` 的脚本与资源限制不同，可能导致部分交互失效，预览请走本地服务器。

本地预览同样提供游玩数据接口（数据写 `website/.data/telemetry/`，已 gitignore）：

```powershell
curl.exe http://127.0.0.1:4173/api/telemetry/health
# {"ok":true,"service":"sn-telemetry","schema":"sn.telemetry.session/1"}
```

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
│   ├── js/release.js   版本信息填充（读取 release-data.js → 版本/日期/大小/链接）
│   └── img/            官网图片（含 MANIFEST.md 来源记录）
│   ├── data/release-data.js  由 GitHub Releases 生成的版本数据（勿手改）
├── tools/
├── server/
│   ├── telemetry.mjs   游玩数据接收端：路由 / 校验 / 限流 / 存储 / 保留清理
│   └── site_api.mjs    官网只读内容 API：服务端缓存 GitHub Releases（/api/site/release）
├── tests/
│   ├── telemetry.test.mjs  接收端 node:test 测试（零依赖）
│   ├── site-api.test.mjs   内容 API node:test 测试（缓存 / 降级 / 503）
│   └── release-data.test.mjs  版本数据生成器 node:test 测试
├── tools/
│   ├── build-wiki-data.mjs  Core 内容 → wiki-data.js
│   ├── build-release-data.mjs  GitHub Releases → release-data.js
│   ├── serve.mjs            本地预览服务器（含 /api/telemetry/*）
│   └── ci.ps1               本地 CI：构建 / 冒烟 / 部署
│   ├── telemetry_dashboard.mjs  本地游玩数据看板（127.0.0.1:8091，只读）
├── deploy/
│   ├── Dockerfile          nginx alpine 静态站镜像（非 root / 单 worker）
│   ├── Dockerfile.telemetry  node 22 接收端镜像（非 root / 8090 / /data）
│   ├── Dockerfile.site-api   node 22 内容 API 镜像（非 root / 8092 / 服务端缓存 GitHub）
│   ├── Dockerfile.dashboard  看板镜像（node 22 / 非 root / 8091 / 只读数据卷）
│   └── nginx.conf          静态站 + /api/telemetry/ + /api/site/ 反代配置
├── .data/telemetry/        本地接收端数据（gitignore，不入库）
├── docker-compose.yml      静态站 + 接收端 + 内容 API + 可选看板 / Cloudflare Tunnel
├── .env.example            Compose 变量与数据说明
├── .gdignore               阻止 Godot 导入站点目录
└── README.md
```

## 内容边界

- **首页**不出现开发 / 调试信息：没有版本号、更新日志、测试状态、Godot / GitHub / 模组等开发者词汇。
- 版本号、更新说明、构建信息只出现在 `download.html` 与 `devlog.html`。
- 导航与页脚中的「开发日志」链接是允许的（用户明确要求该子页面存在）。
- 修改页面后请按 `docs/design/WEBSITE.md` §1 的禁用词表自查首页。

## 更新发布版本（自动）

官网的版本号、发布日期、文件大小与下载直链**不再手改**，有两条自动路径：

1. **运行时（主力，发版后不用重新部署）**：`server/site_api.mjs`（Compose 服务 `site-api`）在服务端缓存
   GitHub Releases（默认 5 分钟），页面 `assets/js/release.js` 先渲染静态数据，再请求同域
   `/api/site/release` 刷新。**发布 Release 后最迟约 5 分钟，线上页面自动变成最新版本**，无需重建镜像。
2. **构建期 fallback**：`tools/build-release-data.mjs` 调 GitHub Releases API 生成
   `assets/data/release-data.js`，作为静态兜底与纯静态托管时使用；`ci.ps1` 构建前会自动刷新。

```powershell
# 手动刷新静态数据（通常不需要：ci.ps1 构建前会自动跑）
node website/tools/build-release-data.mjs

# 校验仓库里的静态数据是否落后于 GitHub 最新 Release（CI / 发版前可用）
node website/tools/build-release-data.mjs --check
```

# 本地验证运行时 API（部署后）
curl.exe http://127.0.0.1:8088/api/site/release

- **自动时机**：
  - 运行时：`site-api` 每 5 分钟从 GitHub 刷新一次；页面每次打开都会拿最新缓存值。
  - 构建期：`ci.ps1` 构建前刷新（`-SkipReleaseData` 可跳过）。
  - 仓库数据：`release.yml` 在发布 Release 后直接同步（`GITHUB_TOKEN` 创建的 Release 不会再触发独立
    workflow，所以同步放在发布流程末尾）；人工在 GitHub UI 发布的 Release 由
    `.github/workflows/website-release-data.yml` 处理，也可手动 `workflow_dispatch` 补同步。
- **离线/API 失败**：`site-api` 依次使用旧缓存 → 镜像内静态文件；再失败才返回 503，页面保留静态值。
- **测试**：`node --test website/tests/site-api.test.mjs website/tests/release-data.test.mjs`。
- **契约**：`latest` 取最新非 draft Release（官网目前发布预发布版本），`stable` 取最新正式版；
  平台链接只使用该 Release 的真实 assets，缺失时页面保留静态 fallback。
- 版本时间线（`devlog.html` 的 `.timeline` 条目）仍人工维护，只自动同步页头版本与日期；
  首页不写版本，无需改动。

```powershell
# 抽查下载链接（替换为生成文件里的最新 tag/文件名）
curl.exe -I https://github.com/xs-www/SteamNavigator/releases/download/<tag>/<filename>
```

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

## 游玩数据接收端（Telemetry）

契约：`docs/design/TELEMETRY.md`（§3 客户端上传协议、§4 官网接收端）。游戏端只在玩家勾选「允许上传数据」后，于退出时上传本局游玩摘要；接收端按 `session_id` 归档，方便后续统计。

### 接口

| 方法 | 路径 | 结果 |
| --- | --- | --- |
| GET | `/api/telemetry/health` | `200 {"ok":true,"service":"sn-telemetry","schema":"sn.telemetry.session/1"}` |
| POST | `/api/telemetry/session` | 校验通过 `204`（无响应体） |

- `400` 坏 JSON；`401` 令牌不匹配（仅 `SN_TELEMETRY_TOKEN` 非空时）；`413` 请求体超过 512 KiB；
  `422` schema / `session_id` / 时间 / 数值 / Content-Type 不合法；`429` 超过每小时配额；`405` 方法不允许；`404` 未知路径；`500` 落盘失败（客户端下次启动重试）。
- 限流：每来源 IP 每小时 120 次；来源取 `X-Forwarded-For` 第一段（nginx 写入），否则 socket 地址；只在内存计数，不落盘、不写 IP 日志。
- 存储：`<数据目录>/sessions/<YYYY-MM-DD>/<session_id>.json` + 同目录 `index.ndjson` 摘要行；保留 180 天（每小时至多一次惰性清理）。

### 本地联调（游戏端 → 官网接收端）

1. 起预览服务器：`node website/tools/serve.mjs`（默认 `http://127.0.0.1:4173/`，接收端数据写 `website/.data/telemetry/`）。
2. 手动验证接口（PowerShell）：

```powershell
# 健康检查
curl.exe http://127.0.0.1:4173/api/telemetry/health

# 合法会话：返回 204，无响应体
curl.exe -i -X POST http://127.0.0.1:4173/api/telemetry/session -H "Content-Type: application/json" --data-binary '{"schema":"sn.telemetry.session/1","session_id":"local-smoke-0001","started_at":"2026-10-27T08:15:00Z","ended_at":"2026-10-27T08:23:32Z","duration_seconds":512,"game_version":"0.2.0","commands":[{"seq":1,"command":"trade.buy","ok":true}],"errors":[]}'

# 非法会话：返回 422（schema 不匹配）
curl.exe -i -X POST http://127.0.0.1:4173/api/telemetry/session -H "Content-Type: application/json" --data-binary '{"schema":"wrong"}'
```

3. 让游戏端指向本地接口（`config/config.json`；`telemetry` 默认 `false`，设置页勾选「允许上传数据」后才会记录并上传）：

```json
{
  "version": 1,
  "locale": "zh_CN",
  "autosave": true,
  "telemetry": true,
  "telemetry_endpoint": "http://127.0.0.1:4173/api/telemetry/session",
  "telemetry_token": ""
}
```

4. 正常退出游戏后，本地应出现：

```text
website/.data/telemetry/sessions/2026-10-27/20261027T081500Z-1a2b3c4d.json
website/.data/telemetry/sessions/2026-10-27/index.ndjson
```

目录名是接收端的接收日期（UTC）。关掉设置开关后不产生 pending，也不会写入 `.data/`。

5. 本地接收端也能校验令牌：`$env:SN_TELEMETRY_TOKEN="dev-token"; node website/tools/serve.mjs`，
   请求时带 `-H "X-SN-Telemetry-Token: dev-token"`。

### 查看数据（本地看板）

看板是**本地工具**，不是官网页面、也不进入站点导航；默认只绑定 `127.0.0.1`，只读数据目录。

```powershell
# 本地预览数据（website/.data/telemetry/）
node website/tools/telemetry_dashboard.mjs
# 打开 http://127.0.0.1:8091/ ；换端口：--port 8092；换数据目录：--data-dir D:\backup\telemetry

# 生产数据（只读挂载 compose 数据卷；只发布到 127.0.0.1:8091）
cd website
docker compose --profile dashboard up -d --build telemetry-dashboard
# 同样打开 http://127.0.0.1:8091/
```

- 页面能力：会话列表（接收时间 / 版本 / 时长 / 命令 / 错误 / 字节）、日期筛选、条数上限、10 秒自动刷新、点击行查看完整 JSON。
- 只读接口：`GET /api/sessions?limit=&date=`、`GET /api/sessions/<session_id>`；索引缺失时回退扫描 JSON；不写数据目录。
- 停止看板：`docker compose --profile dashboard stop telemetry-dashboard`（不删除数据卷）。

### 测试

```powershell
node --test website/tests/telemetry.test.mjs website/tests/telemetry-dashboard.test.mjs
node --check website/server/telemetry.mjs
node --check website/tools/serve.mjs
node --check website/tools/telemetry_dashboard.mjs
```

测试用临时目录 + 随机端口，不碰 `website/.data/`、不需要 Docker。

### 生产部署

Compose 同时起三个服务：

- `website`：nginx 静态站，容器内 8080，只映射到 `127.0.0.1:8088`；`/api/telemetry/` 反代到接收端、`/api/site/` 反代到内容 API。
- `site-api`：只读内容 API，容器内 8092，**不映射宿主机端口**；服务端缓存 GitHub Releases（默认 5 分钟），发版后网站自动显示最新版本，无需重新部署。
- `telemetry`：Node 接收端，容器内 8090，**不映射宿主机端口**，只被 `website` 访问；`website` 等它 healthcheck 通过才启动。
- `telemetry-dashboard`（可选，`--profile dashboard`）：看板容器，只读挂载同一个数据卷，只映射到 `127.0.0.1:8091`。
- nginx：`location /api/telemetry/` → `http://telemetry:8090`（原样保留 URI、`client_max_body_size 1m`、只允许 GET/POST、关闭该 location 的 access_log 以免记录客户端 IP）；`location /api/site/` → `http://site-api:8092`（只允许 GET/HEAD）。

```bash
cd website
cp .env.example .env      # 需要令牌校验时填 SN_TELEMETRY_TOKEN；可选填 SN_SITE_GITHUB_TOKEN
docker compose up -d --build
curl -fsS http://127.0.0.1:8088/api/site/release
curl -fsS http://127.0.0.1:8088/api/telemetry/health
```

数据卷 `steam-navigator-website_telemetry-data` 挂到容器内 `/data`：

```text
/data/sessions/2026-10-27/<session_id>.json   原始游玩会话（紧凑 JSON，同名覆盖 = 幂等）
/data/sessions/2026-10-27/index.ndjson        每行一条摘要：session_id / received_at / game_version / duration_seconds / commands / errors / bytes
```

### 保留期与备份

- 保留 180 天：每次成功写入后最多每小时清理一次，删除 180 天前的日期目录；非日期目录 / 文件不动。
- 查看卷位置：`docker volume inspect steam-navigator-website_telemetry-data`。
- 备份（PowerShell，把整卷打成 tar.gz）：

```powershell
New-Item -ItemType Directory -Force backup | Out-Null
docker run --rm -v steam-navigator-website_telemetry-data:/data:ro -v "${PWD}/backup:/backup" alpine tar czf "/backup/telemetry-$(Get-Date -Format yyyyMMdd-HHmmss).tgz" -C /data .
```

- 恢复：把备份解回卷，`docker run --rm -v steam-navigator-website_telemetry-data:/data -v "${PWD}/backup:/backup" alpine sh -c "tar xzf /backup/<文件名>.tgz -C /data"`。
  升级 / 迁移前先备份；`sessions/` 与 `index.ndjson` 都要保留（缺原始 JSON 会导致统计不完整）。
- 令牌：`.env` 的 `SN_TELEMETRY_TOKEN` 与游戏发布配置注入的 `SN_TELEMETRY_TOKEN` 保持一致；改完重启 `telemetry` 容器，游戏端下次启动时生效。
- 单独跑接收端镜像调接口：

```bash
docker build -f website/deploy/Dockerfile.telemetry -t steam-navigator-telemetry:local website
docker run --rm -p 127.0.0.1:8090:8090 --read-only --tmpfs /tmp:rw,noexec,nosuid,size=8m \
  --memory 64m --cpus 0.5 --pids-limit 64 --cap-drop ALL --security-opt no-new-privileges \
  -v sn-telemetry-dev:/data steam-navigator-telemetry:local
```

注意：只用 `docker run` 跑静态站镜像、没有 Compose 网络时，`/api/telemetry/` 会返回 502——nginx 在请求时解析不到 `telemetry` 服务名，这是预期行为，静态页面不受影响。

## Docker 镜像

生产用三个镜像：

- `steam-navigator-website:local`（`deploy/Dockerfile`）：只包含静态页面与 nginx，不包含游戏本体、Node 或构建工具；nginx 以非 root 运行，单 worker，容器内监听 8080。
- `steam-navigator-site-api:local`（`deploy/Dockerfile.site-api`）：node:22-alpine 跑 `server/site_api.mjs`，非 root，监听 8092，服务端缓存 GitHub Releases；镜像内烘焙 `release-data.js` 作为 fallback。
- `steam-navigator-telemetry:local`（`deploy/Dockerfile.telemetry`）：node:22-alpine 跑 `server/telemetry.mjs`，非 root，监听 8090，数据写 `/data`。

```bash
docker build -f website/deploy/Dockerfile.telemetry -t steam-navigator-telemetry:local website
docker build -f website/deploy/Dockerfile.site-api -t steam-navigator-site-api:local website
docker build -f website/deploy/Dockerfile -t steam-navigator-website:local website
docker run --rm -p 127.0.0.1:8088:8080 \
  --read-only \
docker build -f website/deploy/Dockerfile.telemetry -t steam-navigator-telemetry:local website
  --tmpfs /tmp:rw,noexec,nosuid,size=8m \
  --memory 32m --cpus 0.25 --pids-limit 64 \
  --cap-drop ALL --security-opt no-new-privileges \
  steam-navigator-website:local
# 打开 http://127.0.0.1:8088/ 或 curl http://127.0.0.1:8088/healthz
```

需要 Docker Compose v2（`docker compose` 子命令）。用 Compose 本地跑（会一起构建 / 启动静态站与接收端）：

```bash
cd website
docker compose up -d --build
curl -fsS http://127.0.0.1:8088/api/telemetry/health
docker compose ps
curl -fsS http://127.0.0.1:8088/healthz
```

curl -fsS http://127.0.0.1:8088/api/telemetry/health
## 本地 CI：构建、冒烟、部署

不需要远程 registry，也不依赖远程 runner。所有步骤在本机 Docker 上完成：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File website/tools/ci.ps1
```

脚本会依次执行：

1. 构建 `steam-navigator-website:local` 镜像（构建上下文只包含 `website/`）。
2. 启动临时容器（`127.0.0.1:18080`，32 MB 内存、只读文件系统、0.25 CPU、丢弃 capabilities），检查：
   - `/healthz` 返回 `ok`
   - 首页、游戏信息、百科、开发团队、版本数据、CSS 可访问
   - 未知路径返回 404
   - HTML 为 `no-cache`，`assets/` 为 7 天缓存，版本数据 `release-data.js` 为 `no-cache`
   - CSS 启用 gzip
3. 任一项失败：打印容器日志并退出，不部署。
4. 全部通过：执行 `docker compose up -d --build website site-api`（Compose 会连带启动它依赖的 `telemetry` 服务），
   再读取 Compose 实际映射的宿主机端口并检查 `/healthz`、`/api/site/release`，打印容器内存占用。

常用参数：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File website/tools/ci.ps1 -SkipDeploy      # 只构建 + 冒烟，不部署
powershell -NoProfile -ExecutionPolicy Bypass -File website/tools/ci.ps1 -SkipSmoke       # 跳过冒烟，仅部署（不建议）
powershell -NoProfile -ExecutionPolicy Bypass -File website/tools/ci.ps1 -SmokePort 18081 # 自定义冒烟端口
```

部署完成后更新 Cloudflare Tunnel（如果还没有启动）：

只改接收端时可以先跑 Node 测试，再单独重建容器：

```powershell
node --test website/tests/telemetry.test.mjs
cd website
docker compose up -d --build telemetry
```

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
- 如果使用 Cloudflare Cache Rules，可对 `/assets/*` 设置更长的 Edge TTL，对 HTML 设置为不缓存；
  并确保 `/api/telemetry/*`、`/api/site/*` 不缓存、POST 原样透传（接收端已返回 `Cache-Control: no-store`，
  内容 API 返回 60 秒短缓存）；`/assets/data/release-data.js` 保持 `no-cache`（已由 nginx 单独配置）。

## 内存与资源

| `telemetry` | 64 MB / 0.5 CPU | Node 22 接收端；空闲通常 20–40 MiB，64 MB 覆盖每小时清理扫描与并发请求 |
| `site-api` | 48 MB / 0.2 CPU | Node 22 只读内容 API；实测空闲约 17 MiB（含 GitHub 缓存），GitHub 不可用时自动回退静态文件 |
| 容器 | 限制 | 实测/说明 |
| --- | --- | --- |
| `website` | 32 MB / 0.25 CPU | 静态 nginx 空闲约 2–3 MiB；16 MB 也能启动，32 MB 留出并发余量 |
| `cloudflared` | 64 MB | Cloudflare 官方镜像；只在启用 `tunnel` profile 时启动 |

| `telemetry` | 64 MB / 0.5 CPU | Node 22 接收端；空闲通常 20–40 MiB，64 MB 覆盖每小时清理扫描与并发请求 |
如果出现 OOM 或 502，把 `docker-compose.yml` 对应服务的 `mem_limit` 提高（静态站 48m、接收端 96m）；静态站通常不需要更高。

## 静态托管替代方案

如果不想维护 Docker，也可以把 `website/` 直接发布到 Cloudflare Pages 或任意静态托管：所有站内链接都是相对路径，不需要 Node 构建。此时页面使用构建期生成的 `release-data.js`（版本数据不会运行时刷新），`/api/site/*` 与 `/api/telemetry/*` 不可用；Docker + Tunnel 方案适合已有服务器、想自己控制运行环境并让版本自动追随 GitHub Release 的情况。

## 验收

```powershell
node website/tools/serve.mjs
# 另开终端
# 首页禁用词自查（导航与页脚中的「开发日志」链接除外，需人工排除）
Select-String -Path website/index.html -Pattern '开发|调试|测试|原型|MVP|版本|GitHub|Godot|模组|引擎|构建|诊断|日志|文档|代码|dev|build|debug|changelog'
# 运行时版本 API 只由 Compose 提供（本地预览 serve.mjs 不挂载，页面自动用静态 fallback）：
curl.exe http://127.0.0.1:8088/api/site/release
```

```


# 游玩数据接收端 / 内容 API / 版本数据
node --test website/tests/telemetry.test.mjs website/tests/telemetry-dashboard.test.mjs website/tests/site-api.test.mjs website/tests/release-data.test.mjs
curl.exe http://127.0.0.1:4173/api/telemetry/health
浏览器检查：1440×900 / 1024×768 / 390×844 无横向滚动；百科搜索、分类、`#entry-*` / `#cat-*` 深链接可用；灯箱可用 Esc 关闭。
接收端契约验收见 `docs/design/TELEMETRY.md` §6；版本自动更新验收见 `docs/design/WEBSITE.md` §7；本地看板打开 `http://127.0.0.1:8091/` 能看到列表与 JSON 详情。
