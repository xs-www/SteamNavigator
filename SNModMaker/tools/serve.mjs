#!/usr/bin/env node
/**
 * Local server for the Mod Maker.
 *
 * Serves the static app and exposes a tiny same-origin API so the browser can
 * persist projects under SNModMaker/mods/ and write packaged ZIPs to
 * SNModMaker/exports/. The app detects /api/status and falls back to IndexedDB
 * when this server is not used.
 *
 *   node SNModMaker/tools/serve.mjs [port]
 *
 * Environment overrides (useful for tests):
 *   SNMODMAKER_MODS_DIR, SNMODMAKER_EXPORTS_DIR
 */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const port = Number(process.argv[2] || process.env.PORT || 8099);

const resolveDataDir = (value, fallback) => {
  const target = value ? path.resolve(value) : path.join(root, fallback);
  fs.mkdirSync(target, { recursive: true });
  return target;
};
const MODS_DIR = resolveDataDir(process.env.SNMODMAKER_MODS_DIR, 'mods');
const EXPORTS_DIR = resolveDataDir(process.env.SNMODMAKER_EXPORTS_DIR, 'exports');
const MAX_BODY = 128 * 1024 * 1024;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.map': 'application/json',
  '.zip': 'application/zip',
};

function sendJson(response, status, body) {
  const data = Buffer.from(JSON.stringify(body));
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': data.length,
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  response.end(data);
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    request.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY) {
        reject(Object.assign(new Error('请求体超过 128 MB 限制'), { status: 413 }));
        request.destroy();
        return;
      }
      chunks.push(chunk);
    });
    request.on('end', () => resolve(Buffer.concat(chunks)));
    request.on('error', reject);
  });
}

const isModId = (value) => /^[a-z][a-z0-9_]{2,31}$/.test(String(value || ''));

function safeRelative(value) {
  const clean = String(value || '').replace(/\\/g, '/').replace(/^\/+/, '');
  if (!clean || clean.includes(':') || clean.includes('\0') || clean.length > 240) return '';
  const parts = clean.split('/');
  if (parts.length > 16 || parts.some((part) => !part || part === '.' || part === '..')) return '';
  return clean;
}

function projectDir(id) {
  return path.join(MODS_DIR, id);
}

function projectFile(id) {
  return path.join(projectDir(id), '.snmodproj.json');
}

function listProjects() {
  const rows = [];
  for (const entry of fs.readdirSync(MODS_DIR, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name.startsWith('.')) continue;
    if (!isModId(entry.name)) continue;
    const dir = path.join(MODS_DIR, entry.name);
    const file = path.join(dir, '.snmodproj.json');
    try {
      if (!fs.existsSync(file)) continue;
      const stat = fs.statSync(file);
      const project = JSON.parse(fs.readFileSync(file, 'utf8'));
      const manifest = project.manifest || {};
      const definitions = (project.contentFiles || []).reduce((sum, content) => sum + (content.definitions || []).length, 0);
      rows.push({
        uid: project.uid || `disk-${entry.name}`,
        id: manifest.id || entry.name,
        name: manifest.name || entry.name,
        version: manifest.version || '',
        updatedAt: (project.meta && project.meta.updatedAt) || stat.mtime.toISOString(),
        definitions,
        hasProject: true,
        dir: entry.name,
      });
    } catch (error) {
      /* skip unreadable projects */
    }
  }
  rows.sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));
  return rows;
}

function saveProject(id, payload) {
  if (!isModId(id)) throw Object.assign(new Error('非法模组 ID'), { status: 400 });
  const project = payload && payload.project;
  const files = payload && payload.files;
  if (!project || typeof project !== 'object' || !Array.isArray(files)) {
    throw Object.assign(new Error('缺少 project 或 files'), { status: 400 });
  }
  if (!project.manifest || project.manifest.id !== id) {
    throw Object.assign(new Error('project.manifest.id 与路径不一致'), { status: 400 });
  }
  if (files.length > 2000) throw Object.assign(new Error('文件数量过多'), { status: 400 });

  const target = projectDir(id);
  const temp = path.join(MODS_DIR, `.${id}.tmp-${process.pid}-${Date.now()}`);
  try {
    fs.mkdirSync(temp, { recursive: true });
    for (const entry of files) {
      const relative = safeRelative(entry && entry.path);
      if (!relative) throw Object.assign(new Error(`非法文件路径: ${entry && entry.path}`), { status: 400 });
      const absolute = path.join(temp, relative);
      if (!absolute.startsWith(temp + path.sep)) throw Object.assign(new Error('路径越界'), { status: 400 });
      fs.mkdirSync(path.dirname(absolute), { recursive: true });
      const data = entry.encoding === 'base64' ? Buffer.from(String(entry.data || ''), 'base64') : String(entry.data == null ? '' : entry.data);
      fs.writeFileSync(absolute, data);
    }
    fs.writeFileSync(path.join(temp, '.snmodproj.json'), JSON.stringify(project, null, 2));
    fs.rmSync(target, { recursive: true, force: true });
    fs.renameSync(temp, target);
    return { id, files: files.length };
  } catch (error) {
    fs.rmSync(temp, { recursive: true, force: true });
    throw error;
  }
}

