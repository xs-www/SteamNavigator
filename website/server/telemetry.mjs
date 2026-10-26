// @static-doc
// 作用：游玩数据（telemetry）接收端：校验客户端上传的会话 JSON、按来源限流、写入会话文件与索引，并做 180 天保留清理。
//
// ## 契约与约束
// - 唯一契约：`docs/design/TELEMETRY.md` §3「上传协议」与 §4「官网接收端」；不改 schema、路由、状态码与存储路径。
// - 零第三方依赖：只用 Node 内置模块（node:http / node:fs / node:path / node:url / node:crypto），要求 Node >= 18。
// - 隐私：进程日志只记请求结果与字节数，不记录客户端 IP、请求头或载荷内容；IP 只存在内存限流表里，进程退出即消失。
// - 限流是单进程内存表；多副本部署时每个副本各自计数（`SN_TELEMETRY_TOKEN` 与实例数一起决定实际配额）。
// - TLS / CORS / 请求体上限由前置 nginx 负责（`website/deploy/nginx.conf`）；本模块按 512 KiB 再校验一次。
//
// ## 导出
// - `createTelemetryHandler(options)`：返回 `async (req, res)`，供 `tools/serve.mjs` 与测试复用。
// - `startServer(options)`：监听端口并返回 `{ server, handler, host, port, url, dataDir, close }`。
// - `cleanupOldSessions(options)`：180 天保留清理，测试与运维可单独调用。
// - `validateSessionPayload(payload)`：校验函数，返回 `null`（合法）或第一个非法字段名。
//
// ## 重点逻辑
// ### 路由与状态码
// - `GET /api/telemetry/health` → `200 {"ok":true,"service":"sn-telemetry","schema":"sn.telemetry.session/1"}`。
// - `POST /api/telemetry/session` → 校验通过后 `204`（无响应体）；`400` 坏 JSON；`401` 令牌不匹配；
//   `413` 超过 `maxBodyBytes`；`422` 字段或 Content-Type 不合法；`429` 超过每小时配额；
//   `405` 方法不允许；`404` 未知路径；`500` 落盘失败（客户端下次启动重试）。
// ### 校验
// - JSON 对象 + `schema` 精确等于 `sn.telemetry.session/1` + `session_id` 匹配 `^[A-Za-z0-9_-]{8,64}$`
//   （该正则同时是路径穿越防线：文件名只取自 session_id）+ 起止时间为 ISO-8601 字符串 +
//   `duration_seconds` 为有限数值。其它字段（commands / events / errors / run / mods）不校验内容，只做摘要计数。
// ### 存储
// - `<dataDir>/sessions/<接收日期 YYYY-MM-DD>/<session_id>.json`：紧凑 JSON，先写临时文件再 rename，同名覆盖（幂等）。
// - 同目录 `index.ndjson`：每行一条摘要（session_id / received_at / game_version / duration_seconds /
//   commands / errors / bytes）；append 用 Promise 队列串行，避免多请求并发时行交错。
// ### 限流
// - 来源键取 `X-Forwarded-For` 第一段（nginx 写入），否则 socket 地址；每小时 120 次，滑动窗口按桶重置。
// - 限流表超过 4096 条时顺手清理过期桶，避免长期运行内存增长。
// ### 保留清理
// - 每次成功写入后检查，最多每小时触发一次；只删除 `sessions/` 下匹配 `YYYY-MM-DD` 且早于
//   （今天 UTC - 180 天）的目录，非日期目录/文件一律不动。
// @end-static-doc

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

export const SERVICE_NAME = "sn-telemetry";
export const SCHEMA_ID = "sn.telemetry.session/1";
export const SESSION_ID_PATTERN = /^[A-Za-z0-9_-]{8,64}$/;

const DEFAULT_PORT = 8090;
const DEFAULT_DATA_DIR = "/data";
const DEFAULT_MAX_BODY_BYTES = 512 * 1024;
const DEFAULT_RATE_LIMIT_PER_HOUR = 120;
const DEFAULT_RETENTION_DAYS = 180;
const DEFAULT_CLEANUP_INTERVAL_MS = 60 * 60 * 1000;
const RATE_WINDOW_MS = 60 * 60 * 1000;
const RATE_BUCKET_PRUNE_THRESHOLD = 4096;
const HEALTH_PATH = "/api/telemetry/health";
const SESSION_PATH = "/api/telemetry/session";
const DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const ISO_TIMESTAMP_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/i;
const JSON_CONTENT_TYPE_PATTERN = /^application\/json(?:\s*;|$)/i;
const MILLIS_PER_DAY = 24 * 60 * 60 * 1000;

