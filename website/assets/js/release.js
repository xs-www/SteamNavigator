// @static-doc
// 作用：官网版本信息填充脚本：先用构建期生成的 `assets/data/release-data.js` 立即填充下载页 / 开发日志页，
// 再异步请求同域 `/api/site/release`（服务端缓存 GitHub Releases）刷新到最新版本；API 不可用时静默保留静态值。
//
// ## 契约与约束
// - 静态数据优先渲染：断网 / API 未部署 / 纯静态托管时页面仍有可用版本信息。
// - Windows 下载优先使用后端镜像：API 的 `data.downloads.windows.available` 为真时用 `/downloads/<tag>/...`，
//   否则回退 `data.links.windows`（GitHub）；镜像目录只保留最新版本，历史版本始终走 GitHub。
// - 只做 `textContent` / `href` 赋值，不插入 HTML（tag / 名称按纯文本处理，避免注入）。
// - 找不到数据、字段为 null 或元素不存在时保持页面原有静态 fallback 文案，不隐藏内容、不报错。
// - 约定属性：`data-release="tag|date|state|windows-size|linux-size|banner-note"` 填文本；
//   `data-release-link="releases|windows|linux|checksums"` 填链接。契约见 `docs/design/WEBSITE.md` §2/§7。
//
// ## 重点逻辑
// ### 静态 → API 两段式
// - 首屏用 `window.SN_RELEASE_DATA`；随后 `fetch("/api/site/release", {cache:"no-cache"})`，
//   成功则用响应里的 `data`（与静态文件同构）重新填充，实现「发布 Release 后网站自动更新」。
// ### 填充
// - 版本：`latest.tag`；状态：预发布 / 正式版；大小：字节 → `约 N MB`。
// - 日期：优先把 `published_at`（UTC）按**访客本地时区**格式化成 `YYYY-MM-DD`；
//   解析失败时退回 `latest.date`（生成器按站点时区算好的日历日），再不行保留静态文案。
// - 链接：只使用 release 的真实 asset 直链；缺失的平台保持原静态 href。
// @end-static-doc

(function () {
  "use strict";

  function formatSize(bytes) {
    var value = Number(bytes);
    if (!isFinite(value) || value <= 0) return "";
    var mb = value / (1024 * 1024);
    if (mb >= 10) return "约 " + Math.round(mb) + " MB";
    return "约 " + mb.toFixed(1) + " MB";
  }

  function assetSize(latest, pattern) {
    var assets = latest.assets || [];
    for (var index = 0; index < assets.length; index += 1) {
      if (pattern.test(assets[index].name || "")) return assets[index].size;
    }
    return 0;
  }

  function formatLocalDate(latest) {
    var published = latest && latest.published_at;
    if (typeof published === "string" && published) {
      var time = Date.parse(published);
      if (!isNaN(time)) {
        var date = new Date(time);
        var month = String(date.getMonth() + 1);
        var day = String(date.getDate());
        if (month.length < 2) month = "0" + month;
        if (day.length < 2) day = "0" + day;
        return date.getFullYear() + "-" + month + "-" + day;
      }
    }
    return (latest && latest.date) || "";
  }

  function textFor(latest, key) {
    switch (key) {
      case "tag":
        return latest.tag || "";
      case "date":
        return formatLocalDate(latest);
      case "state":
        return latest.prerelease ? "预发布" : "正式版";
      case "windows-size":
        return formatSize(assetSize(latest, /-windows\.zip$/i));
      case "linux-size":
        return formatSize(assetSize(latest, /-linux\.zip$/i));
      case "banner-note":
        return latest.prerelease
          ? "当前为公开开发版本，系统仍在打磨，内容与平衡会继续调整。"
          : "当前为正式版本，内容与平衡按发布说明为准。";
      default:
        return "";
    }
  }

  function applyData(data) {
    if (!data || !data.latest) return false;
    var latest = data.latest;
    var links = {};
    var sourceLinks = data.links || {};
    for (var key in sourceLinks) {
      if (Object.prototype.hasOwnProperty.call(sourceLinks, key)) links[key] = sourceLinks[key];
    }
    // 后端已镜像最新 Windows zip 时优先本地地址；否则（含历史/未就绪）回退 GitHub 直链。
    var mirrored = data.downloads && data.downloads.windows;
    if (mirrored && mirrored.available && mirrored.url) links.windows = mirrored.url;

    var nodes = document.querySelectorAll("[data-release]");
    for (var index = 0; index < nodes.length; index += 1) {
      var node = nodes[index];
      var value = textFor(latest, node.getAttribute("data-release"));
      if (value) node.textContent = value;
    }

    var linkNodes = document.querySelectorAll("[data-release-link]");
    for (var linkIndex = 0; linkIndex < linkNodes.length; linkIndex += 1) {
      var linkNode = linkNodes[linkIndex];
      var href = links[linkNode.getAttribute("data-release-link")];
      if (typeof href === "string" && href) linkNode.setAttribute("href", href);
    }
    return true;
  }

  function refreshFromApi() {
    if (typeof fetch !== "function") return;
    fetch("/api/site/release", { cache: "no-cache", headers: { Accept: "application/json" } })
      .then(function (response) {
        return response.ok ? response.json() : null;
      })
      .then(function (body) {
        if (body && body.ok && body.data) applyData(body.data);
      })
      .catch(function () {
        // 静态数据已经渲染；API 不可用时静默降级。
      });
  }

  applyData(window.SN_RELEASE_DATA);
  refreshFromApi();
})();
