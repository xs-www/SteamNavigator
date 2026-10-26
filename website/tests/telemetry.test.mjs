// @static-doc
// 作用：游玩数据接收端 Node 测试（node:test，零第三方依赖）：覆盖 health、合法/非法上传、存储与索引、限流、令牌、方法/路径错误与 180 天保留清理。
//
// ## 契约与约束
// - 契约：`docs/design/TELEMETRY.md` §3（上传协议）与 §4（官网接收端）、§6 验收第 5 条。
// - 只跑 `website/server/telemetry.mjs` 的导出，不依赖 nginx / Docker / 游戏端；每个用例用临时目录 + 端口 0。
// - 用例之间不共享数据目录；`test.after` 统一删除临时目录。
// - 断言状态码、响应体、落盘文件与 `index.ndjson` 摘要，避免只测“返回 2xx”。
//
// ## 重点逻辑
// ### 启动
// - `withServer()` 起随机端口，`finally` 里关闭；`logger: null` 保持测试输出干净（日志用例单独注入 logger）。
// ### 数据
// - `validPayload()` 是契约 §3 的完整载荷；`readSessionDirs` / `readIndex` / `sessionFiles` 读回落盘结果。
// ### 时间
// - 保留清理用 UTC 日期目录（今天 ± 若干天），不依赖本地时区。
// @end-static-doc

import { test, after } from "node:test";
import assert from "node:assert/strict";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import {
  SCHEMA_ID,
  cleanupOldSessions,
  startServer,
  validateSessionPayload,
} from "../server/telemetry.mjs";

const tempDirs = [];
const MILLIS_PER_DAY = 24 * 60 * 60 * 1000;

async function makeTempDir() {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), "sn-telemetry-test-"));
  tempDirs.push(dir);
  return dir;
}

async function withServer(options, fn) {
  const dataDir = options.dataDir ?? (await makeTempDir());
  const instance = await startServer({
    host: "127.0.0.1",
    port: 0,
    logger: null,
    ...options,
    dataDir,
  });
  try {
    return await fn({ ...instance, dataDir });
  } finally {
    await instance.close();
  }
}

function validPayload(overrides = {}) {
  return {
    schema: SCHEMA_ID,
    session_id: "20261027T081500Z-1a2b3c4d",
    started_at: "2026-10-27T08:15:00Z",
    ended_at: "2026-10-27T08:23:32Z",
    duration_seconds: 512,
    game_version: "0.2.0",
    framework_version: "0.1.0",
    content_schema: "2.0",
    locale: "zh_CN",
    os: "Windows",
    run: { has_run: true, seed: 12345, commands: 87, failed_commands: 3 },
    mods: [{ id: "core", version: "1.0.0" }],
    commands: [{ seq: 1, command: "trade.buy", ok: true, error_code: "", duration_ms: 2, game_time: 8 }],
    events: [{ event_type: "voyage.completed", game_time: 12, payload: { destination: "iron_harbor" } }],
    errors: [],
    ...overrides,
  };
}

function postSession(instance, payload, headers = {}) {
  const body = typeof payload === "string" ? payload : JSON.stringify(payload);
  return fetch(`${instance.url}/api/telemetry/session`, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body,
  });
}

function dayKey(offsetDays) {
  return new Date(Date.now() - offsetDays * MILLIS_PER_DAY).toISOString().slice(0, 10);
}

