// @static-doc
// 作用：官网只读内容 API（`server/site_api.mjs`）的 Node 测试：覆盖 health / release 响应、5 分钟缓存与并发共享、
// GitHub 失败时旧缓存与镜像 fallback 的降级链、无数据 503、方法与路径错误，以及 token 不下发。
//
// ## 契约与约束
// - 契约：`server/site_api.mjs` 文件头与 `docs/design/WEBSITE.md` §7/§8；不访问真实网络。
// - `fetchImpl` 注入 GitHub 响应；`now` 注入时钟以验证缓存过期；每个用例用临时 fallback 文件 + 端口 0。
// - 断言响应头 `Cache-Control`、`source` 字段与具体版本字段，不只断言 200。
// @end-static-doc

import { test, after } from "node:test";
import assert from "node:assert/strict";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { renderReleaseDataFile } from "../tools/build-release-data.mjs";
import { startSiteApi } from "../server/site_api.mjs";

const tempDirs = [];
after(async () => {
  for (const dir of tempDirs) await fsp.rm(dir, { recursive: true, force: true });
});

function asset(name, size, id) {
  return {
    name,
    size,
    browser_download_url: `https://github.com/xs-www/SteamNavigator/releases/download/v0.2.0-dev.4/${name}`,
    url: `https://api.github.com/repos/xs-www/SteamNavigator/releases/assets/${id}`,
  };
}

function release(overrides = {}) {
  return {
    tag_name: "v0.2.0-dev.4",
    name: "Steam Navigator v0.2.0-dev.4",
    published_at: "2026-10-26T22:18:39Z",
    prerelease: true,
    draft: false,
    html_url: "https://github.com/xs-www/SteamNavigator/releases/tag/v0.2.0-dev.4",
    assets: [
      asset("SHA256SUMS.txt", 335, "2"),
      asset("SteamNavigator-v0.2.0-dev.4-linux.zip", 60000000, "3"),
      asset("SteamNavigator-v0.2.0-dev.4-windows.zip", 70000000, "4"),
    ],
    ...overrides,
  };
}

function response(payload, ok = true, status = 200) {
  return { ok, status, json: async () => payload };
}

async function makeFallbackFile(data) {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), "sn-site-api-test-"));
  tempDirs.push(dir);
  const file = path.join(dir, "release-data.js");
  await fsp.writeFile(file, renderReleaseDataFile(data), "utf8");
  return file;
}

function flickerClock(startIso) {
  let current = new Date(startIso).getTime();
  return {
    now: () => new Date(current),
    advance(ms) {
      current += ms;
    },
  };
}

async function withApi(options, fn) {
  let fallbackFile = options.fallbackFile;
  if (!fallbackFile) {
    fallbackFile = options.fallbackData
      ? await makeFallbackFile(options.fallbackData)
      : path.join(os.tmpdir(), `sn-site-api-missing-${Date.now()}-${Math.random().toString(16).slice(2)}.js`);
  }
  const instance = await startSiteApi({
    host: "127.0.0.1",
    port: 0,
    logger: null,
    ...options,
    fallbackData: undefined,
    fallbackFile,
  });
  try {
    return await fn(instance);
  } finally {
    await instance.close();
  }
}

test("health 返回 200 且不阻塞在 GitHub 请求上", async () => {
  await withApi(
    {
      fallbackData: null,
      fetchImpl: async () => {
        throw new Error("should not be called");
      },
    },
    async (instance) => {
      const res = await fetch(`${instance.url}/api/site/health`);
      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.ok, true);
      assert.equal(body.service, "site-api");
      assert.equal(body.has_token, false);
    },
  );
});

test("release 从 GitHub 取最新 tag，返回同构 data 与短缓存头", async () => {
  let calls = 0;
  await withApi(
    {
      fallbackData: null,
      fetchImpl: async () => {
        calls += 1;
        return response([release()]);
      },
    },
    async (instance) => {
      const res = await fetch(`${instance.url}/api/site/release`);
      assert.equal(res.status, 200);
      assert.match(res.headers.get("cache-control") || "", /max-age=60/);
      const body = await res.json();
      assert.equal(body.ok, true);
      assert.equal(body.source, "github");
      assert.equal(body.data.latest.tag, "v0.2.0-dev.4");
      assert.equal(body.data.latest.date, "2026-10-27", "22:18Z 的发布在站点时区（UTC+8）已是次日");
      assert.equal(body.data.latest.date_time_zone, "Asia/Shanghai");
      assert.match(body.data.links.windows, /v0\.2\.0-dev\.4-windows\.zip$/);
      assert.equal(calls, 1);
    },
  );
});

