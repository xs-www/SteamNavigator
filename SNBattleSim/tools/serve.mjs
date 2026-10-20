// @static-doc
// 作用：以零依赖本地 HTTP 服务启动 SNBattleSim，避免浏览器 file 协议阻止 ES 模块加载。
//
// ## 契约与约束
// - 静态文件只能读取 SNBattleSim 内路径；模组 API 可读取直接子目录和 ZIP，并导出 .snavmod.zip。
// - 默认监听 127.0.0.1:4174，可用 PORT 环境变量覆盖端口。
// @end-static-doc

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { readModPackages, writeModArchive } from "./mod_io.mjs";
import { readWorkspace, writeWorkspace } from "./workspace_io.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const port = Number(process.env.PORT) || 4174;
const modsRoot = path.join(root, "mods");
const userDataRoot = path.join(root, "user_data");
const mime = { ".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8", ".mjs": "text/javascript; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".json": "application/json; charset=utf-8" };

function json(response, status, value) { response.writeHead(status, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" }).end(JSON.stringify(value)); }
function readBody(request) { return new Promise((resolve, reject) => { let body = ""; request.on("data", (chunk) => { body += chunk; if (body.length > 5_000_000) reject(new Error("请求体超过 5MB")); }); request.on("end", () => resolve(body)); request.on("error", reject); }); }

const server = http.createServer(async (request, response) => {
  const rawPath = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
  if (rawPath === "/api/mods" && request.method === "GET") { json(response, 200, { packages: readModPackages(modsRoot) }); return; }
  if (rawPath === "/api/workspace" && request.method === "GET") {
    try { json(response, 200, { workspace: readWorkspace(userDataRoot) }); } catch (error) { json(response, 400, { error: error.message }); } return;
  }
  if (rawPath === "/api/workspace" && request.method === "PUT") {
    try { const target = writeWorkspace(userDataRoot, JSON.parse(await readBody(request))); json(response, 200, { ok: true, file: path.relative(root, target).replaceAll(path.sep, "/") }); }
    catch (error) { json(response, 400, { ok: false, error: error.message }); } return;
  }
  if (rawPath === "/api/mods/export" && request.method === "POST") {
    try { const bundle = JSON.parse(await readBody(request)); const target = writeModArchive(modsRoot, bundle); json(response, 201, { ok: true, directory: path.relative(root, target).replaceAll(path.sep, "/") }); }
    catch (error) { json(response, 400, { ok: false, error: error.message }); }
    return;
  }
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
