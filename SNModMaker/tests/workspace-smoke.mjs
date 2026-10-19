#!/usr/bin/env node
/* Native workspace smoke test: open dev_mods/<id> in place, delete and add
 * definitions/files through the same payload the browser editor sends. */
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const repoRoot = process.cwd();
const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'snmodmaker-workspace-'));
const workspaceRoot = path.join(tempRoot, 'dev_mods');
const coreDir = path.join(workspaceRoot, 'core');
const modsDir = path.join(tempRoot, 'projects');
const exportsDir = path.join(tempRoot, 'exports');
const gameModsDir = path.join(tempRoot, 'game-mods');
const port = 18000 + Math.floor(Math.random() * 10000);
const base = `http://127.0.0.1:${port}`;

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

writeJson(path.join(coreDir, 'manifest.json'), {
  id: 'core',
  name: 'Smoke Core',
  version: '1.0.0',
  api_version: '1.0',
  type: 'content',
  required: true,
  content: ['content/goods.json', 'content/events.json'],
  localization: ['localization/zh_CN.json'],
  assets: { 'model.test': 'assets/models/SN_Test.glb' },
  dependencies: [],
});
writeJson(path.join(coreDir, 'content/goods.json'), {
  schema_version: '1.0',
  content_type: 'goods',
  definitions: [
    { id: 'core:good/keep', name_key: 'good.keep.name', enabled: true, data: { base_price: 10 } },
    { id: 'core:good/drop', name_key: 'good.drop.name', enabled: true, data: { base_price: 20 } },
  ],
});
writeJson(path.join(coreDir, 'content/events.json'), {
  schema_version: '1.0',
  content_type: 'events',
  definitions: [{ id: 'core:event/old', name_key: 'event.old.name', enabled: true, data: { trigger: 'voyage_risk', category: 'mechanical', options: [] } }],
});
writeJson(path.join(coreDir, 'localization/zh_CN.json'), { 'good.keep.name': '淇濈暀', 'good.drop.name': '鍒犻櫎' });
fs.mkdirSync(path.join(coreDir, 'assets/models'), { recursive: true });
fs.writeFileSync(path.join(coreDir, 'assets/models/SN_Test.glb'), 'raw-glb-bytes');

const child = spawn(process.execPath, ['SNModMaker/tools/serve.mjs', String(port)], {
  cwd: repoRoot,
  env: {
    ...process.env,
    SNMODMAKER_MODS_DIR: modsDir,
    SNMODMAKER_EXPORTS_DIR: exportsDir,
    SNMODMAKER_GAME_MODS_DIR: gameModsDir,
    SNMODMAKER_WORKSPACE_ROOT: workspaceRoot,
  },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let serverOutput = '';
child.stdout.on('data', (chunk) => { serverOutput += chunk.toString(); });
child.stderr.on('data', (chunk) => { serverOutput += chunk.toString(); });

async function waitForServer() {
  const deadline = Date.now() + 8000;
  while (Date.now() < deadline) {
    if (child.exitCode != null) throw new Error(`server exited with ${child.exitCode}`);
    try {
      const response = await fetch(`${base}/api/status`);
      if (response.ok) return response.json();
    } catch (error) {
      /* still starting */
    }
    await new Promise((resolve) => setTimeout(resolve, 80));
  }
  throw new Error(`server did not become ready${serverOutput ? `: ${serverOutput.trim()}` : ''}`);
}

const api = async (url, options) => {
  const response = await fetch(`${base}${url}`, options);
  let data = null;
  try { data = await response.json(); } catch (error) { data = null; }
  return { response, data };
};

try {
  const status = await waitForServer();
  assert.ok(status.workspaceDir, 'status exposes the workspace root');

  let { data: listing } = await api('/api/projects');
  const coreRow = (listing.projects || []).find((row) => row.id === 'core');
  assert.ok(coreRow, 'workspace core appears in the project list');
  assert.equal(coreRow.workspace, true);
  assert.equal(coreRow.definitions, 3);

  const opened = await api('/api/workspace/core');
  assert.equal(opened.response.status, 200);
  const project = opened.data.project;
  assert.equal(project.contentFiles.length, 2);
  assert.equal(project.assets[0].dataUrl, '', 'workspace assets stay on disk (no binary round-trip)');

  // Delete one definition, add another, add a new content file.
  const goods = project.contentFiles.find((file) => file.content_type === 'goods');
  goods.definitions = goods.definitions.filter((definition) => definition.id !== 'core:good/drop');
  goods.definitions.push({ id: 'core:good/new', name_key: 'good.new.name', enabled: true, data: { base_price: 30 } });
  project.contentFiles.push({ path: 'content/materials.json', content_type: 'materials', schema_version: '1.0', definitions: [{ id: 'core:material/new', name_key: 'material.new.name', enabled: true, data: {} }] });
  project.manifest.content.push('content/materials.json');

  const files = [
    { path: 'manifest.json', encoding: 'utf8', data: `${JSON.stringify(project.manifest, null, 2)}\n` },
    { path: goods.path, encoding: 'utf8', data: `${JSON.stringify({ schema_version: '1.0', content_type: 'goods', definitions: goods.definitions }, null, 2)}\n` },
    { path: 'content/materials.json', encoding: 'utf8', data: `${JSON.stringify({ schema_version: '1.0', content_type: 'materials', definitions: project.contentFiles.find((file) => file.content_type === 'materials').definitions }, null, 2)}\n` },
  ];
  const saved = await api('/api/workspace/core', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ project, files }),
  });
  assert.equal(saved.response.status, 200, JSON.stringify(saved.data));
  assert.equal(saved.data.workspace, true);

  const goodsOnDisk = JSON.parse(fs.readFileSync(path.join(coreDir, 'content/goods.json'), 'utf8'));
  assert.deepEqual(goodsOnDisk.definitions.map((definition) => definition.id), ['core:good/keep', 'core:good/new']);
  assert.ok(fs.existsSync(path.join(coreDir, 'content/materials.json')), 'new content file is written');
  assert.equal(fs.readFileSync(path.join(coreDir, 'assets/models/SN_Test.glb'), 'utf8'), 'raw-glb-bytes', 'assets are never rewritten');

  // Removing a declared localization file from the manifest deletes it on disk.
  const reopened = await api('/api/workspace/core');
  const update = reopened.data.project;
  update.manifest.localization = [];
  const removal = await api('/api/workspace/core', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      project: update,
      files: [{ path: 'manifest.json', encoding: 'utf8', data: `${JSON.stringify(update.manifest, null, 2)}\n` }],
    }),
  });
  assert.equal(removal.response.status, 200);
  assert.equal(fs.existsSync(path.join(coreDir, 'localization/zh_CN.json')), false, 'dropped localization file is removed');

  const deleted = await api('/api/workspace/core', { method: 'DELETE' });
  assert.equal(deleted.response.status, 400, 'workspace root cannot be deleted from the editor');

  console.log('[PASS] native workspace opens dev_mods/core, saves deletes/additions and leaves assets untouched');
} finally {
  child.kill();
  fs.rmSync(tempRoot, { recursive: true, force: true });
}

