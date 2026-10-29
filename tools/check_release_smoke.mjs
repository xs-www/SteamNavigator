// @static-doc
// 作用：解压最终发布 ZIP，在本机原生运行包内 Windows/Linux 可执行文件，验证真实主菜单启动。
//
// ## 用法与门禁
// - `node tools/check_release_smoke.mjs --archive <zip> --platform windows|linux [--timeout-ms 60000]`。
// - 使用独立临时目录解压；APPDATA/LOCALAPPDATA/HOME/XDG_* 指向临时用户目录，避免读取玩家配置/模组/存档。
// - 不传 `--path` 或 `--script`：必须使用可执行文件内嵌的 PCK、真实 Autoload/main.tscn 和旁边的 mods/。
// - `--release-smoke` 让 Shell 检查启动报告与主菜单树后走真实退出路径；超时、非零退出、
//   SCRIPT ERROR / 其他 ERROR（`ERROR: N resources still in use at exit` 这类引擎退出期资源计数除外）、
//   缺少 `[release-smoke] main-menu-ready` 中任一条件都失败，避免 Godot 脚本加载失败仍返回 0 的漏报。
// - Windows 用 PowerShell Expand-Archive，Linux 用 unzip；只在与包相同的平台运行。临时文件始终清理。
// - 同时校验 `config/install.json`（schema=1/tag、engine/core SHA-256 与包内实际文件一致）：游戏内更新器
//   以它为本地版本依据，元数据错位会导致重复下载或漏更新。
// @end-static-doc

import { spawn } from "node:child_process";
import crypto from "node:crypto";
import { createReadStream } from "node:fs";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

export const READY_MARKER = "[release-smoke] main-menu-ready";
const MAX_OUTPUT_BYTES = 4 * 1024 * 1024;
// `ERROR: N resources still in use at exit` is an engine teardown accounting
// diagnostic; a plain `--quit-after` run of the same exported build prints it too,
// so it says nothing about whether the main menu loaded. Everything else — notably
// the `SCRIPT ERROR` / `Failed to load script` pair from the v0.2.0-dev.4 preload
// regression — stays fatal.
const ENGINE_TEARDOWN_NOISE = /^\s*ERROR:\s+\d+ resources still in use at exit\b/;

/** True when a Godot log line means the release failed to start (not teardown noise). */
export function isFatalStartupError(line) {
  return /^\s*(?:SCRIPT ERROR|USER ERROR|ERROR):/.test(line) && !ENGINE_TEARDOWN_NOISE.test(line);
}

export function parseArguments(args) {
  const options = { timeoutMs: 60_000 };
  for (let index = 0; index < args.length; index++) {
    const flag = args[index];
    if (!["--archive", "--platform", "--timeout-ms"].includes(flag) || !args[index + 1]) {
      throw new Error(`Invalid argument: ${flag}`);
    }
    const value = args[++index];
    if (flag === "--archive") options.archive = path.resolve(value);
    if (flag === "--platform") options.platform = value;
    if (flag === "--timeout-ms") options.timeoutMs = Number(value);
  }
  if (!options.archive || !["windows", "linux"].includes(options.platform)) {
    throw new Error("Usage: node tools/check_release_smoke.mjs --archive <zip> --platform windows|linux [--timeout-ms 60000]");
  }
  if (!Number.isSafeInteger(options.timeoutMs) || options.timeoutMs <= 0) {
    throw new Error("--timeout-ms must be a positive integer");
  }
  return options;
}

export function isolatedEnvironment(directory, inherited = process.env) {
  // Windows treats environment names case-insensitively. Remove old spellings
  // before adding overrides so e.g. AppData cannot win over APPDATA at spawn.
  const overrides = {
    HOME: directory,
    USERPROFILE: directory,
    APPDATA: path.join(directory, "AppData", "Roaming"),
    LOCALAPPDATA: path.join(directory, "AppData", "Local"),
    XDG_DATA_HOME: path.join(directory, "data"),
    XDG_CONFIG_HOME: path.join(directory, "config"),
    XDG_CACHE_HOME: path.join(directory, "cache"),
  };
  return {
    ...Object.fromEntries(Object.entries(inherited).filter(([key]) => !(key.toUpperCase() in overrides))),
    ...overrides,
  };
}

export function runProcess(command, args, { cwd, env, timeoutMs = 60_000 } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, env, windowsHide: true, stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    let outputExceeded = false;
    let outputBytes = 0;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, timeoutMs);
    const capture = (target) => (chunk) => {
      outputBytes += chunk.length;
      if (outputBytes > MAX_OUTPUT_BYTES) {
        outputExceeded = true;
        child.kill("SIGKILL");
        return;
      }
      if (target === "stdout") stdout += chunk.toString();
      else stderr += chunk.toString();
    };
    child.stdout.on("data", capture("stdout"));
    child.stderr.on("data", capture("stderr"));
    child.on("error", (error) => { clearTimeout(timer); reject(error); });
    child.on("close", (exitCode, signal) => {
      clearTimeout(timer);
      resolve({ stdout, stderr, exitCode, signal, timedOut, outputExceeded });
    });
  });
}