test("TTL 内命中缓存，过期后重新请求 GitHub", async () => {
  let calls = 0;
  const clock = flickerClock("2026-10-27T00:00:00Z");
  await withApi(
    {
      fallbackData: null,
      now: clock.now,
      cacheTtlMs: 5 * 60 * 1000,
      fetchImpl: async () => {
        calls += 1;
        return response([release()]);
      },
    },
    async (instance) => {
      await (await fetch(`${instance.url}/api/site/release`)).json();
      await (await fetch(`${instance.url}/api/site/release`)).json();
      assert.equal(calls, 1, "TTL 内只打一次 GitHub");
      clock.advance(5 * 60 * 1000 + 1);
      const body = await (await fetch(`${instance.url}/api/site/release`)).json();
      assert.equal(calls, 2, "TTL 过期后重新拉取");
      assert.equal(body.source, "github");
    },
  );
});

test("GitHub 失败时优先返回旧缓存（stale），没有缓存时回退 fallback 文件", async () => {
  const fallbackData = {
    source: "github",
    repo: "xs-www/SteamNavigator",
    fetched_at: "2026-10-26T22:00:00.000Z",
    latest: {
      tag: "v0.2.0-dev.3",
      name: "v0.2.0-dev.3",
      published_at: "2026-10-22T01:03:37Z",
      date: "2026-10-22",
      prerelease: true,
      url: "https://github.com/xs-www/SteamNavigator/releases/tag/v0.2.0-dev.3",
      assets: [],
    },
    stable: null,
    links: { releases: "https://github.com/xs-www/SteamNavigator/releases" },
  };
  let calls = 0;
  await withApi(
    {
      fallbackFile: await makeFallbackFile(fallbackData),
      cacheTtlMs: 1,
      fetchImpl: async () => {
        calls += 1;
        if (calls === 1) return response([release()]);
        throw new Error("github down");
      },
    },
    async (instance) => {
      const first = await (await fetch(`${instance.url}/api/site/release`)).json();
      assert.equal(first.data.latest.tag, "v0.2.0-dev.4");
      await new Promise((resolve) => setTimeout(resolve, 5));
      const second = await (await fetch(`${instance.url}/api/site/release`)).json();
      assert.equal(second.source, "stale", "GitHub 失败时用旧缓存");
      assert.equal(second.data.latest.tag, "v0.2.0-dev.4");
    },
  );

  await withApi(
    {
      fallbackFile: await makeFallbackFile(fallbackData),
      fetchImpl: async () => response([], false, 500),
    },
    async (instance) => {
      const body = await (await fetch(`${instance.url}/api/site/release`)).json();
      assert.equal(body.source, "fallback");
      assert.equal(body.data.latest.tag, "v0.2.0-dev.3");
    },
  );
});

test("缓存与 fallback 都不可用时返回 503", async () => {
  await withApi(
    {
      fallbackFile: path.join(os.tmpdir(), "does-not-exist-release-data.js"),
      fetchImpl: async () => response([], false, 503),
    },
    async (instance) => {
      const res = await fetch(`${instance.url}/api/site/release`);
      assert.equal(res.status, 503);
      const body = await res.json();
      assert.equal(body.ok, false);
      assert.equal(body.error, "release_data_unavailable");
    },
  );
});

test("非 GET 405、未知路径 404，token 不出现在响应里", async () => {
  await withApi(
    {
      fallbackData: null,
      token: "secret-token",
      logger: null,
      fetchImpl: async () => response([release()]),
    },
    async (instance) => {
      assert.equal((await fetch(`${instance.url}/api/site/release`, { method: "POST" })).status, 405);
      assert.equal((await fetch(`${instance.url}/nope`)).status, 404);
      const body = await (await fetch(`${instance.url}/api/site/release`)).text();
      assert.doesNotMatch(body, /secret-token/);
    },
  );
});
