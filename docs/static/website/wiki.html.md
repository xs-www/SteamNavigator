# `website/wiki.html`

> 作用：游戏百科页：分类导航、搜索、条目卡片与深链接，数据由生成脚本提供。

- 类型：HTML 应用外壳

契约与约束
- 条目数据来自 `assets/data/wiki-data.js`，页面不得硬编码条目或展示 `core:` ID。
- 搜索与分类为交集筛选；`#cat-*` / `#entry-*` 深链接必须可用。

模块索引：[website](./README.md)