export function verifyStartup(result) {
  if (result.timedOut) throw new Error("Release startup timed out");
  if (result.outputExceeded) throw new Error("Release startup exceeded the log size limit");
  if (result.exitCode !== 0 || result.signal) {
    throw new Error(`Release exited with code ${result.exitCode}, signal ${result.signal ?? "none"}`);
  }
  const output = `${result.stdout}\n${result.stderr}`;
  const errors = output.split(/\r?\n/).filter(isFatalStartupError);
  if (errors.length) throw new Error(`Godot reported startup errors:\n${errors.slice(0, 12).join("\n")}`);
  if (!output.split(/\r?\n/).some((line) => line.trim() === READY_MARKER)) {
    throw new Error(`Main menu never reported readiness (${READY_MARKER})`);
  }
}

async function extractArchive(archive, destination) {
  let command = "unzip";
  let args = ["-q", archive, "-d", destination];
  if (process.platform === "win32") {
    const quote = (value) => `'${value.replaceAll("'", "''")}'`;
    const script = `$ErrorActionPreference = 'Stop'; Expand-Archive -LiteralPath ${quote(archive)} -DestinationPath ${quote(destination)}`;
    command = "powershell.exe";
    args = ["-NoProfile", "-NonInteractive", "-EncodedCommand", Buffer.from(script, "utf16le").toString("base64")];
  }
  const result = await runProcess(command, args, { timeoutMs: 120_000 });
  if (result.exitCode !== 0 || result.timedOut || result.outputExceeded) {
    throw new Error(`Cannot extract release ZIP: ${result.stderr || result.stdout || "extractor timed out"}`);
  }
}

async function fileSha256(filePath) {
  const hash = crypto.createHash("sha256");
  for await (const chunk of createReadStream(filePath)) hash.update(chunk);
  return hash.digest("hex");
}

/**
 * The in-game updater trusts config/install.json instead of re-hashing a 115 MB
 * exe on every launch, so a mismatch between it and the shipped files would make
 * the client loop or skip a release. Verify it as part of the release smoke.
 */
export async function verifyInstallMetadata(directory, executablePath, platform) {
  const installPath = path.join(directory, "config", "install.json");
  let install;
  try {
    // Tolerate a UTF-8 BOM from editors that re-save the generated JSON by hand.
    const text = (await fs.readFile(installPath, "utf8")).replace(/^\uFEFF/, "");
    install = JSON.parse(text);
  } catch (error) {
    throw new Error(`Release is missing config/install.json: ${error.message}`);
  }
  if (install.schema !== 1 || typeof install.tag !== "string" || install.tag.length === 0) {
    throw new Error("config/install.json is missing schema=1 or a release tag");
  }
  const coreFile = (await fs.readdir(path.join(directory, "mods"))).find((name) => /^core-.+\.snavmod\.zip$/.test(name));
  if (!coreFile) throw new Error("Release is missing the Core mod pack");
  const engineSha = await fileSha256(executablePath);
  const coreSha = await fileSha256(path.join(directory, "mods", coreFile));
  if (install.engine_sha256 !== engineSha) {
    throw new Error(`config/install.json engine hash does not match the ${platform} executable`);
  }
  if (install.core_sha256 !== coreSha) {
    throw new Error("config/install.json core hash does not match the shipped Core mod pack");
  }
  return install;
}

export async function checkReleaseSmoke({ archive, platform, timeoutMs = 60_000 }) {
  const expectedHost = { windows: "win32", linux: "linux" }[platform];
  if (!expectedHost || process.platform !== expectedHost) {
    throw new Error(`The ${platform} release must be tested on its native host (current: ${process.platform})`);
  }
  await fs.access(archive);
  const temporary = await fs.mkdtemp(path.join(os.tmpdir(), "sn-release-smoke-"));
  try {
    const unpacked = path.join(temporary, "unpacked");
    await extractArchive(path.resolve(archive), unpacked);
    const directory = path.join(unpacked, "SteamNavigator");
    const executable = path.join(directory, platform === "windows" ? "SteamNavigator.exe" : "SteamNavigator.x86_64");
    await fs.access(executable);
    await fs.access(path.join(directory, "config", "config.json"));
    const mods = await fs.readdir(path.join(directory, "mods"));
    if (!mods.some((name) => /^core-.+\.snavmod\.zip$/.test(name))) throw new Error("Release is missing the Core mod pack");
    await verifyInstallMetadata(directory, executable, platform);
    if (platform === "linux") await fs.chmod(executable, 0o755);
    const userDirectory = path.join(temporary, "user");
    const env = isolatedEnvironment(userDirectory);
    for (const key of ["HOME", "APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]) {
      await fs.mkdir(env[key], { recursive: true });
    }
    const result = await runProcess(executable, ["--headless", "--quit-after", "120", "--", "--release-smoke"], {
      cwd: directory, env, timeoutMs,
    });
    try {
      verifyStartup(result);
    } catch (error) {
      error.message += `\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`;
      throw error;
    }
    return { platform, archive: path.resolve(archive), marker: READY_MARKER };
  } finally {
    await fs.rm(temporary, { recursive: true, force: true });
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    const result = await checkReleaseSmoke(parseArguments(process.argv.slice(2)));
    console.log(`Release smoke passed (${result.platform}): ${result.marker}`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