async function readSessionDirs(dataDir) {
  const sessionsRoot = path.join(dataDir, "sessions");
  let entries;
  try {
    entries = await fsp.readdir(sessionsRoot, { withFileTypes: true });
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
  return entries
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

async function readIndex(dataDir) {
  const lines = [];
  for (const day of await readSessionDirs(dataDir)) {
    try {
      const text = await fsp.readFile(path.join(dataDir, "sessions", day, "index.ndjson"), "utf8");
      for (const line of text.split("\n")) {
        if (line.trim()) lines.push(JSON.parse(line));
      }
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  }
  return lines;
}

async function sessionFiles(dataDir) {
  const files = [];
  for (const day of await readSessionDirs(dataDir)) {
    const dir = path.join(dataDir, "sessions", day);
    for (const name of await fsp.readdir(dir)) {
      if (name.endsWith(".json")) files.push(path.join(dir, name));
    }
  }
  return files;
}

after(async () => {
  await Promise.all(tempDirs.map((dir) => fsp.rm(dir, { recursive: true, force: true })));
});

test("GET /api/telemetry/health 返回 200 与固定服务信息", async () => {
  await withServer({}, async (instance) => {
    const response = await fetch(`${instance.url}/api/telemetry/health`);
    assert.equal(response.status, 200);
    assert.match(response.headers.get("content-type") || "", /application\/json/);
    assert.deepEqual(await response.json(), {
      ok: true,
      service: "sn-telemetry",
      schema: SCHEMA_ID,
    });
  });
});

test("合法 POST 返回 204，会话文件与 index.ndjson 摘要落盘", async () => {
  await withServer({}, async (instance) => {
    const payload = validPayload();
    const response = await postSession(instance, payload);
    assert.equal(response.status, 204);
    assert.equal(await response.text(), "");

    const dirs = await readSessionDirs(instance.dataDir);
    assert.equal(dirs.length, 1);
    assert.match(dirs[0], /^\d{4}-\d{2}-\d{2}$/);

    const savedPath = path.join(instance.dataDir, "sessions", dirs[0], `${payload.session_id}.json`);
    const saved = JSON.parse(await fsp.readFile(savedPath, "utf8"));
    assert.deepEqual(saved, payload);

    const index = await readIndex(instance.dataDir);
    assert.equal(index.length, 1);
    const summary = index[0];
    assert.equal(summary.session_id, payload.session_id);
    assert.equal(summary.game_version, "0.2.0");
    assert.equal(summary.duration_seconds, 512);
    assert.equal(summary.commands, 1);
    assert.equal(summary.errors, 0);
    assert.equal(summary.bytes, Buffer.byteLength(JSON.stringify(payload)));
    assert.ok(!Number.isNaN(Date.parse(summary.received_at)), "received_at 应为 ISO 时间");
    assert.match(summary.received_at, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
  });
});

test("重复 session_id 覆盖同名文件（幂等），索引各记一行", async () => {
  await withServer({}, async (instance) => {
    assert.equal((await postSession(instance, validPayload())).status, 204);
    assert.equal((await postSession(instance, validPayload())).status, 204);
    assert.equal((await sessionFiles(instance.dataDir)).length, 1);
    assert.equal((await readIndex(instance.dataDir)).length, 2);
  });
});

test("坏 JSON 返回 400，且不落盘", async () => {
  await withServer({}, async (instance) => {
    const response = await postSession(instance, '{"schema":');
    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { ok: false, error: "invalid_json" });
    assert.deepEqual(await sessionFiles(instance.dataDir), []);
  });
});

test("超过 512 KiB 的请求体返回 413，且不落盘", async () => {
  await withServer({}, async (instance) => {
    const big = validPayload({ pad: "x".repeat(600 * 1024) });
    const response = await postSession(instance, big);
    assert.equal(response.status, 413);
    assert.deepEqual(await response.json(), { ok: false, error: "payload_too_large" });
    assert.deepEqual(await sessionFiles(instance.dataDir), []);
  });
});

test("schema / session_id / 时间 / 数值不合法返回 422", async () => {
  await withServer({}, async (instance) => {
    const cases = [
      { name: "schema 不匹配", payload: validPayload({ schema: "sn.telemetry.session/2" }), field: "schema" },
      { name: "schema 缺失", payload: validPayload({ schema: undefined }), field: "schema" },
      { name: "session_id 太短", payload: validPayload({ session_id: "short" }), field: "session_id" },
      { name: "session_id 太长", payload: validPayload({ session_id: "a".repeat(65) }), field: "session_id" },
      { name: "session_id 含非法字符", payload: validPayload({ session_id: "abc def ghi" }), field: "session_id" },
      { name: "started_at 非 ISO", payload: validPayload({ started_at: "27/10/2026 08:15" }), field: "started_at" },
      { name: "ended_at 缺失", payload: validPayload({ ended_at: undefined }), field: "ended_at" },
      { name: "duration_seconds 为字符串", payload: validPayload({ duration_seconds: "512" }), field: "duration_seconds" },
      { name: "duration_seconds 为负", payload: validPayload({ duration_seconds: -1 }), field: "duration_seconds" },
    ];
    for (const testCase of cases) {
      const response = await postSession(instance, testCase.payload);
      assert.equal(response.status, 422, testCase.name);
      const body = await response.json();
      assert.equal(body.error, "invalid_payload", testCase.name);
      assert.equal(body.field, testCase.field, testCase.name);
    }
    assert.deepEqual(await sessionFiles(instance.dataDir), []);
  });
});

test("数组载荷与非 JSON Content-Type 返回 422", async () => {
  await withServer({}, async (instance) => {
    const arrayResponse = await postSession(instance, [validPayload()]);
    assert.equal(arrayResponse.status, 422);
    assert.deepEqual(await arrayResponse.json(), {
      ok: false,
      error: "invalid_payload",
      field: "body",
    });

    const textResponse = await postSession(instance, validPayload(), {
      "Content-Type": "text/plain",
    });
    assert.equal(textResponse.status, 422);
    assert.deepEqual(await textResponse.json(), {
      ok: false,
      error: "invalid_content_type",
      field: "Content-Type",
    });
  });
});

test("路径穿越 / 可疑 session_id 一律 422，不产生文件", async () => {
  await withServer({}, async (instance) => {
    const suspicious = [
      "../../evil",
      "..%2F..%2Fevil",
      "20261027T081500Z/../../evil",
      ".",
      "..",
      "a".repeat(64) + "/",
    ];
    for (const sessionId of suspicious) {
      const response = await postSession(instance, validPayload({ session_id: sessionId }));
      assert.equal(response.status, 422, sessionId);
      const body = await response.json();
      assert.equal(body.field, "session_id", sessionId);
    }
    assert.deepEqual(await sessionFiles(instance.dataDir), []);
    assert.ok(!(await fsp.readdir(instance.dataDir)).includes("evil"));
  });
});

test("方法不允许返回 405（session 只允许 POST，health 只允许 GET）", async () => {
  await withServer({}, async (instance) => {
    const getSession = await fetch(`${instance.url}/api/telemetry/session`);
    assert.equal(getSession.status, 405);
    assert.equal(getSession.headers.get("allow"), "POST");

    const postHealth = await fetch(`${instance.url}/api/telemetry/health`, { method: "POST" });
    assert.equal(postHealth.status, 405);
    assert.equal(postHealth.headers.get("allow"), "GET");

    const deleteHealth = await fetch(`${instance.url}/api/telemetry/health`, { method: "DELETE" });
    assert.equal(deleteHealth.status, 405);
  });
});

test("未知路径返回 404", async () => {
  await withServer({}, async (instance) => {
    const unknown = await fetch(`${instance.url}/api/telemetry/unknown`);
    assert.equal(unknown.status, 404);
    assert.deepEqual(await unknown.json(), { ok: false, error: "not_found" });

    const trailing = await postSession(
      { ...instance, url: `${instance.url}/api/telemetry/session/extra` },
      validPayload(),
    );
    assert.equal(trailing.status, 404);
  });
});

test("配置 SN_TELEMETRY_TOKEN 后：缺失/错误令牌 401，正确令牌 204", async () => {
  await withServer({ token: "s3cret-token" }, async (instance) => {
    assert.equal((await postSession(instance, validPayload())).status, 401);
    assert.equal((await postSession(instance, validPayload())).status, 401);
    assert.equal(
      (await postSession(instance, validPayload(), { "X-SN-Telemetry-Token": "wrong" })).status,
      401,
    );
    assert.equal(
      (await postSession(instance, validPayload(), { "X-SN-Telemetry-Token": "s3cret-token" })).status,
      204,
    );
    // health 不受令牌限制，便于容器 healthcheck。
    assert.equal((await fetch(`${instance.url}/api/telemetry/health`)).status, 200);
    assert.equal((await sessionFiles(instance.dataDir)).length, 1);
  });
});

test("同一来源每小时配额 429；X-Forwarded-For 首段独立计数", async () => {
  await withServer({ rateLimitPerHour: 2 }, async (instance) => {
    let counter = 0;
    const nextPayload = () => validPayload({ session_id: `quota-session-${(counter += 1)}` });
    assert.equal((await postSession(instance, nextPayload())).status, 204);
    assert.equal((await postSession(instance, nextPayload())).status, 204);
    const limited = await postSession(instance, nextPayload());
    assert.equal(limited.status, 429);
    assert.deepEqual(await limited.json(), { ok: false, error: "rate_limited" });

    // 另一个来源（X-Forwarded-For 第一段）不受前面计数影响。
    const otherIp = await postSession(instance, nextPayload(), {
      "X-Forwarded-For": "203.0.113.9, 10.0.0.1",
    });
    assert.equal(otherIp.status, 204);

    // 同一 X-Forwarded-For 第一段继续计数。
    const sameIp = await postSession(instance, nextPayload(), {
      "X-Forwarded-For": "203.0.113.9",
    });
    assert.equal(sameIp.status, 204);
    const sameIpLimited = await postSession(instance, nextPayload(), {
      "X-Forwarded-For": "203.0.113.9",
    });
    assert.equal(sameIpLimited.status, 429);

    assert.equal((await sessionFiles(instance.dataDir)).length, 4);
  });
});

test("cleanupOldSessions 只删除超过 180 天的日期目录，不误删", async () => {
  const dataDir = await makeTempDir();
  const sessionsRoot = path.join(dataDir, "sessions");
  const expired = dayKey(181);
  const fresh = dayKey(179);
  const today = dayKey(0);
  for (const day of [expired, fresh, today]) {
    await fsp.mkdir(path.join(sessionsRoot, day), { recursive: true });
    await fsp.writeFile(path.join(sessionsRoot, day, "session.json"), "{}", "utf8");
  }
  await fsp.mkdir(path.join(sessionsRoot, "not-a-date"), { recursive: true });
  await fsp.writeFile(path.join(sessionsRoot, "notes.txt"), "keep", "utf8");

  const result = await cleanupOldSessions({ dataDir });
  assert.deepEqual(result, { removed: 1, kept: 2 });

  const remaining = (await fsp.readdir(sessionsRoot, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
  assert.deepEqual(remaining, [fresh, "not-a-date", today].sort());
  assert.deepEqual(await fsp.readdir(path.join(sessionsRoot, fresh)), ["session.json"]);
  assert.equal(await fsp.readFile(path.join(sessionsRoot, "notes.txt"), "utf8"), "keep");

  // 重复调用幂等，不再删除任何目录。
  assert.deepEqual(await cleanupOldSessions({ dataDir }), { removed: 0, kept: 2 });
});

test("惰性清理：首次成功写入时触发，过期目录被删除、当天目录保留", async () => {
  await withServer({}, async (instance) => {
    const expired = dayKey(200);
    const expiredDir = path.join(instance.dataDir, "sessions", expired);
    await fsp.mkdir(expiredDir, { recursive: true });
    await fsp.writeFile(path.join(expiredDir, "old.json"), "{}", "utf8");

    const response = await postSession(instance, validPayload());
    assert.equal(response.status, 204);

    const dirs = await readSessionDirs(instance.dataDir);
    assert.deepEqual(dirs, [dayKey(0)]);
    assert.equal((await sessionFiles(instance.dataDir)).length, 1);
  });
});

test("数据目录不可写时返回 500", async () => {
  const dataDir = await makeTempDir();
  const blocker = path.join(dataDir, "blocker");
  await fsp.writeFile(blocker, "not a directory", "utf8");
  await withServer({ dataDir: blocker }, async (instance) => {
    const response = await postSession(instance, validPayload());
    assert.equal(response.status, 500);
    assert.deepEqual(await response.json(), { ok: false, error: "storage_error" });
  });
});

test("日志只含请求结果与字节数，不含来源 IP 或 session_id", async () => {
  const entries = [];
  await withServer({ logger: (entry) => entries.push(entry) }, async (instance) => {
    assert.equal((await postSession(instance, validPayload())).status, 204);
  });
  const text = JSON.stringify(entries);
  assert.ok(entries.some((entry) => entry.event === "telemetry.request" && entry.status === 204));
  const requestEntry = entries.find((entry) => entry.event === "telemetry.request" && entry.status === 204);
  assert.equal(typeof requestEntry.bytes, "number");
  assert.ok(requestEntry.bytes > 0);
  assert.ok(!text.includes("127.0.0.1"), "日志不得包含来源 IP");
  assert.ok(!text.includes("::1"), "日志不得包含来源 IP");
  assert.ok(!text.includes("20261027T081500Z-1a2b3c4d"), "日志不得包含 session_id");
  assert.ok(!text.toLowerCase().includes("x-sn-telemetry-token"), "日志不得包含请求头");
});

test("validateSessionPayload 只接受契约字段", () => {
  assert.equal(validateSessionPayload(validPayload()), null);
  assert.equal(validateSessionPayload(null), "body");
  assert.equal(validateSessionPayload("string"), "body");
  assert.equal(validateSessionPayload(validPayload({ schema: "other" })), "schema");
  assert.equal(validateSessionPayload(validPayload({ session_id: "bad id" })), "session_id");
  assert.equal(validateSessionPayload(validPayload({ started_at: "2026-10-27" })), "started_at");
  assert.equal(
    validateSessionPayload(validPayload({ duration_seconds: Number.NaN })),
    "duration_seconds",
  );
});
