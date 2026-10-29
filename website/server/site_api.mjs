// @static-doc
// 作用：官网只读内容 API：`GET /api/site/release` 在服务端拉取 GitHub Releases（内存缓存，默认 5 分钟），
// 供前端在不重新部署网站的情况下自动显示「最新版本」；`GET /api/site/update` 返回游戏内自动更新所需的
// 发布清单与文件地址（契约 `docs/design/AUTO_UPDATE.md` §4）；`GET /api/site/health` 供容器健康检查。
//
// ## 契约与约束
// - 只读、无需登录；不接触遥测数据，也不下发任何 token（`GITHUB_TOKEN` 只用于服务端 API 调用）。
// - 缓存：默认 300 秒；同一进程内只有一个进行中的刷新请求（避免并发打爆 GitHub 限流）。
// - 失败降级顺序：新鲜缓存 → 过期但可用的旧缓存（source:"stale"）→ 镜像内 `release-data.js`
//   （source:"fallback"）→ `503`。响应 `Cache-Control: public, max-age=60, stale-while-revalidate=600`。
// - 响应 `data` 与 `assets/data/release-data.js` 的 `window.SN_RELEASE_DATA` 同构，前端 `release.js` 共用一套渲染。
// - 可选下载镜像：把最新 Release 的 Windows zip、`core-*.snavmod.zip` 与 `update-manifest.json` 下载到
//   `SN_SITE_API_DOWNLOAD_DIR`（不配置则关闭），校验字节数与 `SHA256SUMS.txt` 后暴露为
//   `/downloads/<tag>/<file>`；只保留最新 tag，旧版本目录自动删除，历史版本仍由前端回退 GitHub 直链。
// - `update-manifest.json` 只信任能通过 `SHA256SUMS.txt` 交叉校验的版本：清单自身、package、core 的
//   SHA-256 必须与 sums 对应条目一致；`schema` 必须为 1、`tag` 必须等于最新 Release。engine 在平台 ZIP
//   内、没有独立 sums 条目，接口只校验其路径 / 哈希字段形状，客户端解压后再按清单哈希校验。
// - 校验清单兼容裸文件名与发布流程的 `dist/release/<文件名>`；校验和缺失、请求失败或不匹配时不提供镜像，
//   也不提供 `/api/site/update` 数据（`503 { ok:false, error }`，客户端回退手动更新）。
//   进程重启后也必须重新计算已有文件的 SHA-256；损坏副本移除后重新下载，不能只凭相同大小复用。
// - 依赖 `tools/build-release-data.mjs` 的纯函数（fetchReleases / buildReleaseData / parseReleaseDataFile），
//   零第三方依赖，Node >= 18。
//
// ## 重点逻辑
// ### `createSiteApiHandler(options)`
// - 路由 `/api/site/release`、`/api/site/update` 与 `/api/site/health`；其它 404，非 GET/HEAD 405。
// ### `getRelease()`
// - 缓存未过期直接返回；过期时复用同一个刷新 Promise；GitHub 失败时优先旧缓存，再读 fallback 文件。
// ### 下载镜像
// - 刷新成功后后台下载最新 Windows zip（旧行为）、`update-manifest.json` 与 core 包；每个文件独立校验、
//   独立就绪，镜像未就绪时 `/api/site/update` 的 `files.*.url` 为空字符串，由 `fallback_url`（GitHub）兜底。
// ### `/api/site/update`
// - 清单来自 GitHub Release 资产并与 `SHA256SUMS.txt` 交叉校验后缓存（每个 tag 只加载一次，失败下次刷新重试）；
//   刷新失败沿用旧 tag 的缓存（stale），无可用清单 / 无 Release 数据时 503。
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
const UPDATE_PATH = "/api/site/update";
const HEALTH_PATH = "/api/site/health";
const UPDATE_MANIFEST_NAME = "update-manifest.json";
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

