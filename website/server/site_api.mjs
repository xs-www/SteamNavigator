// @static-doc
// 作用：官网只读内容 API：`GET /api/site/release` 在服务端拉取 GitHub Releases（内存缓存，默认 5 分钟），
// 供前端在不重新部署网站的情况下自动显示「最新版本」；GitHub/网络失败时回退到镜像内烘焙的
// `release-data.js`，两者都没有才返回 503。`GET /api/site/health` 供 Docker / Compose 健康检查。
//
// ## 契约与约束
// - 只读、无需登录；不接触遥测数据，也不下发任何 token（`GITHUB_TOKEN` 只用于服务端 API 调用）。
// - 缓存：默认 300 秒；同一进程内只有一个进行中的刷新请求（避免并发打爆 GitHub 限流）。
// - 失败降级顺序：新鲜缓存 → 过期但可用的旧缓存（source:"stale"）→ 镜像内 `release-data.js`
//   （source:"fallback"）→ `503`。响应 `Cache-Control: public, max-age=60, stale-while-revalidate=600`。
// - 响应 `data` 与 `assets/data/release-data.js` 的 `window.SN_RELEASE_DATA` 同构，前端 `release.js` 共用一套渲染。
// - 可选 Windows 镜像：把最新 Release 的 Windows zip 流式下载到 `SN_SITE_API_DOWNLOAD_DIR`（不配置则关闭），
//   校验字节数与 `SHA256SUMS.txt` 后暴露为 `data.downloads.windows.url`（`/downloads/<tag>/<file>`）；只保留
//   最新 tag，旧版本目录自动删除，历史版本仍由前端回退 GitHub 直链。
// - 依赖 `tools/build-release-data.mjs` 的纯函数（fetchReleases / buildReleaseData / parseReleaseDataFile），
//   零第三方依赖，Node >= 18。
//
// ## 重点逻辑
// ### `createSiteApiHandler(options)`
// - 路由 `/api/site/release` 与 `/api/site/health`；其它 404，非 GET/HEAD 405。
// ### `getRelease()`
// - 缓存未过期直接返回；过期时复用同一个刷新 Promise；GitHub 失败时优先旧缓存，再读 fallback 文件。
// ### Windows 镜像
// - 刷新成功后后台下载最新 Windows zip（流式 + SHA-256 校验），完成后 `downloads.windows.available=true`；
//   下载进行中/失败时 API 仍正常返回，前端用 `links.windows`（GitHub）兜底。
// ### `startSiteApi(options)`
// - 默认监听 `0.0.0.0:8092`（Compose 内由 nginx 反代），返回 `{server,url,close}`。
// @end-static-doc

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { Readable } from "node:stream";
import { fileURLToPath } from "node:url";

import { DEFAULT_REPO, buildReleaseData, fetchReleases, parseReleaseDataFile } from "../tools/build-release-data.mjs";

const SERVER_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_PORT = 8092;
const DEFAULT_HOST = "0.0.0.0";
const DEFAULT_CACHE_TTL_MS = 5 * 60 * 1000;
const DEFAULT_FALLBACK_FILE = path.resolve(SERVER_DIR, "..", "assets", "data", "release-data.js");
const DEFAULT_MAX_DOWNLOAD_BYTES = 400 * 1024 * 1024;
const RELEASE_PATH = "/api/site/release";
const HEALTH_PATH = "/api/site/health";
const RESPONSE_CACHE_CONTROL = "public, max-age=60, stale-while-revalidate=600";

function sendJson(res, statusCode, payload, extraHeaders = {}) {
  if (res.writableEnded || res.destroyed) return;
  const body = Buffer.from(JSON.stringify(payload), "utf8");
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": body.length,
    "X-Content-Type-Options": "nosniff",
    ...extraHeaders,
  });
  res.end(body);
}

