# 游玩数据上传（Telemetry）契约

> 状态：Active（实现中）。本文件是**唯一契约**：设置项、客户端会话记录、上传协议、官网接收端与存储、验收标准的改动都必须先改这里。
> 相关模块：`framework/services/`（记录与上传）、`framework/ui/shell/main.gd`（设置与退出接线）、`website/server/`（接收端）。

## 1. 目标与红线

- 目标：设置页新增一条**默认关闭**的「允许上传数据以帮助我们优化游戏」选项；勾选后，玩家**每次游玩结束**（正常退出游戏）时把本局游戏日志上传到官网；未勾选时**不记录、不上传、不落盘**。
- 隐私红线：
  - 上传内容只含**游玩数据**（版本、语言、平台、本局命令/事件/警告摘要、游玩统计），**不含**账号、昵称、硬件标识、机器名、IP、剪贴板；结构化字段不写本地路径，WARN+ 只快照 `level` / `time` / `message` 文本（日志 `fields` 不上传）。命令参数只上传 §3.4 白名单里的内容 ID / 枚举 / 数量 / 时长，不上传自由文本与嵌套对象。
  - 默认 `false`（opt-in）。取消勾选后停止记录并**删除本机待上传队列**。
  - 客户端上传前把字符串字段截断（单字段 ≤ 300 字符，命令/事件名 ≤ 80 字符）；单文件/单次请求体 ≤ 512 KiB（超限先裁最旧数据）。
  - 官网接收端**不记录客户端 IP**；进程日志只记请求结果与字节数。
- 失败降级：官网不可达 / 超时 / 非 2xx 时保留待上传文件，下次启动游戏再重试；绝不阻塞退出超过 3 秒，也不弹错误框。

## 2. 设置项

`config/config.json`（发布版随 exe 放在 `config/config.json`，见 `.github/workflows/release.yml`）：

```json
{
  "version": 1,
  "locale": "zh_CN",
  "autosave": true,
  "telemetry": false,
  "telemetry_endpoint": "https://steamnavigator.playthought.cn/api/telemetry/session",
  "telemetry_token": ""
}
```

- `telemetry`：bool，默认 `false`。设置页复选框状态。`SettingsService.telemetry()` / `set_telemetry()` 存取。
- `telemetry_endpoint`：绝对 `http(s)://` URL；空或非法时回退到代码常量 `TelemetryService.DEFAULT_ENDPOINT = "https://steamnavigator.playthought.cn/api/telemetry/session"`。发布流水线可用仓库变量覆盖（见 §7）。
- `telemetry_token`：可选共享令牌，非空时客户端随请求发送 `X-SN-Telemetry-Token`；默认空 = 不校验。
- 设置页：字段宽 96 px 的行，字段名 `ui.menu.telemetry`（「允许上传数据」），值按钮「开 / 关」（`toggle_telemetry` 意图），右侧说明 `ui.menu.telemetry_note`。默认关；勾选即时生效（保存到 `config/config.json`）。
- 关闭时：停止记录、丢弃当前会话缓冲、删除 `user://telemetry/pending/` 下所有文件。

## 3. 客户端会话生命周期

一次「游玩」= 一次进程启动到退出（含主菜单时间）。

1. `main.gd` `_ready()` 加载设置后创建 `TelemetryService` 并挂到 `AppContext.telemetry`；`enabled` 取自设置。
2. `enabled` 时 `begin_session(meta)`：`session_id`、`started_at`、版本/语言/平台。
3. 游戏过程中被动记录（`is_recording()` 为假时全部 no-op）：
   - `CommandBus.execute()` 每次命令一条 `commands` 记录（命令名、成功、错误码、耗时毫秒、游戏时间、**白名单参数摘要**，见 §3.4）。
   - `DomainEventBus.event_published` 只记录白名单事件（`voyage.*`、`port.*`、`contract.*`、`combat.*`、`story.*`、`quest.*`、`market.*`、`run.*`），payload 截断后进 `events`。
   - `AppLogger` WARN/ERROR/FATAL 在收尾时快照进 `errors`。
4. 退出（`_graceful_quit()`，「退出游戏」按钮与窗口关闭都走这里）：
   - `finalize_session(summary)` 写 `user://telemetry/pending/<session_id>.json`；
   - `await TelemetryUploader.flush(endpoint, token)`，最多等 3 秒；
   - 无论成功与否继续原有清理/退出流程。
5. 下次启动且 `enabled` 时，`flush()` 后台补传遗留的 pending 文件（先入先出）；无头进程（测试/工具）不发起真实网络请求。
6. 队列上限 20 个 pending 文件；超出丢弃最旧的。单文件上限 512 KiB（超限先裁剪命令/事件再写）。

### 会话载荷（`sn.telemetry.session/1`）