/** 流式复验磁盘副本，避免进程重启后把同大小损坏文件直接标记为可用。 */
async function fileSha256(filePath) {
  const hash = crypto.createHash("sha256");
  for await (const chunk of fs.createReadStream(filePath)) hash.update(chunk);
  return hash.digest("hex");
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
  /** `/api/site/update` 的已校验清单（每个 release tag 一份）。 */
  let updateState = null;
  /** 当前 tag 的清单加载尝试；失败后保留 error，下一次 GitHub 刷新时重试。 */
  let updateAttempt = { tag: "", inflight: null, error: "" };
  /** 清单 / core 包的镜像状态（Windows zip 复用上面的 `mirror`）。 */
  let updateMirror = { tag: "", files: {} };

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

  /** 在最新 Release 的资产里按文件名匹配；只认带 URL 的资产。 */
  function findAsset(assets, pattern) {
    return (
      (Array.isArray(assets) ? assets : []).find(
        (asset) =>
          asset &&
          typeof asset.name === "string" &&
          pattern.test(asset.name) &&
          typeof asset.url === "string" &&
          asset.url !== "",
      ) ?? null
    );
  }

  /** 解析 `sha256sum` 风格清单：按 basename 建索引，兼容裸文件名与 `dist/release/<文件名>`。 */
  function parseChecksumLines(text) {
    const entries = new Map();
    for (const line of String(text ?? "").split("\n")) {
      const match = /^([a-f0-9]{64})\s+\*?(.+)$/i.exec(line.trim());
      if (!match) continue;
      const name = path.posix.basename(match[2].trim().replaceAll("\\", "/"));
      if (name) entries.set(name, match[1].toLowerCase());
    }
    return entries;
  }

  async function fetchChecksums(fetchImpl, latest) {
    const sums = findAsset(latest.assets, /^SHA256SUMS\.txt$/i);
    if (!sums) throw new Error("release checksums missing");
    const response = await fetchImpl(sums.url, { redirect: "follow" });
    if (!response || !response.ok) throw new Error("release checksums unavailable");
    return parseChecksumLines(await response.text());
  }

  function checksumFor(entries, fileName) {
    const hash = entries.get(fileName);
    if (!hash) throw new Error(`checksum entry missing for ${fileName}`);
    return hash;
  }

  async function expectedSha256(fetchImpl, latest, fileName) {
    return checksumFor(await fetchChecksums(fetchImpl, latest), fileName);
  }

  /**
   * 把一个 Release 资产流式镜像到 `<downloadDir>/<tag>/<asset.name>`：先写 `.tmp`，字节数与 SHA-256
   * 校验通过后原子改名；磁盘已有同大小且哈希一致的副本直接复用（重启后也重新算哈希，不能只看大小）。
   */
  async function mirrorAsset(fetchImpl, latest, asset, expectedSha, expectedBytes, label) {
    const dayDir = path.join(downloadDir, latest.tag);
    const target = path.join(dayDir, asset.name);
    const temp = path.join(dayDir, `.${asset.name}.${process.pid}.tmp`);
    try {
      await fs.promises.mkdir(dayDir, { recursive: true });
      if (fs.existsSync(target)) {
        const size = (await fs.promises.stat(target)).size;
        if ((!expectedBytes || size === expectedBytes) && (await fileSha256(target)) === expectedSha) {
          return { name: asset.name, size, sha256: expectedSha, ready: true };
        }
        await fs.promises.rm(target);
      }
      const response = await fetchImpl(asset.url, { redirect: "follow" });
      if (!response || !response.ok) throw new Error(`${label} download ${response ? response.status : "unavailable"}`);
      const declared = Number(
        response.headers && typeof response.headers.get === "function" ? response.headers.get("content-length") : 0,
      );
      if (declared > maxDownloadBytes) throw new Error(`${label} download exceeds size limit`);
      const { sha256, bytes } = await streamToFile(response.body, temp, maxDownloadBytes);
      if (expectedBytes > 0 && bytes !== expectedBytes) {
        throw new Error(`${label} download size mismatch (${bytes} != ${expectedBytes})`);
      }
      if (expectedSha !== sha256) throw new Error(`${label} download sha256 mismatch`);
      await fs.promises.rename(temp, target);
      log({ event: "site_api.mirror_ready", tag: latest.tag, file: asset.name, bytes });
      return { name: asset.name, size: bytes, sha256, ready: true };
    } catch (error) {
      await fs.promises.rm(temp, { force: true }).catch(() => {});
      throw error;
    }
  }

  /** 只把「最新 Release 的 Windows zip」下载到镜像目录；旧 tag 目录自动清理，历史版本回退 GitHub。 */
  async function downloadLatestWindows(data) {
    if (!mirrorWindows || !downloadDir || !data || !data.latest || mirroring !== null) return;
    const latest = data.latest;
    if (mirror.ready && mirror.tag === latest.tag) return;
    const win = findAsset(latest.assets, /-windows\.zip$/i);
    if (!win) return;
    const fetchImpl = options.fetchImpl ?? globalThis.fetch;
    mirroring = (async () => {
      try {
        const expected = await expectedSha256(fetchImpl, latest, win.name);
        const file = await mirrorAsset(fetchImpl, latest, win, expected, win.size || 0, "windows");
        mirror = { tag: latest.tag, file: win.name, size: file.size, ready: true };
        await cleanupOtherTags(latest.tag);
      } catch (error) {
        log({ event: "site_api.mirror_error", tag: latest.tag, message: error.message });
      }
    })().finally(() => {
      mirroring = null;
    });
  }

  function requireManifestSha256(value, label) {
    const text = typeof value === "string" ? value.toLowerCase() : "";
    if (!/^[a-f0-9]{64}$/.test(text)) throw new Error(`update manifest ${label} sha256 is invalid`);
    return text;
  }

  function requireManifestSize(value, label) {
    if (!Number.isInteger(value) || value < 0) throw new Error(`update manifest ${label} size is invalid`);
    return value;
  }

  /** 清单位置字段只能描述包内相对路径，拒绝绝对路径 / `..`（客户端安全边界 §7）。 */
  function requirePortablePath(value, label) {
    const raw = typeof value === "string" ? value.trim().replaceAll("\\", "/") : "";
    if (raw === "" || raw.startsWith("/") || raw.split("/").some((segment) => segment === "" || segment === "..")) {
      throw new Error(`update manifest ${label} path is unsafe`);
    }
    return raw;
  }

  function requireUtcTimestamp(value) {
    const text = typeof value === "string" ? value : "";
    const time = Date.parse(text);
    if (
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(text) ||
      !Number.isFinite(time) ||
      new Date(time).toISOString().slice(0, 19) + "Z" !== text
    ) {
      throw new Error("update manifest published_at is not a UTC timestamp");
    }
    return text;
  }

  /**
   * 校验契约 §3 清单的 schema / tag / 便携路径，并把 package、core 的哈希与 `SHA256SUMS.txt` 交叉核对。
   * engine 在平台 ZIP 内，没有独立 sums 条目：这里只校验字段形状，客户端解压后再校验实际 exe。
   */
  function validateUpdateManifest(manifest, context) {
    if (!manifest || typeof manifest !== "object" || Array.isArray(manifest)) {
      throw new Error("update manifest is not an object");
    }
    if (manifest.schema !== 1) throw new Error("update manifest schema is not 1");
    if (manifest.tag !== context.latestTag) {
      throw new Error(`update manifest tag ${manifest.tag} does not match release ${context.latestTag}`);
    }
    const publishedAt = requireUtcTimestamp(manifest.published_at);
    const windows = manifest.platforms && manifest.platforms.windows;
    if (!windows || typeof windows !== "object") throw new Error("update manifest platforms.windows is missing");

    const engine = windows.engine;
    if (!engine || typeof engine !== "object") throw new Error("update manifest engine entry is missing");
    const enginePath = requirePortablePath(engine.path, "engine");
    if (path.posix.basename(enginePath) !== "SteamNavigator.exe") {
      throw new Error("update manifest engine path is not SteamNavigator.exe");
    }
    requireManifestSize(engine.size, "engine");
    requireManifestSha256(engine.sha256, "engine");

    const core = windows.core;
    if (!core || typeof core !== "object") throw new Error("update manifest core entry is missing");
    const corePath = requirePortablePath(core.path, "core");
    if (path.posix.basename(corePath) !== context.core.name) {
      throw new Error("update manifest core path does not match core asset");
    }
    const coreSha = requireManifestSha256(core.sha256, "core");
    if (coreSha !== context.coreExpected) throw new Error("update manifest core sha256 does not match SHA256SUMS");
    const coreSize = requireManifestSize(core.size, "core");

    const packageEntry = windows.package;
    if (!packageEntry || typeof packageEntry !== "object") throw new Error("update manifest package entry is missing");
    if (packageEntry.name !== context.win.name) {
      throw new Error("update manifest package name does not match windows asset");
    }
    const packageSha = requireManifestSha256(packageEntry.sha256, "package");
    if (packageSha !== context.packageExpected) {
      throw new Error("update manifest package sha256 does not match SHA256SUMS");
    }
    const packageSize = requireManifestSize(packageEntry.size, "package");

    return {
      tag: context.latestTag,
      publishedAt,
      manifest,
      files: {
        package: { name: context.win.name, size: packageSize, sha256: packageSha },
        core: { name: context.core.name, size: coreSize, sha256: coreSha },
      },
      fallbacks: { package: context.win.url, core: context.core.url },
    };
  }

  /** 拉取并交叉校验最新 Release 的 `update-manifest.json`；通过后才提供 `/api/site/update` 数据。 */
  async function loadUpdateData(data) {
    const latest = data && data.latest;
    if (!latest) throw new Error("no published release found");
    const win = findAsset(latest.assets, /-windows\.zip$/i);
    const core = findAsset(latest.assets, /^core-.*\.snavmod\.zip$/i) ?? findAsset(latest.assets, /\.snavmod\.zip$/i);
    const manifestAsset = findAsset(latest.assets, /^update-manifest\.json$/i);
    if (!win) throw new Error("windows package asset missing");
    if (!core) throw new Error("core package asset missing");
    if (!manifestAsset) throw new Error("update manifest asset missing");
    const fetchImpl = options.fetchImpl ?? globalThis.fetch;
    const entries = await fetchChecksums(fetchImpl, latest);
    const manifestExpected = checksumFor(entries, UPDATE_MANIFEST_NAME);
    const coreExpected = checksumFor(entries, core.name);
    const packageExpected = checksumFor(entries, win.name);

    const response = await fetchImpl(manifestAsset.url, { redirect: "follow" });
    if (!response || !response.ok) {
      throw new Error(`update manifest download ${response ? response.status : "unavailable"}`);
    }
    const bytes = Buffer.from(await response.arrayBuffer());
    if (crypto.createHash("sha256").update(bytes).digest("hex") !== manifestExpected) {
      throw new Error("update manifest sha256 mismatch");
    }
    let manifest;
    try {
      manifest = JSON.parse(bytes.toString("utf8"));
    } catch {
      throw new Error("update manifest is not valid JSON");
    }
    const state = validateUpdateManifest(manifest, { latestTag: latest.tag, win, core, coreExpected, packageExpected });
    updateState = state;
    log({ event: "site_api.update_ready", tag: latest.tag });
    if (mirrorWindows && downloadDir) {
      // 清单字节已通过 SHA 校验：镜像时原样落盘，保证 `/downloads/.../update-manifest.json` 与 sums 一致。
      mirrorUpdateFiles(latest, core, bytes, manifestExpected, state).catch(() => {});
    }
    return state;
  }

  /** 镜像自动更新需要的 `update-manifest.json` 与 core 包；与 Windows zip 一样只保留最新 tag。 */
  async function mirrorUpdateFiles(latest, core, manifestBytes, manifestExpected, state) {
    const tag = latest.tag;
    const dayDir = path.join(downloadDir, tag);
    const fetchImpl = options.fetchImpl ?? globalThis.fetch;
    try {
      await fs.promises.mkdir(dayDir, { recursive: true });
      const manifestTarget = path.join(dayDir, UPDATE_MANIFEST_NAME);
      if (!(fs.existsSync(manifestTarget) && (await fileSha256(manifestTarget)) === manifestExpected)) {
        const temp = path.join(dayDir, `.${UPDATE_MANIFEST_NAME}.${process.pid}.tmp`);
        try {
          await fs.promises.writeFile(temp, manifestBytes);
          await fs.promises.rename(temp, manifestTarget);
        } catch (error) {
          await fs.promises.rm(temp, { force: true }).catch(() => {});
          throw error;
        }
      }
      updateMirror = {
        tag,
        files: {
          ...(updateMirror.tag === tag ? updateMirror.files : {}),
          manifest: { name: UPDATE_MANIFEST_NAME, size: manifestBytes.length, sha256: manifestExpected, ready: true },
        },
      };
      const coreFile = await mirrorAsset(fetchImpl, latest, core, state.files.core.sha256, state.files.core.size, "core");
      updateMirror = {
        tag,
        files: { ...(updateMirror.tag === tag ? updateMirror.files : {}), core: coreFile },
      };
      await cleanupOtherTags(tag);
    } catch (error) {
      log({ event: "site_api.mirror_error", tag, message: error.message });
    }
  }

  /** 组装契约 §4 的 `/api/site/update` data；清单不可用或 tag 不匹配时返回 null（路由给 503）。 */
  function buildUpdateData(latest) {
    if (!latest || !updateState || updateState.tag !== latest.tag) return null;
    const packageUrl =
      mirror.ready && mirror.tag === latest.tag
        ? `/downloads/${encodeURIComponent(latest.tag)}/${encodeURIComponent(mirror.file)}`
        : "";
    const coreMirrored = updateMirror.tag === latest.tag ? updateMirror.files.core : null;
    const coreUrl =
      coreMirrored && coreMirrored.ready
        ? `/downloads/${encodeURIComponent(latest.tag)}/${encodeURIComponent(updateState.files.core.name)}`
        : "";
    return {
      tag: updateState.tag,
      published_at: updateState.publishedAt,
      manifest: updateState.manifest,
      files: {
        package: {
          url: packageUrl,
          size: updateState.files.package.size,
          sha256: updateState.files.package.sha256,
          fallback_url: updateState.fallbacks.package,
        },
        core: {
          url: coreUrl,
          size: updateState.files.core.size,
          sha256: updateState.files.core.sha256,
          fallback_url: updateState.fallbacks.core,
        },
      },
    };
  }

  /**
   * 每个 release tag 只加载（并交叉校验）一次清单；失败保留 error，下一次 GitHub 刷新用 retry 重试。
   * Windows zip 与清单 / core 的镜像相互独立，任一失败都不影响 `/api/site/release`。
   */
  function primeUpdate(data, options = {}) {
    const tag = data && data.latest ? String(data.latest.tag) : "";
    if (!tag) return Promise.resolve(null);
    if (updateAttempt.inflight) {
      if (updateAttempt.tag === tag) return updateAttempt.inflight;
      return updateAttempt.inflight.then(() => primeUpdate(data, options));
    }
    if (updateAttempt.tag === tag && !(options.retry === true && updateAttempt.error !== "")) {
      return Promise.resolve(updateState);
    }
    updateAttempt = { tag, inflight: null, error: "" };
    updateAttempt.inflight = loadUpdateData(data)
      .catch((error) => {
        updateAttempt.error = error.message;
        if (updateState && updateState.tag === tag) updateState = null;
        log({ event: "site_api.update_error", tag, message: error.message });
        return null;
      })
      .finally(() => {
        updateAttempt.inflight = null;
      });
    return updateAttempt.inflight;
  }

  async function refresh() {
    const data = buildReleaseData(await fetchReleases({ repo, token, fetchImpl: options.fetchImpl }), { repo, now: now() });
    if (data === null) throw new Error("no published release found");
    cache = { data, source: "github", fetchedAt: now().getTime() };
    // 清单校验失败过就在下一次刷新重试；成功过的 tag 不重复拉取（tag 内容不可变）。
    primeUpdate(data, { retry: true });
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
      if (pathname === UPDATE_PATH) {
        const result = await getRelease();
        const latest = result.data && result.data.latest;
        if (result.data === null || !latest) {
          sendJson(res, 503, { ok: false, error: "release_data_unavailable" }, { "Cache-Control": "no-store" });
          return;
        }
        if (updateAttempt.tag !== latest.tag && !updateAttempt.inflight) {
          await primeUpdate(result.data);
        } else if (updateAttempt.inflight) {
          await updateAttempt.inflight;
        }
        const data = buildUpdateData(latest);
        if (data === null) {
          sendJson(res, 503, { ok: false, error: "update_data_unavailable" }, { "Cache-Control": "no-store" });
          return;
        }
        sendJson(
          res,
          200,
          { ok: true, source: result.source, stale: result.stale, fetched_at: now().toISOString(), data },
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
