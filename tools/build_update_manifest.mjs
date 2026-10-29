// @static-doc
// 作用：生成游戏内自动更新的发布清单 `dist/release/update-manifest.json`（契约见
// `docs/design/AUTO_UPDATE.md` §3 / §8）：记录 tag、构建时间，以及 Windows 便携布局中
// `SteamNavigator.exe`、`mods/core-*.snavmod.zip`、平台 ZIP 的路径 / 字节数 / SHA-256。
//
// ## 契约与约束
// - 零依赖、Node >= 18；`buildUpdateManifest` 是可 import 的同步函数（文件读取可注入 `fs`），CLI 与测试共用。
// - `schema` 固定 `1`；`published_at` 必须是 UTC ISO（`YYYY-MM-DDTHH:MM:SSZ`），只用于阻止客户端降级。
// - 位置字段描述**发布包内**的便携布局，不是构建机路径：`engine.path` / `package.name` 取 basename，
//   `core.path` 固定写 `mods/<core 文件名>`（core 包在便携包内位于 `mods/`）。
// - 路径字段只允许相对路径，拒绝绝对路径 / `..` / 空段（客户端按契约只写 exe、`mods/`、`config/install.json`）。
// - 输出键顺序固定（schema → tag → published_at → platforms.windows.engine/core/package），同一输入生成结果可 diff。
// - 清单**不包含自身哈希**：`release.yml` 在清单生成后把它并入 `SHA256SUMS.txt`，由 sums 记录清单哈希。
// - CLI 参数缺失、文件不存在 / 不是普通文件、`published_at` 或 `tag` 非法时写 stderr 并 exit 1；成功打印输出路径。
//
// ## 重点逻辑
// ### `buildUpdateManifest({ tag, publishedAt, enginePath, corePath, packagePath, fs? })`
// - 校验参数 → 逐文件 stat + SHA-256（一次只读一个文件）→ 返回契约 §3 的对象。
// ### `renderUpdateManifest(manifest)`
// - `JSON.stringify(manifest, null, 2) + "\n"`，供 CLI 落盘、测试断言稳定文本。
// ### CLI
// - `node tools/build_update_manifest.mjs --tag <tag> --published-at <UTC ISO> --engine <file> --core <file> --package <file> --output <file>`
// @end-static-doc

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const MANIFEST_SCHEMA = 1;
/** 契约 §3：`published_at` 必须是秒级 UTC ISO（`2026-10-30T05:00:00Z`）。 */
export const UTC_TIMESTAMP_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const TAG_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._+-]*$/;
const CLI_FLAGS = new Map([
  ["--tag", "tag"],
  ["--published-at", "publishedAt"],
  ["--engine", "engine"],
  ["--core", "core"],
  ["--package", "package"],
  ["--output", "output"],
]);

function fail(message) {
  throw new Error(message);
}

/** 校验并返回 UTC 秒级 ISO 时间；`Date.parse` 兜底拒绝 `2026-02-30` 这类非法日期。 */
export function validatePublishedAt(value) {
  const text = String(value ?? "");
  if (!UTC_TIMESTAMP_PATTERN.test(text)) fail(`published_at must be UTC ISO like 2026-10-30T05:00:00Z, got "${text}"`);
  const time = Date.parse(text);
  if (!Number.isFinite(time)) fail(`published_at is not a valid date: "${text}"`);
  if (new Date(time).toISOString().slice(0, 19) + "Z" !== text) fail(`published_at is not a valid UTC timestamp: "${text}"`);
  return text;
}

/** 校验并返回 release tag（GitHub tag 名；不允许空白或路径分隔符）。 */
export function validateTag(value) {
  const text = String(value ?? "").trim();
  if (!TAG_PATTERN.test(text)) fail(`tag must look like v0.2.0-dev.5, got "${text}"`);
  return text;
}

/** 便携布局内的安全相对路径：拒绝绝对路径、`..` 与空路径段。 */
export function normalizePortablePath(value, label) {
  const raw = typeof value === "string" ? value.trim().replaceAll("\\", "/") : "";
  if (raw === "" || raw.startsWith("/") || raw.split("/").some((segment) => segment === "" || segment === "..")) {
    fail(`${label} must be a safe relative path, got "${String(value ?? "")}"`);
  }
  return raw;
}

