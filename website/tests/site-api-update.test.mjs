// @static-doc
// 作用：官网只读内容 API 的「游戏内自动更新」测试：覆盖 `update-manifest.json` 与 package / core 镜像、
// `GET /api/site/update` 契约 §4 字段（url / fallback_url / sha256 / size / tag / published_at）、镜像未就绪时
// 空 url + GitHub 兜底、清单缺失 / 清单 SHA 与 `SHA256SUMS.txt` 不一致 / 清单内部哈希不一致、schema / tag 漂移，
// 以及 GitHub 失败时的降级（旧缓存无清单、静态 fallback）、无 Release 数据 503。
//
// ## 契约与约束
// - 契约：`docs/design/AUTO_UPDATE.md` §4 / §8 与 `server/site_api.mjs` 文件头；GitHub / 下载请求全部用
//   `fetchImpl` 注入，不访问真实网络。
// - 清单由真实 `tools/build_update_manifest.mjs` 生成（临时文件 + 真实 SHA-256），测试同时验证发布链路两侧一致。
// - 每个用例临时 `downloadDir` + 端口 0；镜像下载是后台任务，用轮询等待「就绪 / 保持不可用」，并断言落盘字节。
// @end-static-doc

import { test, after } from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { renderReleaseDataFile } from "../tools/build-release-data.mjs";
import { buildUpdateManifest } from "../../tools/build_update_manifest.mjs";
import { startSiteApi } from "../server/site_api.mjs";

const TAG = "v0.2.0-dev.5";
const PUBLISHED_AT = "2026-10-30T05:00:00Z";
const CORE_NAME = "core-1.0.0.snavmod.zip";
const MANIFEST_NAME = "update-manifest.json";

const tempDirs = [];
after(async () => {
  for (const dir of tempDirs) await fsp.rm(dir, { recursive: true, force: true });
});

async function makeTempDir(prefix) {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), prefix));
  tempDirs.push(dir);
  return dir;
}

function sha256(bytes) {
  return crypto.createHash("sha256").update(bytes).digest("hex");
}

function asset(name, bytes, url) {
  return { name, size: bytes.length, browser_download_url: url, url };
}

async function makeFixture(options = {}) {
  const tag = options.tag ?? TAG;
  const dir = await makeTempDir("sn-site-update-fixture-");
  const engineBytes = Buffer.from("MZ engine bytes");
  const coreBytes = Buffer.from("PK core archive bytes");
  const packageBytes = Buffer.from("PK windows archive bytes");
  const packageName = `SteamNavigator-${tag}-windows.zip`;
  const write = async (name, bytes) => {
    const file = path.join(dir, name);
    await fsp.writeFile(file, bytes);
    return file;
  };
  const enginePath = await write("SteamNavigator.exe", engineBytes);
  const corePath = await write(CORE_NAME, coreBytes);
  const packagePath = await write(packageName, packageBytes);
  const manifest = buildUpdateManifest({
    tag,
    publishedAt: PUBLISHED_AT,
    enginePath,
    corePath,
    packagePath,
  });
  if (typeof options.mutateManifest === "function") options.mutateManifest(manifest);
  const manifestBytes = Buffer.from(JSON.stringify(manifest, null, 2) + "\n");

  const packageUrl = `https://downloads.example/${tag}/${packageName}`;
  const coreUrl = `https://downloads.example/${tag}/${CORE_NAME}`;
  const manifestUrl = `https://downloads.example/${tag}/${MANIFEST_NAME}`;
  const sumsUrl = `https://downloads.example/${tag}/SHA256SUMS.txt`;
  const hashes = {
    package: sha256(packageBytes),
    core: sha256(coreBytes),
    manifest: sha256(manifestBytes),
    ...(options.sumsHashes ?? {}),
  };
  const sumsText =
    options.sumsText ??
    [
      `${hashes.package}  dist/release/${packageName}`,
      `${hashes.core}  dist/release/${CORE_NAME}`,
      `${hashes.manifest}  dist/release/${MANIFEST_NAME}`,
    ].join("\n") + "\n";

  const omit = new Set(options.omit ?? []);
  const assets = [asset(`SteamNavigator-${tag}-linux.zip`, Buffer.alloc(64), `https://downloads.example/${tag}-linux.zip`)];
  if (!omit.has("package")) assets.push(asset(packageName, packageBytes, packageUrl));
  if (!omit.has("core")) assets.push(asset(CORE_NAME, coreBytes, coreUrl));
  if (!omit.has("manifest")) assets.push(asset(MANIFEST_NAME, manifestBytes, manifestUrl));
  if (!omit.has("sums")) assets.push(asset("SHA256SUMS.txt", Buffer.from(sumsText), sumsUrl));

  return {
    tag,
    manifest,
    manifestBytes,
    engineBytes,
    coreBytes,
    packageBytes,
    packageName,
    coreName: CORE_NAME,
    manifestUrl,
    packageUrl,
    coreUrl,
    sumsText,
    releases: [
      {
        tag_name: tag,
        name: `Steam Navigator ${tag}`,
        published_at: PUBLISHED_AT,
        prerelease: true,
        draft: false,
        html_url: `https://github.com/xs-www/SteamNavigator/releases/tag/${tag}`,
        assets,
      },
    ],
  };
}

