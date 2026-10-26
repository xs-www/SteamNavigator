// @static-doc
// 作用：官网 Release 版本数据生成器（`tools/build-release-data.mjs`）的 Node 测试：覆盖 latest/stable 选择、
// 资产直链与大小推导、生成文件往返、`--check` 陈旧检测，以及 GitHub API 失败时“保留旧文件 / strict 失败”的降级契约。
//
// ## 契约与约束
// - 契约：`docs/design/WEBSITE.md` §2/§7 与 `website/tools/build-release-data.mjs` 文件头；不访问真实网络。
// - 网络用注入的 `fetchImpl` 模拟；每个用例用 `os.tmpdir()` 下的独立输出文件，结束后删除。
// - 断言生成数据的具体字段（tag/date/links/size）与失败分支，不只断言“文件存在”。
// @end-static-doc

import { test, after } from "node:test";
import assert from "node:assert/strict";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import {
  buildReleaseData,
  parseReleaseDataFile,
  renderReleaseDataFile,
  selectReleases,
  updateReleaseData,
} from "../tools/build-release-data.mjs";

const tempDirs = [];

after(async () => {
  for (const dir of tempDirs) await fsp.rm(dir, { recursive: true, force: true });
});

async function makeTempFile() {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), "sn-release-data-test-"));
  tempDirs.push(dir);
  return path.join(dir, "release-data.js");
}

function asset(name, size, id) {
  return {
    name,
    size,
    browser_download_url: `https://github.com/xs-www/SteamNavigator/releases/download/v0.2.0-dev.3/${name}`,
    url: `https://api.github.com/repos/xs-www/SteamNavigator/releases/assets/${id}`,
  };
}

function release(overrides = {}) {
  return {
    tag_name: "v0.2.0-dev.3",
    name: "Steam Navigator v0.2.0-dev.3",
    published_at: "2026-10-22T01:03:37Z",
    prerelease: true,
    draft: false,
    html_url: "https://github.com/xs-www/SteamNavigator/releases/tag/v0.2.0-dev.3",
    assets: [
      asset("core-1.0.0.snavmod.zip", 32000297, "1"),
      asset("SHA256SUMS.txt", 335, "2"),
      asset("SteamNavigator-v0.2.0-dev.3-linux.zip", 64308391, "3"),
      asset("SteamNavigator-v0.2.0-dev.3-windows.zip", 73968001, "4"),
    ],
    ...overrides,
  };
}

function response(payload, ok = true, status = 200) {
  return { ok, status, json: async () => payload };
}

test("latest 取第一个非 draft（含预发布），stable 取第一个正式版；draft 被跳过", () => {
  const releases = [
    release({ tag_name: "v9.9.9-draft", draft: true }),
    release({ tag_name: "v0.2.0-dev.3" }),
    release({ tag_name: "v0.2.0", prerelease: false, published_at: "2026-10-20T00:00:00Z" }),
  ];
  const selected = selectReleases(releases);
  assert.equal(selected.latest.tag, "v0.2.0-dev.3");
  assert.equal(selected.stable.tag, "v0.2.0");
  assert.equal(selected.latest.date, "2026-10-22");
  assert.equal(selected.stable.date, "2026-10-20");
  assert.equal(selectReleases([release({ draft: true })]).latest, null);
  assert.equal(selectReleases([]).stable, null);
});

test("生成数据推导下载直链、日期与大小，缺失资产留 null", () => {
  const data = buildReleaseData([release()], { repo: "xs-www/SteamNavigator", now: new Date("2026-10-27T00:00:00Z") });
  assert.equal(data.latest.tag, "v0.2.0-dev.3");
  assert.equal(data.latest.date, "2026-10-22");
  assert.equal(data.latest.prerelease, true);
  assert.equal(data.stable, null);
  assert.equal(data.fetched_at, "2026-10-27T00:00:00.000Z");
  assert.equal(data.links.releases, "https://github.com/xs-www/SteamNavigator/releases");
  assert.match(data.links.windows, /SteamNavigator-v0\.2\.0-dev\.3-windows\.zip$/);
  assert.match(data.links.linux, /SteamNavigator-v0\.2\.0-dev\.3-linux\.zip$/);
  assert.match(data.links.checksums, /SHA256SUMS\.txt$/);
  assert.equal(data.latest.assets.find((item) => item.name.endsWith("windows.zip")).size, 73968001);

  const partial = buildReleaseData([
    release({ assets: [asset("SHA256SUMS.txt", 335, "2"), asset("SteamNavigator-v0.2.0-dev.3-windows.zip", 1, "4")] }),
  ]);
  assert.equal(partial.links.linux, null);
  assert.match(partial.links.windows, /windows\.zip$/);
});

test("生成文件可被 parse 还原（window.SN_RELEASE_DATA）", () => {
  const data = buildReleaseData([release()], { now: new Date("2026-10-27T00:00:00Z") });
  const text = renderReleaseDataFile(data);
  assert.match(text, /^\/\/ 生成文件，请勿手改/);
  assert.match(text, /window\.SN_RELEASE_DATA = \{/);
  const parsed = parseReleaseDataFile(text);
  assert.deepEqual(parsed, data);
  assert.equal(parseReleaseDataFile("window.SN_RELEASE_DATA = not-json;"), null);
});

test("updateReleaseData 写入、幂等、--check 检测陈旧且网络失败保留旧文件", async () => {
  const out = await makeTempFile();
  const fetchImpl = async () => response([release()]);
  const first = await updateReleaseData({ out, fetchImpl, now: new Date("2026-10-27T00:00:00Z") });
  assert.equal(first.ok, true);
  assert.equal(first.changed, true);
  const text = await fsp.readFile(out, "utf8");
  assert.match(text, /"tag": "v0\.2\.0-dev\.3"/);

  const second = await updateReleaseData({ out, fetchImpl, now: new Date("2026-10-27T02:00:00Z") });
  assert.equal(second.changed, false, "同一份 release 数据不重复写入");

  const stale = await updateReleaseData({ out, check: true, fetchImpl: async () => response([release({ tag_name: "v0.2.1" })]) });
  assert.equal(stale.stale, true);
  assert.equal(stale.ok, false);

  const fresh = await updateReleaseData({ out, check: true, fetchImpl });
  assert.equal(fresh.stale, false);
  assert.equal(fresh.ok, true);

  const offline = await updateReleaseData({ out, fetchImpl: async () => { throw new Error("network down"); } });
  assert.equal(offline.ok, true, "网络失败时保留旧文件");
  assert.match(offline.error, /network down/);
  assert.match(await fsp.readFile(out, "utf8"), /v0\.2\.0-dev\.3/);

  await assert.rejects(
    updateReleaseData({ out, strict: true, fetchImpl: async () => response([], false, 403) }),
    /GitHub Releases API 403/,
  );
});

test("token 只用于请求头，不写进生成文件", async () => {
  const out = await makeTempFile();
  let seenHeaders = null;
  const fetchImpl = async (_url, init) => {
    seenHeaders = init.headers;
    return response([release()]);
  };
  await updateReleaseData({ out, token: "secret-token", fetchImpl });
  assert.equal(seenHeaders.Authorization, "Bearer secret-token");
  assert.doesNotMatch(await fsp.readFile(out, "utf8"), /secret-token/);
});