/** 超限请求体：抛出后由 handler 回 413。 */
class PayloadTooLargeError extends Error {
  constructor(total) {
    super("payload too large");
    this.name = "PayloadTooLargeError";
    this.total = total;
  }
}

/** 读请求体失败（客户端中断 / socket 错误），由 handler 回 400。 */
class BodyReadError extends Error {
  constructor(message) {
    super(message);
    this.name = "BodyReadError";
  }
}

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isFiniteNumber(value) {
  return typeof value === "number" && Number.isFinite(value);
}

function isIsoTimestamp(value) {
  return (
    typeof value === "string" &&
    ISO_TIMESTAMP_PATTERN.test(value) &&
    !Number.isNaN(Date.parse(value))
  );
}

/** UTC 日期键（YYYY-MM-DD），用于 sessions/ 子目录名。 */
function utcDayKey(date) {
  return date.toISOString().slice(0, 10);
}

/** 取 UTC 当天零点，避免保留边界随请求时刻漂移。 */
function startOfUtcDay(date) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function countCommands(payload) {
  if (Array.isArray(payload.commands)) return payload.commands.length;
  if (isPlainObject(payload.run) && isFiniteNumber(payload.run.commands)) return payload.run.commands;
  return 0;
}

/**
 * 校验会话载荷，返回第一个非法字段名；合法返回 null。
 * 只校验契约 §3 列出的字段，未知字段不拒绝（便于客户端向后兼容）。
 */
export function validateSessionPayload(payload) {
  if (!isPlainObject(payload)) return "body";
  if (payload.schema !== SCHEMA_ID) return "schema";
  if (typeof payload.session_id !== "string" || !SESSION_ID_PATTERN.test(payload.session_id)) {
    return "session_id";
  }
  if (!isIsoTimestamp(payload.started_at)) return "started_at";
  if (!isIsoTimestamp(payload.ended_at)) return "ended_at";
  if (!isFiniteNumber(payload.duration_seconds) || payload.duration_seconds < 0) {
    return "duration_seconds";
  }
  return null;
}

/** 常量时间比较共享令牌，避免长度泄漏以外的时序差异。 */
function tokenMatches(provided, expected) {
  if (typeof provided !== "string") return false;
  const a = Buffer.from(provided, "utf8");
  const b = Buffer.from(expected, "utf8");
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

/** 取限流键：nginx 写入的 X-Forwarded-For 第一段优先，否则 socket 地址。 */
function clientRateKey(req) {
  const forwarded = req.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.length > 0) {
    const first = forwarded.split(",")[0].trim();
    if (first) return first;
  }
  const address = req.socket && req.socket.remoteAddress;
  return address || "unknown";
}

/** 内存限流表：按小时桶计数，不持久化、不写日志。 */
function createRateLimiter(limitPerHour) {
  const buckets = new Map();
  return {
    allow(key, nowMs) {
      if (!(limitPerHour > 0)) return true;
      const bucket = buckets.get(key);
      if (!bucket || nowMs >= bucket.resetAt) {
        buckets.set(key, { count: 1, resetAt: nowMs + RATE_WINDOW_MS });
        return true;
      }
      if (bucket.count >= limitPerHour) return false;
      bucket.count += 1;
      return true;
    },
    prune(nowMs) {
      for (const [key, bucket] of buckets) {
        if (nowMs >= bucket.resetAt) buckets.delete(key);
      }
    },
    get size() {
      return buckets.size;
    },
  };
}

/**
 * 读取请求体。超过 maxBytes 时先回 413 再继续排空（hard cap 为 8 倍上限），
 * 避免客户端还卡在上传时收不到响应；极端超限直接断连接。
 */
function readRequestBody(req, maxBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    const hardCap = maxBytes * 8;
    let total = 0;
    let tooLarge = false;
    let settled = false;
    const settle = (fn, value) => {
      if (settled) return;
      settled = true;
      fn(value);
    };

    req.on("data", (chunk) => {
      total += chunk.length;
      if (tooLarge) {
        if (total > hardCap) req.destroy();
        return;
      }
      if (total > maxBytes) {
        tooLarge = true;
        chunks.length = 0;
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      if (tooLarge) settle(reject, new PayloadTooLargeError(total));
      else settle(resolve, Buffer.concat(chunks));
    });
    req.on("aborted", () => settle(reject, new BodyReadError("client aborted")));
    req.on("error", (error) => settle(reject, new BodyReadError(error.message)));
  });
}

