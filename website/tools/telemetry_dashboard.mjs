// @static-doc
// 作用：本地「游玩数据看板」：零依赖 Node 服务，在 127.0.0.1:8091 提供单页前端，只读展示遥测接收端落盘在
// `<dataDir>/sessions/<YYYY-MM-DD>/` 的会话 JSON（列表 + 单条完整载荷）。生产容器挂载同一个数据卷只读运行，
// 本地预览直接读 `website/.data/telemetry/`。
//
// ## 契约与约束
// - 契约：`docs/design/TELEMETRY.md` §4/§5（存储结构）与 `docs/design/WEBSITE.md` §10；本工具只读，绝不写数据目录。
// - 默认只绑定 `127.0.0.1`，不对外网暴露；生产 compose 也只发布到 `127.0.0.1:8091`，故不做登录（本地单人运维工具）。
// - 数据目录结构固定为 `<dataDir>/sessions/<YYYY-MM-DD>/<session_id>.json` 与同目录 `index.ndjson`；
//   索引优先，缺失时回退读 JSON（按 mtime/size 现场摘要），不迁移、不修补历史数据。
// - `session_id` 必须匹配 `^[A-Za-z0-9_-]{8,64}$`、日期必须匹配 `YYYY-MM-DD`，其余路径参数一律拒绝（防路径穿越）。
// - 只使用 Node 内置模块（node:http / node:fs / node:path / node:url），无构建步骤、无外部字体 / CDN。
//
// ## 重点逻辑
// ### 路由
// - `GET /` 单页看板；`GET /api/health` 健康检查；`GET /api/sessions?limit=&date=` 列表；
//   `GET /api/sessions/<session_id>` 单条完整载荷；其余路径 404，非 GET 405。
// ### 列表
// - 读 `sessions/` 下所有日期目录，优先解析每天的 `index.ndjson`；索引缺失时回退逐文件读取。
//   `limit` 默认 100、上限 500；`date` 精确过滤；结果按 `received_at` 倒序，并返回完整日期列表供前端筛选。
// ### 前端
// - 单文件内联 HTML/CSS/JS：日期筛选、条数上限、手动 / 10 秒自动刷新、指标卡、可点击表格与 JSON 详情面板。
// - 前端只调用相对路径 `/api/*`，不依赖站点域名、不带任何第三方脚本。
// @end-static-doc

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const TOOLS_DIR = path.dirname(fileURLToPath(import.meta.url));
const SITE_ROOT = path.resolve(TOOLS_DIR, "..");
const DEFAULT_DATA_DIR = path.join(SITE_ROOT, ".data", "telemetry");
const DEFAULT_HOST = "127.0.0.1";
const DEFAULT_PORT = 8091;
const DEFAULT_LIMIT = 100;
const MAX_LIMIT = 500;
const SESSION_ID_PATTERN = /^[A-Za-z0-9_-]{8,64}$/;
const DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const SESSIONS_PATH = "/api/sessions";

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseLimit(raw) {
  const value = Number.parseInt(String(raw ?? ""), 10);
  if (!Number.isFinite(value) || value <= 0) return DEFAULT_LIMIT;
  return Math.min(value, MAX_LIMIT);
}

function normalizeDay(raw) {
  const value = String(raw ?? "").trim();
  return DAY_PATTERN.test(value) ? value : "";
}

function countCommands(payload) {
  if (Array.isArray(payload.commands)) return payload.commands.length;
  if (isPlainObject(payload.run) && Number.isFinite(payload.run.commands)) return payload.run.commands;
  return 0;
}

