# SNModMaker — 零依赖网页端模组制作器

在浏览器里可视化创建、编辑和打包《Steam Navigator》的内容模组：

- 读取仓库内 **官方 JSON Schema**，按类型生成表单；
- 编辑 Manifest、15 类内容、显式补丁、本地化与资源；
- 实时校验 ID 命名空间、字段约束、跨引用、本地化覆盖与补丁安全；
- 导入松散目录 / `.snavmod.zip` / 项目文件；
- 导出 `mods/<id>/` 结构的 `.snavmod.zip`、项目文件，或直接写入本地目录；
- 启动本地服务后，自动把项目写入 [`mods/`](mods/README.md)，打包结果可写入 [`exports/`](exports/README.md)。

运行时**零第三方依赖**：没有 npm 包、没有 CDN、没有构建步骤、没有网络请求。所有代码都是仓库里的原生 HTML / CSS / JavaScript。

---

## 快速开始

### 方式一：直接打开

双击 `SNModMaker/index.html`。适合快速试用；部分浏览器会限制 `file://` 下的 IndexedDB，自动保存可能不可用，此时请使用方式二或导出项目文件备份。

### 方式二：本地静态服务（推荐）

```powershell
node SNModMaker/tools/serve.mjs
# 打开 http://127.0.0.1:8099/
```

该服务同时提供本地磁盘 API：项目会写入 `SNModMaker/mods/<mod_id>/`，导出可写入 `SNModMaker/exports/`。不启动它也能用，只是仅保存在浏览器 IndexedDB。

也可以用任意静态服务器，例如：

```powershell
python -m http.server 8099 --bind 127.0.0.1 -d SNModMaker
```

### 第一次使用

1. 点击「新建模组」，填写模组 ID（小写字母开头，3–32 位，`a-z 0-9 _`）和显示名称，选择模板。
2. 在左侧选择内容类型，点击「新增定义」；或「从 Core 复制」一个官方条目再改。
3. 在「本地化」里补齐 `zh_CN` / `en` 文本。
4. 打开「校验」，修正错误与警告。
5. 「导出」→ 打包 `.snavmod.zip`，放到游戏的 `mods/` 或 `user://mods/`。

> 官方内容也是模组。新建项目默认依赖 `core`；引用 `core:good/brass` 这类 ID 时请保留完整命名空间。

---

## 功能

### 内容类型

| 类型 | `content_type` | ID 类型段 | 说明 |
| --- | --- | --- | --- |
| 商品 | `goods` | `good` | 价格、重量、库存、弹性 |
| 造船材料 | `materials` | `material` | 打造材料 |
| 船体 | `hulls` | `hull` | 航速、载重、槽位、耐久 |
| 锅炉 | `boilers` | `boiler` | 航速与煤水系数 |
| 货舱 | `cargo_modules` | `cargo_module` | 容量 |
| 导航模块 | `navigation_modules` | `navigation_module` | 风险 / 航速 / 揭示设施 |
| 安全模块 | `safety_modules` | `safety_module` | 风险 / 损伤 / 维修 |
| 客舱 | `cabins` | `cabin` | 载客量 |
| 船员岗位 | `roles` | `role` | 工资与属性修正 |
| 锅炉策略 | `strategies` | `strategy` | 航速 / 煤 / 水 / 风险 |
| 港口原型 | `port_archetypes` | `port_archetype` | 设施与商品表 |
| 地图配置 | `map_profiles` | `map_profile` | 生成参数 |
| 初始构筑 | `starting_builds` | `starting_build` | 开局配置 |
| 委托 | `contracts` | `contract` | 生成、需求、奖励 |
| 航行事件 | `events` | `event` | 选项、条件与效果 |
| 显式补丁 | `patches` | — | 修改其他模组 |

### 编辑器