function sendJson(res, statusCode, payload, extraHeaders = {}) {
  if (res.writableEnded || res.destroyed) return false;
  const body = Buffer.from(JSON.stringify(payload), "utf8");
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": body.length,
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    ...extraHeaders,
  });
  res.end(body);
  return true;
}

function sendEmpty(res, statusCode, extraHeaders = {}) {
  if (res.writableEnded || res.destroyed) return false;
  res.writeHead(statusCode, {
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    ...extraHeaders,
  });
  res.end();
  return true;
}

/** 默认日志：JSON 单行，只含请求结果与字节数（契约 §4 隐私要求）。 */
function defaultLogger(entry) {
  console.log(JSON.stringify(entry));
}

/**
 * 删除超过保留期的会话日期目录；非日期目录/文件不动。
 * @returns {Promise<{removed:number, kept:number}>}
 */
export async function cleanupOldSessions(options = {}) {
  const env = options.env ?? process.env;
  const dataDir = path.resolve(options.dataDir ?? env.SN_TELEMETRY_DATA_DIR ?? DEFAULT_DATA_DIR);
  const retentionDays = isFiniteNumber(options.retentionDays)
    ? options.retentionDays
    : DEFAULT_RETENTION_DAYS;
  const now = typeof options.now === "function" ? options.now : () => new Date();
  const sessionsRoot = path.join(dataDir, "sessions");

  let entries;
  try {
    entries = await fs.promises.readdir(sessionsRoot, { withFileTypes: true });
  } catch (error) {
    if (error.code === "ENOENT") return { removed: 0, kept: 0 };
    throw error;
  }

  const cutoffMs = startOfUtcDay(new Date(now().getTime() - retentionDays * MILLIS_PER_DAY)).getTime();
  let removed = 0;
  let kept = 0;
  for (const entry of entries) {
    if (!entry.isDirectory() || !DAY_PATTERN.test(entry.name)) continue;
    const dayMs = Date.parse(`${entry.name}T00:00:00.000Z`);
    if (Number.isNaN(dayMs)) continue;
    if (dayMs < cutoffMs) {
      await fs.promises.rm(path.join(sessionsRoot, entry.name), { recursive: true, force: true });
      removed += 1;
    } else {
      kept += 1;
    }
  }
  return { removed, kept };
}

/**
 * 创建接收端请求处理器。
 *
 * @param {object} [options]
 * @param {string} [options.dataDir] 数据根目录（默认 SN_TELEMETRY_DATA_DIR 或 /data）
 * @param {number} [options.maxBodyBytes] 请求体上限，默认 512 KiB
 * @param {number} [options.rateLimitPerHour] 每来源 IP 每小时配额，默认 120；0 表示关闭限流
 * @param {string} [options.token] 共享令牌；空字符串表示不校验（默认读 SN_TELEMETRY_TOKEN）
 * @param {number} [options.retentionDays] 保留天数，默认 180
 * @param {number} [options.cleanupIntervalMs] 清理最小间隔，默认 1 小时
 * @param {() => Date} [options.now] 时钟注入（测试用）
 * @param {(entry: object) => void|null} [options.logger] 日志函数；传 null 静默
 * @param {NodeJS.ProcessEnv} [options.env] 环境变量来源（测试用）
 * @returns {(req: import("node:http").IncomingMessage, res: import("node:http").ServerResponse) => Promise<void>}
 */