```json
{
  "schema": "sn.telemetry.session/1",
  "session_id": "20261027T081500Z-1a2b3c4d",
  "started_at": "2026-10-27T08:15:00Z",
  "ended_at": "2026-10-27T08:23:32Z",
  "duration_seconds": 512,
  "game_version": "0.2.0",
  "framework_version": "0.1.0",
  "content_schema": "2.0",
  "locale": "zh_CN",
  "os": "Windows",
  "run": {
    "has_run": true,
    "seed": 12345,
    "port_id": "core:port_template/iron_harbor",
    "money": 1234,
    "game_hours": 42.0,
    "victory": false,
    "commands": 87,
    "failed_commands": 3
  },
  "mods": [{"id": "core", "version": "1.0.0"}],
  "commands": [
    {"seq": 1, "command": "trade.buy", "ok": true, "error_code": "", "duration_ms": 2, "game_time": 8.0,
     "params": {"item_id": "core:item/iron_ore", "amount": 3}},
    {"seq": 2, "command": "voyage.start", "ok": false, "error_code": "route_locked", "duration_ms": 1, "game_time": 9.0,
     "params": {"destination": "core:port_template/spice_harbor", "strategy_id": "core:boiler_strategy/steady"}}
  ],
  "events": [
    {"event_type": "voyage.completed", "game_time": 12.0, "payload": {"destination": "..."}}
  ],
  "errors": [
    {"level": "ERROR", "time": "2026-10-27T08:20:00Z", "message": "..."}
  ]
}
```

- 字段上限：`commands` 300、`events` 150、`errors` 40；超出丢最旧。
- `session_id` 必须匹配 `^[A-Za-z0-9_-]{8,64}$`（服务端按它做文件名，防路径穿越）。
- 序列化用 `JsonUtils.canonical_stringify`，UTF-8，无 BOM。

### 命令参数摘要（`commands[].params`，§3.4）

- 目的：能回答「玩家买了什么、跑哪条线、装了什么件」这类行为问题，又不把整份参数（`data` 大对象、自由文本）传上来。
- 参数按**键名白名单**过滤，只保留标量值；没有白名单参数时**不写** `params` 字段：
  - ID / 枚举键：`item_id`、`module_id`、`replace_module_id`、`weapon_id`、`hull_id`、`port_id`、`destination`、`destination_id`、`origin`、`origin_id`、`source`、`strategy_id`、`socket`、`slot`、`tier`、`instance_id`、`contract_id`、`clue_id`、`quest_id`、`event`、`option_id`、`encounter_id`、`encounter_table_id`、`starting_scenario`、`start_profile`、`settlement_key`。
  - 数值键：`amount`、`qty`、`hours`、`speed`、`seed`。
- 限制：字符串值 ≤80 字符；每条命令最多 8 个键；`Dictionary` / `Array` / `Object` / `null` 值一律丢弃（防止嵌套对象或自由文本外泄）。
- 实现：`TelemetryService.sanitize_command_params()`（纯函数，测试直接覆盖）；`CommandBus` 在调用 `record_command()` 时附带原始 `params`，过滤在服务内完成。

### 上传协议

- `POST <telemetry_endpoint>`，`Content-Type: application/json`，`Accept: application/json`，可选 `X-SN-Telemetry-Token`。
- 成功：HTTP 200/201/204（服务端返回 204）。客户端删除该 pending 文件。
- 失败（超时 8 秒 / 网络错误 / 4xx / 5xx）：保留文件，本轮停止（避免雪崩），下次启动重试。
- 每次只上传一个文件，串行。

## 4. 官网接收端

- 代码：`website/server/telemetry.mjs`（零依赖 Node，>= 18）。导出 `createTelemetryHandler(options)` 便于本地预览与测试复用；`node website/server/telemetry.mjs` 直接启动。
- 路由（挂在官网同域 `/api/telemetry/` 下，生产由 nginx 反代到 `telemetry` 容器）：
  - `GET /api/telemetry/health` → `200 {"ok":true,"service":"sn-telemetry","schema":"sn.telemetry.session/1"}`
  - `POST /api/telemetry/session` → 校验 → `204`（无响应体）
- 校验：JSON 对象、`schema` 精确匹配、`session_id` 正则、`started_at`/`ended_at` 为 ISO-8601 字符串、`duration_seconds` 数值、请求体 ≤ 512 KiB。失败：`400`（坏 JSON）/ `413`（超限）/ `422`（字段不合法）；其它路径 `404`，非 POST `405`。
- 限流：按来源 IP 每小时 120 次，超出 `429`；不持久化 IP。
- 存储（数据目录默认 `/data`，环境变量 `SN_TELEMETRY_DATA_DIR`）：
  - `sessions/<YYYY-MM-DD>/<session_id>.json`：原始载荷（紧凑 JSON）。
  - `sessions/<YYYY-MM-DD>/index.ndjson`：每行一条摘要（`session_id`、`received_at`、`game_version`、`duration_seconds`、`commands`、`errors`、`bytes`），便于统计。
  - 保留 180 天：每小时至多一次惰性清理；写入失败返回 `500`，客户端下次重试。
