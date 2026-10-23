# `SNModMaker`

> 零依赖网页端模组制作器：原生 HTML/CSS/JS，从仓库 Schema 与 Core 索引生成表单、校验并打包模组。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `.dockerignore` | Docker 构建上下文过滤：排除本地 mods/、exports/ 与 Docker 自身文件。 | 本页 |
| `Dockerfile` | 零依赖容器镜像：Node 22 Alpine 打包静态编辑器与 tools/，以 node 用户运行，所有可写目录重定向到 /app/data 命名卷。 | [查看](./Dockerfile.md) |
| `README.md` | 使用说明、数据流、开发约定与已知边界。 | 本页 |
| `WORKSPACE.md` | 原生工作区使用说明：启动本地服务、在编辑器里直接编辑 dev_mods/core、保存边界与发布前校验。 | 本页 |
| `css/app.css` | 暗色工业主题与响应式布局：顶栏、侧栏、模块子分页、自定义资源选择器、船体模块区、内容/多语言编辑器、模态框与 Toast。 | [查看](./css/app.css.md) |
| `docs/DEVELOPMENT.md` | 源文件：DEVELOPMENT.md | 本页 |
| `docs/USER_GUIDE.md` | 源文件：USER_GUIDE.md | 本页 |
| `exports/README.md` | 本地导出目录说明：ZIP 命名与忽略规则。 | 本页 |
| `index.html` | 模组制作器的静态外壳：顶栏、导航/工作区/检视器布局，以及模态框、Toast、拖放与忙碌层宿主。 | [查看](./index.html.md) |
| `js/app.js` | 应用控制器：视图状态、事件委托、表单写回、撤销/重做、自动保存、导入导出与 Modal 流程。 | [查看](./js/app.js.md) |
| `js/catalog.js` | 字段标签、默认值、标签建议、条件/效果词汇与新建模板（含「舰载武器包」5 件武器预设）；内容类型列表来自生成的 content-types.js（`TYPES` + `DRAFT_TYPES`），并按类型提供剧情模式（篇章/关卡）的标签、默认值与枚举可读名。 | [查看](./js/catalog.js.md) |
| `js/glb.js` | 最小 GLB（glTF 2.0 二进制）解析器，为资源卡片提供场景节点、三角形网格、法线与材质基色。 | [查看](./js/glb.js.md) |
| `js/io.js` | 浏览器 I/O：IndexedDB 项目库、文件/文件夹/ZIP 导入、下载、目录导出与本地游戏模组部署 API。 | [查看](./js/io.js.md) |
| `js/model_thumb.js` | 用共享 WebGL 上下文把 GLB 渲染成自动取景的 PNG 缩略图，并按键缓存结果。 | [查看](./js/model_thumb.js.md) |
| `js/store.js` | 项目模型与纯数据操作：模板、定义增删改复制、Manifest 同步、导入导出映射与 Core 克隆。 | [查看](./js/store.js.md) |
| `js/ui.js` | Schema 驱动的表单渲染与通用 UI 组件：字段控件、数组/条件/效果编辑器、自定义资源选择器、船体模块区、模态框与 Toast。 | [查看](./js/ui.js.md) |
| `js/validate.js` | JSON Schema 子集校验器与 Steam Navigator 项目语义校验：Schema 版本、ID、引用、本地化、补丁、清单一致性，以及剧情模式（故事包白名单 / 篇章 / 关卡固定地图与任务线）语义。 | [查看](./js/validate.js.md) |
| `js/zip.js` | 零依赖 ZIP 读写：中央目录解析、CRC32、store / deflate-raw 压缩，以及 ZIP 体积与路径限制。 | [查看](./js/zip.js.md) |
| `mods/README.md` | 磁盘工作区说明：每个模组目录的结构与 .snmodproj.json。 | 本页 |
| `start.bat` | Windows 双击启动 SNModMaker；缺少 Node.js 时先安装最新 LTS，再启动本地服务并打开浏览器。 | [查看](./start.bat.md) |
| `tests/browser-smoke.mjs` | Chrome DevTools Protocol 冒烟测试：新建项目、实体键事务、模块子分页与船体模块区 / 安装点面板、本地化、自定义资源选择器、ZIP、导入与撤销。 | [查看](./tests/browser-smoke.mjs.md) |
| `tests/content-cli.test.mjs` | Content CLI 集成测试：用 node:test 子进程调用真实 CLI，在临时模组目录覆盖十个命令、保源写回、校验闸门与 JSON 输出；含 D1 `weapons` / D2 fleet 运行时类型与「舰载武器包」模板，以及剧情 `story_arcs` / `story_levels` 草案与示例剧情包。 | [查看](./tests/content-cli.test.mjs.md) |
| `tests/run-tests.js` | Node 单元测试：Schema 校验、项目模型、全部内容类型表单、索引/克隆、ZIP、导入导出往返、GLB 解析与部署目标解析；含 D1 `weapons` / 战斗类型、D2 fleet 4 类型、船体 socket 镜像、「舰载武器包」模板与剧情模式（`story_arcs` / `story_levels`）用例。 | [查看](./tests/run-tests.js.md) |
| `tests/server-smoke.mjs` | 本地服务磁盘 API 冒烟测试：在隔离临时目录验证游戏模组部署、覆盖、枚举、删除与旧版本清理。 | [查看](./tests/server-smoke.mjs.md) |
| `tests/workspace-smoke.mjs` | 原生工作区冒烟测试：用 `/api/workspace/<id>` 打开 dev_mods/<id>，验证删除定义、新增内容文件、删除本地化、资产不被改写与禁止整体删除。 | [查看](./tests/workspace-smoke.mjs.md) |
| `tools/content.mjs` | SNModMaker 内容 CLI（零依赖 Node ESM）：types / describe / list / add / set / loc / rm / clone / validate / new 十个无头命令，按 Schema 增删改定义、补本地化并校验；类型清单含 37 个运行时类型（D4 后全部为 Schema 2.0）与 3 个 Schema 2.0 草案类型（剧情 `story_arcs` / `story_levels` + `combat_ai_profiles`）；`new --draft` 可直接创建纯 2.0 草案项目。 | [查看](./tools/content.mjs.md) |
| `tools/content_json.mjs` | 保源 JSON 源文本编辑器（纯函数、无 fs）：解析带 start / end 的节点树，只替换目标节点附近的文本切片，让 CLI 增删改内容时既有字节、缩进与 BOM 保持不变。 | [查看](./tools/content_json.mjs.md) |
| `tools/game_mods_dir.mjs` | 解析编辑器「导出并覆盖到发布包 mods/」的默认目标目录。 | [查看](./tools/game_mods_dir.mjs.md) |
| `tools/serve.mjs` | 零依赖本地静态服务器 + 磁盘 API：项目工作区、原生模组工作区（dev_mods 原地编辑）、普通导出与发布包模组覆盖部署。 | [查看](./tools/serve.mjs.md) |
| `tools/sync-core-index.mjs` | 从 `dev_mods/core` 生成 `js/core-index.js`：Manifest、内容文件、双语本地化与定义索引。 | [查看](./tools/sync-core-index.mjs.md) |
| `tools/sync-schemas.mjs` | 把 `schemas/` 下全部 `*.schema.json`（含 `v2/` 草案）递归打包为可直接 `<script>` 引入的 `js/schema-bundle.js`。 | [查看](./tools/sync-schemas.mjs.md) |

