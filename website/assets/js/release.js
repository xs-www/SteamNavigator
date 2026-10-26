// @static-doc
// 作用：官网版本信息填充脚本：读取 `assets/data/release-data.js`（由 `tools/build-release-data.mjs` 从 GitHub Releases 生成），
// 把下载页 / 开发日志页里的版本号、发布日期、文件大小、状态文案与下载链接替换为当前最新 release。
//
// ## 契约与约束
// - 不请求网络：数据由构建/部署前的生成器写入静态 JS；页面断网也能显示已生成的版本信息。
// - 只做 `textContent` / `href` 赋值，不插入 HTML（GitHub 的 tag / 名称按纯文本处理，避免注入）。
// - 找不到数据、字段为 null 或元素不存在时保持页面原有静态 fallback 文案，不隐藏内容、不报错。
// - 约定属性：`data-release="tag|date|state|windows-size|linux-size|banner-note"` 填文本；
//   `data-release-link="releases|windows|linux|checksums"` 填链接。契约见 `docs/design/WEBSITE.md` §2/§7。
//
// ## 重点逻辑
// ### 填充
// - 版本：`latest.tag`；日期：`latest.date`（GitHub `published_at` 的 UTC 日期）；状态：预发布 / 正式版。
// - 大小：字节 → `约 N MB`（四舍五入，0/缺失时保留原文案）。
// - 链接：只使用 release 的真实 asset 直链；缺失的平台保持原静态 href。
// @end-static-doc

(function () {
  "use strict";

  var data = window.SN_RELEASE_DATA;
  if (!data || !data.latest) return;

  var latest = data.latest;
  var links = data.links || {};

  function formatSize(bytes) {
    var value = Number(bytes);
    if (!isFinite(value) || value <= 0) return "";
    var mb = value / (1024 * 1024);
    if (mb >= 10) return "约 " + Math.round(mb) + " MB";
    return "约 " + mb.toFixed(1) + " MB";
  }

  function textFor(key) {
    switch (key) {
      case "tag":
        return latest.tag || "";
      case "date":
        return latest.date || "";
      case "state":
        return latest.prerelease ? "预发布" : "正式版";
      case "windows-size":
        return formatSize(assetSize(/-windows\.zip$/i));
      case "linux-size":
        return formatSize(assetSize(/-linux\.zip$/i));
      case "banner-note":
        return latest.prerelease
          ? "当前为公开开发版本，系统仍在打磨，内容与平衡会继续调整。"
          : "当前为正式版本，内容与平衡按发布说明为准。";
      default:
        return "";
    }
  }

  function assetSize(pattern) {
    var assets = latest.assets || [];
    for (var index = 0; index < assets.length; index += 1) {
      if (pattern.test(assets[index].name || "")) return assets[index].size;
    }
    return 0;
  }

  function applyText() {
    var nodes = document.querySelectorAll("[data-release]");
    for (var index = 0; index < nodes.length; index += 1) {
      var node = nodes[index];
      var value = textFor(node.getAttribute("data-release"));
      if (value) node.textContent = value;
    }
  }

  function applyLinks() {
    var nodes = document.querySelectorAll("[data-release-link]");
    for (var index = 0; index < nodes.length; index += 1) {
      var node = nodes[index];
      var key = node.getAttribute("data-release-link");
      var href = typeof links[key] === "string" ? links[key] : "";
      if (href) node.setAttribute("href", href);
    }
  }

  applyText();
  applyLinks();
})();
