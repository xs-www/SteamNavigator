// @static-doc
// 作用：官网只读内容 API 的「最新 Windows zip 镜像」测试：覆盖后台流式下载 + SHA-256 校验、镜像可用后
// `data.downloads.windows` 暴露本地地址、旧 tag 目录清理、哈希不匹配不暴露、无 Windows 资产不下载。
// 增量回归覆盖发布流水线 `dist/release/` 校验路径、校验文件缺失/请求失败，以及重启后已有文件的哈希复验。
//
// ## 契约与约束
// - 契约：`server/site_api.mjs` 文件头「Windows 镜像」与小节；GitHub / 下载请求全部用 `fetchImpl` 注入，不访问真实网络。
// - 每个用例用临时 `downloadDir` + 端口 0；下载是异步后台任务，用轮询等待「可用/保持不可用」。
// - 断言落盘文件字节数、旧目录被删、API 的 `downloads.windows.url` 与 `github_url`，不只断言接口 200。
// @end-static-doc

import { test, after } from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { startSiteApi } from "../server/site_api.mjs";

const tempDirs = [];
after(async () => {
  for (const dir of tempDirs) await fsp.rm(dir, { recursive: true, force: true });
});

async function makeTempDir(prefix) {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), prefix));
  tempDirs.push(dir);
  return dir;
}