- 可选令牌：环境变量 `SN_TELEMETRY_TOKEN` 非空时要求 `X-SN-Telemetry-Token` 相等，否则 `401`。
- 部署：`website/deploy/Dockerfile.telemetry`（`node:22-alpine`，非 root，端口 8090）+ `website/docker-compose.yml` 的 `telemetry` 服务（数据卷、只读根、64 MB / 0.5 CPU、healthcheck）；`website/deploy/nginx.conf` 把 `/api/telemetry/` 反代到 `http://telemetry:8090`（`client_max_body_size 1m`，其余静态行为不变）。
- 本地：`node website/tools/serve.mjs` 同样提供 `/api/telemetry/*`（数据写 `website/.data/telemetry/`，已 gitignore），方便游戏端联调与自动测试。

## 5. 代码落点与职责

| 位置 | 职责 |
| --- | --- |
| `framework/services/telemetry_service.gd` | 纯逻辑：会话缓冲、裁剪、payload、pending 队列读写、开关与丢弃；不依赖 SceneTree。 |
| `framework/services/telemetry_uploader.gd` | Node：`HTTPRequest` 串行上传 pending、超时、成功删除、失败保留。 |
| `framework/services/settings_service.gd` | `telemetry` / `telemetry_endpoint` / `telemetry_token` 的规范化与存取。 |
| `framework/application/command_bus.gd` | 每条命令记入 `context.telemetry`（null 安全）。 |
| `framework/bootstrap/app_context.gd` | `var telemetry: TelemetryService = null`。 |
| `framework/ui/shell/main.gd` | 创建服务/上传器、绑定事件总线、设置页 VM、`toggle_telemetry`、退出收尾与补传。 |
| `framework/ui/screens/menu/settings_screen.gd` | 设置行与说明（不直接读写服务）。 |
| `framework/localization/{zh_CN,en}.json` | `ui.menu.telemetry` / `_on` / `_off` / `_note`。 |
| `website/server/telemetry.mjs` | 接收、校验、限流、存储、保留策略。 |
| `website/tools/serve.mjs` | 本地预览挂载同一 handler。 |
| `website/deploy/Dockerfile.telemetry`、`website/docker-compose.yml`、`website/deploy/nginx.conf` | 生产部署与反代。 |
| `website/tests/telemetry.test.mjs` | 接收端 Node 测试。 |
| `framework/tests/cases/test_telemetry.gd` | 客户端记录/队列/设置测试（进 `test_runner.gd`）。 |

## 6. 验收标准

1. 设置页显示默认关闭的「允许上传数据」；点击切换后写回 `config/config.json`，重启保持。
2. 关闭状态下启动、游玩、退出：`user://telemetry/` 不产生 pending；命令/事件不进入缓冲。
3. 开启状态下退出：`user://telemetry/pending/` 出现一份符合 §3 schema 的 JSON；再次启动联调（本地 `node website/tools/serve.mjs` + `telemetry_endpoint=http://127.0.0.1:4173/api/telemetry/session`）后文件被删除，`website/.data/telemetry/sessions/<日期>/` 出现对应文件与 `index.ndjson`。
4. 官网不可达时退出不被阻塞超过 3 秒，pending 保留，下次启动重试。
5. `node --test website/tests/telemetry.test.mjs` 全绿（校验、413、429、401、存储、health）。
6. `pwsh ./tools/test.ps1 -Suite telemetry` 与 `-Suite settings`、`-Suite ui_shell` 全绿。
7. `node tools/gen_static_docs.mjs --check` 通过。
8. `commands[].params` 只含 §3.4 白名单键的标量值：嵌套对象/数组/自由文本键不出现，字符串 ≤80，无参数的命令不写 `params` 字段。

## 7. 发布配置注入

- 发布流水线（`.github/workflows/release.yml`）在导出前用仓库变量 `SN_TELEMETRY_ENDPOINT`（可选 `SN_TELEMETRY_TOKEN`）覆盖 `config/config.json` 的对应字段；变量为空时保留仓库默认值（`https://steamnavigator.playthought.cn/api/telemetry/session`）。
- 运维侧用 `website/.env` 的 `SN_TELEMETRY_TOKEN` 与游戏发布变量保持一致即可启用令牌校验。

## 8. 已知边界

- 只覆盖正常退出；崩溃 / 强制结束 / `OS.kill` 兜底路径由「下次启动补传已落盘会话」覆盖，进程内未落盘的缓冲会丢失。
- 上传在退出流程内最多等 3 秒；慢网络下更多会话会留到下个启动周期。
- 不做客户端去重（同一 session_id 重复提交时服务端覆盖同名文件，幂等）。
- 官网管理/统计页面不在本期范围；数据目录结构与 `index.ndjson` 已为后续统计留好接口。