function readFallback(file) {
  try {
    return parseReleaseDataFile(fs.readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}

/** 把 Web Stream 下载到文件，同时计算 SHA-256 与字节数（用于镜像校验，不把整个 zip 读进内存）。 */
function streamToFile(webStream, filePath, maxBytes) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    let bytes = 0;
    if (!webStream) {
      reject(new Error("download body missing"));
      return;
    }
    const file = fs.createWriteStream(filePath);
    const reader = Readable.fromWeb(webStream);
    reader.on("data", (chunk) => {
      bytes += chunk.length;
      if (bytes > maxBytes) {
        reader.destroy(new Error("download exceeds size limit"));
        return;
      }
      hash.update(chunk);
    });
    reader.on("error", (error) => {
      file.destroy();
      reject(error);
    });
    file.on("error", reject);
    file.on("finish", () => resolve({ sha256: hash.digest("hex"), bytes }));
    reader.pipe(file);
  });
}

/**
 * 创建只读内容 API 处理器（测试 / 本地 / 容器共用）。
 *
 * @param {object} [options]
 * @param {string} [options.repo] GitHub 仓库（默认 xs-www/SteamNavigator）
 * @param {string} [options.token] GitHub token（仅服务端使用）
 * @param {string} [options.fallbackFile] 缓存与 API 都不可用时的 release-data.js
 * @param {number} [options.cacheTtlMs] 内存缓存时长，默认 5 分钟
 * @param {() => Date} [options.now] 时钟注入（测试）
 * @param {Function} [options.fetchImpl] GitHub 请求注入（测试）
 * @param {string} [options.downloadDir] Windows zip 镜像目录（为空则关闭镜像）
 * @param {boolean} [options.mirrorWindows] 是否镜像最新 Windows zip（默认看 downloadDir 是否配置）
 * @param {number} [options.maxDownloadBytes] 单次下载上限，默认 400 MB
 * @param {(entry: object) => void|null} [options.logger] 日志函数；null 静默
 */
