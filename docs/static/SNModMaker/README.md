# `SNModMaker`

> 零依赖网页端模组制作器：原生 HTML/CSS/JS，从仓库 Schema 与 Core 索引生成表单、校验并打包模组。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `README.md` | 使用说明、数据流、开发约定与已知边界。 | 本页 |
| `WORKSPACE.md` | 原生工作区使用说明：启动本地服务、在编辑器里直接编辑 dev_mods/core、保存边界与发布前校验。 | 本页 |
| `css/app.css` | 暗色工业主题与响应式布局：顶栏、侧栏、模块子分页、自定义资源选择器、船体模块区、内容/多语言编辑器、模态框与 Toast。 | [查看](./css/app.css.md) |
| `exports/README.md` | 本地导出目录说明：ZIP 命名与忽略规则。 | 本页 |
| `index.html` | 模组制作器的静态外壳：顶栏、导航/工作区/检视器布局，以及模态框、Toast、拖放与忙碌层宿主。 | [查看](./index.html.md) |
| `js/app.js` | 应用控制器：视图状态、事件委托、表单写回、撤销/重做、自动保存、导入导出与 Modal 流程。 | [查看](./js/app.js.md) |
| `js/catalog.js` | 字段标签、默认值、标签建议、条件/效果词汇与新建模板；内容类型列表来自生成的 content-types.js。 | [查看](./js/catalog.js.md) |
| `js/glb.js` | 最小 GLB（glTF 2.0 二进制）解析器，为资源卡片提供场景节点、三角形网格、法线与材质基色。 | [查看](./js/glb.js.md) |
| `js/io.js` | 浏览器 I/O：IndexedDB 项目库、文件/文件夹/ZIP 导入、下载、目录导出与本地游戏模组部署 API。 | [查看](./js/io.js.md) |
| `js/model_thumb.js` | 用共享 WebGL 上下文把 GLB 渲染成自动取景的 PNG 缩略图，并按键缓存结果。 | [查看](./js/model_thumb.js.md) |
| `js/store.js` | 项目模型与纯数据操作：模板、定义增删改复制、Manifest 同步、导入导出映射与 Core 克隆。 | [查看](./js/store.js.md) |
| `js/ui.js` | Schema 驱动的表单渲染与通用 UI 组件：字段控件、数组/条件/效果编辑器、自定义资源选择器、船体模块区、模态框与 Toast。 | [查看](./js/ui.js.md) |
| `js/validate.js` | JSON Schema 子集校验器与 Steam Navigator 项目语义校验：ID、引用、本地化、补丁与清单一致性。 | [查看](./js/validate.js.md) |
| `js/zip.js` | 零依赖 ZIP 读写：中央目录解析、CRC32、store / deflate-raw 压缩，以及 ZIP 体积与路径限制。 | [查看](./js/zip.js.md) |
| `mods/README.md` | 磁盘工作区说明：每个模组目录的结构与 .snmodproj.json。 | 本页 |
| `mods/core/.snmodproj.json` | 源文件：.snmodproj.json | 本页 |
| `mods/core/assets/icons/coal.png` | 源文件：coal.png | 本页 |
| `mods/core/assets/icons/money.png` | 源文件：money.png | 本页 |
| `mods/core/assets/icons/water.png` | 源文件：water.png | 本页 |
| `mods/core/assets/models/SN_Barrel.glb` | 源文件：SN_Barrel.glb | 本页 |
| `mods/core/assets/models/SN_Bell.glb` | 源文件：SN_Bell.glb | 本页 |
| `mods/core/assets/models/SN_Boiler_Unit.glb` | 源文件：SN_Boiler_Unit.glb | 本页 |
| `mods/core/assets/models/SN_Buoy.glb` | 源文件：SN_Buoy.glb | 本页 |
| `mods/core/assets/models/SN_Capstan.glb` | 源文件：SN_Capstan.glb | 本页 |
| `mods/core/assets/models/SN_Cargo_Net.glb` | 源文件：SN_Cargo_Net.glb | 本页 |
| `mods/core/assets/models/SN_Chain_Coil.glb` | 源文件：SN_Chain_Coil.glb | 本页 |
| `mods/core/assets/models/SN_Coal_Chute.glb` | 源文件：SN_Coal_Chute.glb | 本页 |
| `mods/core/assets/models/SN_Coal_Pile.glb` | 源文件：SN_Coal_Pile.glb | 本页 |
| `mods/core/assets/models/SN_Crate.glb` | 源文件：SN_Crate.glb | 本页 |
| `mods/core/assets/models/SN_Dock_Fender.glb` | 源文件：SN_Dock_Fender.glb | 本页 |
| `mods/core/assets/models/SN_Dock_Ladder.glb` | 源文件：SN_Dock_Ladder.glb | 本页 |
| `mods/core/assets/models/SN_Dock_Stairs.glb` | 源文件：SN_Dock_Stairs.glb | 本页 |
| `mods/core/assets/models/SN_Dock_Wall.glb` | 源文件：SN_Dock_Wall.glb | 本页 |
| `mods/core/assets/models/SN_Fender_Ball.glb` | 源文件：SN_Fender_Ball.glb | 本页 |
| `mods/core/assets/models/SN_Flag_Pole.glb` | 源文件：SN_Flag_Pole.glb | 本页 |
| `mods/core/assets/models/SN_Gangway.glb` | 源文件：SN_Gangway.glb | 本页 |
| `mods/core/assets/models/SN_Gas_Lamp.glb` | 源文件：SN_Gas_Lamp.glb | 本页 |
| `mods/core/assets/models/SN_Gear_Crate.glb` | 源文件：SN_Gear_Crate.glb | 本页 |
| `mods/core/assets/models/SN_Grab_Bucket.glb` | 源文件：SN_Grab_Bucket.glb | 本页 |
| `mods/core/assets/models/SN_Handcart.glb` | 源文件：SN_Handcart.glb | 本页 |
| `mods/core/assets/models/SN_Harbor_Crane.glb` | 源文件：SN_Harbor_Crane.glb | 本页 |
| `mods/core/assets/models/SN_Ironclad.glb` | 源文件：SN_Ironclad.glb | 本页 |
| `mods/core/assets/models/SN_Keel_Block.glb` | 源文件：SN_Keel_Block.glb | 本页 |
| `mods/core/assets/models/SN_Mooring_Bollard.glb` | 源文件：SN_Mooring_Bollard.glb | 本页 |
| `mods/core/assets/models/SN_Mooring_Rope.glb` | 源文件：SN_Mooring_Rope.glb | 本页 |
| `mods/core/assets/models/SN_Ore_Pile.glb` | 源文件：SN_Ore_Pile.glb | 本页 |
| `mods/core/assets/models/SN_Paddle_Freighter.glb` | 源文件：SN_Paddle_Freighter.glb | 本页 |
| `mods/core/assets/models/SN_Paddle_Steamer.glb` | 源文件：SN_Paddle_Steamer.glb | 本页 |
| `mods/core/assets/models/SN_Pallet.glb` | 源文件：SN_Pallet.glb | 本页 |
| `mods/core/assets/models/SN_Plate_Stack.glb` | 源文件：SN_Plate_Stack.glb | 本页 |
| `mods/core/assets/models/SN_Port_Sign.glb` | 源文件：SN_Port_Sign.glb | 本页 |
| `mods/core/assets/models/SN_Sack_Pile.glb` | 源文件：SN_Sack_Pile.glb | 本页 |
| `mods/core/assets/models/SN_Schooner_Fame.glb` | 源文件：SN_Schooner_Fame.glb | 本页 |
| `mods/core/assets/models/SN_Ship_Prototype.glb` | 源文件：SN_Ship_Prototype.glb | 本页 |
| `mods/core/assets/models/SN_Steam_Pipe.glb` | 源文件：SN_Steam_Pipe.glb | 本页 |
| `mods/core/assets/models/SN_Timber_Stack.glb` | 源文件：SN_Timber_Stack.glb | 本页 |
| `mods/core/content/boilers.json` | 源文件：boilers.json | 本页 |
| `mods/core/content/cabins.json` | 源文件：cabins.json | 本页 |
| `mods/core/content/cargo_modules.json` | 源文件：cargo_modules.json | 本页 |
| `mods/core/content/contracts.json` | 源文件：contracts.json | 本页 |
| `mods/core/content/events.json` | 源文件：events.json | 本页 |
| `mods/core/content/goods.json` | 源文件：goods.json | 本页 |
| `mods/core/content/hulls.json` | 源文件：hulls.json | 本页 |
| `mods/core/content/map_profiles.json` | 源文件：map_profiles.json | 本页 |
| `mods/core/content/materials.json` | 源文件：materials.json | 本页 |
| `mods/core/content/navigation_modules.json` | 源文件：navigation_modules.json | 本页 |
| `mods/core/content/port_archetypes.json` | 源文件：port_archetypes.json | 本页 |
| `mods/core/content/roles.json` | 源文件：roles.json | 本页 |
| `mods/core/content/safety_modules.json` | 源文件：safety_modules.json | 本页 |
| `mods/core/content/starting_builds.json` | 源文件：starting_builds.json | 本页 |
| `mods/core/content/strategies.json` | 源文件：strategies.json | 本页 |
| `mods/core/localization/en.json` | 源文件：en.json | 本页 |
| `mods/core/localization/zh_CN.json` | 源文件：zh_CN.json | 本页 |
| `mods/core/manifest.json` | 源文件：manifest.json | 本页 |
| `tests/browser-smoke.mjs` | Chrome DevTools Protocol 冒烟测试：新建项目、实体键事务、模块子分页与船体模块区、本地化、自定义资源选择器、ZIP、导入与撤销。 | [查看](./tests/browser-smoke.mjs.md) |
| `tests/content-cli.test.mjs` | Content CLI 集成测试：用 node:test 子进程调用真实 CLI，在临时模组目录覆盖十个命令、保源写回、校验闸门与 JSON 输出。 | [查看](./tests/content-cli.test.mjs.md) |
| `tests/run-tests.js` | Node 单元测试：Schema 校验、项目模型、全部内容类型表单、索引/克隆、ZIP、导入导出往返、GLB 解析与部署目标解析。 | [查看](./tests/run-tests.js.md) |
| `tests/server-smoke.mjs` | 本地服务磁盘 API 冒烟测试：在隔离临时目录验证游戏模组部署、覆盖、枚举、删除与旧版本清理。 | [查看](./tests/server-smoke.mjs.md) |
| `tests/workspace-smoke.mjs` | 原生工作区冒烟测试：用 `/api/workspace/<id>` 打开 dev_mods/<id>，验证删除定义、新增内容文件、删除本地化、资产不被改写与禁止整体删除。 | [查看](./tests/workspace-smoke.mjs.md) |
| `tools/content.mjs` | SNModMaker 内容 CLI（零依赖 Node ESM）：types / describe / list / add / set / loc / rm / clone / validate / new 十个无头命令，按 Schema 增删改定义、补本地化并校验。 | [查看](./tools/content.mjs.md) |
| `tools/content_json.mjs` | 保源 JSON 源文本编辑器（纯函数、无 fs）：解析带 start / end 的节点树，只替换目标节点附近的文本切片，让 CLI 增删改内容时既有字节、缩进与 BOM 保持不变。 | [查看](./tools/content_json.mjs.md) |
| `tools/game_mods_dir.mjs` | 解析编辑器「导出并覆盖到发布包 mods/」的默认目标目录。 | [查看](./tools/game_mods_dir.mjs.md) |
| `tools/serve.mjs` | 零依赖本地静态服务器 + 磁盘 API：项目工作区、原生模组工作区（dev_mods 原地编辑）、普通导出与发布包模组覆盖部署。 | [查看](./tools/serve.mjs.md) |
| `tools/sync-core-index.mjs` | 从 `dev_mods/core` 生成 `js/core-index.js`：Manifest、内容文件、双语本地化与定义索引。 | [查看](./tools/sync-core-index.mjs.md) |
| `tools/sync-schemas.mjs` | 把 `schemas/*.schema.json` 打包为可直接 `<script>` 引入的 `js/schema-bundle.js`。 | [查看](./tools/sync-schemas.mjs.md) |

## 模块契约

- 运行时无第三方依赖、无构建步骤、无 CDN；经典 script 以支持 file://。
- Schema 与 Core 数据以仓库为唯一来源；`schema-bundle.js` / `core-index.js` 只由生成脚本产出。
- 导出 JSON 与 Godot 加载链共享同一套 Schema；网页端不运行领域逻辑、注册表或 Core 完整性检查。
- 实体 ID 修改只实时预览新多语言键，点击保存条目才原子迁移所有语言；模块类通过子分页切换。
- 标准实体可配置贴图与 GLB 模型资源键，编辑器校验资源存在性与格式。
- 所有导入内容都经过 HTML 转义、路径检查与 ZIP 体积/条目/CRC 限制。
- 浏览器存储始终可用；`tools/serve.mjs` 运行时额外镜像到 `mods/`，导出可写入 `exports/`。
- `tools/content.mjs` 是无头 CLI，与网页端共用 `js/store.js` / `js/validate.js`；写回用 `tools/content_json.mjs` 保源编辑，写前按 SHA-256 检测并发修改。
