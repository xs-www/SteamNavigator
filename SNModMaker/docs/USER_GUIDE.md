# SNModMaker 用户手册

> README 只保留入门信息；本文件是完整使用说明（功能、编辑器、导入导出、本地工作区、Docker/Tailscale、Content CLI、校验范围与已知边界）。

## 功能

### 内容类型

| 类型 | `content_type` | ID 类型段 | 说明 |
| --- | --- | --- | --- |
| 物品 | `items` | `item` | C2 合并商品与造船材料；`data.crafting_material` 区分打造材料（C2 起 Schema 2.0） |
| 船体 | `hulls` | `hull` | 航速、载重、槽位、耐久、武器/帆索安装点（C1 起 Schema 2.0） |
| 模块 | `modules` | `module` | C1 合并锅炉 / 货舱 / 杂项功能（导航·安全）/ 客舱，`data.v2_category` 区分 |
| 船员岗位 | `crew_roles` | `crew_role` | 工资与属性修正（C4-C 由 1.0 roles 升级，2.0） |
| 锅炉策略 | `boiler_strategies` | `boiler_strategy` | 航速 / 煤 / 水 / 风险（C4-C 由 1.0 strategies 升级，2.0） |
| 港口模板 | `port_templates` | `port_template` | 设施与商品表（C4 由 1.0 port_archetypes 升级，2.0） |
| 起始场景 | `starting_scenarios` | `starting_scenario` | 开局配置（C4 由 1.0 starting_builds 升级，2.0） |
| 委托 | `contracts` | `contract` | 生成、需求、奖励（保持独立的运输请求；C4-D 升 2.0） |
| 任务 | `quests` | `quest` | C3 抽象引导：剧情/指引/系统目标，stages 复用剧情条件 DSL（C3 起 Schema 2.0） |
| 航行事件 | `voyage_events` | `voyage_event` | 选项、条件与效果（C4-C 由 1.0 events 升级，2.0） |
| 显式补丁 | `patches` | — | 修改其他模组（C4-D 升 2.0） |

#### Content Schema 2.0 运行时类型与草案

Phase B 起，8 类世界/战役类型 + 新增 `map_configs` 已提升为**运行时 active 类型**；D2 起 30 类运行时类型全部为 `schema_version: "2.0"`（含 6 个战斗类型、4 个舰队类型与 `patches`），内容文件统一写 2.0 envelope；「Schema 2.0 草案 / 运行时不加载」分区只剩 2 类草案：剧情 `story_arcs` / `story_levels`（Story Mode S1 数据契约）。注意「不加载」不是静默忽略：Core 里若出现未注册类型或版本不符的内容，运行时会按 mod error 拒绝，Core 作为必需包会导致启动进入 `Degraded`；因此剧情草案只存在于编辑器项目与 `sdk/templates/story_pack_iron_tide`，不要写进 `dev_mods/core`。