function listExports() {
  const rows = [];
  for (const entry of fs.readdirSync(EXPORTS_DIR, { withFileTypes: true })) {
    if (!entry.isFile()) continue;
    if (!/\.(zip|json|snavmod\.zip)$/i.test(entry.name)) continue;
    const stat = fs.statSync(path.join(EXPORTS_DIR, entry.name));
    rows.push({ name: entry.name, size: stat.size, updatedAt: stat.mtime.toISOString() });
  }
  rows.sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));
  return rows;
}

function safeExportName(value) {
  const name = path.basename(String(value || '').replace(/\\/g, '/'));
  if (!name || name.startsWith('.') || !/\.(zip|json)$/i.test(name)) return '';
  return name;
}

async function handleApi(request, response, url) {
  const parts = url.pathname.split('/').filter(Boolean); // ["api", ...]
  const method = request.method || 'GET';

  if (url.pathname === '/api/status' && method === 'GET') {
    sendJson(response, 200, {
      ok: true,
      modsDir: path.relative(root, MODS_DIR).replaceAll('\\', '/') || 'mods',
      exportsDir: path.relative(root, EXPORTS_DIR).replaceAll('\\', '/') || 'exports',
    });
    return;
  }

  if (url.pathname === '/api/projects' && method === 'GET') {
    sendJson(response, 200, { ok: true, projects: listProjects() });
    return;
  }

  if (parts[1] === 'projects' && parts[2]) {
    const id = decodeURIComponent(parts[2]);
    if (!isModId(id)) {
      sendJson(response, 400, { ok: false, error: '非法模组 ID' });
      return;
    }
    if (method === 'GET') {
      const file = projectFile(id);
      if (!fs.existsSync(file)) {
        sendJson(response, 404, { ok: false, error: '项目不存在' });
        return;
      }
      try {
        const project = JSON.parse(fs.readFileSync(file, 'utf8'));
        sendJson(response, 200, { ok: true, project });
      } catch (error) {
        sendJson(response, 500, { ok: false, error: `项目文件损坏: ${error.message}` });
      }
      return;
    }
    if (method === 'PUT') {
      try {
        const body = await readBody(request);
        const payload = JSON.parse(body.toString('utf8'));
        const result = saveProject(id, payload);
        sendJson(response, 200, { ok: true, ...result });
      } catch (error) {
        sendJson(response, error.status || 500, { ok: false, error: error.message });
      }
      return;
    }
    if (method === 'DELETE') {
      try {
        fs.rmSync(projectDir(id), { recursive: true, force: true });
        sendJson(response, 200, { ok: true });
      } catch (error) {
        sendJson(response, 500, { ok: false, error: error.message });
      }
      return;
    }
  }

  if (url.pathname === '/api/exports' && method === 'GET') {
    sendJson(response, 200, { ok: true, exports: listExports() });
    return;
  }

  if (url.pathname === '/api/exports' && method === 'POST') {
    const name = safeExportName(url.searchParams.get('filename'));
    if (!name) {
      sendJson(response, 400, { ok: false, error: '非法文件名（需要 .zip 或 .json）' });
      return;
    }
    try {
      const body = await readBody(request);
      const target = path.join(EXPORTS_DIR, name);
      fs.writeFileSync(target, body);
      sendJson(response, 200, { ok: true, name, size: body.length });
    } catch (error) {
      sendJson(response, error.status || 500, { ok: false, error: error.message });
    }
    return;
  }

  if (parts[1] === 'exports' && parts[2] && method === 'DELETE') {
    const name = safeExportName(decodeURIComponent(parts[2]));
    if (!name) {
      sendJson(response, 400, { ok: false, error: '非法文件名' });
      return;
    }
    try {
      fs.rmSync(path.join(EXPORTS_DIR, name), { force: true });
      sendJson(response, 200, { ok: true });
    } catch (error) {
      sendJson(response, 500, { ok: false, error: error.message });
    }
    return;
  }

  sendJson(response, 404, { ok: false, error: 'Not found' });
}

const server = http.createServer(async (request, response) => {
  try {
    const url = new URL(request.url, 'http://localhost');
    if (url.pathname.startsWith('/api/')) {
      await handleApi(request, response, url);
      return;
    }

    const urlPath = decodeURIComponent(url.pathname);
    const relative = urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, '');
    const absolute = path.resolve(root, relative);
    if (!absolute.startsWith(root + path.sep) && absolute !== root) {
      response.writeHead(403).end('Forbidden');
      return;
    }
    const stat = fs.statSync(absolute);
    if (stat.isDirectory()) {
      const index = path.join(absolute, 'index.html');
      if (fs.existsSync(index)) {
        response.writeHead(302, { Location: `${urlPath.replace(/\/?$/, '/')}index.html` }).end();
        return;
      }
      response.writeHead(404).end('Not found');
      return;
    }
    const data = fs.readFileSync(absolute);
    response.writeHead(200, {
      'Content-Type': MIME[path.extname(absolute).toLowerCase()] || 'application/octet-stream',
      'Content-Length': data.length,
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    });
    response.end(data);
  } catch (error) {
    response.writeHead(404).end('Not found');
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`Steam Navigator Mod Maker: http://127.0.0.1:${port}/`);
  console.log(`Static: ${root}`);
  console.log(`Projects: ${MODS_DIR}`);
  console.log(`Exports:  ${EXPORTS_DIR}`);
});