- **表单驱动**：字段、枚举、数字范围、必填项与数组结构来自 `schemas/*.schema.json`，与 Godot 加载链共用同一套约束。
- **专用控件**：属性修正（stat / op / value）、打造材料、载货/载客需求、港口商品表、事件选项、条件树、效果操作码、补丁操作。
- **引用选择**：船体、锅炉、商品、材料等字段带 Core + 当前项目的 ID 候选；显示中文名。
- **复制与派生**：复制当前定义，或从 Core 复制一条完整定义并自动改写 ID、本地化键与翻译。
- **JSON 检视 / 编辑**：任意定义可切换为原始 JSON 编辑；右侧检视器可查看当前上下文。
- **自动保存**：IndexedDB；状态栏显示保存时间。撤销 / 重做 40 步。
- **批量本地化**：缺失键列表、一键补齐键、未引用键提示、覆盖率。
- **资源**：添加 png / webp / svg / ogg / wav，自动生成 `manifest.assets` 映射并随 ZIP 打包。

### 导入 / 导出

| 格式 | 导入 | 导出 |
| --- | --- | --- |
| 松散模组目录 | 选择文件夹或拖入 | 写入 `<id>/` 目录（Chrome / Edge），或由本地服务写入 `mods/<id>/` |
| `.snavmod.zip` | 支持 | 支持，包内为 `mods/<id>/...`；本地服务可直接写入 `exports/` |
| `.snmodproj.json` | 支持 | 支持，含全部内容、翻译与附件 |
| 拖放 | 文件夹、ZIP、项目文件 | — |

### 本地磁盘工作区

`tools/serve.mjs` 额外提供同源 API：

```text
GET    /api/status
GET    /api/projects
GET    /api/projects/<id>
PUT    /api/projects/<id>     浏览器提交 project + 文件树
DELETE /api/projects/<id>
GET    /api/exports
POST   /api/exports?filename=...
DELETE /api/exports/<name>
```

- 写入 `mods/<id>/` 时同时生成 `.snmodproj.json`（编辑器项目）与 `manifest.json`、`content/`、`localization/`、`assets/`（可直接作为松散模组使用）。
- 服务只监听 `127.0.0.1`，没有鉴权，适合本机单人使用。
- 浏览器自动保存仍走 IndexedDB；磁盘写入是同一份项目的镜像，Ctrl+S 会立即刷新磁盘。
- 静态托管或 `file://` 打开时 `api/status` 不可用，界面会自动退化为浏览器存储。

ZIP 使用浏览器原生 `CompressionStream('deflate-raw')`；不支持时自动退化为存储（store）模式。Godot 的 `ZIPReader` 对两种模式都可读。

---

## 校验范围

网页端校验分两层：

1. **JSON Schema 子集**（`js/validate.js`）
   `type` / `enum` / `const` / `pattern` / `minLength` / `maxLength` / `minimum` / `maximum` /
   `exclusiveMinimum` / `exclusiveMaximum` / `required` / `properties` / `additionalProperties` /
   `items` / `minItems` / `maxItems` / `uniqueItems` / `allOf` / `anyOf` / `oneOf` / `not` /
   本地与 `common.schema.json` 引用。
2. **Steam Navigator 语义**
   Manifest ID / SemVer / 依赖范围、内容与本地化清单一致性、ID 命名空间与类型段、跨文件重复 ID、
   本模组引用是否存在、Core 引用是否存在、本地化键缺失/空值、补丁目标与操作安全、资源扩展名与大小。

网页端**不会**执行 Godot 的领域规则、Core 完整性检查、真实注册表冻结或脚本/资源包安全检查。导出前仍建议用 SDK 再跑一次：

```powershell
godot --headless --path . --script res://sdk/validate.gd -- --mod-root=sdk/examples/your_mod
```

---

## 项目结构