function response(body, status = 200) {
  return new Response(body, {
    status,
    headers: { "Content-Type": "application/octet-stream", "Content-Length": String(Buffer.byteLength(body)) },
  });
}

function createFetch(fixture, counters, options = {}) {
  return async (url) => {
    const target = String(url);
    if (target.startsWith("https://api.github.com/repos/")) {
      if (options.releaseStatus) return response("upstream error", options.releaseStatus);
      return new Response(JSON.stringify(fixture.releases), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    if (target.includes("SHA256SUMS.txt")) {
      if (options.checksumStatus) return response("unavailable", options.checksumStatus);
      return response(fixture.sumsText);
    }
    if (target.includes(MANIFEST_NAME)) {
      counters.manifest += 1;
      if (options.gateManifest) await options.gateManifest();
      if (options.manifestStatus) return response("unavailable", options.manifestStatus);
      return response(fixture.manifestBytes);
    }
    if (target.includes(".snavmod.zip")) {
      counters.core += 1;
      if (options.gateCore) await options.gateCore();
      return response(fixture.coreBytes);
    }
    if (target.includes("-windows.zip")) {
      counters.package += 1;
      if (options.gatePackage) await options.gatePackage();
      return response(fixture.packageBytes);
    }
    return response("not found", 404);
  };
}

async function withUpdateApi(fixture, options, fn) {
  const downloadDir = await makeTempDir("sn-site-update-mirror-");
  const counters = { package: 0, core: 0, manifest: 0 };
  const events = [];
  const instance = await startSiteApi({
    host: "127.0.0.1",
    port: 0,
    fallbackFile: options.fallbackFile ?? path.join(downloadDir, "missing-release-data.js"),
    downloadDir: options.mirror === false ? "" : downloadDir,
    cacheTtlMs: 60 * 1000,
    logger: (event) => events.push(event),
    fetchImpl: createFetch(fixture, counters, options),
  });
  try {
    return await fn({ instance, downloadDir, counters, events });
  } finally {
    await instance.close();
  }
}

async function getJson(url) {
  const res = await fetch(url);
  return { status: res.status, headers: res.headers, body: await res.json() };
}

async function waitForHttp(url, predicate, timeoutMs = 8000) {
  const deadline = Date.now() + timeoutMs;
  let last = null;
  while (Date.now() < deadline) {
    try {
      last = await getJson(url);
      if (predicate(last)) return last;
    } catch (error) {
      last = { status: 0, body: null, error: error.message };
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(`timed out waiting for ${url}; last=${JSON.stringify(last)}`);
}

async function waitFor(predicate, timeoutMs = 4000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error("timed out waiting for condition");
}

function updateUrl(instance) {
  return `${instance.url}/api/site/update`;
}

test("镜像清单 + core + Windows zip 后，/api/site/update 返回契约 §4 字段", async () => {
  const fixture = await makeFixture();
  await withUpdateApi(fixture, {}, async ({ instance, downloadDir, counters }) => {
    const ready = await waitForHttp(
      updateUrl(instance),
      ({ status, body }) =>
        status === 200 && body.ok === true && body.data.files.package.url !== "" && body.data.files.core.url !== "",
      10000,
    );
    assert.match(ready.headers.get("cache-control") || "", /max-age=60/);
    assert.equal(ready.body.data.tag, TAG);
    assert.equal(ready.body.data.published_at, PUBLISHED_AT);
    assert.deepEqual(ready.body.data.manifest, fixture.manifest);
    assert.equal(ready.body.data.files.package.size, fixture.packageBytes.length);
    assert.equal(ready.body.data.files.package.sha256, sha256(fixture.packageBytes));
    assert.equal(ready.body.data.files.core.size, fixture.coreBytes.length);
    assert.equal(ready.body.data.files.core.sha256, sha256(fixture.coreBytes));
    assert.equal(ready.body.data.files.package.url, `/downloads/${TAG}/${fixture.packageName}`);
    assert.equal(ready.body.data.files.core.url, `/downloads/${TAG}/${CORE_NAME}`);
    assert.equal(ready.body.data.files.package.fallback_url, fixture.packageUrl);
    assert.equal(ready.body.data.files.core.fallback_url, fixture.coreUrl);
    assert.equal(counters.package, 1, "Windows zip 只下载一次");
    assert.equal(counters.core, 1, "core 包镜像一次");

    const tagDir = path.join(downloadDir, TAG);
    assert.deepEqual(await fsp.readFile(path.join(tagDir, fixture.packageName)), fixture.packageBytes);
    assert.deepEqual(await fsp.readFile(path.join(tagDir, CORE_NAME)), fixture.coreBytes);
    assert.deepEqual(await fsp.readFile(path.join(tagDir, MANIFEST_NAME)), fixture.manifestBytes, "清单原样落盘");

    const release = await getJson(`${instance.url}/api/site/release`);
    assert.equal(release.status, 200);
    assert.equal(release.body.data.downloads.windows.available, true, "旧 release 镜像行为不变");
  });
});

test("镜像关闭时 /api/site/update 仍返回清单，url 为空串、fallback_url 指向 GitHub", async () => {
  const fixture = await makeFixture();
  await withUpdateApi(fixture, { mirror: false }, async ({ instance, counters }) => {
    const { status, body } = await waitForHttp(updateUrl(instance), ({ status, body }) => status === 200 && body.ok === true);
    assert.equal(body.data.files.package.url, "");
    assert.equal(body.data.files.core.url, "");
    assert.equal(body.data.files.package.fallback_url, fixture.packageUrl);
    assert.equal(body.data.files.core.fallback_url, fixture.coreUrl);
    assert.equal(body.data.files.core.sha256, sha256(fixture.coreBytes));
    assert.equal(counters.package, 0, "关闭镜像不下载 Windows zip");
    assert.equal(counters.core, 0, "关闭镜像不下载 core");
  });
});

test("core 镜像下载中 url 仍为空串，完成后切换为 /downloads 地址", async () => {
  const fixture = await makeFixture();
  let releaseCore = () => {};
  const gate = new Promise((resolve) => {
    releaseCore = resolve;
  });
  let coreStarted = false;
  await withUpdateApi(
    fixture,
    {
      gateCore: async () => {
        coreStarted = true;
        await gate;
      },
    },
    async ({ instance }) => {
      const first = await waitForHttp(updateUrl(instance), ({ status, body }) => status === 200 && body.ok === true);
      assert.equal(first.body.data.files.core.url, "", "core 未就绪时同源 url 为空");
      assert.equal(first.body.data.files.core.fallback_url, fixture.coreUrl);
      await waitFor(() => coreStarted);
      releaseCore();
      const ready = await waitForHttp(
        updateUrl(instance),
        ({ status, body }) => status === 200 && body.data.files.core.url !== "",
      );
      assert.equal(ready.body.data.files.core.url, `/downloads/${TAG}/${CORE_NAME}`);
    },
  );
});

test("清单缺失时不提供更新数据（503），但 /api/site/release 仍可用", async () => {
  const fixture = await makeFixture({ omit: ["manifest"] });
  await withUpdateApi(fixture, {}, async ({ instance, downloadDir, counters }) => {
    const update = await getJson(updateUrl(instance));
    assert.equal(update.status, 503);
    assert.equal(update.body.ok, false);
    assert.equal(update.body.error, "update_data_unavailable");
    assert.equal(counters.core, 0, "没有清单就不镜像 core");
    await assert.rejects(fsp.stat(path.join(downloadDir, TAG, MANIFEST_NAME)), { code: "ENOENT" });

    const release = await getJson(`${instance.url}/api/site/release`);
    assert.equal(release.status, 200);
    assert.equal(release.body.data.latest.tag, TAG);
  });
});

test("清单 SHA 与 SHA256SUMS 不一致时 503，且不落盘清单", async () => {
  const fixture = await makeFixture({ sumsHashes: { manifest: "0".repeat(64) } });
  await withUpdateApi(fixture, {}, async ({ instance, downloadDir, events }) => {
    const update = await getJson(updateUrl(instance));
    assert.equal(update.status, 503);
    assert.equal(update.body.error, "update_data_unavailable");
    const failure = events.find((event) => event.event === "site_api.update_error");
    assert.ok(failure, "记录清单校验失败");
    assert.match(failure.message, /update manifest sha256 mismatch/);
    await assert.rejects(fsp.stat(path.join(downloadDir, TAG, MANIFEST_NAME)), { code: "ENOENT" });
  });
});

test("清单内的 core / package 哈希与 SHA256SUMS 不一致时 503", async () => {
  for (const field of ["core", "package"]) {
    const fixture = await makeFixture({
      mutateManifest: (manifest) => {
        manifest.platforms.windows[field].sha256 = "0".repeat(64);
      },
    });
    await withUpdateApi(fixture, {}, async ({ instance, events }) => {
      const update = await getJson(updateUrl(instance));
      assert.equal(update.status, 503, field);
      assert.equal(update.body.error, "update_data_unavailable");
      const failure = events.find((event) => event.event === "site_api.update_error");
      assert.ok(failure, field);
      assert.match(failure.message, new RegExp(`${field} sha256 does not match SHA256SUMS`), field);
    });
  }
});

test("清单 schema / tag / 下载失败时不提供更新数据", async () => {
  const mutations = [
    ["schema", (manifest) => { manifest.schema = 2; }],
    ["tag", (manifest) => { manifest.tag = "v9.9.9"; }],
  ];
  for (const [label, mutateManifest] of mutations) {
    const fixture = await makeFixture({ mutateManifest });
    await withUpdateApi(fixture, {}, async ({ instance }) => {
      const update = await getJson(updateUrl(instance));
      assert.equal(update.status, 503, label);
      assert.equal(update.body.ok, false, label);
    });
  }

  const fixture = await makeFixture();
  await withUpdateApi(fixture, { manifestStatus: 500 }, async ({ instance }) => {
    const update = await getJson(updateUrl(instance));
    assert.equal(update.status, 503);
    assert.equal(update.body.error, "update_data_unavailable");
  });
});

test("GitHub 不可用时降级：静态 fallback 不含清单则 503；无 Release 数据也 503", async () => {
  const fixture = await makeFixture();
  const fallbackDir = await makeTempDir("sn-site-update-fallback-");
  const fallbackData = {
    source: "github",
    repo: "xs-www/SteamNavigator",
    fetched_at: "2026-10-26T22:00:00.000Z",
    latest: {
      tag: "v0.2.0-dev.3",
      name: "Steam Navigator v0.2.0-dev.3",
      published_at: "2026-10-22T01:03:37Z",
      date: "2026-10-22",
      prerelease: true,
      url: "https://github.com/xs-www/SteamNavigator/releases/tag/v0.2.0-dev.3",
      assets: [],
    },
    stable: null,
    links: { releases: "https://github.com/xs-www/SteamNavigator/releases" },
  };
  const fallbackFile = path.join(fallbackDir, "release-data.js");
  await fsp.writeFile(fallbackFile, renderReleaseDataFile(fallbackData), "utf8");

  await withUpdateApi(fixture, { releaseStatus: 503, fallbackFile }, async ({ instance }) => {
    const release = await getJson(`${instance.url}/api/site/release`);
    assert.equal(release.status, 200);
    assert.equal(release.body.source, "fallback");
    const update = await getJson(updateUrl(instance));
    assert.equal(update.status, 503);
    assert.equal(update.body.ok, false);
    assert.equal(update.body.error, "update_data_unavailable");
  });

  await withUpdateApi(fixture, { releaseStatus: 503 }, async ({ instance }) => {
    const update = await getJson(updateUrl(instance));
    assert.equal(update.status, 503);
    assert.equal(update.body.error, "release_data_unavailable");
    assert.equal((await getJson(`${instance.url}/api/site/release`)).status, 503);
  });
});