| 类型 | `content_type` | 状态 | 说明 |
| --- | --- | --- | --- |
| 世界配置 | `world_profiles` | 运行时 2.0 | 区域 / 地点 / 港口 / 遗迹 / 基地 / 阵营数量 |
| 场景配置 | `map_configs` | 运行时 2.0 | 港口模板/名称、设施、NPC 与经济、孪生世界尺寸、31 键探索规则、教程 story；C4 起取代已退役的 map_profiles |
| 区域 | `regions` | 运行时 2.0 | 区域类型、规模、密度、敌对度、天气与阵营 |
| 地点 | `sites` | 运行时 2.0 | 遗迹 / 基地点 / 资源 / 残骸 / 地标 / 遭遇 |
| 航道模板 | `route_templates` | 运行时 2.0 | 距离、风险、耗时区间、双向与遭遇表 |
| 天气配置 | `weather_profiles` | 运行时 2.0 | 气候带、雾 / 风暴 / 浮冰概率与修正 |
| 阵营 | `factions` | 运行时 2.0 | 声望、阈值、巡逻强度、偏好商品、活动区域 |
| 图鉴发现 | `discoveries` | 运行时 2.0 | 图鉴条目类型、稀有度、权重与解锁引用 |
| 起始档案 | `start_profiles` | 运行时 2.0 | 世界配置 + 场景配置 + 起始构筑、难度、起始港口与货物 |
| 舰载武器 | `weapons` | 运行时 2.0（D1） | 战斗数值（对齐 SNBattleSim）、装配 class / 机构层、经济与模型键；船体安装点决定可装 class |
| 伤害类型 | `damage_types` | 运行时 2.0（D1） | 动能 / 爆炸 / 燃烧 / 电击；被武器与防御引用 |
| 战斗能力 | `combat_abilities` | 运行时 2.0（D1） | FSM 动作 + 目标优先级 / 距离阈值等 AI 行为参数 |
| 敌舰原型 | `enemy_archetypes` | 运行时 2.0（D1） | combat_kit 敌舰 class / 炮位、血量 / 装甲 / 航速、AI 与掉落引用 |
| 遭遇表 | `encounter_tables` | 运行时 2.0（D1） | 敌舰原型权重与数量区间、场景类型、危险度 |
| 掉落表 | `loot_tables` | 运行时 2.0（D1） | item / weapon / module 权重掉落与金钱区间 |
| 剧情篇章 | `story_arcs` | 草案 | 固定主角 / 角色表 / 术语 / 有序关卡列表；一个剧情包一个篇章（见 [STORY_MODE.md](../docs/design/STORY_MODE.md)） |
| 剧情关卡 | `story_levels` | 草案 | 内嵌固定地图（港口 / 航线 / 坐标）、初始状态、任务阶段、叙事、难度、checkpoint、仅成就类奖励 |

这些类型使用 `schemas/v2/` 下的 Schema（含 `v2/common.schema.json` 的共享定义与跨文件 `$ref`）。使用 `capability` 的内容模组需在 `manifest.capabilities` 声明对应能力（例如 `content.world.v1`、`content.campaign.v1`、`content.combat.v1`、`content.story.v1`），否则校验给出 `capability_undeclared` 警告；该规则按 `schema_version: "2.0"` 判定，不再只针对草案。

剧情包是「只加剧情的模组」：同一包里出现 `story_arcs` / `story_levels` 之外的内容会报 `story_pack_off_whitelist`，保证不改动自由模式。示例见 `sdk/templates/story_pack_iron_tide/`。

### 编辑器

