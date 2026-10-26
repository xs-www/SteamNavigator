// @static-doc
// 作用：本地游玩数据看板（`tools/telemetry_dashboard.mjs`）的 Node 测试（node:test，零第三方依赖）：
// 覆盖页面/健康检查、列表摘要（索引与回退扫描）、日期/条数过滤、单条详情、404/405/422 与路径穿越拒绝、只读性。
//
// ## 契约与约束
// - 契约：`docs/design/TELEMETRY.md` §4/§5 的存储结构（`sessions/<YYYY-MM-DD>/<id>.json` + `index.ndjson`）。
// - 每个用例用临时目录 + 端口 0；只通过 HTTP 访问看板，不 mock 内部函数。
// - 断言列表排序（received_at 倒序）、limit 上限裁剪、日期过滤、未知/非法 session_id 的状态码，避免只测 200。
// - 测试结束删除临时目录，不依赖 Docker / nginx / 游戏端。
// @end-static-doc

import { test, after } from "node:test";
import assert from "node:assert/strict";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { startDashboard } from "../tools/telemetry_dashboard.mjs";

const tempDirs = [];
const DAY = "2026-10-26";

async function makeTempDir() {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), "sn-telemetry-dashboard-test-"));
  tempDirs.push(dir);
  return dir;
}

after(async () => {
  for (const dir of tempDirs) await fsp.rm(dir, { recursive: true, force: true });
});

async function withDashboard(dataDir, fn) {
  const instance = await startDashboard({ host: "127.0.0.1", port: 0, dataDir });
  try {
    return await fn(instance);
  } finally {
    await instance.close();
  }
}

function payload(overrides = {}) {
  return {
    schema: "sn.telemetry.session/1",
    session_id: "20261026T120000Z-aaaa0001",
    started_at: "2026-10-26T12:00:00Z",
    ended_at: "2026-10-26T12:10:00Z",
    duration_seconds: 600,
    game_version: "0.2.0",
    locale: "zh_CN",
    os: "Windows",
    run: { has_run: true, seed: 7, commands: 3, failed_commands: 1, port_id: "core:port_template/iron_harbor", money: 100 },
    commands: [{ seq: 1, command: "trade.buy", ok: true, error_code: "", duration_ms: 1, game_time: 1 }],
    events: [],
    errors: [{ level: "WARN", time: "2026-10-26T12:05:00Z", message: "w" }],
    ...overrides,
  };
}

async function seedSession(dataDir, overrides = {}, index = true, receivedAt = `${DAY}T12:00:00.000Z`) {
  const value = payload(overrides);
  const dayDir = path.join(dataDir, "sessions", DAY);
  await fsp.mkdir(dayDir, { recursive: true });
  await fsp.writeFile(path.join(dayDir, `${value.session_id}.json`), `${JSON.stringify(value)}\n`, "utf8");
  if (index) {
    const summary = {
      session_id: value.session_id,
      received_at: receivedAt,
      game_version: value.game_version,
      duration_seconds: value.duration_seconds,
      commands: value.commands.length,
      errors: value.errors.length,
      bytes: 240,
    };
    await fsp.appendFile(path.join(dayDir, "index.ndjson"), `${JSON.stringify(summary)}\n`, "utf8");
  }
  return value;
}

test("根路径返回内联看板页面，健康检查可用", async () => {
  const dataDir = await makeTempDir();
  await withDashboard(dataDir, async (instance) => {
    const page = await fetch(`${instance.url}/`);
    assert.equal(page.status, 200);
    assert.match(page.headers.get("content-type") || "", /text\/html/);
    const html = await page.text();
    assert.match(html, /游玩数据看板/);
    assert.match(html, /\/api\/sessions/);
    assert.match(page.headers.get("x-frame-options") || "", /DENY/);

    const health = await fetch(`${instance.url}/api/health`);
    assert.equal(health.status, 200);
    const body = await health.json();
    assert.equal(body.ok, true);
    assert.equal(body.tool, "sn-telemetry-dashboard");
    assert.equal(body.data_dir, dataDir);
  });
});