function sha256(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

function asset(name, size, url) {
  return { name, size, browser_download_url: url, url };
}

function release({ tag = "v0.2.0-dev.4", windowsBytes, sumsHash } = {}) {
  const winName = `SteamNavigator-${tag}-windows.zip`;
  const assets = [
    asset("SteamNavigator-" + tag + "-linux.zip", 60 * 1024 * 1024, `https://downloads.example/${tag}-linux.zip`),
    asset("SHA256SUMS.txt", 200, `https://downloads.example/${tag}-SHA256SUMS.txt`),
  ];
  if (windowsBytes) {
    assets.push(asset(winName, windowsBytes.length, `https://downloads.example/${tag}-windows.zip`));
  }
  return {
    tag,
    winName,
    windowsBytes,
    releases: [
      {
        tag_name: tag,
        name: `Steam Navigator ${tag}`,
        published_at: "2026-10-26T22:18:39Z",
        prerelease: true,
        draft: false,
        html_url: `https://github.com/xs-www/SteamNavigator/releases/tag/${tag}`,
        assets,
      },
    ],
    sumsText: `${sumsHash || (windowsBytes ? sha256(windowsBytes) : "")}  ${winName}\n`,
  };
}

async function waitForAvailability(url, expected, timeoutMs = 8000) {
  const deadline = Date.now() + timeoutMs;
  let last = null;
  while (Date.now() < deadline) {
    last = await (await fetch(url)).json();
    if (last.data.downloads.windows.available === expected) return last;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(`timed out waiting for downloads.windows.available=${expected}; last=${JSON.stringify(last)}`);
}

async function withMirror(fixture, fn) {
  const downloadDir = await makeTempDir("sn-site-mirror-");
  let windowDownloads = 0;
  const mirrorErrors = [];
  const fetchImpl = async (url) => {
    if (String(url).includes("/releases?per_page=")) {
      return new Response(JSON.stringify(fixture.releases), { status: 200, headers: { "Content-Type": "application/json" } });
    }
    if (String(url).includes("-windows.zip")) {
      windowDownloads += 1;
      return new Response(fixture.windowsBytes, {
        status: 200,
        headers: { "Content-Type": "application/zip", "Content-Length": String(fixture.windowsBytes.length) },
      });
    }
    if (String(url).includes("SHA256SUMS.txt")) {
      return new Response(fixture.sumsText, { status: fixture.checksumStatus ?? 200, headers: { "Content-Type": "text/plain" } });
    }
    return new Response("not found", { status: 404 });
  };
  const instance = await startSiteApi({
    host: "127.0.0.1",
    port: 0,
    logger: (event) => {
      if (event.event === "site_api.mirror_error") mirrorErrors.push(event);
    },
    fallbackFile: path.join(downloadDir, "missing-release-data.js"),
    downloadDir,
    cacheTtlMs: 60 * 1000,
    fetchImpl,
  });
  try {
    return await fn({ instance, downloadDir, mirrorErrors, windowDownloads: () => windowDownloads });
  } finally {
    await instance.close();
  }
}

test("后台镜像最新 Windows zip：校验哈希、暴露本地地址、清理旧 tag", async () => {
  const windowsBytes = Buffer.concat([Buffer.from("PK\u0003\u0004", "binary"), Buffer.alloc(4096, 7)]);
  const fixture = release({ windowsBytes });
  await withMirror(fixture, async ({ instance, downloadDir, windowDownloads }) => {
    const oldDir = path.join(downloadDir, "v0.2.0-dev.3");
    await fsp.mkdir(oldDir, { recursive: true });
    await fsp.writeFile(path.join(oldDir, "old.zip"), "old");

    const first = await (await fetch(`${instance.url}/api/site/release`)).json();
    assert.equal(first.data.downloads.windows.available, false, "下载完成前不可用，前端回退 GitHub");

    const ready = await waitForAvailability(`${instance.url}/api/site/release`, true);
    assert.equal(ready.data.downloads.windows.available, true);
    assert.match(ready.data.downloads.windows.url, /^\/downloads\/v0\.2\.0-dev\.4\/SteamNavigator-v0\.2\.0-dev\.4-windows\.zip$/);
    assert.match(ready.data.downloads.windows.github_url, /v0\.2\.0-dev\.4-windows\.zip$/);
    assert.equal(ready.data.downloads.windows.size, windowsBytes.length);
    assert.equal(windowDownloads(), 1, "只下载 Windows zip，不碰 Linux");

    const target = path.join(downloadDir, "v0.2.0-dev.4", fixture.winName);
    assert.deepEqual(await fsp.readFile(target), windowsBytes, "镜像文件字节一致");
    await assert.rejects(fsp.stat(oldDir), { code: "ENOENT" }, "旧 tag 目录被清理（历史版本回退 GitHub）");
  });
});

test("SHA-256 不匹配时不暴露镜像，且不留下临时/最终文件", async () => {
  const windowsBytes = Buffer.from("not-the-right-content");
  const fixture = release({ windowsBytes, sumsHash: "0".repeat(64) });
  await withMirror(fixture, async ({ instance, downloadDir }) => {
    const body = await (await fetch(`${instance.url}/api/site/release`)).json();
    assert.equal(body.data.downloads.windows.available, false);
    await new Promise((resolve) => setTimeout(resolve, 400));
    const again = await (await fetch(`${instance.url}/api/site/release`)).json();
    assert.equal(again.data.downloads.windows.available, false, "哈希错误不能标记可用");
    const tagDir = path.join(downloadDir, "v0.2.0-dev.4");
    const files = await fsp.readdir(tagDir).catch(() => []);
    assert.deepEqual(files, [], "失败下载不留下 tmp 或 zip");
  });
});

test("没有 Windows 资产时不做下载，镜像保持不可用", async () => {
  const fixture = release({});
  await withMirror(fixture, async ({ instance, windowDownloads }) => {
    const body = await (await fetch(`${instance.url}/api/site/release`)).json();
    assert.equal(body.data.latest.tag, "v0.2.0-dev.4");
    assert.equal(body.data.downloads.windows.available, false);
    await new Promise((resolve) => setTimeout(resolve, 200));
    assert.equal(windowDownloads(), 0, "没有 Windows 资产就不发起下载");
  });
});

async function waitForMirrorError(mirrorErrors, timeoutMs = 8000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (mirrorErrors.length > 0) return mirrorErrors[0];
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error("timed out waiting for mirror failure");
}

test("实际发布的 dist/release 校验路径可匹配，并拒绝错误哈希", async () => {
  for (const valid of [true, false]) {
    const windowsBytes = Buffer.from("release archive bytes");
    const fixture = release({ windowsBytes, sumsHash: valid ? sha256(windowsBytes) : "0".repeat(64) });
    fixture.sumsText = fixture.sumsText.replace(fixture.winName, `dist/release/${fixture.winName}`);
    await withMirror(fixture, async ({ instance, downloadDir, mirrorErrors }) => {
      const url = `${instance.url}/api/site/release`;
      await (await fetch(url)).json();
      const target = path.join(downloadDir, fixture.tag, fixture.winName);
      if (valid) {
        const body = await waitForAvailability(url, true);
        assert.equal(body.data.downloads.windows.size, windowsBytes.length);
        assert.deepEqual(await fsp.readFile(target), windowsBytes);
      } else {
        assert.match((await waitForMirrorError(mirrorErrors)).message, /sha256 mismatch/);
        const body = await (await fetch(url)).json();
        assert.equal(body.data.downloads.windows.available, false);
        assert.deepEqual(await fsp.readdir(path.dirname(target)), []);
      }
    });
  }
});

test("校验清单缺失、请求失败或缺少目标条目时不下载、不暴露镜像", async () => {
  for (const failure of ["missing", "unavailable", "no-entry"]) {
    const fixture = release({ windowsBytes: Buffer.from("release archive bytes") });
    if (failure === "missing") fixture.releases[0].assets = fixture.releases[0].assets.filter((item) => item.name !== "SHA256SUMS.txt");
    if (failure === "unavailable") fixture.checksumStatus = 503;
    if (failure === "no-entry") fixture.sumsText = `${sha256(fixture.windowsBytes)}  unrelated.zip\n`;
    await withMirror(fixture, async ({ instance, downloadDir, mirrorErrors, windowDownloads }) => {
      const url = `${instance.url}/api/site/release`;
      await (await fetch(url)).json();
      await waitForMirrorError(mirrorErrors);
      const body = await (await fetch(url)).json();
      assert.equal(body.data.latest.tag, fixture.tag);
      assert.equal(body.data.downloads.windows.available, false);
      assert.match(body.data.links.windows, /v0\.2\.0-dev\.4-windows\.zip$/);
      assert.equal(windowDownloads(), 0);
      await assert.rejects(fsp.stat(path.join(downloadDir, fixture.tag, fixture.winName)), { code: "ENOENT" });
    });
  }
});

test("重启后已有文件必须通过 SHA 复验，同大小损坏文件重新下载", async () => {
  for (const valid of [true, false]) {
    const windowsBytes = Buffer.from("release archive bytes");
    const fixture = release({ windowsBytes });
    await withMirror(fixture, async ({ instance, downloadDir, windowDownloads }) => {
      const target = path.join(downloadDir, fixture.tag, fixture.winName);
      await fsp.mkdir(path.dirname(target), { recursive: true });
      await fsp.writeFile(target, valid ? windowsBytes : Buffer.alloc(windowsBytes.length));
      const body = await waitForAvailability(`${instance.url}/api/site/release`, true);
      assert.equal(body.data.downloads.windows.available, true);
      assert.equal(windowDownloads(), valid ? 0 : 1);
      assert.deepEqual(await fsp.readFile(target), windowsBytes);
    });
  }
});

test("校验清单不可用时，重启后也不信任磁盘已有副本", async () => {
  const windowsBytes = Buffer.from("release archive bytes");
  const fixture = release({ windowsBytes });
  fixture.checksumStatus = 503;
  await withMirror(fixture, async ({ instance, downloadDir, mirrorErrors }) => {
    const target = path.join(downloadDir, fixture.tag, fixture.winName);
    await fsp.mkdir(path.dirname(target), { recursive: true });
    await fsp.writeFile(target, windowsBytes);
    const url = `${instance.url}/api/site/release`;
    await (await fetch(url)).json();
    await waitForMirrorError(mirrorErrors);
    const body = await (await fetch(url)).json();
    assert.equal(body.data.downloads.windows.available, false);
    assert.match(body.data.downloads.windows.github_url, /v0\.2\.0-dev\.4-windows\.zip$/);
  });
});