export function createTelemetryHandler(options = {}) {
  const env = options.env ?? process.env;
  const dataDir = path.resolve(options.dataDir ?? env.SN_TELEMETRY_DATA_DIR ?? DEFAULT_DATA_DIR);
  const maxBodyBytes = isFiniteNumber(options.maxBodyBytes)
    ? options.maxBodyBytes
    : DEFAULT_MAX_BODY_BYTES;
  const rateLimitPerHour = isFiniteNumber(options.rateLimitPerHour)
    ? options.rateLimitPerHour
    : DEFAULT_RATE_LIMIT_PER_HOUR;
  const retentionDays = isFiniteNumber(options.retentionDays)
    ? options.retentionDays
    : DEFAULT_RETENTION_DAYS;
  const cleanupIntervalMs = isFiniteNumber(options.cleanupIntervalMs)
    ? options.cleanupIntervalMs
    : DEFAULT_CLEANUP_INTERVAL_MS;
  const now = typeof options.now === "function" ? options.now : () => new Date();
  const logger = options.logger === undefined ? defaultLogger : options.logger;
  const token = options.token !== undefined ? String(options.token ?? "") : String(env.SN_TELEMETRY_TOKEN ?? "");
  const limiter = createRateLimiter(rateLimitPerHour);

  let lastCleanupAt = 0;
  let indexQueue = Promise.resolve();
  let tempCounter = 0;

  const log = (entry) => {
    if (typeof logger !== "function") return;
    try {
      logger(entry);
    } catch {
      // 日志失败不影响请求处理
    }
  };

  async function appendIndexLine(dayDir, line) {
    const indexFile = path.join(dayDir, "index.ndjson");
    const task = indexQueue.then(() => fs.promises.appendFile(indexFile, line, "utf8"));
    indexQueue = task.then(
      () => undefined,
      () => undefined,
    );
    return task;
  }

  async function writeSession(payload, receivedAt, bodyBytes) {
    const sessionsRoot = path.join(dataDir, "sessions");
    const dayDir = path.join(sessionsRoot, utcDayKey(receivedAt));
    const targetFile = path.join(dayDir, `${payload.session_id}.json`);

    // 纵深防御：session_id 已由正则约束，再确认落点没有逃出 sessions/。
    const relative = path.relative(sessionsRoot, targetFile);
    if (!relative || relative.startsWith("..") || path.isAbsolute(relative)) {
      throw new Error("unsafe session storage path");
    }

    await fs.promises.mkdir(dayDir, { recursive: true });

    tempCounter += 1;
    const tempFile = path.join(dayDir, `.${payload.session_id}.${process.pid}.${tempCounter}.tmp`);
    const serialized = `${JSON.stringify(payload)}\n`;
    try {
      await fs.promises.writeFile(tempFile, serialized, "utf8");
      await fs.promises.rename(tempFile, targetFile);
    } catch (error) {
      await fs.promises.rm(tempFile, { force: true }).catch(() => {});
      throw error;
    }

    const summary = {
      session_id: payload.session_id,
      received_at: receivedAt.toISOString(),
      game_version: typeof payload.game_version === "string" ? payload.game_version : "",
      duration_seconds: payload.duration_seconds,
      commands: countCommands(payload),
      errors: Array.isArray(payload.errors) ? payload.errors.length : 0,
      bytes: bodyBytes,
    };
    await appendIndexLine(dayDir, `${JSON.stringify(summary)}\n`);
    return { dayDir, targetFile, summary };
  }

  async function maybeCleanup(nowMs) {
    if (!(retentionDays > 0)) return;
    if (nowMs - lastCleanupAt < cleanupIntervalMs) return;
    lastCleanupAt = nowMs;
    try {
      await cleanupOldSessions({ dataDir, retentionDays, now: () => new Date(nowMs) });
    } catch (error) {
      log({ event: "telemetry.cleanup_error", message: error.message });
    }
  }

  return async function telemetryHandler(req, res) {
    const startedAtMs = Date.now();
    const requestTime = now();
    const nowMs = requestTime.getTime();
    let route = "unknown";
    let status = 500;
    let bytes = 0;

    const respondJson = (statusCode, payload, extraHeaders) => {
      status = statusCode;
      return sendJson(res, statusCode, payload, extraHeaders);
    };
    const respondEmpty = (statusCode) => {
      status = statusCode;
      return sendEmpty(res, statusCode);
    };

    try {
      let pathname;
      try {
        pathname = new URL(req.url || "/", "http://localhost").pathname;
      } catch {
        route = "invalid-url";
        respondJson(400, { ok: false, error: "invalid_url" });
        return;
      }

      if (pathname === HEALTH_PATH) {
        route = "health";
        if (req.method !== "GET") {
          respondJson(405, { ok: false, error: "method_not_allowed" }, { Allow: "GET" });
          return;
        }
        respondJson(200, { ok: true, service: SERVICE_NAME, schema: SCHEMA_ID });
        return;
      }

      if (pathname !== SESSION_PATH) {
        route = "not-found";
        respondJson(404, { ok: false, error: "not_found" });
        return;
      }

      route = "session";
      if (req.method !== "POST") {
        respondJson(405, { ok: false, error: "method_not_allowed" }, { Allow: "POST" });
        return;
      }
      if (token && !tokenMatches(req.headers["x-sn-telemetry-token"], token)) {
        respondJson(401, { ok: false, error: "unauthorized" });
        return;
      }
      if (limiter.size > RATE_BUCKET_PRUNE_THRESHOLD) limiter.prune(nowMs);
      if (!limiter.allow(clientRateKey(req), nowMs)) {
        respondJson(429, { ok: false, error: "rate_limited" });
        return;
      }
      const contentType = String(req.headers["content-type"] || "");
      if (!JSON_CONTENT_TYPE_PATTERN.test(contentType)) {
        respondJson(422, {
          ok: false,
          error: "invalid_content_type",
          field: "Content-Type",
        });
        return;
      }

      let body;
      try {
        body = await readRequestBody(req, maxBodyBytes);
      } catch (error) {
        if (error instanceof PayloadTooLargeError) {
          bytes = error.total;
          respondJson(413, { ok: false, error: "payload_too_large" });
        } else {
          respondJson(400, { ok: false, error: "bad_request" });
        }
        return;
      }
      bytes = body.length;

      let payload;
      try {
        payload = JSON.parse(body.toString("utf8"));
      } catch {
        respondJson(400, { ok: false, error: "invalid_json" });
        return;
      }

      const invalidField = validateSessionPayload(payload);
      if (invalidField) {
        respondJson(422, { ok: false, error: "invalid_payload", field: invalidField });
        return;
      }

      try {
        await writeSession(payload, requestTime, body.length);
      } catch (error) {
        log({ event: "telemetry.storage_error", message: error.message });
        respondJson(500, { ok: false, error: "storage_error" });
        return;
      }

      await maybeCleanup(Date.now());
      respondEmpty(204);
    } catch (error) {
      log({ event: "telemetry.internal_error", message: error.message });
      try {
        respondJson(500, { ok: false, error: "internal_error" });
      } catch {
        // 连接已断开，忽略
      }
    } finally {
      log({
        event: "telemetry.request",
        route,
        status,
        bytes,
        duration_ms: Date.now() - startedAtMs,
      });
    }
  };
}

