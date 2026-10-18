# `SNModMaker`

> 零依赖网页端模组制作器：原生 HTML/CSS/JS，从仓库 Schema 与 Core 索引生成表单、校验并打包模组。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `README.md` | 使用说明、数据流、开发约定与已知边界。 | 本页 |
| `css/app.css` | 暗色工业主题与响应式布局：顶栏、侧栏、内容编辑器、表单控件、条件/效果编辑器、模态框与 Toast。 | [查看](./css/app.css.md) |
| `exports/README.md` | 本地导出目录说明：ZIP 命名与忽略规则。 | 本页 |
| `index.html` | 模组制作器的静态外壳：顶栏、导航/工作区/检视器布局，以及模态框、Toast、拖放与忙碌层宿主。 | [查看](./index.html.md) |
| `js/app.js` | 应用控制器：视图状态、事件委托、表单写回、撤销/重做、自动保存、导入导出与 Modal 流程。 | [查看](./js/app.js.md) |
| `js/catalog.js` | 内容类型展示元数据、字段标签、默认值、标签建议、条件/效果词汇与新建模板。 | [查看](./js/catalog.js.md) |
| `js/io.js` | 浏览器 I/O：IndexedDB 项目库、文件/文件夹/ZIP 导入、下载、File System Access 目录导出。 | [查看](./js/io.js.md) |
| `js/store.js` | 项目模型与纯数据操作：模板、定义增删改复制、Manifest 同步、导入导出映射与 Core 克隆。 | [查看](./js/store.js.md) |
| `js/ui.js` | Schema 驱动的表单渲染与通用 UI 组件：字段控件、数组/条件/效果编辑器、模态框、Toast、Datalist。 | [查看](./js/ui.js.md) |
| `js/validate.js` | JSON Schema 子集校验器与 Steam Navigator 项目语义校验：ID、引用、本地化、补丁与清单一致性。 | [查看](./js/validate.js.md) |
| `js/zip.js` | 零依赖 ZIP 读写：中央目录解析、CRC32、store / deflate-raw 压缩，以及 ZIP 体积与路径限制。 | [查看](./js/zip.js.md) |
| `mods/README.md` | 磁盘工作区说明：每个模组目录的结构与 .snmodproj.json。 | 本页 |
| `tests/browser-smoke.mjs` | Chrome DevTools Protocol 冒烟测试：新建项目、编辑、本地化、检视、自动保存、ZIP、导入与撤销。 | [查看](./tests/browser-smoke.mjs.md) |
| `tests/run-tests.js` | Node 单元测试：Schema 校验、项目模型、全部内容类型表单、索引/克隆、ZIP 与导入导出往返。 | [查看](./tests/run-tests.js.md) |
| `tools/serve.mjs` | 零依赖本地静态服务器 + 磁盘 API：项目写入 `mods/<id>/`，ZIP 写入 `exports/`。 | [查看](./tools/serve.mjs.md) |
| `tools/sync-core-index.mjs` | 从 `dev_mods/core` 生成 `js/core-index.js`：Manifest、内容文件、双语本地化与定义索引。 | [查看](./tools/sync-core-index.mjs.md) |
| `tools/sync-schemas.mjs` | 把 `schemas/*.schema.json` 打包为可直接 `<script>` 引入的 `js/schema-bundle.js`。 | [查看](./tools/sync-schemas.mjs.md) |

## 模块契约

- 运行时无第三方依赖、无构建步骤、无 CDN；经典 script 以支持 file://。
- Schema 与 Core 数据以仓库为唯一来源；`schema-bundle.js` / `core-index.js` 只由生成脚本产出。
- 导出 JSON 与 Godot 加载链共享同一套 Schema；网页端不运行领域逻辑、注册表或 Core 完整性检查。
- 所有导入内容都经过 HTML 转义、路径检查与 ZIP 体积/条目/CRC 限制。
- 浏览器存储始终可用；`tools/serve.mjs` 运行时额外镜像到 `mods/`，导出可写入 `exports/`。