function fileFingerprint(filePath, label, fsImpl) {
  if (typeof filePath !== "string" || filePath.trim() === "") fail(`${label} path is required`);
  const resolved = path.resolve(filePath);
  let stat;
  try {
    stat = fsImpl.statSync(resolved);
  } catch {
    fail(`${label} file not found: ${filePath}`);
  }
  if (!stat.isFile()) fail(`${label} is not a file: ${filePath}`);
  const bytes = fsImpl.readFileSync(resolved);
  return {
    name: path.basename(resolved),
    size: bytes.length,
    sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
  };
}

/**
 * 计算契约 §3 的发布清单对象。
 *
 * @param {object} options
 * @param {string} options.tag GitHub release tag（例如 `v0.2.0-dev.5`）
 * @param {string} options.publishedAt 本次构建时间（UTC `YYYY-MM-DDTHH:MM:SSZ`）
 * @param {string} options.enginePath 构建产物中的 Windows exe
 * @param {string} options.corePath 构建产物中的 `core-*.snavmod.zip`
 * @param {string} options.packagePath 构建产物中的 Windows 平台 ZIP
 * @param {typeof import("node:fs")} [options.fs] 文件系统注入（测试 / 工具复用）
 * @returns {{schema: number, tag: string, published_at: string, platforms: {windows: object}}}
 */
export function buildUpdateManifest(options = {}) {
  const fsImpl = options.fs ?? fs;
  const tag = validateTag(options.tag);
  const publishedAt = validatePublishedAt(options.publishedAt);
  const engine = fileFingerprint(options.enginePath, "engine", fsImpl);
  const core = fileFingerprint(options.corePath, "core", fsImpl);
  const packageFile = fileFingerprint(options.packagePath, "package", fsImpl);

  return {
    schema: MANIFEST_SCHEMA,
    tag,
    published_at: publishedAt,
    platforms: {
      windows: {
        engine: {
          path: engine.name,
          size: engine.size,
          sha256: engine.sha256,
        },
        core: {
          path: `mods/${core.name}`,
          size: core.size,
          sha256: core.sha256,
        },
        package: {
          name: packageFile.name,
          size: packageFile.size,
          sha256: packageFile.sha256,
        },
      },
    },
  };
}

/** 稳定的清单文本（JSON 键顺序由 `buildUpdateManifest` 固定）。 */
export function renderUpdateManifest(manifest) {
  return JSON.stringify(manifest, null, 2) + "\n";
}

/** 解析 CLI 参数；未知参数 / 缺值 / 缺必填项抛错，由调用方统一写 stderr。 */
export function parseArguments(argv = []) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    const key = CLI_FLAGS.get(flag);
    if (!key) fail(`unknown argument: ${flag}`);
    const value = argv[index + 1];
    if (value === undefined || value.startsWith("--")) fail(`missing value for ${flag}`);
    args[key] = value;
    index += 1;
  }
  for (const [flag, key] of CLI_FLAGS) {
    if (args[key] === undefined) fail(`missing required argument ${flag}`);
  }
  return args;
}

/** CLI 入口：构建清单并写入 `--output`，失败抛错（由调用方 exit 1）。 */
export function writeUpdateManifestFile(argv = [], options = {}) {
  const fsImpl = options.fs ?? fs;
  const args = parseArguments(argv);
  const manifest = buildUpdateManifest({
    tag: args.tag,
    publishedAt: args.publishedAt,
    enginePath: args.engine,
    corePath: args.core,
    packagePath: args.package,
    fs: fsImpl,
  });
  const output = path.resolve(args.output);
  fsImpl.mkdirSync(path.dirname(output), { recursive: true });
  fsImpl.writeFileSync(output, renderUpdateManifest(manifest), "utf8");
  return { manifest, output };
}

const invokedPath = process.argv[1] ? path.resolve(process.argv[1]) : "";
if (invokedPath === path.resolve(fileURLToPath(import.meta.url))) {
  try {
    const { output } = writeUpdateManifestFile(process.argv.slice(2));
    console.log(`update manifest written: ${output}`);
  } catch (error) {
    console.error(`build_update_manifest: ${error.message}`);
    process.exitCode = 1;
  }
}