/**
 * 启动接收端。options 与 createTelemetryHandler 相同，另有：
 * - `port`（默认 SN_TELEMETRY_PORT 或 8090；0 = 随机端口，测试用）
 * - `host`（默认 SN_TELEMETRY_HOST 或 0.0.0.0）
 *
 * @returns {Promise<{server: import("node:http").Server, handler: Function, host: string, port: number, url: string, dataDir: string, close: () => Promise<void>}>}
 */
export async function startServer(options = {}) {
  const env = options.env ?? process.env;
  const dataDir = path.resolve(options.dataDir ?? env.SN_TELEMETRY_DATA_DIR ?? DEFAULT_DATA_DIR);
  const host = options.host ?? env.SN_TELEMETRY_HOST ?? "0.0.0.0";
  const requestedPort = Number(options.port ?? env.SN_TELEMETRY_PORT ?? DEFAULT_PORT);
  const port = Number.isInteger(requestedPort) && requestedPort >= 0 ? requestedPort : DEFAULT_PORT;
  const handler = options.handler ?? createTelemetryHandler({ ...options, env, dataDir });

  const server = http.createServer((req, res) => {
    Promise.resolve(handler(req, res)).catch((error) => {
      try {
        if (!res.headersSent && !res.writableEnded) {
          sendJson(res, 500, { ok: false, error: "internal_error" });
        } else if (!res.writableEnded) {
          res.end();
        }
      } catch {
        // 连接已断开，忽略
      }
      console.error(`sn-telemetry handler failure: ${error.message}`);
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
    handler,
    host,
    port: actualPort,
    url: `http://${displayHost}:${actualPort}`,
    dataDir,
    close() {
      return new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
        // 测试与容器退出时不等 keep-alive 空闲连接自然超时。
        if (typeof server.closeAllConnections === "function") server.closeAllConnections();
      });
    },
  };
}

const invokedPath = process.argv[1] ? path.resolve(process.argv[1]) : "";
const modulePath = fileURLToPath(import.meta.url);
if (invokedPath === path.resolve(modulePath)) {
  startServer()
    .then((instance) => {
      console.log(
        `sn-telemetry listening on ${instance.url} (dataDir=${instance.dataDir})`,
      );
      const shutdown = (signal) => {
        console.log(`sn-telemetry shutting down (${signal})`);
        instance
          .close()
          .then(() => process.exit(0))
          .catch((error) => {
            console.error(`sn-telemetry shutdown failed: ${error.message}`);
            process.exit(1);
          });
      };
      process.on("SIGTERM", () => shutdown("SIGTERM"));
      process.on("SIGINT", () => shutdown("SIGINT"));
    })
    .catch((error) => {
      console.error(`sn-telemetry failed to start: ${error.message}`);
      process.exitCode = 1;
    });
}
