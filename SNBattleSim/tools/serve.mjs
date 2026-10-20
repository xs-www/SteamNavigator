// @static-doc
// 作用：以零依赖本地 HTTP 服务启动 SNBattleSim，避免浏览器 file 协议阻止 ES 模块加载。
//
// ## 契约与约束
// - 只允许读取 SNBattleSim 目录内的已存在文件，路径解析后越界直接返回 403。
// - 默认监听 127.0.0.1:4174，可用 PORT 环境变量覆盖端口。
// @end-static-doc

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const port = Number(process.env.PORT) || 4174;
const mime = { ".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8", ".mjs": "text/javascript; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".json": "application/json; charset=utf-8" };

const server = http.createServer((request, response) => {
  const rawPath = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
  const relative = rawPath === "/" ? "index.html" : rawPath.replace(/^\/+/, "");
  const target = path.resolve(root, relative);
  if (target !== root && !target.startsWith(root + path.sep)) {
    response.writeHead(403).end("Forbidden"); return;
  }
  if (!fs.existsSync(target) || !fs.statSync(target).isFile()) {
    response.writeHead(404).end("Not found"); return;
  }
  response.writeHead(200, { "Content-Type": mime[path.extname(target)] || "application/octet-stream", "Cache-Control": "no-store" });
  fs.createReadStream(target).pipe(response);
});

server.listen(port, "127.0.0.1", () => {
  console.log(`SNBattleSim: http://127.0.0.1:${port}`);
});