function summarizePayload(payload, extra) {
  const run = isPlainObject(payload.run) ? payload.run : {};
  return {
    session_id: typeof payload.session_id === "string" ? payload.session_id : "",
    received_at: extra.received_at,
    ended_at: typeof payload.ended_at === "string" ? payload.ended_at : "",
    game_version: typeof payload.game_version === "string" ? payload.game_version : "",
    framework_version: typeof payload.framework_version === "string" ? payload.framework_version : "",
    locale: typeof payload.locale === "string" ? payload.locale : "",
    os: typeof payload.os === "string" ? payload.os : "",
    duration_seconds: Number.isFinite(payload.duration_seconds) ? payload.duration_seconds : 0,
    commands: countCommands(payload),
    failed_commands: Number.isFinite(run.failed_commands) ? run.failed_commands : 0,
    events: Array.isArray(payload.events) ? payload.events.length : 0,
    errors: Array.isArray(payload.errors) ? payload.errors.length : 0,
    bytes: Number.isFinite(extra.bytes) ? extra.bytes : 0,
    has_run: run.has_run === true,
    seed: run.seed ?? null,
    port_id: typeof run.port_id === "string" ? run.port_id : "",
    money: run.money ?? null,
    victory: run.victory === true,
    date: extra.date,
  };
}