test("列表从 index.ndjson 读摘要并按 received_at 倒序", async () => {
  const dataDir = await makeTempDir();
  await seedSession(dataDir, {
    session_id: "20261026T120000Z-old00001",
    ended_at: "2026-10-26T12:00:00Z",
  }, true, `${DAY}T12:00:00.000Z`);
  await seedSession(dataDir, {
    session_id: "20261026T130000Z-new00001",
    ended_at: "2026-10-26T13:00:00Z",
    duration_seconds: 120,
    commands: [{ seq: 1, command: "voyage.start", ok: true }],
    errors: [],
  }, true, `${DAY}T13:00:00.000Z`);
  await withDashboard(dataDir, async (instance) => {
    const response = await fetch(`${instance.url}/api/sessions`);
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.ok, true);
    assert.equal(body.total, 2);
    assert.deepEqual(body.dates, [DAY]);
    assert.equal(body.sessions.length, 2);
    assert.equal(body.sessions[0].session_id, "20261026T130000Z-new00001");
    assert.equal(body.sessions[0].date, DAY);
    assert.equal(body.sessions[0].duration_seconds, 120);
    assert.equal(body.sessions[1].session_id, "20261026T120000Z-old00001");
    assert.equal(body.sessions[1].errors, 1);
  });
});

test("limit 裁剪结果，date 过滤日期", async () => {
  const dataDir = await makeTempDir();
  for (let index = 0; index < 3; index += 1) {
    await seedSession(dataDir, { session_id: `20261026T12000${index}Z-bulk000${index}` });
  }
  const otherDayDir = path.join(dataDir, "sessions", "2026-10-25");
  await fsp.mkdir(otherDayDir, { recursive: true });
  await fsp.writeFile(
    path.join(otherDayDir, "20261025T120000Z-other001.json"),
    `${JSON.stringify(payload({ session_id: "20261025T120000Z-other001" }))}\n`,
    "utf8",
  );
  await withDashboard(dataDir, async (instance) => {
    const limited = await (await fetch(`${instance.url}/api/sessions?limit=2`)).json();
    assert.equal(limited.total, 4);
    assert.equal(limited.sessions.length, 2);

    const filtered = await (await fetch(`${instance.url}/api/sessions?date=2026-10-25`)).json();
    assert.equal(filtered.total, 1);
    assert.equal(filtered.sessions.length, 1);
    assert.equal(filtered.sessions[0].date, "2026-10-25");
    assert.deepEqual(filtered.dates, ["2026-10-26", "2026-10-25"]);

    const capped = await (await fetch(`${instance.url}/api/sessions?limit=9999`)).json();
    assert.equal(capped.sessions.length, 4);
  });
});

test("索引缺失时回退扫描 JSON 文件摘要", async () => {
  const dataDir = await makeTempDir();
  await seedSession(dataDir, { session_id: "20261026T120000Z-fallback01" }, false);
  await withDashboard(dataDir, async (instance) => {
    const body = await (await fetch(`${instance.url}/api/sessions`)).json();
    assert.equal(body.total, 1);
    assert.equal(body.sessions[0].session_id, "20261026T120000Z-fallback01");
    assert.equal(body.sessions[0].game_version, "0.2.0");
    assert.ok(body.sessions[0].bytes > 0, "fallback summaries report file size");
  });
});

test("详情返回完整载荷；未知会话 404、非法 id 422", async () => {
  const dataDir = await makeTempDir();
  await seedSession(dataDir);
  await withDashboard(dataDir, async (instance) => {
    const ok = await fetch(`${instance.url}/api/sessions/20261026T120000Z-aaaa0001`);
    assert.equal(ok.status, 200);
    const body = await ok.json();
    assert.equal(body.ok, true);
    assert.equal(body.date, DAY);
    assert.equal(body.session.session_id, "20261026T120000Z-aaaa0001");
    assert.equal(Array.isArray(body.session.commands), true);

    const missing = await fetch(`${instance.url}/api/sessions/20261026T120000Z-missing01`);
    assert.equal(missing.status, 404);

    const invalid = await fetch(`${instance.url}/api/sessions/..%2F..%2Fetc%2Fpasswd`);
    assert.equal(invalid.status, 422);
  });
});

test("非 GET 405、未知路径 404，且看板不写数据目录", async () => {
  const dataDir = await makeTempDir();
  await seedSession(dataDir);
  const before = (await fsp.readdir(path.join(dataDir, "sessions", DAY))).sort();
  await withDashboard(dataDir, async (instance) => {
    const post = await fetch(`${instance.url}/api/sessions`, { method: "POST" });
    assert.equal(post.status, 405);
    assert.match(post.headers.get("allow") || "", /GET/);
    assert.equal((await fetch(`${instance.url}/nope`)).status, 404);
    for (let index = 0; index < 3; index += 1) {
      assert.equal((await fetch(`${instance.url}/api/sessions`)).status, 200);
    }
  });
  const afterList = (await fsp.readdir(path.join(dataDir, "sessions", DAY))).sort();
  assert.deepEqual(afterList, before, "the dashboard only reads the data directory");
});
