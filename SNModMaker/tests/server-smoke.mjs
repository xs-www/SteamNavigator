#!/usr/bin/env node
/* Local disk API smoke test, including overwrite deployment to game mods. */
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const workspace = process.cwd();
const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'snmodmaker-server-'));
const modsDir = path.join(tempRoot, 'projects');
const exportsDir = path.join(tempRoot, 'exports');
const gameModsDir = path.join(tempRoot, 'game-mods');
const port = 18000 + Math.floor(Math.random() * 10000);
const base = `http://127.0.0.1:${port}`;
const child = spawn(process.execPath, ['SNModMaker/tools/serve.mjs', String(port)], {
  cwd: workspace,
  env: {
    ...process.env,
    SNMODMAKER_MODS_DIR: modsDir,
    SNMODMAKER_EXPORTS_DIR: exportsDir,
    SNMODMAKER_GAME_MODS_DIR: gameModsDir,
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
      /* server is still starting */
    }
    await new Promise((resolve) => setTimeout(resolve, 80));
  }
  throw new Error(`server did not become ready${serverOutput ? `: ${serverOutput.trim()}` : ''}`);
}

try {
  const status = await waitForServer();
  assert.equal(status.ok, true);
  assert.ok(status.gameModsDir);

  fs.writeFileSync(path.join(gameModsDir, 'smoke_mod-0.1.0.snavmod.zip'), 'old');
  let response = await fetch(`${base}/api/game-mods/smoke_mod`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/octet-stream' },
    body: Buffer.from('first-package'),
  });
  let result = await response.json();
  assert.equal(response.status, 200);
  assert.equal(result.name, 'smoke_mod.snavmod.zip');
  assert.equal(result.removed, 1);

  response = await fetch(`${base}/api/game-mods/smoke_mod`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/octet-stream' },
    body: Buffer.from('replacement-package'),
  });
  result = await response.json();
  assert.equal(response.status, 200);
  assert.equal(fs.readFileSync(path.join(gameModsDir, result.name), 'utf8'), 'replacement-package');

  const listing = await (await fetch(`${base}/api/game-mods`)).json();
  assert.deepEqual(listing.mods.map((entry) => entry.name), ['smoke_mod.snavmod.zip']);

  response = await fetch(`${base}/api/game-mods/smoke_mod`, { method: 'DELETE' });
  assert.equal(response.status, 200);
  assert.equal(fs.existsSync(path.join(gameModsDir, 'smoke_mod.snavmod.zip')), false);
  console.log('[PASS] local server deploys, overwrites, lists and removes a game mod package');
} finally {
  child.kill();
  fs.rmSync(tempRoot, { recursive: true, force: true });
}
