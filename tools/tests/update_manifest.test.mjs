// @static-doc
// 作用：自动更新清单生成器 `tools/build_update_manifest.mjs` 的 node:test 用例：覆盖契约 §3 字段 / 哈希 / 大小、
// 便携布局路径（engine 裸名、core `mods/` 前缀、package 文件名）、非法 `published_at` / tag、缺失 / 非文件路径，
// 以及 CLI 成功落盘与失败退出码（stderr）。
//
// ## 契约与约束
// - 契约：`docs/design/AUTO_UPDATE.md` §3 / §8；清单 schema 固定 1，不包含自身哈希。
// - 全部用 `node:fs` 临时目录构造真实文件，不访问网络、不依赖仓库构建产物。
// - CLI 用 `spawnSync(process.execPath, ...)` 真实子进程验证退出码与 stderr，避免只测函数不测入口。
// @end-static-doc

import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  MANIFEST_SCHEMA,
  buildUpdateManifest,
  parseArguments,
  renderUpdateManifest,
  validatePublishedAt,
  validateTag,
  writeUpdateManifestFile,
} from "../build_update_manifest.mjs";

const SCRIPT = fileURLToPath(new URL("../build_update_manifest.mjs", import.meta.url));
const tempDirs = [];
const TAG = "v0.2.0-dev.5";
const PUBLISHED_AT = "2026-10-30T05:00:00Z";

function makeTempDir() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "sn-update-manifest-"));
  tempDirs.push(dir);
  return dir;
}

function writeFixture(dir, name, bytes) {
  const file = path.join(dir, name);
  fs.writeFileSync(file, bytes);
  return file;
}

function sha256(bytes) {
  return crypto.createHash("sha256").update(bytes).digest("hex");
}

function createFixture(overrides = {}) {
  const dir = makeTempDir();
  const engineBytes = Buffer.from("MZ fake windows executable", "utf8");
  const coreBytes = Buffer.from("PK fake core mod archive", "utf8");
  const packageBytes = Buffer.from("PK fake windows release zip", "utf8");
  return {
    dir,
    engineBytes,
    coreBytes,
    packageBytes,
    enginePath: writeFixture(dir, "SteamNavigator.exe", engineBytes),
    corePath: writeFixture(dir, "core-1.0.0.snavmod.zip", coreBytes),
    packagePath: writeFixture(dir, `SteamNavigator-${TAG}-windows.zip`, packageBytes),
    ...overrides,
  };
}

function build(fixture) {
  return buildUpdateManifest({
    tag: TAG,
    publishedAt: PUBLISHED_AT,
    enginePath: fixture.enginePath,
    corePath: fixture.corePath,
    packagePath: fixture.packagePath,
  });
}

test("清单字段 / 哈希 / 大小 / 便携布局路径符合契约 §3", () => {
  const fixture = createFixture();
  const manifest = build(fixture);

  assert.equal(manifest.schema, MANIFEST_SCHEMA);
  assert.equal(manifest.schema, 1);
  assert.equal(manifest.tag, TAG);
  assert.equal(manifest.published_at, PUBLISHED_AT);
  assert.deepEqual(manifest.platforms.windows.engine, {
    path: "SteamNavigator.exe",
    size: fixture.engineBytes.length,
    sha256: sha256(fixture.engineBytes),
  });
  assert.deepEqual(manifest.platforms.windows.core, {
    path: "mods/core-1.0.0.snavmod.zip",
    size: fixture.coreBytes.length,
    sha256: sha256(fixture.coreBytes),
  });
  assert.deepEqual(manifest.platforms.windows.package, {
    name: `SteamNavigator-${TAG}-windows.zip`,
    size: fixture.packageBytes.length,
    sha256: sha256(fixture.packageBytes),
  });
  assert.deepEqual(Object.keys(manifest), ["schema", "tag", "published_at", "platforms"]);

  const rendered = renderUpdateManifest(manifest);
  assert.ok(rendered.endsWith("\n"));
  assert.deepEqual(JSON.parse(rendered), manifest);
});

test("缺失文件、目录或空路径都报错，不产出半成品清单", () => {
  const fixture = createFixture();
  const missing = path.join(fixture.dir, "missing.bin");
  for (const label of ["engine", "core", "package"]) {
    const options = {
      tag: TAG,
      publishedAt: PUBLISHED_AT,
      enginePath: fixture.enginePath,
      corePath: fixture.corePath,
      packagePath: fixture.packagePath,
    };
    options[`${label}Path`] = missing;
    assert.throws(() => buildUpdateManifest(options), new RegExp(`${label} file not found`), label);

    options[`${label}Path`] = fixture.dir;
    assert.throws(() => buildUpdateManifest(options), new RegExp(`${label} is not a file`), label);

    options[`${label}Path`] = "";
    assert.throws(() => buildUpdateManifest(options), new RegExp(`${label} path is required`), label);
  }
});

