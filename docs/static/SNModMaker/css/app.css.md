# `SNModMaker/css/app.css`

> 作用：暗色工业主题与响应式布局：顶栏、侧栏、模块子分页、自定义资源选择器、船体模块区、蓝图槽位编辑器画布、内容/多语言编辑器、模态框与 Toast。

- 类型：样式表

## 契约与约束

- 颜色、间距、字体通过 `:root` 变量统一；不引入外部字体。
- `[hidden] { display: none !important; }` 支撑视图与过滤逻辑。
- 资源候选菜单使用编辑器主题、绝对定位和滚动上限；船体模块卡在窄屏断点退化为单列。
- 断点 1240 / 1000 / 800 / 760 / 560：编辑区单列、侧栏图标化、顶栏换行与操作压缩。
- Schema 2.0 草案分区与徽标（`side-group-draft` / `side-draft-tag` / `draft-badge` / `draft-notice` / `mini-badge.draft`）复用既有暗色变量，不引入新字体或配色体系。

模块索引：[SNModMaker](../README.md)