export function createSiteApiHandler(options = {}) {
  const repo = String(options.repo ?? DEFAULT_REPO);
  const token = String(options.token ?? "");
  const fallbackFile = path.resolve(options.fallbackFile ?? DEFAULT_FALLBACK_FILE);
  const cacheTtlMs = Number.isFinite(options.cacheTtlMs) ? Number(options.cacheTtlMs) : DEFAULT_CACHE_TTL_MS;
  const now = typeof options.now === "function" ? options.now : () => new Date();
  const logger = options.logger === undefined ? (entry) => console.log(JSON.stringify(entry)) : options.logger;
  const downloadDir = options.downloadDir ? path.resolve(options.downloadDir) : "";
  const mirrorWindows = options.mirrorWindows !== undefined ? Boolean(options.mirrorWindows) : downloadDir !== "";
  const maxDownloadBytes = Number.isFinite(options.maxDownloadBytes)
    ? Number(options.maxDownloadBytes)
    : DEFAULT_MAX_DOWNLOAD_BYTES;

  let cache = null;
  let inflight = null;
  let mirror = { tag: "", file: "", size: 0, ready: false };
  let mirroring = null;

  const log = (entry) => {
    if (typeof logger !== "function") return;
    try {
      logger(entry);
    } catch {
      // 日志失败不影响响应。
    }
  };

  function mirrorUrl(data) {
    if (!mirror.ready || !data || !data.latest || data.latest.tag !== mirror.tag) return null;
    return `/downloads/${encodeURIComponent(mirror.tag)}/${encodeURIComponent(mirror.file)}`;
  }

  /** 在 API 的 release 数据上附加最新 Windows 镜像状态；不可用时前端回退 GitHub 直链。 */
  function withDownloads(data) {
    if (!data) return data;
    const url = mirrorUrl(data);
    const clone = JSON.parse(JSON.stringify(data));
    clone.downloads = {
      windows: {
        available: url !== null,
        url: url || "",
        size: url ? mirror.size : 0,
        github_url: data.links && typeof data.links.windows === "string" ? data.links.windows : "",
      },
    };
    return clone;
  }

  async function cleanupOtherTags(keepTag) {
    if (!downloadDir) return;
    let entries;
    try {
      entries = await fs.promises.readdir(downloadDir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      if (!entry.isDirectory() || entry.name === keepTag) continue;
      await fs.promises.rm(path.join(downloadDir, entry.name), { recursive: true, force: true }).catch(() => {});
    }
  }

  async function expectedSha256(fetchImpl, latest, fileName) {
    const sums = (latest.assets || []).find((asset) => /^SHA256SUMS\.txt$/i.test(asset.name) && asset.url);
    if (!sums) return "";
    try {
      const response = await fetchImpl(sums.url, { redirect: "follow" });
      if (!response || !response.ok) return "";
      for (const line of String(await response.text()).split("\n")) {
        const match = /^([a-f0-9]{64})\s+\*?(.+)$/i.exec(line.trim());
        if (match && match[2].trim() === fileName) return match[1].toLowerCase();
      }
    } catch {
      // 校验文件不可用时不阻断镜像（仍会校验字节数）。
    }
    return "";
  }

  /** 只把「最新 Release 的 Windows zip」下载到镜像目录；旧 tag 目录自动清理，历史版本回退 GitHub。 */
  async function downloadLatestWindows(data) {
    if (!mirrorWindows || !downloadDir || !data || !data.latest || mirroring !== null) return;
    const latest = data.latest;
    if (mirror.ready && mirror.tag === latest.tag) return;
    const win = (latest.assets || []).find((asset) => /-windows\.zip$/i.test(asset.name) && asset.url);
    if (!win) return;
    const fetchImpl = options.fetchImpl ?? globalThis.fetch;
    mirroring = (async () => {
      const dayDir = path.join(downloadDir, latest.tag);
      const target = path.join(dayDir, win.name);
      const temp = path.join(dayDir, `.${win.name}.${process.pid}.tmp`);
      try {
        await fs.promises.mkdir(dayDir, { recursive: true });
        if (fs.existsSync(target) && (!win.size || fs.statSync(target).size === win.size)) {
          mirror = { tag: latest.tag, file: win.name, size: fs.statSync(target).size, ready: true };
          await cleanupOtherTags(latest.tag);
          return;
        }
        const response = await fetchImpl(win.url, { redirect: "follow" });
        if (!response || !response.ok) throw new Error(`windows download ${response ? response.status : "unavailable"}`);
        const declared = Number(response.headers && typeof response.headers.get === "function" ? response.headers.get("content-length") : 0);
        if (declared > maxDownloadBytes) throw new Error("windows download exceeds size limit");
        const { sha256, bytes } = await streamToFile(response.body, temp, maxDownloadBytes);
        if (win.size > 0 && bytes !== win.size) throw new Error(`windows download size mismatch (${bytes} != ${win.size})`);
        const expected = await expectedSha256(fetchImpl, latest, win.name);
        if (expected && expected !== sha256) throw new Error("windows download sha256 mismatch");
        await fs.promises.rename(temp, target);
        mirror = { tag: latest.tag, file: win.name, size: bytes, ready: true };
        await cleanupOtherTags(latest.tag);
        log({ event: "site_api.mirror_ready", tag: latest.tag, bytes });
      } catch (error) {
        await fs.promises.rm(temp, { force: true }).catch(() => {});
        log({ event: "site_api.mirror_error", tag: latest.tag, message: error.message });
      }
    })().finally(() => {
      mirroring = null;
    });
  }

  async function refresh() {
    const data = buildReleaseData(await fetchReleases({ repo, token, fetchImpl: options.fetchImpl }), { repo, now: now() });
    if (data === null) throw new Error("no published release found");
    cache = { data, source: "github", fetchedAt: now().getTime() };
    downloadLatestWindows(data);
    return cache;
  }

  async function getRelease() {
    const nowMs = now().getTime();
    if (cache !== null && nowMs - cache.fetchedAt < cacheTtlMs) {
      return { data: cache.data, source: "cache", stale: false };
    }
    if (inflight === null) {
      inflight = refresh().finally(() => {
        inflight = null;
      });
    }
    try {
      const refreshed = await inflight;
      return { data: refreshed.data, source: "github", stale: false };
    } catch (error) {
      log({ event: "site_api.release_error", message: error.message });
      if (cache !== null) return { data: cache.data, source: "stale", stale: true };
      const fallback = readFallback(fallbackFile);
      if (fallback !== null) return { data: fallback, source: "fallback", stale: true };
      return { data: null, source: "unavailable", stale: true, error: error.message };
    }
  }

  return async function siteApiHandler(req, res) {
    try {
      let pathname;
      try {
        pathname = new URL(req.url || "/", "http://localhost").pathname;
      } catch {
        sendJson(res, 400, { ok: false, error: "invalid_url" });
        return;
      }
      if (req.method !== "GET" && req.method !== "HEAD") {
        sendJson(res, 405, { ok: false, error: "method_not_allowed" }, { Allow: "GET, HEAD" });
        return;
      }
      if (pathname === HEALTH_PATH) {
        sendJson(
          res,
          200,
          { ok: true, service: "site-api", has_token: token !== "", mirror_enabled: mirrorWindows, mirror_ready: mirror.ready },
          { "Cache-Control": "no-store" },
        );
        return;
      }
      if (pathname === RELEASE_PATH) {
        const result = await getRelease();
        if (result.data === null) {
          sendJson(res, 503, { ok: false, error: "release_data_unavailable" }, { "Cache-Control": "no-store" });
          return;
        }
        sendJson(
          res,
          200,
          { ok: true, source: result.source, stale: result.stale, fetched_at: now().toISOString(), data: withDownloads(result.data) },
          { "Cache-Control": RESPONSE_CACHE_CONTROL },
        );
        return;
      }
      sendJson(res, 404, { ok: false, error: "not_found" });
    } catch (error) {
      sendJson(res, 500, { ok: false, error: "internal_error", message: error.message });
    }
  };
}

/**
 * 启动只读内容 API。
 *
 * @param {object} [options] 传给 `createSiteApiHandler`，额外支持 host / port
 * @returns {Promise<{server: import("node:http").Server, host: string, port: number, url: string, close: () => Promise<void>}>}
 */
export async function startSiteApi(options = {}) {
  const host = options.host ?? DEFAULT_HOST;
  const requestedPort = Number(options.port ?? DEFAULT_PORT);
  const port = Number.isInteger(requestedPort) && requestedPort >= 0 ? requestedPort : DEFAULT_PORT;
  const handler = options.handler ?? createSiteApiHandler(options);
  const server = http.createServer((req, res) => {
    Promise.resolve(handler(req, res)).catch((error) => {
      if (!res.headersSent && !res.writableEnded) {
        sendJson(res, 500, { ok: false, error: "internal_error" });
      } else if (!res.writableEnded) {
        res.end();
      }
      console.error(`site-api handler failure: ${error.message}`);
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
    close() {
      return new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
        if (typeof server.closeAllConnections === "function") server.closeAllConnections();
      });
    },
  };
}

const invokedPath = process.argv[1] ? path.resolve(process.argv[1]) : "";
if (invokedPath === path.resolve(fileURLToPath(import.meta.url))) {
  const port = Number(process.env.SN_SITE_API_PORT || DEFAULT_PORT);
  const options = {
    repo: process.env.SN_SITE_API_REPO || DEFAULT_REPO,
    token: process.env.GITHUB_TOKEN || "",
    fallbackFile: process.env.SN_SITE_API_FALLBACK_FILE || DEFAULT_FALLBACK_FILE,
    cacheTtlMs: Number(process.env.SN_SITE_API_CACHE_SECONDS || 300) * 1000,
    downloadDir: process.env.SN_SITE_API_DOWNLOAD_DIR || "",
    mirrorWindows: process.env.SN_SITE_API_MIRROR_WINDOWS !== "0",
    host: process.env.SN_SITE_API_HOST || DEFAULT_HOST,
    port,
  };
  startSiteApi(options)
    .then((instance) => {
      const mode = options.token ? "token" : "anonymous";
      console.log(`sn-site-api listening on ${instance.url} (cache ${options.cacheTtlMs / 1000}s, github ${mode})`);
      const shutdown = (signal) => {
        instance
          .close()
          .then(() => process.exit(0))
          .catch((error) => {
            console.error(`sn-site-api shutdown failed: ${error.message}`);
            process.exit(1);
          });
      };
      process.on("SIGTERM", () => shutdown("SIGTERM"));
      process.on("SIGINT", () => shutdown("SIGINT"));
    })
    .catch((error) => {
      console.error(`sn-site-api failed to start: ${error.message}`);
      process.exitCode = 1;
    });
}
