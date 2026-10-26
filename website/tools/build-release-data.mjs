// @static-doc
// 作用：从 GitHub Releases API 生成官网的版本数据文件 `website/assets/data/release-data.js`（`window.SN_RELEASE_DATA`），
// 让下载页 / 开发日志页的版本号、发布日期、文件大小与下载链接不再手改。零依赖 Node（>= 18，内置 fetch）。
//
// ## 契约与约束
// - 数据来源：`https://api.github.com/repos/xs-www/SteamNavigator/releases?per_page=30`（`--repo` 可覆盖）。
//   只读公开 Release API；`GITHUB_TOKEN` / `--token` 可选，仅用于提高限流额度，不写入输出。
// - `latest` = 第一个非 draft release（包含预发布，官网当前就是预发布版本）；`stable` = 第一个非 draft 非 prerelease，可为 null。
// - 输出结构固定（见 `buildReleaseData`）：`latest` / `stable` / `links`；`links` 只从该 release 的真实 assets 名称推导，
//   缺失的平台资产留 `null`，前端保留原静态文案，不伪造下载地址。
// - 生成物只含公开版本信息（tag / 名称 / 发布时间 / 资产名 / 字节数 / GitHub 链接），不含 token 或私有数据。
// - 网络失败时默认保留上一次生成的文件并 exit 0（离线部署不炸站）；`--strict` 才失败。
// - `--check` 只比较版本内容（忽略 `fetched_at`），用于确认仓库里的数据是否落后于 GitHub。
// - 日期：`published_at` 保留 GitHub 的 UTC 时间；`date` 是**站点时区**（默认 `Asia/Shanghai`，
//   `SN_RELEASE_TIME_ZONE` / `--time-zone` 可覆盖）的日历日，`date_time_zone` 记录所用时区。
//   直接截取 UTC 日期会让 22:18Z 这类晚间发布显示成前一天，页面再用访客本地时区覆盖显示。
//
// ## 重点逻辑
// ### `buildReleaseData(releases, { repo, now, timeZone })`
// - 过滤 draft → 选 latest / stable → 从 assets 推导 windows / linux / SHA256SUMS 直链 → 生成 `window.SN_RELEASE_DATA`。
// ### `updateReleaseData(options)`
// - CLI 与测试共用：fetch → build → 与现有文件比较 → 写入或保留；返回 `{ok, changed, stale, data, path, error}`。
// ### `renderReleaseDataFile(data)`
// - 固定头部注释 + `window.SN_RELEASE_DATA = <canonical JSON>;`，保证同一份 Release 数据生成结果稳定、可 diff。
// @end-static-doc

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const TOOLS_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_OUT = path.resolve(TOOLS_DIR, "..", "assets", "data", "release-data.js");
export const DEFAULT_REPO = "xs-www/SteamNavigator";
/** 站点时区：`date` 字段按它计算（官网面向中文玩家，默认北京时间 UTC+8）。 */
export const DEFAULT_TIME_ZONE = "Asia/Shanghai";
const API_BASE = "https://api.github.com";
const PER_PAGE = 30;

function isValidTimeZone(timeZone) {
  if (typeof timeZone !== "string" || timeZone === "") return false;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone });
    return true;
  } catch {
    return false;
  }
}

/** 解析时区：调用方传入 > `SN_RELEASE_TIME_ZONE` > 站点默认；非法值退回默认，不让发版挂掉。 */
export function resolveTimeZone(value) {
  const candidate = typeof value === "string" && value.trim() !== "" ? value.trim() : "";
  if (isValidTimeZone(candidate)) return candidate;
  const fromEnv =
    candidate === "" && typeof process !== "undefined" && process.env ? process.env.SN_RELEASE_TIME_ZONE : "";
  if (isValidTimeZone(fromEnv)) return String(fromEnv).trim();
  return DEFAULT_TIME_ZONE;
}