## 模块契约

- 运行时无第三方依赖、无构建步骤、无 CDN；经典 script 以支持 file://。
- Schema 与 Core 数据以仓库为唯一来源；`schema-bundle.js` / `core-index.js` 只由生成脚本产出。
- 导出 JSON 与 Godot 加载链共享同一套 Schema；网页端不运行领域逻辑、注册表或 Core 完整性检查。
- 实体 ID 修改只实时预览新多语言键，点击保存条目才原子迁移所有语言；模块类通过子分页切换。
- 标准实体可配置贴图与 GLB 模型资源键，编辑器校验资源存在性与格式。
- `weapons`（战斗 / 装配 / 经济三组）与船体 `weapon_sockets` / `rig_sockets` 镜像走同一套 v2 Schema；安装点重复 name / 索引与非法 class/kind 由编辑器语义校验拦截。
- 「舰载武器包」模板（`TEMPLATES.weapons` / `new --template weapons`）一次生成 5 件模拟器武器草案定义与 `asset://core/model.weapon.*` 模型引用，capability 自动声明；草案与模板只写编辑器项目，不写 Core（Core 出现 2.0/未注册类型会被运行时按 mod error 拒绝）。
- 所有导入内容都经过 HTML 转义、路径检查与 ZIP 体积/条目/CRC 限制。
- 浏览器存储始终可用；`tools/serve.mjs` 运行时额外镜像到 `mods/`，导出可写入 `exports/`。
- `tools/content.mjs` 是无头 CLI，与网页端共用 `js/store.js` / `js/validate.js`；写回用 `tools/content_json.mjs` 保源编辑，写前按 SHA-256 检测并发修改。
