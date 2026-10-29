// @static-doc
// 作用：成品启动门禁的 Node 回归测试；真实子进程覆盖成功、Godot 报错但退出 0、缺标记、崩溃和超时。
// - 不运行游戏、不读写玩家目录；验证隔离用户环境与 Windows 大小写环境变量覆盖。
// @end-static-doc

import test from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { READY_MARKER, isolatedEnvironment, isFatalStartupError, parseArguments, runProcess, verifyInstallMetadata, verifyStartup } from "../check_release_smoke.mjs";

const execute = (source, options) => runProcess(process.execPath, ["-e", source], options);
const sha = (buffer) => crypto.createHash("sha256").update(buffer).digest("hex");

test("a real child process must exit cleanly after reporting main-menu readiness", async () => {
  const result = await execute(`console.log(${JSON.stringify(READY_MARKER)})`);
  assert.doesNotThrow(() => verifyStartup(result));
});

test("the reported regression fails even when bootstrap succeeds and Godot exits zero", async () => {
  const result = await execute('console.log("bootstrap finished: ok"); console.error("SCRIPT ERROR: Parse Error: Could not preload resource sn_carry_ghost.tscn");');
  assert.equal(result.exitCode, 0);
  assert.throws(() => verifyStartup(result), /Godot reported startup errors/);
});

test("errors after the success marker still fail, including teardown errors", async () => {
  for (const prefix of ["ERROR", "SCRIPT ERROR", "USER ERROR"]) {
    const result = await execute(`console.log(${JSON.stringify(READY_MARKER)}); console.error(${JSON.stringify(`${prefix}: resource failure`)});`);
    assert.throws(() => verifyStartup(result), /Godot reported startup errors/);
  }
});

test("engine resource-accounting noise at exit does not mask a working main menu", async () => {
  const result = await execute(`console.log(${JSON.stringify(READY_MARKER)}); console.error("ERROR: 16 resources still in use at exit (run with --verbose for details).");`);
  assert.doesNotThrow(() => verifyStartup(result));
  assert.equal(isFatalStartupError("ERROR: 16 resources still in use at exit (run with --verbose for details)."), false);
  assert.equal(isFatalStartupError("ERROR: Failed to load script \"res://framework/ui/shell/main.gd\""), true);
  assert.equal(isFatalStartupError("SCRIPT ERROR: Parse Error: Could not preload resource"), true);
});

test("exit zero without the exact marker fails instead of passing a blank main window", async () => {
  const result = await execute(`console.log("bootstrap finished: ok"); console.log(${JSON.stringify(`${READY_MARKER} (not really)`)});`);
  assert.throws(() => verifyStartup(result), /never reported readiness/);
});

test("a nonzero exit after the marker fails", async () => {
  const result = await execute(`console.log(${JSON.stringify(READY_MARKER)}); process.exitCode = 7;`);
  assert.throws(() => verifyStartup(result), /code 7/);
});

test("a hanging process is killed and fails even if it printed readiness", async () => {
  const result = await execute(`console.log(${JSON.stringify(READY_MARKER)}); setInterval(() => {}, 1000);`, { timeoutMs: 500 });
  assert.equal(result.timedOut, true);
  assert.throws(() => verifyStartup(result), /timed out/);
});

test("an executable that cannot be launched rejects", async () => {
  await assert.rejects(runProcess(path.resolve("missing-release-smoke-executable"), []), /ENOENT/);
});

test("all player-data roots are isolated without duplicate Windows variable spellings", () => {
  const root = path.resolve("isolated-user");
  const env = isolatedEnvironment(root, { Path: "keep-path", AppData: "player", LOCALAPPDATA: "player", HOME: "player", USERPROFILE: "player", XDG_DATA_HOME: "player" });
  assert.equal(env.Path, "keep-path");
  assert.equal(env.AppData, undefined);
  for (const name of ["HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]) {
    assert.ok(env[name] === root || env[name].startsWith(root + path.sep), name);
    assert.notEqual(env[name], "player");
  }
});

test("install.json metadata must match the shipped executable and core pack", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "sn-install-metadata-"));
  const directory = path.join(root, "SteamNavigator");
  const executable = path.join(directory, "SteamNavigator.exe");
  const core = path.join(directory, "mods", "core-1.0.0.snavmod.zip");
  const install = path.join(directory, "config", "install.json");
  const writeInstall = async (engineSha = null, coreSha = null) => {
    await fs.mkdir(path.dirname(install), { recursive: true });
    await fs.writeFile(install, JSON.stringify({
      schema: 1,
      tag: "v0.2.0-dev.5",
      published_at: "2026-10-30T05:00:00Z",
      engine_sha256: engineSha ?? sha(await fs.readFile(executable)),
      core_sha256: coreSha ?? sha(await fs.readFile(core)),
    }));
  };
  try {
    await fs.mkdir(path.dirname(core), { recursive: true });
    await fs.writeFile(executable, "engine bytes");
    await fs.writeFile(core, "core bytes");
    await writeInstall();
    assert.equal((await verifyInstallMetadata(directory, executable, "windows")).tag, "v0.2.0-dev.5");
    await writeInstall("0".repeat(64));
    await assert.rejects(() => verifyInstallMetadata(directory, executable, "windows"), /engine hash/);
    await writeInstall(null, "0".repeat(64));
    await assert.rejects(() => verifyInstallMetadata(directory, executable, "windows"), /core hash/);
    await fs.writeFile(install, JSON.stringify({ schema: 1, tag: "", engine_sha256: "", core_sha256: "" }));
    await assert.rejects(() => verifyInstallMetadata(directory, executable, "windows"), /schema=1/);
    await fs.rm(install);
    await assert.rejects(() => verifyInstallMetadata(directory, executable, "windows"), /missing config\/install.json/);
  } finally {
    await fs.rm(root, { recursive: true, force: true });
  }
});

test("CLI requires a known platform, archive and bounded positive timeout", () => {
  assert.deepEqual(parseArguments(["--archive", "build.zip", "--platform", "windows", "--timeout-ms", "5000"]), {
    archive: path.resolve("build.zip"), platform: "windows", timeoutMs: 5000,
  });
  for (const args of [[], ["--archive", "a", "--platform", "mac"], ["--archive", "a", "--platform", "linux", "--timeout-ms", "0"], ["--wat"]]) {
    assert.throws(() => parseArguments(args));
  }
});
