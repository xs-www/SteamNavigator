# `website/tools/build-release-data.mjs`

> 作用：从 GitHub Releases API 生成官网的版本数据文件 `website/assets/data/release-data.js`（`window.SN_RELEASE_DATA`），

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TOOLS_DIR` | L31 |
| `DEFAULT_OUT` | L32 |
| `API_BASE` | L36 |
| `PER_PAGE` | L37 |
| `isValidTimeZone(timeZone)` | L39 |
| `resolveTimeZone(value)` | L50 |
| `formatDateInTimeZone(iso, timeZone)` | L60 |
| `pickAsset(assets, pattern)` | L81 |
| `normalizeAsset(asset)` | L86 |
| `normalizeLatest(raw, timeZone)` | L100 |
| `selectReleases(rawReleases, options = {})` | L116 |
| `buildReleaseData(rawReleases, options = {})` | L130 |
| `renderReleaseDataFile(data)` | L156 |
| `parseReleaseDataFile(text)` | L165 |
| `comparable(data)` | L175 |
| `fetchReleases(options = {})` | L183 |
| `updateReleaseData(options = {})` | L213 |
| `parseArgs(argv)` | L247 |

让下载页 / 开发日志页的版本号、发布日期、文件大小与下载链接不再手改。零依赖 Node（>= 18，内置 fetch）。

## 契约与约束
- 数据来源：`https://api.github.com/repos/xs-www/SteamNavigator/releases?per_page=30`（`--repo` 可覆盖）。
  只读公开 Release API；`GITHUB_TOKEN` / `--token` 可选，仅用于提高限流额度，不写入输出。
- `latest` = 第一个非 draft release（包含预发布，官网当前就是预发布版本）；`stable` = 第一个非 draft 非 prerelease，可为 null。
- 输出结构固定（见 `buildReleaseData`）：`latest` / `stable` / `links`；`links` 只从该 release 的真实 assets 名称推导，
  缺失的平台资产留 `null`，前端保留原静态文案，不伪造下载地址。
- 生成物只含公开版本信息（tag / 名称 / 发布时间 / 资产名 / 字节数 / GitHub 链接），不含 token 或私有数据。
- 网络失败时默认保留上一次生成的文件并 exit 0（离线部署不炸站）；`--strict` 才失败。
- `--check` 只比较版本内容（忽略 `fetched_at`），用于确认仓库里的数据是否落后于 GitHub。
- 日期：`published_at` 保留 GitHub 的 UTC 时间；`date` 是**站点时区**（默认 `Asia/Shanghai`，
  `SN_RELEASE_TIME_ZONE` / `--time-zone` 可覆盖）的日历日，`date_time_zone` 记录所用时区。
  直接截取 UTC 日期会让 22:18Z 这类晚间发布显示成前一天，页面再用访客本地时区覆盖显示。

## 重点逻辑
### `buildReleaseData(releases, { repo, now, timeZone })`
- 过滤 draft → 选 latest / stable → 从 assets 推导 windows / linux / SHA256SUMS 直链 → 生成 `window.SN_RELEASE_DATA`。
### `updateReleaseData(options)`
- CLI 与测试共用：fetch → build → 与现有文件比较 → 写入或保留；返回 `{ok, changed, stale, data, path, error}`。
### `renderReleaseDataFile(data)`
- 固定头部注释 + `window.SN_RELEASE_DATA = <canonical JSON>;`，保证同一份 Release 数据生成结果稳定、可 diff。

模块索引：[website](../README.md)
