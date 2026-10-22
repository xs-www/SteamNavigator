# SNModMaker — 零依赖网页端模组制作器

在浏览器里可视化创建、编辑和打包《Steam Navigator》的内容模组：

- 读取仓库内**官方 JSON Schema**，按类型生成表单；
- 编辑 Manifest、20 类运行时类型（4 类 1.0 + 15 类 2.0 + 显式补丁）、3 类 Content Schema 2.0 草案类型（`weapons`、`story_arcs`、`story_levels`）、本地化与资源；
- 实时校验 ID 命名空间、字段约束、跨引用、本地化覆盖与补丁安全；
- 导入松散目录 / `.snavmod.zip` / 项目文件；导出同结构 ZIP、项目文件或写入本地目录；
- 无头命令行 `tools/content.mjs`：给 agent / CI / 批量脚本按 Schema 增删改定义、补本地化并校验。

运行时**零第三方依赖**：没有 npm 包、CDN、构建步骤或网络请求；全部是仓库里的原生 HTML / CSS / JavaScript。

**详细文档按需读取：**

| 文档 | 内容 |
| --- | --- |
| [docs/USER_GUIDE.md](docs/USER_GUIDE.md) | 功能、编辑器、导入/导出、本地工作区、Docker/Tailscale、Content CLI 全量命令、校验范围、已知边界 |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | 项目结构、数据流、生成物维护、测试与代码约定 |
| [../sdk/README.md](../sdk/README.md) | 游戏侧 SDK 的 runtime/draft 校验与发布打包 |
| [../README.md](../README.md) | 仓库入口、跑游戏、全量测试 |

---

## 快速开始

### Windows 一键启动（推荐）

双击 [`start.bat`](start.bat)。脚本会在缺少 Node.js 时自动安装最新 LTS 版，然后启动本地服务并打开 `http://127.0.0.1:8099/`。使用期间请保留命令窗口；关闭窗口即停止服务。

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

**起始模板**（新建模组对话框与 CLI `new --template <key>` 共用同一清单）：物品包、锅炉包、事件包、**舰载武器包**（战斗模拟器 5 件内置武器，带 `asset://core/model.weapon.*` 模型与 `weapon-assembly@2` 装配数据）、小型内容合集、空白模组。武器包只写入编辑器项目、不写 Core，原因见 [USER_GUIDE.md](docs/USER_GUIDE.md) 的「Schema 2.0 草案」。

> 官方内容也是模组。新建项目默认依赖 `core`；引用 `core:item/brass` 这类 ID 时请保留完整命名空间。

---

## 功能摘要

- **内容类型**：20 类运行时类型 + 3 类草案；类型清单来自 `content_types.json`（唯一真源），表单由 Schema 生成。
- **编辑器**：Manifest / 定义表单 / 本地化 / 资源；模块按 `v2_category` 分类；武器与剧情草案可编辑校验但不能部署。
- **导入导出**：松散目录、`.snavmod.zip`、项目文件；本地服务可直接写入游戏 `mods/` 或发布包。
- **Content CLI**：`list / add / set / describe / validate / new / clone / rm` 等，支持 agent 无头工作流。

**命令行快速示例**（完整参数与退出码见 [USER_GUIDE.md](docs/USER_GUIDE.md#命令行agent-无头工作流)）：

```powershell
node SNModMaker/tools/content.mjs types
node SNModMaker/tools/content.mjs validate --mod SNModMaker/mods/my_mod
node SNModMaker/tools/content.mjs add --mod my_mod --type items --id my_mod:item/tea --name "Tea"
```

## 开发

```powershell
node SNModMaker/tests/run-tests.js          # 纯逻辑 / Schema / 表单
node --test SNModMaker/tests/content-cli.test.mjs  # Content CLI 集成
node tools/gen_content_types.mjs            # 修改 content_types.json 后重新生成
node tools/gen_content_types.mjs --check    # 检查生成物是否最新
node tools/gen_static_docs.mjs --check      # 静态文档门禁
```

项目结构、数据流、Schema/Core 索引再生成、浏览器冒烟与代码约定见 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)。

## 已知边界

编辑器不执行模组代码；武器/剧情草案只能校验、不能部署；`file://` 下浏览器存储受限。完整列表见 [docs/USER_GUIDE.md](docs/USER_GUIDE.md) 的「已知边界」。
