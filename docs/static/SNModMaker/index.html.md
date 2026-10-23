# `SNModMaker/index.html`

> 作用：模组制作器的静态外壳：顶栏、导航/工作区/检视器布局，以及模态框、Toast、拖放与忙碌层宿主。

- 类型：HTML 应用外壳

## 契约与约束

- 脚本按 `schema-bundle → core-index → catalog → zip → validate → store → io → ui → blueprint_editor → app` 顺序加载，全部为经典 script，支持 file://。
- 不引用外部字体、CDN、图片或模块；图标为内联 SVG / CSS。
- `#datalists` 必须保持可被表单引用，不能使用 `display:none` 以外的移除方式。

模块索引：[SNModMaker](./README.md)