async function readDayIndex(dayDir) {
  try {
    const text = await fs.promises.readFile(path.join(dayDir, "index.ndjson"), "utf8");
    const rows = [];
    for (const line of text.split("\n")) {
      if (!line.trim()) continue;
      try {
        const value = JSON.parse(line);
        if (isPlainObject(value) && typeof value.session_id === "string") rows.push(value);
      } catch {
        // 索引行损坏时跳过，不阻塞看板。
      }
    }
    return rows;
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

function summaryFromIndexRow(row, day) {
  return {
    session_id: row.session_id,
    received_at: typeof row.received_at === "string" ? row.received_at : "",
    ended_at: typeof row.ended_at === "string" ? row.ended_at : "",
    game_version: typeof row.game_version === "string" ? row.game_version : "",
    framework_version: typeof row.framework_version === "string" ? row.framework_version : "",
    locale: typeof row.locale === "string" ? row.locale : "",
    os: typeof row.os === "string" ? row.os : "",
    duration_seconds: Number.isFinite(row.duration_seconds) ? row.duration_seconds : 0,
    commands: Number.isFinite(row.commands) ? row.commands : 0,
    failed_commands: Number.isFinite(row.failed_commands) ? row.failed_commands : 0,
    events: Number.isFinite(row.events) ? row.events : 0,
    errors: Number.isFinite(row.errors) ? row.errors : 0,
    bytes: Number.isFinite(row.bytes) ? row.bytes : 0,
    has_run: row.has_run === true,
    seed: row.seed ?? null,
    port_id: typeof row.port_id === "string" ? row.port_id : "",
    money: row.money ?? null,
    victory: row.victory === true,
    date: day,
  };
}

async function readDaySummaries(day) {
  const dayDir = path.join(day.dir, day.name);
  const indexed = await readDayIndex(dayDir);
  if (indexed !== null) {
    // 索引行本身就是摘要（commands / errors 是计数而非数组），不能再套完整载荷的摘要函数。
    return indexed.map((row) => summaryFromIndexRow(row, day.name));
  }
  const files = await fs.promises.readdir(dayDir).catch((error) => {
    if (error.code === "ENOENT") return [];
    throw error;
  });
  const rows = [];
  for (const name of files) {
    if (!name.endsWith(".json")) continue;
    const full = path.join(dayDir, name);
    let payload = {};
    let stat = null;
    try {
      const [text, fileStat] = await Promise.all([fs.promises.readFile(full, "utf8"), fs.promises.stat(full)]);
      stat = fileStat;
      payload = JSON.parse(text);
    } catch {
      continue;
    }
    if (!isPlainObject(payload)) continue;
    if (typeof payload.session_id !== "string") payload.session_id = name.replace(/\.json$/, "");
    rows.push(
      summarizePayload(payload, {
        received_at: stat ? stat.mtime.toISOString() : "",
        bytes: stat ? stat.size : 0,
        date: day.name,
      }),
    );
  }
  return rows;
}

async function listDays(dataDir) {
  const sessionsRoot = path.join(dataDir, "sessions");
  let entries;
  try {
    entries = await fs.promises.readdir(sessionsRoot, { withFileTypes: true });
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
  return entries
    .filter((entry) => entry.isDirectory() && DAY_PATTERN.test(entry.name))
    .map((entry) => ({ name: entry.name, dir: sessionsRoot }))
    .sort((a, b) => b.name.localeCompare(a.name));
}

async function collectSessions(dataDir, options = {}) {
  const limit = parseLimit(options.limit);
  const date = normalizeDay(options.date);
  const days = await listDays(dataDir);
  const dates = days.map((day) => day.name);
  const sessions = [];
  let total = 0;
  for (const day of days) {
    if (date && day.name !== date) continue;
    const summaries = await readDaySummaries(day);
    total += summaries.length;
    for (const summary of summaries) sessions.push(summary);
  }
  sessions.sort((a, b) => String(b.received_at).localeCompare(String(a.received_at)));
  return { dates, total, count: Math.min(total, limit), sessions: sessions.slice(0, limit) };
}

async function readSession(dataDir, sessionId, options = {}) {
  const date = normalizeDay(options.date);
  const days = await listDays(dataDir);
  for (const day of days) {
    if (date && day.name !== date) continue;
    const full = path.join(day.dir, day.name, `${sessionId}.json`);
    try {
      const [text, stat] = await Promise.all([fs.promises.readFile(full, "utf8"), fs.promises.stat(full)]);
      const payload = JSON.parse(text);
      if (!isPlainObject(payload)) continue;
      return { ok: true, date: day.name, received_at: stat.mtime.toISOString(), session: payload };
    } catch (error) {
      if (error.code === "ENOENT") continue;
      throw error;
    }
  }
  return null;
}

function sendJson(res, statusCode, payload, extraHeaders = {}) {
  if (res.writableEnded || res.destroyed) return;
  const body = Buffer.from(JSON.stringify(payload), "utf8");
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": body.length,
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    ...extraHeaders,
  });
  res.end(body);
}

function sendHtml(res, html) {
  const body = Buffer.from(html, "utf8");
  res.writeHead(200, {
    "Content-Type": "text/html; charset=utf-8",
    "Content-Length": body.length,
    "Cache-Control": "no-store",
    "Referrer-Policy": "no-referrer",
    "X-Frame-Options": "DENY",
    "X-Content-Type-Options": "nosniff",
  });
  res.end(body);
}

/**
 * 创建看板请求处理器（测试与本地/容器共用）。
 *
 * @param {object} [options]
 * @param {string} [options.dataDir] 遥测数据根目录（包含 `sessions/`）
 * @returns {(req: import("node:http").IncomingMessage, res: import("node:http").ServerResponse) => Promise<void>}
 */
export function createDashboardHandler(options = {}) {
  const dataDir = path.resolve(options.dataDir ?? DEFAULT_DATA_DIR);

  return async function dashboardHandler(req, res) {
    try {
      let pathname;
      try {
        pathname = new URL(req.url || "/", "http://localhost").pathname;
      } catch {
        sendJson(res, 400, { ok: false, error: "invalid_url" });
        return;
      }

      if (pathname !== "/" && req.method !== "GET" && req.method !== "HEAD") {
        sendJson(res, 405, { ok: false, error: "method_not_allowed" }, { Allow: "GET, HEAD" });
        return;
      }

      if (pathname === "/") {
        sendHtml(res, DASHBOARD_HTML);
        return;
      }

      if (pathname === "/api/health") {
        sendJson(res, 200, { ok: true, tool: "sn-telemetry-dashboard", data_dir: dataDir });
        return;
      }

      if (pathname === SESSIONS_PATH) {
        const url = new URL(req.url || "/", "http://localhost");
        const result = await collectSessions(dataDir, {
          limit: url.searchParams.get("limit"),
          date: url.searchParams.get("date"),
        });
        sendJson(res, 200, { ok: true, data_dir: dataDir, ...result });
        return;
      }

      if (pathname.startsWith(`${SESSIONS_PATH}/`)) {
        const rawId = decodeURIComponent(pathname.slice(SESSIONS_PATH.length + 1));
        if (!SESSION_ID_PATTERN.test(rawId)) {
          sendJson(res, 422, { ok: false, error: "invalid_session_id" });
          return;
        }
        const url = new URL(req.url || "/", "http://localhost");
        const session = await readSession(dataDir, rawId, { date: url.searchParams.get("date") });
        if (session === null) {
          sendJson(res, 404, { ok: false, error: "not_found" });
          return;
        }
        sendJson(res, 200, session);
        return;
      }

      sendJson(res, 404, { ok: false, error: "not_found" });
    } catch (error) {
      sendJson(res, 500, { ok: false, error: "internal_error", message: error.message });
    }
  };
}

/**
 * 启动本地看板。
 *
 * @param {object} [options]
 * @param {string} [options.dataDir] 数据目录
 * @param {string} [options.host] 监听地址（默认 127.0.0.1）
 * @param {number} [options.port] 监听端口（默认 8091；0 = 随机端口，测试用）
 * @returns {Promise<{server: import("node:http").Server, host: string, port: number, url: string, dataDir: string, close: () => Promise<void>}>}
 */
export async function startDashboard(options = {}) {
  const dataDir = path.resolve(options.dataDir ?? DEFAULT_DATA_DIR);
  const host = options.host ?? DEFAULT_HOST;
  const requestedPort = Number(options.port ?? DEFAULT_PORT);
  const port = Number.isInteger(requestedPort) && requestedPort >= 0 ? requestedPort : DEFAULT_PORT;
  const handler = options.handler ?? createDashboardHandler({ ...options, dataDir });
  const server = http.createServer((req, res) => {
    Promise.resolve(handler(req, res)).catch((error) => {
      try {
        if (!res.headersSent && !res.writableEnded) {
          sendJson(res, 500, { ok: false, error: "internal_error" });
        } else if (!res.writableEnded) {
          res.end();
        }
      } catch {
        // 连接已断开，忽略。
      }
      console.error(`sn-telemetry-dashboard handler failure: ${error.message}`);
    });
  });

  await new Promise((resolve, reject) => {
    const onError = (error) => {
      server.off("listening", onListening);
      reject(error);
    };
    const onListening = () => {
      server.off("error", onError);
      resolve();
    };
    server.once("error", onError);
    server.once("listening", onListening);
    server.listen(port, host);
  });

  const address = server.address();
  const actualPort = address && typeof address === "object" ? address.port : port;
  const displayHost = host === "0.0.0.0" || host === "::" ? "127.0.0.1" : host;
  return {
    server,
    host,
    port: actualPort,
    url: `http://${displayHost}:${actualPort}`,
    dataDir,
    close() {
      return new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
        if (typeof server.closeAllConnections === "function") server.closeAllConnections();
      });
    },
  };
}

