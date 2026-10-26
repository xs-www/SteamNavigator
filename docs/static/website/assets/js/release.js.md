# `website/assets/js/release.js`

> 作用：官网版本信息填充脚本：读取 `assets/data/release-data.js`（由 `tools/build-release-data.mjs` 从 GitHub Releases 生成），

- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `formatSize(bytes)` | L28 |
| `textFor(key)` | L36 |
| `assetSize(pattern)` | L57 |
| `applyText()` | L65 |
| `applyLinks()` | L74 |

把下载页 / 开发日志页里的版本号、发布日期、文件大小、状态文案与下载链接替换为当前最新 release。

## 契约与约束
- 不请求网络：数据由构建/部署前的生成器写入静态 JS；页面断网也能显示已生成的版本信息。
- 只做 `textContent` / `href` 赋值，不插入 HTML（GitHub 的 tag / 名称按纯文本处理，避免注入）。
- 找不到数据、字段为 null 或元素不存在时保持页面原有静态 fallback 文案，不隐藏内容、不报错。
- 约定属性：`data-release="tag|date|state|windows-size|linux-size|banner-note"` 填文本；
  `data-release-link="releases|windows|linux|checksums"` 填链接。契约见 `docs/design/WEBSITE.md` §2/§7。

## 重点逻辑
### 填充
- 版本：`latest.tag`；日期：`latest.date`（GitHub `published_at` 的 UTC 日期）；状态：预发布 / 正式版。
- 大小：字节 → `约 N MB`（四舍五入，0/缺失时保留原文案）。
- 链接：只使用 release 的真实 asset 直链；缺失的平台保持原静态 href。

模块索引：[website](../../README.md)
