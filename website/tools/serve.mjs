// @static-doc
// 作用：零依赖本地静态预览服务器，用于开发与验收官网（不对公网部署）；同时挂载游玩数据接收端方便游戏端联调。
//
// ## 契约与约束
// - 只读服务 website/ 目录；禁止路径穿越与目录列表。
// - 根路径与目录路径自动回退到 index.html；未知文件返回 404。
// - 仅用于本地预览（默认 127.0.0.1:4173），生产环境交给 `deploy/` 的 nginx + telemetry 容器。
// - 输出中文页面使用 UTF-8 Content-Type；不注入构建步骤。
// - `/api/telemetry/*` 交给 `server/telemetry.mjs` 的同一 handler（契约见 `docs/design/TELEMETRY.md` §4），
//   本地数据写 `website/.data/telemetry/`（已 gitignore），不进入静态文件服务。
//
// ## 重点逻辑
// ### 路径解析
// - 先 decodeURIComponent，再 path.resolve 到站点根，并用 path.relative 判断是否越界。
// ### 缓存
// - 预览服务器固定 `Cache-Control: no-cache`，避免改完 CSS/JS 后浏览器仍读旧文件。
// ### 接收端
// - 在方法检查之前按路径前缀分派，POST 只对 `/api/telemetry/*` 放行；其它路径仍只允许 GET / HEAD。
// - `SN_TELEMETRY_TOKEN` 非空时，本地接收端同样要求 `X-SN-Telemetry-Token`。
// @end-static-doc

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { createTelemetryHandler } from "../server/telemetry.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const HOST = process.env.HOST || "127.0.0.1";
const PORT = Number(process.argv[2] || process.env.PORT || 4173);
const TELEMETRY_PREFIX = "/api/telemetry";
const TELEMETRY_DATA_DIR = path.join(ROOT, ".data", "telemetry");

const telemetry = createTelemetryHandler({
  dataDir: TELEMETRY_DATA_DIR,
  token: process.env.SN_TELEMETRY_TOKEN || "",
});

const MIME = new Map([
  [".html", "text/html; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".mjs", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".svg", "image/svg+xml"],
  [".jpg", "image/jpeg"],
  [".jpeg", "image/jpeg"],
  [".png", "image/png"],
  [".webp", "image/webp"],
  [".ico", "image/x-icon"],
  [".txt", "text/plain; charset=utf-8"],
  [".woff2", "font/woff2"],
]);

const server = http.createServer((req, res) => {
  let pathname;
  try {
    pathname = decodeURIComponent(new URL(req.url, `http://${HOST}:${PORT}`).pathname);
  } catch {
    res.writeHead(400, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Bad Request");
    return;
  }

  if (pathname === TELEMETRY_PREFIX || pathname.startsWith(`${TELEMETRY_PREFIX}/`)) {
    telemetry(req, res).catch((error) => {
      console.error(`telemetry handler failure: ${error.message}`);
      if (!res.headersSent && !res.writableEnded) {
        res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
        res.end('{"ok":false,"error":"internal_error"}');
      } else if (!res.writableEnded) {
        res.end();
      }
    });
    return;
  }

  if (req.method !== "GET" && req.method !== "HEAD") {
    res.writeHead(405, { Allow: "GET, HEAD" });
    res.end("Method Not Allowed");
    return;
  }

  let target = path.resolve(ROOT, "." + pathname);
  const relative = path.relative(ROOT, target);
  if (relative.startsWith("..") || path.isAbsolute(relative)) {
    res.writeHead(403, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Forbidden");
    return;
  }

  try {
    if (!fs.existsSync(target)) {
      res.writeHead(404, { "Content-Type": "text/html; charset=utf-8" });
      res.end("<!doctype html><meta charset=\"utf-8\"><title>404</title><p>404 · 页面不存在</p>");
      return;
    }
    if (fs.statSync(target).isDirectory()) {
      target = path.join(target, "index.html");
      if (!fs.existsSync(target)) {
        res.writeHead(404, { "Content-Type": "text/html; charset=utf-8" });
        res.end("<!doctype html><meta charset=\"utf-8\"><title>404</title><p>404 · 页面不存在</p>");
        return;
      }
    }

    const data = fs.readFileSync(target);
    const type = MIME.get(path.extname(target).toLowerCase()) || "application/octet-stream";
    res.writeHead(200, {
      "Content-Type": type,
      "Content-Length": data.length,
      "Cache-Control": "no-cache",
      "Content-Language": "zh-CN",
      "X-Content-Type-Options": "nosniff",
    });
    if (req.method === "HEAD") res.end();
    else res.end(data);
  } catch (error) {
    res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
    res.end(`Internal Server Error: ${error.message}`);
  }
});

server.on("error", (error) => {
  if (error.code === "EADDRINUSE") {
    console.error(`端口 ${PORT} 已被占用，换一个：node website/tools/serve.mjs 4174`);
  } else {
    console.error(error);
  }
  process.exitCode = 1;
});

server.listen(PORT, HOST, () => {
  console.log(`Steam Navigator 官网预览：http://${HOST}:${PORT}/`);
  console.log(`站点目录：${ROOT}`);
  console.log(`游玩数据接收端：http://${HOST}:${PORT}/api/telemetry/health`);
  console.log(`本地数据目录：${TELEMETRY_DATA_DIR}`);
});