function parseArgs(argv) {
  const result = { dataDir: DEFAULT_DATA_DIR, host: DEFAULT_HOST, port: DEFAULT_PORT };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--data-dir") result.dataDir = path.resolve(argv[++index] ?? ".");
    else if (arg === "--host") result.host = String(argv[++index] ?? DEFAULT_HOST);
    else if (arg === "--port") result.port = Number(argv[++index] ?? DEFAULT_PORT);
    else if (arg === "--help" || arg === "-h") result.help = true;
  }
  return result;
}

const DASHBOARD_HTML = `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>游玩数据看板 · Steam Navigator</title>
<style>
:root{--ink:#050f11;--petrol:#082025;--panel:#0d2f34;--raise:#144347;--brass:#c59a54;--brass-light:#e7cf9a;--paper:#d9c9a6;--text:#ece1c5;--muted:#9fb0a8;--good:#7fb79a;--warn:#a4553f;--line:rgba(197,154,84,.24)}
*{box-sizing:border-box}
body{margin:0;background:radial-gradient(1200px 600px at 20% 0%,#0b252a 0%,var(--ink) 60%);color:var(--text);font:14px/1.6 "Segoe UI","Microsoft YaHei",system-ui,sans-serif;min-height:100vh}
header{display:flex;flex-wrap:wrap;gap:12px;align-items:baseline;padding:22px 28px 10px;border-bottom:1px solid var(--line)}
h1{font-size:20px;letter-spacing:.12em;font-weight:500;margin:0;color:var(--brass-light)}
.sub{color:var(--muted);font-size:12px;letter-spacing:.06em}
main{padding:18px 28px 60px;max-width:1500px;margin:0 auto}
.toolbar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-bottom:16px}
button,select{background:var(--panel);color:var(--text);border:1px solid var(--line);border-radius:2px;padding:7px 12px;font:inherit;cursor:pointer}
button:hover{border-color:var(--brass);color:var(--brass-light)}
button.primary{border-color:var(--brass);color:var(--brass-light)}
label.toggle{display:flex;gap:6px;align-items:center;color:var(--muted);font-size:12px;cursor:pointer}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin-bottom:16px}
.card{border:1px solid var(--line);background:linear-gradient(180deg,var(--panel),rgba(8,32,37,.7));padding:12px 14px}
.card .k{font-size:11px;letter-spacing:.14em;color:var(--muted);text-transform:uppercase}
.card .v{font-size:22px;color:var(--brass-light);margin-top:2px}
.layout{display:grid;grid-template-columns:minmax(0,1.5fr) minmax(0,1fr);gap:16px}
@media (max-width:1100px){.layout{grid-template-columns:1fr}}
.panel{border:1px solid var(--line);background:rgba(8,32,37,.62)}
.panel h2{margin:0;padding:10px 14px;border-bottom:1px solid var(--line);font-size:12px;letter-spacing:.16em;color:var(--brass);font-weight:500}
.table-wrap{max-height:64vh;overflow:auto}
table{width:100%;border-collapse:collapse;font-size:13px}
th,td{text-align:left;padding:8px 10px;border-bottom:1px solid rgba(197,154,84,.12);white-space:nowrap}
th{position:sticky;top:0;background:var(--petrol);color:var(--muted);font-weight:500;font-size:11px;letter-spacing:.1em}
tbody tr{cursor:pointer}
tbody tr:hover{background:var(--raise)}
tbody tr.active{background:rgba(197,154,84,.16)}
td.num{text-align:right;font-variant-numeric:tabular-nums}
td.err{color:var(--warn)}
td.ok{color:var(--good)}
.empty{padding:24px;color:var(--muted);text-align:center}
#detail{padding:12px 14px}
.meta{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:6px 14px;margin-bottom:10px}
.meta div{font-size:12px;color:var(--muted)}
.meta b{display:block;color:var(--text);font-weight:500;font-size:13px;word-break:break-all}
pre{margin:0;padding:10px;background:var(--ink);border:1px solid var(--line);max-height:48vh;overflow:auto;font:12px/1.55 "Cascadia Mono",Consolas,monospace;color:var(--paper);white-space:pre-wrap;word-break:break-word}
#status{padding:8px 0;min-height:20px;color:var(--muted);font-size:12px}
#status.error{color:var(--warn)}
.timestamp{color:var(--muted);font-size:12px}
</style>
</head>
<body>
<header>
  <h1>游玩数据看板</h1>
  <span class="sub">本地只读 · 数据来自遥测接收端 sessions/</span>
</header>
<main>
  <div class="toolbar">
    <select id="date"><option value="">全部日期</option></select>
    <select id="limit">
      <option value="50">最近 50 条</option>
      <option value="100" selected>最近 100 条</option>
      <option value="200">最近 200 条</option>
      <option value="500">最近 500 条</option>
    </select>
    <button id="refresh" class="primary">刷新</button>
    <label class="toggle"><input type="checkbox" id="auto"> 10 秒自动刷新</label>
    <span class="timestamp" id="loaded"></span>
  </div>
  <div id="status"></div>
  <div class="cards">
    <div class="card"><div class="k">会话总数</div><div class="v" id="m-total">0</div></div>
    <div class="card"><div class="k">当前显示</div><div class="v" id="m-count">0</div></div>
    <div class="card"><div class="k">数据日期</div><div class="v" id="m-days">0</div></div>
    <div class="card"><div class="k">命令总数</div><div class="v" id="m-commands">0</div></div>
    <div class="card"><div class="k">错误总数</div><div class="v" id="m-errors">0</div></div>
  </div>
  <div class="layout">
    <section class="panel">
      <h2>会话列表</h2>
      <div class="table-wrap">
        <table>
          <thead><tr><th>接收时间</th><th>版本</th><th class="num">时长</th><th class="num">命令</th><th class="num">错误</th><th class="num">字节</th><th>平台</th></tr></thead>
          <tbody id="rows"></tbody>
        </table>
        <div class="empty" id="empty" hidden>暂无数据：勾选设置里的「允许上传数据」后退出游戏，或先启动本地接收端。</div>
      </div>
    </section>
    <section class="panel">
      <h2>会话详情</h2>
      <div id="detail"><div class="empty">点击左侧任意一行查看完整载荷</div></div>
    </section>
  </div>
</main>
<script>
(function () {
  var state = { sessions: [], dates: [], activeId: "", timer: 0 };
  var $ = function (id) { return document.getElementById(id); };

  function fmtDuration(seconds) {
    var s = Math.max(0, Math.round(Number(seconds) || 0));
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var r = s % 60;
    return (h ? h + "h" : "") + (m ? m + "m" : "") + r + "s";
  }
  function fmtTime(iso) {
    if (!iso) return "—";
    var d = new Date(iso);
    if (isNaN(d.getTime())) return iso;
    return d.toLocaleString("zh-CN", { hour12: false });
  }
  function fmtBytes(bytes) {
    var n = Number(bytes) || 0;
    if (n < 1024) return n + " B";
    if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB";
    return (n / 1024 / 1024).toFixed(2) + " MB";
  }
  function setStatus(text, isError) {
    $("status").textContent = text || "";
    $("status").className = isError ? "error" : "";
  }
  function setText(id, value) { $(id).textContent = String(value); }

  function fetchJson(url) {
    return fetch(url, { cache: "no-store" }).then(function (res) {
      return res.json().then(function (body) {
        if (!res.ok || body.ok === false) throw new Error((body && body.error) || ("HTTP " + res.status));
        return body;
      });
    });
  }

  function renderCards(total, count, dates, sessions) {
    var commands = 0;
    var errors = 0;
    sessions.forEach(function (s) { commands += Number(s.commands) || 0; errors += Number(s.errors) || 0; });
    setText("m-total", total);
    setText("m-count", count);
    setText("m-days", dates.length);
    setText("m-commands", commands);
    setText("m-errors", errors);
  }

  function renderDateOptions(dates) {
    var select = $("date");
    var current = select.value;
    var html = '<option value="">全部日期</option>';
    dates.forEach(function (day) { html += '<option value="' + day + '">' + day + "</option>"; });
    select.innerHTML = html;
    if (current && dates.indexOf(current) >= 0) select.value = current;
  }

  function renderRows(sessions) {
    var tbody = $("rows");
    tbody.innerHTML = "";
    sessions.forEach(function (s) {
      var tr = document.createElement("tr");
      tr.dataset.id = s.session_id;
      if (s.session_id === state.activeId) tr.className = "active";
      var cells = [
        fmtTime(s.received_at),
        s.game_version || "—",
        fmtDuration(s.duration_seconds),
        String(s.commands || 0),
        String(s.errors || 0),
        fmtBytes(s.bytes),
        s.os || "—"
      ];
      cells.forEach(function (text, index) {
        var td = document.createElement("td");
        td.textContent = text;
        if (index >= 2 && index <= 5) td.className = "num";
        if (index === 4 && Number(s.errors) > 0) td.className = "num err";
        tr.appendChild(td);
      });
      tr.addEventListener("click", function () { loadDetail(s.session_id); });
      tbody.appendChild(tr);
    });
    $("empty").hidden = sessions.length > 0;
  }

  function renderDetail(body) {
    var session = body.session || {};
    var run = session.run || {};
    var detail = $("detail");
    detail.innerHTML = "";
    var meta = document.createElement("div");
    meta.className = "meta";
    [
      ["会话", session.session_id || "—"],
      ["接收时间", fmtTime(body.received_at)],
      ["结束时间", fmtTime(session.ended_at)],
      ["时长", fmtDuration(session.duration_seconds)],
      ["语言 / 平台", (session.locale || "—") + " / " + (session.os || "—")],
      ["是否开局", run.has_run ? "是" : "否"],
      ["种子", run.seed == null ? "—" : String(run.seed)],
      ["当前港", run.port_id || "—"],
      ["金币", run.money == null ? "—" : String(run.money)],
      ["命令 / 失败", String(run.commands || 0) + " / " + String(run.failed_commands || 0)],
      ["事件", String((session.events || []).length)],
      ["错误", String((session.errors || []).length)]
    ].forEach(function (pair) {
      var div = document.createElement("div");
      var label = document.createElement("span");
      label.textContent = pair[0];
      var value = document.createElement("b");
      value.textContent = pair[1];
      div.appendChild(label);
      div.appendChild(value);
      meta.appendChild(div);
    });
    detail.appendChild(meta);
    var pre = document.createElement("pre");
    pre.textContent = JSON.stringify(body.session, null, 2);
    detail.appendChild(pre);
  }

  function loadDetail(sessionId) {
    state.activeId = sessionId;
    renderRows(state.sessions);
    fetchJson("/api/sessions/" + encodeURIComponent(sessionId))
      .then(renderDetail)
      .catch(function (error) { setStatus("读取会话失败：" + error.message, true); });
  }

  function load() {
    var date = $("date").value;
    var limit = $("limit").value;
    var url = "/api/sessions?limit=" + encodeURIComponent(limit) + (date ? "&date=" + encodeURIComponent(date) : "");
    setStatus("加载中…", false);
    fetchJson(url)
      .then(function (body) {
        state.sessions = body.sessions || [];
        state.dates = body.dates || [];
        renderDateOptions(state.dates);
        renderRows(state.sessions);
        renderCards(body.total || 0, state.sessions.length, state.dates, state.sessions);
        $("loaded").textContent = "数据目录：" + (body.data_dir || "—") + " · " + fmtTime(new Date().toISOString());
        if (state.activeId && !state.sessions.some(function (s) { return s.session_id === state.activeId; })) {
          state.activeId = "";
          $("detail").innerHTML = '<div class="empty">点击左侧任意一行查看完整载荷</div>';
        }
        setStatus(state.sessions.length ? "" : "数据目录里还没有会话。", false);
      })
      .catch(function (error) { setStatus("读取失败：" + error.message, true); });
  }

  $("refresh").addEventListener("click", load);
  $("date").addEventListener("change", load);
  $("limit").addEventListener("change", load);
  $("auto").addEventListener("change", function () {
    if (state.timer) { clearInterval(state.timer); state.timer = 0; }
    if ($("auto").checked) state.timer = setInterval(load, 10000);
  });
  load();
})();
</script>
</body>
</html>`;

const invokedPath = process.argv[1] ? path.resolve(process.argv[1]) : "";
const modulePath = fileURLToPath(import.meta.url);
if (invokedPath === path.resolve(modulePath)) {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log("Usage: node website/tools/telemetry_dashboard.mjs [--data-dir <dir>] [--host 127.0.0.1] [--port 8091]");
    process.exit(0);
  }
  startDashboard(args)
    .then((instance) => {
      console.log(`sn-telemetry-dashboard: ${instance.url}`);
      console.log(`data dir: ${instance.dataDir}`);
      const shutdown = (signal) => {
        instance
          .close()
          .then(() => process.exit(0))
          .catch((error) => {
            console.error(`shutdown failed: ${error.message}`);
            process.exit(1);
          });
      };
      process.on("SIGTERM", () => shutdown("SIGTERM"));
      process.on("SIGINT", () => shutdown("SIGINT"));
    })
    .catch((error) => {
      console.error(`sn-telemetry-dashboard failed to start: ${error.message}`);
      process.exitCode = 1;
    });
}