- **表单驱动**：字段、枚举、数字范围、必填项与数组结构来自 `schemas/` 的 JSON Schema，与 Godot 加载链共用同一套约束。
- **Content Schema 2.0 类型**：运行时分组列出 30 类，全部为 2.0（Phase B 的 9 类 + C1 的 `hulls` / `modules` + C2 的 `items` + C3 的 `quests` + C4 的 `port_templates` / `starting_scenarios` + C4-C 的 `voyage_events` / `crew_roles` / `boiler_strategies` + C4-D 的 `contracts` / `patches` + D1 的 `weapons` / `damage_types` / `combat_abilities` / `enemy_archetypes` / `encounter_tables` / `loot_tables` + D2 的 `ship_archetypes` / `captains` / `formations` / `fleet_doctrines`），按 v2 Schema 校验并正常导出；不再有 1.0 运行时类型，侧栏「Schema 2.0 草案 / 运行时不加载」列出 2 类草案（剧情 `story_arcs` / `story_levels`，带 draft 标记）；表单、默认值、引用与校验走同一套 Schema，内容文件自动写 `schema_version: "2.0"`。
- **剧情表单**：`story_arcs` 编辑主角 / 角色表 / 术语 / 关卡顺序；`story_levels` 编辑内嵌固定地图（港口坐标、设施、市场、航道）、初始状态、任务阶段（含 checkpoint / presentation）、叙事简报 / beats / 结算、难度旋钮、奖励与失败重试策略；默认值自带 2 港 1 航道小地图，可直接校验通过。
- **舰载武器表单**：`weapons`（运行时 2.0）按战斗（kind / damage_type / damage / range / cooldown / accuracy / salvo / color…）、装配（weapon_class / assembly_profile / has_yaw·has_pitch·has_recoil·has_muzzle / muzzle_count / envelope_* / height / mount_scale）、经济（tier / weight / purchase_price / craft_* / materials）三组渲染；新增定义默认取模拟器「甲板速射炮」数值。
- **船体安装点**：船体表单可编辑 `weapon_sockets` / `rig_sockets` 数组（安装点名称、class/kind、索引、position 三元组、clearance_*、mount_scale、note），校验重复 name / 索引、非法 class/kind 与缺失必填；写出的是内容侧镜像，运行时装配仍读 GLB extras。
- **专用控件**：属性修正（stat / op / value）、打造材料、载货/载客需求、港口商品表、事件选项、条件树、效果操作码、补丁操作。
- **引用选择**：船体、模块、物品等字段带 Core + 当前项目的 ID 候选；显示中文名。
- **复制与派生**：复制当前定义，或从 Core 复制一条完整定义并自动改写 ID、本地化键与翻译；官方贴图/模型会保留为 `asset://core/...` 引用，不会被误认成当前模组资产。
- **实体键事务**：编辑 ID 时只同步显示多语言键预览；名称/描述可直接编辑所有语言，点击「保存条目」后才一次性迁移键和值并清理旧键。
- **模块分类**：船体（`hulls`）与模块（`modules`，按 boiler/cargo/utility/cabin 分类页签）、岗位与策略在同一“船只与模块”工作区中直接切换；导航/安全归入 utility 分类。
- **实体视觉资源**：每条标准实体都可通过暗色可搜索下拉框配置贴图与单文件 GLB 模型；图片、模型候选分开过滤，也允许直接输入资源键。
- **船体模块配置**：船体表单单独展示锅炉、导航、安全固定槽位，并直接编辑货舱与客舱槽位数量，不再混在普通数值字段中。
- **JSON 检视 / 编辑**：任意定义可切换为原始 JSON 编辑；右侧检视器可查看当前上下文。
- **自动保存**：IndexedDB；状态栏显示保存时间。撤销 / 重做 40 步。
- **批量本地化**：缺失键列表、一键补齐键、未引用键提示、覆盖率。
- **资源**：添加 png / webp / svg / ogg / wav / glb，自动生成 `manifest.assets` 映射并随 ZIP 打包；GLB 资源卡片会渲染自动取景的缩略图。
- **模型缩略图**：内置 GLB 解析 + WebGL 单帧渲染，无第三方库；只读取场景节点、三角网格、法线与材质基色，不做交互旋转或动画。

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
GET    /api/game-mods
POST   /api/game-mods/<id>    覆盖部署 <id>.snavmod.zip
DELETE /api/game-mods/<id>
```

- 写入 `mods/<id>/` 时同时生成 `.snmodproj.json`（编辑器项目）与 `manifest.json`、`content/`、`localization/`、`assets/`（可直接作为松散模组使用）。
- 默认只监听 `127.0.0.1`；`SNMODMAKER_HOST` 可覆盖（容器里设为 `0.0.0.0`），但服务没有鉴权，只应经宿主机端口映射 + `tailscale serve` 之类的可信通道访问。
- 浏览器自动保存仍走 IndexedDB；磁盘写入是同一份项目的镜像，Ctrl+S 会立即刷新磁盘。
- 导出菜单的“导出并覆盖到发布包 mods/”默认写入当前平台发布包的 `dist/build/<platform>/mods/<id>.snavmod.zip`（Windows 为 `dist/build/windows/mods/`）；若已存在其他平台的导出目录则优先使用当前平台，重复部署会覆盖稳定文件名，并清理同 ID 的旧 `<id>-<version>.snavmod.zip`，避免游戏加载重复模组。
- 含当前运行时不支持内容的项目（剧情草案，或内容文件版本与类型期望不一致 / 未知类型）：ZIP / 目录导出会二次确认并说明“游戏运行时不支持”，而“导出并覆盖到发布包 mods/”直接禁用（会让游戏启动进入 `Degraded` 且内容被丢弃）；30 类运行时 2.0 类型（含 `contracts` / `patches` / 6 个战斗类型 / 4 个舰队类型）都可以正常部署；`map_profiles` 已退役（`map_configs` 取代）。
- 默认目标由 `tools/game_mods_dir.mjs` 解析：优先 `SNMODMAKER_GAME_MODS_DIR`，其次已有的 `dist/build/*`，最后回退到当前平台目录。若编辑的是另一个游戏安装目录，启动服务前把 `SNMODMAKER_GAME_MODS_DIR` 设为该游戏旁的 `mods/`；开发态调试（编辑器 F5 扫描的 `dist/mods`）也可显式指向 `dist/mods`。项目与普通导出目录仍可分别用 `SNMODMAKER_MODS_DIR`、`SNMODMAKER_EXPORTS_DIR` 调整。
- 静态托管或 `file://` 打开时 `api/status` 不可用，界面会自动退化为浏览器存储。

ZIP 使用浏览器原生 `CompressionStream('deflate-raw')`；不支持时自动退化为存储（store）模式。Godot 的 `ZIPReader` 对两种模式都可读。

---

## Docker 与 Tailscale 远程访问

仓库根 `docker-compose.yml` + [`Dockerfile`](Dockerfile) 把编辑器打包成零依赖容器：只用 Node 内置模块，数据全部写容器侧命名卷，**不挂载宿主机仓库，也不会改 `dev_mods/core`**。

```powershell
docker compose up -d --build
# 本机打开 http://127.0.0.1:8099/
docker compose logs -f
docker compose down        # 停止，保留数据卷
docker compose down -v     # 停止并删除数据卷
```

容器内数据都在命名卷 `snmodmaker-data` 的 `/app/data` 下：

| 容器路径 | 用途 |
| --- | --- |
| `/app/data/mods/` | 编辑器项目副本（普通项目模式） |
| `/app/data/exports/` | ZIP / 项目文件导出 |
| `/app/data/game-mods/` | 「导出并覆盖到发布包 mods/」的落点 |
| `/app/data/workspace/` | 原生工作区根（在容器内，默认空；不会写回宿主机 core） |

- 宿主机只映射 `127.0.0.1:8099`；可用 `SNMODMAKER_PORT` 改宿主端口（`$env:SNMODMAKER_PORT=8100; docker compose up -d`）。
- 静态文件在镜像里，改 `js/`、`css/`、`index.html` 后要 `docker compose build` 再 `up -d`。
- 备份数据卷：`docker run --rm -v snmodmaker-data:/data -v "${PWD}:/backup" alpine tar czf /backup/snmodmaker-data.tgz -C /data .`
- 服务没有鉴权，不要把容器端口发布到 `0.0.0.0` 或公网。

### Tailscale 远程访问

宿主机 Tailscale 登录后，用 Serve 把本机 8099 以 HTTPS 暴露给 tailnet（Windows / Linux 均可）。两种挂载方式任选：

```powershell
# 方式 A：独立 HTTPS 端口（推荐；不占用 443 上已有的路径）
tailscale serve --bg --https 8443 http://127.0.0.1:8099
# 浏览器打开 https://<机器名>.<tailnet>.ts.net:8443/
tailscale serve --https=8443 off          # 撤销

# 方式 B：挂到现有 443 的子路径（不额外占端口）
tailscale serve --bg --set-path /snmodmaker http://127.0.0.1:8099
# 浏览器打开 https://<机器名>.<tailnet>.ts.net/snmodmaker/
# 结尾斜杠必须存在；漏写时 index.html 会自动补一次
```

- 只走 tailnet；**不要用 `tailscale funnel`**，它会把无鉴权编辑器公开到互联网。
- 用 Tailscale ACL 限制可访问该设备的用户/设备；需要额外一层认证时可在前面加 Caddy Basic Auth。
- `tailscale serve` 提供有效 HTTPS 证书，浏览器处于 secure context，「文件夹导出」等 File System Access 功能可用。
- 子路径挂载依赖相对路径加载资源；`index.html` 内置补斜杠脚本，反向代理不需要额外 rewrite。

---

## 命令行（agent 无头工作流）

除网页编辑器外，`tools/content.mjs` 提供同一套内容模型的命令行入口：按 Schema 增删改定义、补本地化、读取类型说明、校验既有模组。它面向 agent、CI 与批量维护脚本，不启动浏览器，也不引入额外依赖（Node.js ≥ 18，ESM）。

CLI 与编辑器使用同一份类型清单：`types` 会同时列出 30 个运行时类型（C1 起锅炉/货舱/导航/安全/客舱合并为 `modules`，船体升级为 2.0；C2 起商品与材料合并为 `items`；C3 新增 `quests`，`contracts` 保持独立；C4 起港口原型→`port_templates`、初始构筑→`starting_scenarios`，`map_profiles` 退役；C4-C 起 `events`→`voyage_events`、`roles`→`crew_roles`、`strategies`→`boiler_strategies`；C4-D 起 `contracts` 与 `patches` 也升为 2.0；D1 起 `weapons` 与 5 个战斗类型全部转正；D2 起 4 个舰队类型转正，运行时类型不再有 1.0）与 2 个 Schema 2.0 草案类型（剧情 story_arcs / story_levels；草案标 `draft: true`、`schema_version: "2.0"`），`describe` / `list` / `add` / `set` / `validate` 对草案类型同样可用；写出的草案内容文件自动使用 `schema_version: "2.0"`。新建项目时可用 `new --draft <content_type>`（可重复）直接创建**纯 2.0 草案项目**：每类生成一个内容文件与起始定义，并把 capability 自动写入 `manifest.capabilities`（例如 `--draft story_arcs --draft story_levels` 建一个纯剧情包）；`--template` 可选 `items` / `boiler` / `event` / `weapons` / `starter_kit` / `blank`，其中 `--template boiler` 生成一个 `modules` 类型的锅炉模块（`data.v2_category: "boiler"`），`--template weapons` 是「舰载武器包」（一次生成 5 件模拟器武器，运行时 2.0 内容）。剧情草案是白名单模组，不要与自由模式模板叠加。

所有命令都从**仓库根**执行，`--mod` 指向仓库内的松散模组目录（例如 `dev_mods/core` 或 `SNModMaker/mods/<id>`，必须含 `manifest.json`）；所有写入都会留在该目录内。

### 命令

| 命令 | 用途 |
| --- | --- |
| `types` | 列出内容类型：`content_type`、ID 类型段与内容文件 |
| `describe <type>` | 输出该类型的字段表、默认值、ID 规则与可直接修改的骨架 |
| `list --mod <dir>` | 列出模组内已有定义，可按 `--type` 过滤 |
| `add --mod <dir>` | 新增一条定义（双语文案、tags、data），或以 patch 形式修改其他模组 |
| `set --mod <dir> <id> <path>=<value>` | 修改既有定义的字段或数组（`+=` / `-=`） |
| `loc --mod <dir> ...` | 写本地化文案：按定义键，或按任意 `--key` 直接写入 |
| `rm --mod <dir> <id> --yes` | 删除定义，并清理它独占的本地化键 |
| `clone --mod <dir> --from <core-id>` | 从 Core 定义复制一条到当前模组 |
| `validate --mod <dir>` | 只读校验：Schema、引用、命名空间与本地化 |
| `new --mod <dir> --id <mod_id>` | 从模板新建模组骨架：`--template items\|boiler\|event\|weapons\|starter_kit\|blank`（`weapons` 生成 5 件舰载武器包）；`--draft <content_type>`（可重复）改为新建纯 Schema 2.0 草案项目 |

每个命令都支持 `--json`、`--quiet`、`--help`（`-h`）；`add` / `set` / `rm` / `clone` 支持 `--dry-run`（`rm` 另需 `--yes`），`add` / `set` / `clone` 支持 `--force`。完整选项见 `node SNModMaker/tools/content.mjs <command> --help`。

### 典型用法

先看某个类型的字段与骨架，再照着写 `add`：

```powershell
node SNModMaker/tools/content.mjs describe items
```

新增商品；`--data` 按路径赋值，支持 `a.b`、`a[2].b` 与 `/data/x`：

```powershell
node SNModMaker/tools/content.mjs add --mod SNModMaker/mods/my_mod --type items --id tea `
  --name-zh "红茶" --name-en "Black Tea" `
  --desc-zh "来自东方的发酵茶。" --desc-en "A fermented tea from the east." `
  --tag good.trade --data base_price=68 --data unit_weight=1
```

改既有定义；`+=` / `-=` 用于数组，`--dry-run` 只看 diff 不落盘：

```powershell
node SNModMaker/tools/content.mjs set --mod SNModMaker/mods/my_mod my_mod:item/tea data.base_price=72
node SNModMaker/tools/content.mjs set --mod SNModMaker/mods/my_mod my_mod:item/tea tags+=good.luxury --dry-run
```

从 Core 复制一条再校验：

```powershell
node SNModMaker/tools/content.mjs clone --mod SNModMaker/mods/my_mod --from core:item/iron_ore --id iron_ore `
  --name-zh "铁矿石" --name-en "Iron Ore"
node SNModMaker/tools/content.mjs validate --mod SNModMaker/mods/my_mod --json
```

新建 Schema 2.0 草案项目（武器 / 剧情等）；`--template` 可叠加内容模板：

```powershell
node SNModMaker/tools/content.mjs new --mod SNModMaker/mods/my_weapons --id my_weapons `
  --name "我的武器包" --draft weapons
node SNModMaker/tools/content.mjs new --mod SNModMaker/mods/my_story --id my_story `
  --name "我的剧情包" --draft story_arcs --draft story_levels
node SNModMaker/tools/content.mjs validate --mod SNModMaker/mods/my_weapons --json
```

`--draft` 项目会在 `manifest.capabilities` 里自动声明对应 capability（weapons → `content.combat.v1`，剧情 → `content.story.v1`），校验只会给 `draft_content`（新建剧情项目另有 `story_arc_empty_levels` / `story_level_orphan` 提示，补齐关卡与引用后消失）；这类项目同样不能「导出并覆盖到发布包 mods/」（运行时不加载草案内容）。普通 `add` 新增 Phase B 的 2.0 运行时类型（如 `world_profiles`）会正常写出 2.0 文件并参与导出，但需在 manifest 声明对应 capability，否则校验给 `capability_undeclared` 警告（按 capability 去重）。

校验随仓库分发的完整剧情示例包（1 篇章 + 2 关卡 + 中英文本）：`node SNModMaker/tools/content.mjs validate --mod sdk/templates/story_pack_iron_tide`（0 error / 2 个预期 `draft_content` warning）。剧情包里混入任何非剧情内容会报 `story_pack_off_whitelist`。

一次生成 5 件战斗模拟器武器（「舰载武器包」模板，运行时 2.0 内容）：

```powershell
node SNModMaker/tools/content.mjs new --mod SNModMaker/mods/my_weapon_pack --id my_weapon_pack `
  --name "我的武器包" --template weapons
```

它会创建 `content/weapons.json`（`schema_version: "2.0"`）与 5 条定义：`my_weapon_pack:weapon/deck_gun` / `heavy_cannon` / `mortar` / `repeater` / `broadside`，战斗数值抄 SNBattleSim，装配字段来自 GLB extras，`information.model` 写成 `asset://core/model.weapon.<id>`，并把 `content.combat.v1` 写进 `manifest.capabilities`。需要单条骨架时用 `add --type weapons`。

### JSON 输出与退出码

加 `--json` 后 stdout 只有一个 JSON 对象，日志走 stderr 或放进 `notes`，可直接交给 jq / agent 解析：

```json
{
  "ok": true,
  "command": "add",
  "mod": "dev_mods/core",
  "changes": [{ "path": "content/items.json", "action": "update", "bytes": 4321, "diff": "..." }],
  "issues": { "errors": 0, "warnings": 29, "newErrors": 0, "newWarnings": 0, "list": [] },
  "stats": { "definitions": 51, "contentFiles": 15, "locales": 2 },
  "notes": []
}
```

- `changes[].action` 为 `create` / `update` / `delete`；`--dry-run` 时为 `would-create` / `would-update` / `would-delete`。
- `issues.list` 只列本次**新增**的问题，每项为 `{severity, code, message}`。
- 失败时同样只有一个 JSON 对象：`{"ok": false, "command": "...", "error": {"code": "...", "message": "..."}}`。
- 退出码：`0` 成功；`1` 执行失败 / 校验未通过 / 并发冲突；`2` 用法错误（缺参、未知命令或未知类型）。`--json` 在用法错误时也会输出 JSON。

### 写入、格式与并发保护

- **只写变化的文件**：内容 JSON 走保源编辑，只增删目标节点所在的行，不重排既有定义、不丢 `3.0` 这类结尾小数点、不改缩进；本地化文件只改受影响的值所在行；`manifest.json` 只增量插入或删除条目。
- **校验闸门**：`add` / `set` / `rm` / `clone` 会对比改动前后的校验结果，出现新的 error 就不写盘并退出 `1`；`--force` 会在有 new error 时仍写盘，但结果标记为失败（退出 `1`），只在明确知情时使用。
- **并发保护**：加载时记录每个待写文件的 SHA-256，写前重新读取比对；文件已被其他进程或 agent 改过就报 `conflict`，整批不写。写入使用同目录临时文件加 rename 原子替换。
- **写盘后钩子**：对 `manifest.id` 为 `core` 的模组，`add` / `clone` 的 `--sync` 会在真实写入后重新生成 Core 索引；`add` 的 `--test` 会在真实写入后运行 `node SNModMaker/tests/run-tests.js`，失败则退出 `1`。

### 可选：用 Godot 再校验

`validate` 默认只跑网页端同源的 Schema 与语义校验。要让本体的加载链复核，先设置 Godot 可执行文件，再加 `--godot`：

```powershell
$env:GODOT_BIN = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
node SNModMaker/tools/content.mjs validate --mod dev_mods/core --godot
```

它通过 `GODOT_BIN` 调用 `sdk/validate.gd --mod-root=<mod>`，把退出码与输出并入结果；未设置 `GODOT_BIN` 时在 `notes` 里注明跳过，不算失败。

---

## 校验范围

网页端校验分两层：

1. **JSON Schema 子集**（`js/validate.js`）
   `type` / `enum` / `const` / `pattern` / `minLength` / `maxLength` / `minimum` / `maximum` /
   `exclusiveMinimum` / `exclusiveMaximum` / `required` / `properties` / `additionalProperties` /
   `items` / `minItems` / `maxItems` / `uniqueItems` / `allOf` / `anyOf` / `oneOf` / `not` /
   本地与 `common.schema.json` 引用；`schemas/v2/` 的草案 Schema 按基准文件所在目录解析
   `common.schema.json` 等跨文件 `$ref`。
2. **Schema 版本**：每个内容类型在 `content_types.json` 声明自己的 `schema_version`，生成到编辑器的 `schemaVersion` 字段
   （当前 30 类运行时类型全部为 2.0：Phase B 的 9 类 + C1 的 `hulls` / `modules` + C2 的 `items` + C3 的 `quests` + C4 的 `port_templates` / `starting_scenarios` + C4-C 的 `voyage_events` / `crew_roles` / `boiler_strategies` + C4-D 的 `contracts` / `patches` + D1 的 6 个战斗类型 + D2 的 `ship_archetypes` / `captains` / `formations` / `fleet_doctrines`；`story_arcs` / `story_levels` 草案为 2.0）；声明版本与类型不符报 `schema_version_mismatch`，不是 1.0 / 2.0 报
   `schema_version_unsupported`。运行时同样按类型校验版本，不再有全局单一门禁。
3. **Steam Navigator 语义**
   Manifest ID / SemVer / 依赖范围、内容与本地化清单一致性、ID 命名空间与类型段、跨文件重复 ID、
   本模组引用是否存在、Core 引用是否存在、本地化键缺失/空值、补丁目标与操作安全、资源扩展名与大小。
   `draft_content` 只对 `story_arcs` / `story_levels` 草案提示（运行时暂不加载）；`schemaVersion = 2.0` 的内容使用
   `capability` 但未写入 `manifest.capabilities` 时给 `capability_undeclared` 警告（同一 capability 一条）。

网页端**不会**执行 Godot 的领域规则、Core 完整性检查、真实注册表冻结或脚本/资源包安全检查。导出前仍建议用 SDK 再跑一次：

```powershell
godot --headless --path . --script res://sdk/validate.gd -- --mod-root=sdk/examples/your_mod
```

---

## 已知边界

- Content Schema 2.0：30 类运行时类型（Phase B 的 9 类 world_profiles / map_configs / regions / sites / route_templates / weather_profiles / factions / discoveries / start_profiles，加 C1 的 `hulls` / `modules`、C2 的 `items`、C3 的 `quests`、C4 的 `port_templates` / `starting_scenarios`、C4-C 的 `voyage_events` / `crew_roles` / `boiler_strategies`、C4-D 的 `contracts` / `patches` + D1 的 `weapons` / `damage_types` / `combat_abilities` / `enemy_archetypes` / `encounter_tables` / `loot_tables` + D2 的 `ship_archetypes` / `captains` / `formations` / `fleet_doctrines`）已是**运行时类型**，可正常编辑、校验、导出并部署；剧情 `story_arcs` / `story_levels` 仍是编辑器草案（运行时暂不加载，校验给 `draft_content` 警告，含它的项目不能部署到发布包）。`schemaVersion = 2.0` 的内容需在 `manifest.capabilities` 声明对应 capability（如 `content.world.v1` / `content.campaign.v1` / `content.modules.v1` / `content.hulls.v1` / `content.items.v1` / `content.quests.v1` / `content.port_templates.v1` / `content.starting_scenarios.v1` / `content.voyage_events.v1` / `content.crew_roles.v1` / `content.boiler_strategies.v1` / `content.contracts.v1` / `content.patches.v1` / `content.combat.v1` / `content.fleet.v1` / `content.story.v1`），否则给 `capability_undeclared` 警告。**「运行时不支持」不等于静默忽略**：Core 里出现未注册类型 / 版本不符会按 mod error 拒绝，Core 必需包会让启动进入 `Degraded`；武器示例包放在 `sdk/examples/example_weapons`，剧情示例包只放在 `sdk/templates/story_pack_iron_tide`，不要手工搬进 `dev_mods/core`。
- 船体 `weapon_sockets` / `rig_sockets` 是**内容侧镜像**：编辑器可编辑、Schema 可校验，但运行时装配仍读 GLB 节点 extras，`ShipVisualAssembler` 尚未接入；镜像里的 `socket_index` 从 0 起，GLB extras 的武器 socket 从 1 起，对表时需转换。
- 不支持 `.csv` 本地化；导入时会被跳过并给出警告。
- 不读取 Godot `.import` / `.uid`；资源以原始文件打包。
- 模型缩略图只做基础单帧渲染：不解析贴图、Draco / KTX2、骨骼动画与变形目标；解析失败时保留 GLB 占位，不影响编辑和导出。
- 不做校验和自动计算；`checksum` 字段保留给 SDK / 发布链。
- 不做模组启用/禁用与加载顺序管理（那是游戏侧 `mods/` 的职责）。
- 浏览器端不运行领域逻辑，因此无法发现「数值可加载但玩法不可行」的问题。
- 文件夹导出依赖 File System Access API（Chromium）；其他浏览器请用 ZIP。
- Content CLI 只处理内容 JSON 与本地化；资源（图片 / GLB）与 ZIP 导入导出仍走网页编辑器或 SDK。
- Content CLI 不做定义 ID 重命名（`clone --id` 新建条目除外），也不运行 Godot 领域逻辑；需要时用 `--godot` 交给 SDK 校验。
- 大型资源会以 base64 存在项目 JSON 中；图片/音频建议单个资源 ≤ 2 MB，GLB 模型上限 20 MB，项目文件用于备份而非版本控制。
