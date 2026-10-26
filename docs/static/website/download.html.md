# `website/download.html`

> 作用：下载页：真实 GitHub Release 资产、平台卡片、运行需求、安装步骤与 FAQ。

- 类型：HTML 应用外壳

契约与约束
- 下载链接必须指向真实 Release 资产，不使用占位 URL。
- 版本号 / 发布日期 / 文件大小 / 下载直链由 `assets/data/release-data.js`（`tools/build-release-data.mjs`
从 GitHub Releases API 生成）+ `assets/js/release.js` 自动填充；元素上的 `data-release` / `data-release-link`
是契约，静态文案只是无 JS/无数据时的 fallback。
- 外链使用 `target="_blank" rel="noopener noreferrer"`；不改生成数据的结构（契约见 docs/design/WEBSITE.md §2）。
- 运行需求为建议值，不承诺未经测试的配置。

模块索引：[website](./README.md)