test("published_at 只接受 UTC 秒级 ISO", () => {
  for (const valid of ["2026-10-30T05:00:00Z", "2026-01-01T00:00:00Z"]) {
    assert.equal(validatePublishedAt(valid), valid);
  }
  for (const invalid of [
    "",
    "2026-10-30",
    "2026-10-30T05:00:00",
    "2026-10-30T05:00:00+00:00",
    "2026-10-30 05:00:00Z",
    "2026-10-30T05:00:00.000Z",
    "2026-02-30T00:00:00Z",
    "not-a-timestamp",
  ]) {
    assert.throws(() => validatePublishedAt(invalid), /published_at/, invalid);
  }
  const fixture = createFixture();
  for (const invalid of ["2026-10-30", "now"]) {
    assert.throws(
      () =>
        buildUpdateManifest({
          tag: TAG,
          publishedAt: invalid,
          enginePath: fixture.enginePath,
          corePath: fixture.corePath,
          packagePath: fixture.packagePath,
        }),
      /published_at/,
    );
  }
});

test("tag 必须是合法 release tag", () => {
  assert.equal(validateTag(" v0.2.0-dev.5 "), TAG);
  for (const invalid of ["", "v 0.2.0", "../v0.2.0", "v0.2.0/evil", "-v0.2.0"]) {
    assert.throws(() => validateTag(invalid), /tag must look like/, invalid);
  }
});

test("CLI 参数解析拒绝未知参数、缺值与缺必填项", () => {
  assert.deepEqual(
    parseArguments(["--tag", TAG, "--published-at", PUBLISHED_AT, "--engine", "a", "--core", "b", "--package", "c", "--output", "d"]),
    { tag: TAG, publishedAt: PUBLISHED_AT, engine: "a", core: "b", package: "c", output: "d" },
  );
  for (const argv of [
    [],
    ["--tag", TAG],
    ["--wat", "x"],
    ["--tag"],
    ["--tag", TAG, "--published-at"],
  ]) {
    assert.throws(() => parseArguments(argv), /argument|missing value/);
  }
});

test("CLI 成功写入清单并打印输出路径", () => {
  const fixture = createFixture();
  const output = path.join(fixture.dir, "nested", "dist", "update-manifest.json");
  const result = spawnSync(
    process.execPath,
    [
      SCRIPT,
      "--tag", TAG,
      "--published-at", PUBLISHED_AT,
      "--engine", fixture.enginePath,
      "--core", fixture.corePath,
      "--package", fixture.packagePath,
      "--output", output,
    ],
    { encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /update manifest written:/);
  const written = JSON.parse(fs.readFileSync(output, "utf8"));
  assert.equal(written.schema, 1);
  assert.equal(written.tag, TAG);
  assert.equal(written.platforms.windows.core.path, "mods/core-1.0.0.snavmod.zip");
});

test("CLI 缺参、非法时间或文件缺失时 stderr 报错并 exit 1", () => {
  const fixture = createFixture();
  const missing = path.join(fixture.dir, "missing.exe");
  const cases = [
    ["--tag", TAG, "--published-at", PUBLISHED_AT, "--engine", fixture.enginePath, "--core", fixture.corePath],
    ["--tag", TAG, "--published-at", "2026-10-30", "--engine", fixture.enginePath, "--core", fixture.corePath, "--package", fixture.packagePath, "--output", path.join(fixture.dir, "out.json")],
    ["--tag", TAG, "--published-at", PUBLISHED_AT, "--engine", missing, "--core", fixture.corePath, "--package", fixture.packagePath, "--output", path.join(fixture.dir, "out.json")],
  ];
  for (const argv of cases) {
    const result = spawnSync(process.execPath, [SCRIPT, ...argv], { encoding: "utf8" });
    assert.equal(result.status, 1, `expected exit 1 for ${argv.join(" ")}`);
    assert.match(result.stderr, /build_update_manifest:/);
    assert.equal(result.stdout.trim(), "");
  }
});

test("注入 fs 时仍使用同一套校验（writeUpdateManifestFile 复用纯函数）", () => {
  const fixture = createFixture();
  const output = path.join(fixture.dir, "manifest.json");
  const { manifest } = writeUpdateManifestFile(
    [
      "--tag", TAG,
      "--published-at", PUBLISHED_AT,
      "--engine", fixture.enginePath,
      "--core", fixture.corePath,
      "--package", fixture.packagePath,
      "--output", output,
    ],
    { fs },
  );
  assert.deepEqual(JSON.parse(fs.readFileSync(output, "utf8")), manifest);
});