/** ISO 时间 → 指定时区的 `YYYY-MM-DD`；解析失败返回空串。 */
export function formatDateInTimeZone(iso, timeZone) {
  const time = Date.parse(String(iso ?? ""));
  if (!Number.isFinite(time)) return "";
  try {
    const parts = new Intl.DateTimeFormat("en-CA", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(new Date(time));
    const pick = (type) => (parts.find((part) => part.type === type) || {}).value || "";
    const year = pick("year");
    const month = pick("month");
    const day = pick("day");
    if (year && month && day) return `${year}-${month}-${day}`;
  } catch {
    // 无效时区：退回 UTC，保证仍有可用日期。
  }
  return new Date(time).toISOString().slice(0, 10);
}

function pickAsset(assets, pattern) {
  if (!Array.isArray(assets)) return null;
  return assets.find((asset) => asset && typeof asset.name === "string" && pattern.test(asset.name)) ?? null;
}

function normalizeAsset(asset) {
  return {
    name: String(asset?.name ?? ""),
    size: Number.isFinite(asset?.size) ? Number(asset.size) : 0,
    // 浏览器要直接下载，必须用 browser_download_url（api.github.com 资产地址需要鉴权/Accept 头）。
    url:
      typeof asset?.browser_download_url === "string"
        ? asset.browser_download_url
        : typeof asset?.url === "string"
          ? asset.url
          : "",
  };
}

function normalizeLatest(raw, timeZone) {
  const assets = Array.isArray(raw.assets) ? raw.assets.map(normalizeAsset) : [];
  const published = typeof raw.published_at === "string" ? raw.published_at : "";
  return {
    tag: String(raw.tag_name ?? ""),
    name: String(raw.name ?? raw.tag_name ?? ""),
    published_at: published,
    date: formatDateInTimeZone(published, timeZone),
    date_time_zone: timeZone,
    prerelease: raw.prerelease === true,
    url: typeof raw.html_url === "string" ? raw.html_url : "",
    assets,
  };
}

/** 只保留可展示的已发布 release，最新在前（GitHub API 已按创建时间倒序）。 */
export function selectReleases(rawReleases, options = {}) {
  const timeZone = resolveTimeZone(options.timeZone);
  const valid = (Array.isArray(rawReleases) ? rawReleases : []).filter(
    (release) => release && release.draft !== true && typeof release.tag_name === "string" && release.tag_name.length > 0,
  );
  const latest = valid.length > 0 ? normalizeLatest(valid[0], timeZone) : null;
  const stableRaw = valid.find((release) => release.prerelease !== true) ?? null;
  return { latest, stable: stableRaw ? normalizeLatest(stableRaw, timeZone) : null };
}

/**
 * 把 GitHub Releases 列表转成官网数据对象。
 * @returns {{source:string, repo:string, fetched_at:string, latest:object, stable:object|null, links:object}|null}
 */
export function buildReleaseData(rawReleases, options = {}) {
  const repo = String(options.repo ?? DEFAULT_REPO);
  const now = options.now instanceof Date ? options.now : new Date();
  const timeZone = resolveTimeZone(options.timeZone);
  const { latest, stable } = selectReleases(rawReleases, { timeZone });
  if (latest === null) return null;

  const windows = pickAsset(latest.assets, /-windows\.zip$/i);
  const linux = pickAsset(latest.assets, /-linux\.zip$/i);
  const checksums = pickAsset(latest.assets, /^SHA256SUMS\.txt$/i);
  return {
    source: "github",
    repo,
    fetched_at: now.toISOString(),
    latest,
    stable,
    links: {
      releases: `https://github.com/${repo}/releases`,
      windows: windows ? windows.url : null,
      linux: linux ? linux.url : null,
      checksums: checksums ? checksums.url : null,
    },
  };
}

/** 生成稳定的 JS 文件文本（同一份 Release 数据可重复 diff）。 */
export function renderReleaseDataFile(data) {
  return (
    "// 生成文件，请勿手改：node website/tools/build-release-data.mjs\n" +
    `// 数据来源：GitHub Releases API（${data.repo}）\n` +
    `window.SN_RELEASE_DATA = ${JSON.stringify(data, null, 2)};\n`
  );
}

/** 从生成的 JS 里读回数据（用于 --check 与离线保留）。 */
export function parseReleaseDataFile(text) {
  const match = /window\.SN_RELEASE_DATA\s*=\s*([\s\S]*?);\s*$/.exec(String(text ?? ""));
  if (!match) return null;
  try {
    return JSON.parse(match[1]);
  } catch {
    return null;
  }
}

function comparable(data) {
  if (!data) return null;
  const clone = JSON.parse(JSON.stringify(data));
  delete clone.fetched_at;
  return JSON.stringify(clone);
}

/** 调用 GitHub Releases API；`fetchImpl` 供测试注入。 */
export async function fetchReleases(options = {}) {
  const repo = String(options.repo ?? DEFAULT_REPO);
  const token = String(options.token ?? "");
  const fetchImpl = options.fetchImpl ?? globalThis.fetch;
  if (typeof fetchImpl !== "function") throw new Error("fetch is not available (Node >= 18 required)");
  const headers = {
    Accept: "application/vnd.github+json",
    "User-Agent": "sn-website-release-data",
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetchImpl(`${API_BASE}/repos/${repo}/releases?per_page=${PER_PAGE}`, { headers });
  if (!response || response.ok !== true) {
    throw new Error(`GitHub Releases API ${response ? response.status : "unavailable"}`);
  }
  return await response.json();
}

/**
 * 生成 / 校验 / 保留数据文件的唯一入口（CLI 与测试共用）。
 *
 * @param {object} [options]
 * @param {string} [options.out] 输出文件（默认 website/assets/data/release-data.js）
 * @param {string} [options.repo]
 * @param {string} [options.token]
 * @param {Function} [options.fetchImpl] 测试注入
 * @param {Date} [options.now]
 * @param {boolean} [options.check] 只比较，不写文件
 * @param {boolean} [options.strict] 网络/API 失败时抛错而不是保留旧文件
 * @returns {Promise<{ok:boolean, changed:boolean, stale:boolean, data:object|null, path:string, error:string}>}
 */
export async function updateReleaseData(options = {}) {
  const out = path.resolve(options.out ?? DEFAULT_OUT);
  const existingText = fs.existsSync(out) ? await fs.promises.readFile(out, "utf8") : "";
  const existing = parseReleaseDataFile(existingText);
  let raw;
  try {
    raw = await fetchReleases(options);
  } catch (error) {
    if (options.strict) throw error;
    return {
      ok: Boolean(existing),
      changed: false,
      stale: false,
      data: existing,
      path: out,
      error: error.message,
    };
  }
  const data = buildReleaseData(raw, options);
  if (data === null) {
    return { ok: false, changed: false, stale: false, data: existing, path: out, error: "no published release found" };
  }
  const stale = comparable(existing) !== comparable(data);
  if (options.check) {
    return { ok: !stale, changed: false, stale, data: existing, path: out, error: "" };
  }
  if (!stale && existingText !== "") {
    return { ok: true, changed: false, stale: false, data: existing, path: out, error: "" };
  }
  await fs.promises.mkdir(path.dirname(out), { recursive: true });
  await fs.promises.writeFile(out, renderReleaseDataFile(data), "utf8");
  return { ok: true, changed: true, stale: true, data, path: out, error: "" };
}

function parseArgs(argv) {
  const args = {
    out: DEFAULT_OUT,
    repo: DEFAULT_REPO,
    token: process.env.GITHUB_TOKEN || "",
    timeZone: process.env.SN_RELEASE_TIME_ZONE || "",
    check: false,
    strict: false,
    help: false,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--check") args.check = true;
    else if (arg === "--strict") args.strict = true;
    else if (arg === "--out") args.out = path.resolve(argv[++index] ?? ".");
    else if (arg === "--repo") args.repo = String(argv[++index] ?? DEFAULT_REPO);
    else if (arg === "--token") args.token = String(argv[++index] ?? "");
    else if (arg === "--time-zone") args.timeZone = String(argv[++index] ?? "");
    else if (arg === "--help" || arg === "-h") args.help = true;
  }
  return args;
}

const invokedPath = process.argv[1] ? path.resolve(process.argv[1]) : "";
if (invokedPath === path.resolve(fileURLToPath(import.meta.url))) {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(
      "Usage: node website/tools/build-release-data.mjs [--check] [--strict] [--repo <owner/name>] [--token <token>] [--time-zone <IANA>] [--out <file>]",
    );
    process.exit(0);
  }
  updateReleaseData(args)
    .then((result) => {
      if (result.error) console.warn(`release data warning: ${result.error}${result.ok ? " (kept existing file)" : ""}`);
      if (args.check) {
        if (result.stale) {
          console.error(`release data is stale: ${result.path} (GitHub latest differs)`);
          process.exitCode = 1;
        } else if (result.ok) {
          console.log(`release data is up to date: ${result.path}`);
        } else {
          process.exitCode = 1;
        }
        return;
      }
      if (result.ok) {
        const tag = result.data ? result.data.latest.tag : "unknown";
        console.log(`release data ${result.changed ? "updated" : "unchanged"} (${tag}): ${result.path}`);
      } else {
        console.error("release data could not be generated");
        process.exitCode = 1;
      }
    })
    .catch((error) => {
      console.error(`release data failed: ${error.message}`);
      process.exitCode = 1;
    });
}
