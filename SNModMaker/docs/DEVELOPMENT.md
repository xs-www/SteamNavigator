# SNModMaker 开发说明

> 项目结构、数据流、生成物维护、测试与代码约定；日常使用看 [README.md](../README.md) 或 [USER_GUIDE.md](USER_GUIDE.md)。

## 项目结构

```text
SNModMaker/
├── index.html                  应用外壳
├── css/app.css                 暗色工业主题，无外部字体
├── js/schema-bundle.js         自动生成：/schemas/ 下全部 Schema（含 v2/ 草案）
├── js/core-index.js            自动生成：Core 定义、名称与翻译索引
├── js/content-types.js         自动生成：内容类型清单（含 DRAFT_TYPES，来自 content_types.json）
├── js/catalog.js               字段标签、默认值、条件/效果词汇
├── js/zip.js                   ZIP 读写（store / deflate-raw，CRC32）
├── js/validate.js              Schema 子集与项目语义校验
├── js/store.js                 项目模型、模板、导入导出映射、Core 克隆
├── js/glb.js                   最小 GLB 解析：场景节点、网格、法线与材质基色
├── js/model_thumb.js           WebGL 单帧缩略图渲染与缓存
├── js/io.js                    IndexedDB、文件/文件夹/ZIP 导入、下载与目录写入
├── js/ui.js                    表单渲染、条件/效果编辑器、模态框
├── js/app.js                   应用状态、事件、撤销、自动保存、视图
├── Dockerfile                  容器镜像：Node 22 Alpine，数据写入 /app/data（见后文）
├── tools/sync-schemas.mjs      重新生成 schema-bundle.js
├── tools/sync-core-index.mjs   重新生成 core-index.js
├── tools/serve.mjs             本地静态服务 + 磁盘 API（Node 内置模块）
├── tools/game_mods_dir.mjs     解析默认部署目标：发布包 dist/build/<platform>/mods/
├── tools/content.mjs           Content CLI：按 Schema 增删改定义、本地化与校验
├── tools/content_json.mjs      保源 JSON 编辑与风格化序列化（CLI 内部模块）
├── mods/                       本地磁盘工作区（默认被 .gitignore 忽略）
├── exports/                    本地导出目录（默认被 .gitignore 忽略）
└── tests/                      Node 单元测试与 Chrome CDP 冒烟测试
```

### 数据流

```text
project
├── manifest
├── contentFiles[]   每个文件 = { path, content_type, schema_version, definitions[] }
├── localization[]   { path, locale, entries{} }
├── assets[]         { key, path, mime, size, dataUrl }
└── meta

manifest.content / localization / assets 由上述集合自动重建；
导出时再展开为 mods/<id>/ 文件树。
```

所有内容写入都先经过 `SNStore`；表单只发送 `data-field` 路径，`app.js` 负责 `setByPath` 与重新校验。UI 不直接改文件系统。

---

## 开发

### 重新生成内容类型清单

修改 `/content_types.json` 后：

```powershell
node tools/gen_content_types.mjs
# 只检查生成物是否最新
node tools/gen_content_types.mjs --check
```

生成的 `framework/modding/content_types.gd` 与 `js/content-types.js` 不应手工编辑。

### 重新生成 Schema 包

修改 `/schemas/` 下的 Schema（含 `schemas/v2/` 草案）后：

```powershell
node SNModMaker/tools/sync-schemas.mjs
```

生成物覆盖 26 个 Schema：10 个顶层运行时 Schema + 16 个 `v2/`（`v2/common.schema.json` + Phase B 9 类 + C1 的 `hull` / `module` + C2 的 `item` + `weapon` + `story_arc` + `story_level`）。

### 重新生成 Core 索引

修改 `/dev_mods/core` 的内容或本地化后：

```powershell
node SNModMaker/tools/sync-core-index.mjs
```

Core 索引提供引用候选、中文名、跨引用检查与「从 Core 复制」的源数据。生成的 `js/schema-bundle.js` 与 `js/core-index.js` 不应手工编辑。

### 测试

```powershell
# 纯逻辑：Schema（含 v2 草案）、校验、项目模型、导入导出、ZIP、全部内容类型表单
node SNModMaker/tests/run-tests.js

# Content CLI 集成测试：真实子进程调用 content.mjs，覆盖 1.0 与草案类型
node SNModMaker/tests/content-cli.test.mjs

# 本地服务：隔离临时目录中验证项目 API 与游戏模组覆盖部署
node SNModMaker/tests/server-smoke.mjs

# 浏览器冒烟：需要 Chrome 以调试端口启动，并先启动静态服务
node SNModMaker/tools/serve.mjs
& 'C:\Program Files\Google\Chrome\Application\chrome.exe' --headless=new --disable-gpu --remote-debugging-port=9222 --user-data-dir="$env:TEMP\snmod-cdp" about:blank
node SNModMaker/tests/browser-smoke.mjs http://127.0.0.1:8099/ "$env:TEMP\snmod-smoke.png"
```

当前基线：**50 个 Node 用例 + 57 个 Content CLI 用例 + 1 个本地服务用例 + 17 个浏览器用例**。浏览器测试会清空该调试实例下 `127.0.0.1:8099` 的存储，再完整走一遍：新建项目 → 新增定义 → 改数值 → ID/多语言键事务 → 模块子分页与船体模块区 → 本地化 → JSON 检视 → 自动保存 → 导出 ZIP → 资源与自定义资源选择器 → 事件条件/效果 → 补丁 → 撤销 → 从 ZIP 重新导入 → 文件夹导出 → 写入 `mods/` / `exports/` → 覆盖部署到发布包 `mods/`。

### 代码约定

- 纯经典脚本（无 ES module），便于直接 `file://` 打开；模块通过 `globalThis.SN*` 暴露。
- `tools/*.mjs` 是 Node ESM 工具（本地服务、生成脚本与 Content CLI），不参与网页打包，也不要在 `index.html` 中引用。
- 不引入第三方库、字体或 CDN；图标使用内联 SVG / CSS。
- 新增内容类型时需要同步：`schemas/`、`ContentTypes`、`catalog.js`（标签 / 默认值 / key 前缀）、以及 `store.js` 使用这些默认值的模板/克隆逻辑。
- Schema 2.0 草案类型登记在 `content_types.json` 的 `draft_schemas` / `draft_types`，Schema 放在 `schemas/v2/`；生成后由 `SNContentTypes.DRAFT_TYPES` 驱动编辑器与 CLI，运行时类型清单（`TYPES`）保持不变，直到对应运行时系统落地。
- 所有用户文本与属性值都经过 `esc` / `attr` 转义；导入的 ZIP 有路径、条目数、解压体积与 CRC 限制。

---