```text
SNModMaker/
├── index.html                  应用外壳
├── css/app.css                 暗色工业主题，无外部字体
├── js/schema-bundle.js         自动生成：/schemas/*.schema.json
├── js/core-index.js            自动生成：Core 定义、名称与翻译索引
├── js/catalog.js               内容类型元数据、字段标签、默认值、条件/效果词汇
├── js/zip.js                   ZIP 读写（store / deflate-raw，CRC32）
├── js/validate.js              Schema 子集与项目语义校验
├── js/store.js                 项目模型、模板、导入导出映射、Core 克隆
├── js/io.js                    IndexedDB、文件/文件夹/ZIP 导入、下载与目录写入
├── js/ui.js                    表单渲染、条件/效果编辑器、模态框
├── js/app.js                   应用状态、事件、撤销、自动保存、视图
├── tools/sync-schemas.mjs      重新生成 schema-bundle.js
├── tools/sync-core-index.mjs   重新生成 core-index.js
├── tools/serve.mjs             本地静态服务 + 磁盘 API（Node 内置模块）
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

### 重新生成 Schema 包

修改 `/schemas/*.schema.json` 后：

```powershell
node SNModMaker/tools/sync-schemas.mjs
```

### 重新生成 Core 索引

修改 `/dev_mods/core` 的内容或本地化后：

```powershell
node SNModMaker/tools/sync-core-index.mjs
```

Core 索引提供引用候选、中文名、跨引用检查与「从 Core 复制」的源数据。生成的 `js/schema-bundle.js` 与 `js/core-index.js` 不应手工编辑。

### 测试

```powershell
# 纯逻辑：Schema、校验、项目模型、导入导出、ZIP、全部内容类型表单
node SNModMaker/tests/run-tests.js

# 浏览器冒烟：需要 Chrome 以调试端口启动，并先启动静态服务
node SNModMaker/tools/serve.mjs
& 'C:\Program Files\Google\Chrome\Application\chrome.exe' --headless=new --disable-gpu --remote-debugging-port=9222 --user-data-dir="$env:TEMP\snmod-cdp" about:blank
node SNModMaker/tests/browser-smoke.mjs http://127.0.0.1:8099/ "$env:TEMP\snmod-smoke.png"
```

当前基线：**28 个 Node 用例 + 14 个浏览器用例**。浏览器测试会清空该调试实例下 `127.0.0.1:8099` 的存储，再完整走一遍：新建项目 → 新增定义 → 改数值 → 本地化 → JSON 检视 → 自动保存 → 导出 ZIP → 资源 → 事件条件/效果 → 补丁 → 撤销 → 从 ZIP 重新导入 → 文件夹导出 → 写入 `mods/` 与 `exports/`。

### 代码约定

- 纯经典脚本（无 ES module），便于直接 `file://` 打开；模块通过 `globalThis.SN*` 暴露。
- 不引入第三方库、字体或 CDN；图标使用内联 SVG / CSS。
- 新增内容类型时需要同步：`schemas/`、`ContentTypes`、`catalog.js`（标签 / 默认值 / key 前缀）、以及 `store.js` 使用这些默认值的模板/克隆逻辑。
- 所有用户文本与属性值都经过 `esc` / `attr` 转义；导入的 ZIP 有路径、条目数、解压体积与 CRC 限制。

---

## 已知边界

- 不支持 `.csv` 本地化；导入时会被跳过并给出警告。
- 不读取 Godot `.import` / `.uid`；资源以原始文件打包。
- 不做校验和自动计算；`checksum` 字段保留给 SDK / 发布链。
- 不做模组启用/禁用与加载顺序管理（那是游戏侧 `mods/` 的职责）。
- 浏览器端不运行领域逻辑，因此无法发现「数值可加载但玩法不可行」的问题。
- 文件夹导出依赖 File System Access API（Chromium）；其他浏览器请用 ZIP。
- 大型资源会以 base64 存在项目 JSON 中；建议单个资源 ≤ 2 MB，项目文件用于备份而非版本控制。
