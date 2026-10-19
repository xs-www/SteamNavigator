#!/usr/bin/env node
/*
 * Browser smoke test over the Chrome DevTools Protocol.
 *
 * Zero npm dependencies: uses Node's built-in fetch + WebSocket and a Chrome
 * started with --remote-debugging-port=9222.
 *
 *   node SNModMaker/tests/browser-smoke.mjs [url] [screenshot.png]
 */
import fs from 'node:fs';
import path from 'node:path';

const url = process.argv[2] || 'http://127.0.0.1:8099/';
const screenshotPath = process.argv[3] || path.join(process.env.TEMP || '.', 'snmod-smoke.png');
const devtools = 'http://127.0.0.1:9222';

const consoleErrors = [];
let passed = 0;
let failed = 0;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

class CDP {
  constructor(wsUrl) {
    this.id = 0;
    this.pending = new Map();
    this.ws = new WebSocket(wsUrl);
    this.ready = new Promise((resolve, reject) => {
      this.ws.onopen = resolve;
      this.ws.onerror = reject;
    });
    this.ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.id) {
        const entry = this.pending.get(message.id);
        if (!entry) return;
        this.pending.delete(message.id);
        if (message.error) entry.reject(new Error(message.error.message));
        else entry.resolve(message.result);
        return;
      }
      if (message.method === 'Runtime.exceptionThrown') {
        const details = message.params.exceptionDetails;
        const text = details.exception?.description || details.text || 'exception';
        const frames = (details.stackTrace?.callFrames || [])
          .slice(0, 5)
          .map((frame) => `${frame.functionName || '(anon)'}@${frame.url}:${frame.lineNumber + 1}`)
          .join(' <- ');
        consoleErrors.push(`${text.split('\n')[0]} | ${frames}`);
      }
      if (message.method === 'Runtime.consoleAPICalled' && ['error', 'warning'].includes(message.params.type)) {
        consoleErrors.push(message.params.args.map((arg) => arg.value ?? arg.description ?? '').join(' '));
      }
    };
  }

  async send(method, params) {
    await this.ready;
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params: params || {} }));
    });
  }

  async eval(expression) {
    const result = await this.send('Runtime.evaluate', {
      expression,
      awaitPromise: true,
      returnByValue: true,
      userGesture: true,
      replMode: false,
    });
    if (result.exceptionDetails) {
      throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text);
    }
    return result.result ? result.result.value : undefined;
  }
}

async function waitFor(cdp, expression, timeoutMs, label) {
  const deadline = Date.now() + (timeoutMs || 12000);
  while (Date.now() < deadline) {
    const value = await cdp.eval(expression);
    if (value) return value;
    await sleep(120);
  }
  throw new Error(`timeout waiting for ${label || expression}`);
}

async function check(name, fn) {
  try {
    await fn();
    passed += 1;
    console.log(`[PASS] ${name}`);
  } catch (error) {
    failed += 1;
    console.error(`[FAIL] ${name}`);
    console.error(`       ${error.message}`);
  }
}

const targets = await (await fetch(`${devtools}/json/list`)).json();
const page = targets.find((target) => target.type === 'page');
if (!page) throw new Error('No page target; start Chrome with --remote-debugging-port=9222');

const cdp = new CDP(page.webSocketDebuggerUrl);
await cdp.send('Runtime.enable');
await cdp.send('Page.enable');
await cdp.send('Network.enable');
await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
await cdp.send('Emulation.setDeviceMetricsOverride', {
  width: 1440, height: 1000, deviceScaleFactor: 1, mobile: false,
});

try {
  await cdp.send('Storage.clearDataForOrigin', { origin: new URL(url).origin, storageTypes: 'all' });
} catch (error) {
  /* older Chrome builds */
}
await cdp.send('Page.navigate', { url });
await waitFor(cdp, "document.readyState === 'complete' && !!document.getElementById('workspace')", 15000, 'application shell');
await sleep(1500);
await cdp.eval("document.querySelector('[data-action=\"welcome\"]')?.click()");
await waitFor(cdp, "!!document.querySelector('.welcome')", 5000, 'welcome render');
await sleep(200);

await check('welcome renders and local project library settles', async () => {
  const hasTitle = await cdp.eval("!!document.querySelector('.welcome-intro h1')");
  if (!hasTitle) throw new Error('welcome title missing');
  const loading = await cdp.eval("!!document.querySelector('#recent-list .loading-text')");
  if (loading) throw new Error('recent project list is still loading');
});

await check('new project modal creates a valid project', async () => {
  await cdp.eval("document.querySelector('.topbar-actions [data-action=\"new-project\"]').click()");
  await waitFor(cdp, "!!document.getElementById('np-id')", 4000, 'new project modal');
  await cdp.eval(`(() => {
    const id = document.getElementById('np-id');
    id.value = 'smoke_mod';
    id.dispatchEvent(new Event('input', { bubbles: true }));
    const name = document.getElementById('np-name');
    name.value = 'Smoke Mod';
    name.dispatchEvent(new Event('input', { bubbles: true }));
    document.querySelector('[data-action="create-project"]').click();
  })()`);
  await waitFor(cdp, "!!document.querySelector('.overview-view')", 8000, 'overview after create');
  const title = await cdp.eval("document.querySelector('.view-head h1')?.textContent");
  if (!title || !title.includes('Smoke Mod')) throw new Error(`unexpected title: ${title}`);
  const errorCount = await cdp.eval("document.querySelector('.status-pill.has-error')?.textContent.trim()");
  if (errorCount && !errorCount.startsWith('0')) throw new Error(`validation errors after create: ${errorCount}`);
});

await check('goods editor adds a definition and edits a number field', async () => {
  await cdp.eval("document.querySelector('[data-nav=\"content:goods\"]').click()");
  await waitFor(cdp, "!!document.querySelector('.content-view')", 4000, 'content view');
  const before = await cdp.eval("document.querySelectorAll('.def-card').length");
  await cdp.eval("document.querySelector('.content-view [data-action=\"add-definition\"]').click()");
  await waitFor(cdp, `document.querySelectorAll('.def-card').length > ${before}`, 4000, 'new definition');
  const fieldCount = await cdp.eval("document.querySelectorAll('#definition-editor [data-field]').length");
  if (fieldCount < 4) throw new Error(`form did not render enough fields: ${fieldCount}`);
  await cdp.eval(`(() => {
    const input = document.querySelector('#definition-editor [data-field="data.base_price"]');
    input.value = '77';
    input.dispatchEvent(new Event('input', { bubbles: true }));
  })()`);
  await sleep(500);
  const value = await cdp.eval("document.querySelector('#definition-editor [data-field=\"data.base_price\"]').value");
  if (value !== '77') throw new Error(`base_price did not update: ${value}`);
});

await check('entity ID previews localization keys and commits them only on save', async () => {
  const original = await cdp.eval(`(async () => {
    await new Promise((resolve) => setTimeout(resolve, 1000));
    const project = (await SNIO.listProjects())[0];
    const file = project.contentFiles.find((item) => item.content_type === 'goods');
    const definition = file.definitions[file.definitions.length - 1];
    return { id: definition.id, key: definition.name_key };
  })()`);
  await cdp.eval(`(() => {
    const input = document.querySelector('#definition-editor [data-field="id"]');
    input.value = 'renamed_good';
    input.dispatchEvent(new Event('input', { bubbles: true }));
  })()`);
  const preview = await cdp.eval("document.querySelector('[data-key-preview-field=\"name_key\"]')?.value");
  if (preview !== 'good.smoke_mod.renamed_good.name') throw new Error(`localization preview did not follow ID: ${preview}`);
  await sleep(1100);
  const staged = await cdp.eval(`(async () => {
    const project = (await SNIO.listProjects())[0];
    const file = project.contentFiles.find((item) => item.content_type === 'goods');
    const definition = file.definitions.find((item) => item.id === 'smoke_mod:good/renamed_good');
    const zh = project.localization.find((item) => item.locale === 'zh_CN').entries;
    return { key: definition.name_key, oldValue: zh[definition.name_key], previewValue: zh['good.smoke_mod.renamed_good.name'] };
  })()`);
  if (staged.key !== original.key || !staged.oldValue || staged.previewValue != null) {
    throw new Error(`localization keys changed before save: ${JSON.stringify(staged)}`);
  }
  await cdp.eval(`(() => {
    const input = document.querySelector('[data-entity-locale="zh_CN"][data-entity-locale-field="name_key"]');
    input.value = '已保存的红茶';
    input.dispatchEvent(new Event('input', { bubbles: true }));
    document.querySelector('[data-action="save-definition"]').click();
  })()`);
  await waitFor(cdp, "!document.querySelector('[data-localization-pending]') || document.querySelector('[data-localization-pending]').hidden", 5000, 'localization transaction commit');
  const committed = await cdp.eval(`(async () => {
    await new Promise((resolve) => setTimeout(resolve, 900));
    const project = (await SNIO.listProjects())[0];
    const file = project.contentFiles.find((item) => item.content_type === 'goods');
    const definition = file.definitions.find((item) => item.id === 'smoke_mod:good/renamed_good');
    const zh = project.localization.find((item) => item.locale === 'zh_CN').entries;
    return { key: definition.name_key, value: zh[definition.name_key], oldExists: Object.hasOwn(zh, ${JSON.stringify(original.key)}) };
  })()`);
  if (committed.key !== preview || committed.value !== '已保存的红茶' || committed.oldExists) {
    throw new Error(`localization transaction failed: ${JSON.stringify(committed)}`);
  }
});

await check('module workspace exposes type subpages', async () => {
  await cdp.eval("document.querySelector('[data-nav=\"content:boilers\"]').click()");
  await waitFor(cdp, "document.querySelectorAll('.module-tab').length >= 8", 3000, 'module subpages');
  await cdp.eval("document.querySelector('.module-tab[data-nav=\"content:hulls\"]').click()");
  await waitFor(cdp, "!!document.querySelector('.module-tab.active[data-nav=\"content:hulls\"]')", 3000, 'hull module subpage');
  await cdp.eval("document.querySelector('.content-view [data-action=\"add-definition\"]').click()");
  await waitFor(cdp, "!!document.querySelector('#definition-editor .hull-module-grid')", 4000, 'hull module configuration');
  const hullModules = await cdp.eval(`(() => ({
    fixed: document.querySelectorAll('#definition-editor .hull-module-card.fixed').length,
    cargo: document.querySelectorAll('#definition-editor [data-field="data.cargo_slots"]').length,
    cabin: document.querySelectorAll('#definition-editor [data-field="data.cabin_slots"]').length,
  }))()`);
  if (hullModules.fixed !== 3 || hullModules.cargo !== 1 || hullModules.cabin !== 1) {
    throw new Error(`unexpected hull module configuration: ${JSON.stringify(hullModules)}`);
  }
  await cdp.eval("document.querySelector('.module-tab[data-nav=\"content:cargo_modules\"]').click()");
  await waitFor(cdp, "!!document.querySelector('.module-tab.active[data-nav=\"content:cargo_modules\"]')", 3000, 'cargo module subpage');
});

await check('localization view lists keys and accepts a translation', async () => {
  await cdp.eval("document.querySelector('[data-nav=\"localization:zh_CN\"]').click()");
  await waitFor(cdp, "!!document.querySelector('.localization-view')", 4000, 'localization view');
  const rows = await cdp.eval("document.querySelectorAll('.loc-row').length");
  if (rows < 2) throw new Error(`expected localization rows, got ${rows}`);
  await cdp.eval(`(() => {
    const input = document.querySelector('.loc-row input[data-locale-input]');
    input.value = '烟雾测试翻译';
    input.dispatchEvent(new Event('input', { bubbles: true }));
  })()`);
  await sleep(400);
  const value = await cdp.eval("document.querySelector('.loc-row input[data-locale-input]').value");
  if (value !== '烟雾测试翻译') throw new Error('localization input did not persist in the DOM');
});

await check('JSON inspector opens and contains project data', async () => {
  await cdp.eval("document.querySelector('[data-action=\"toggle-inspector\"]').click()");
  await waitFor(cdp, "!document.getElementById('inspector').hidden", 3000, 'inspector open');
  const text = await cdp.eval("document.querySelector('.json-view')?.textContent || ''");
  if (!text.includes('smoke_mod')) throw new Error('inspector does not show project data');
  await cdp.eval("document.querySelector('[data-action=\"toggle-inspector\"]').click()");
});

await check('autosave persists the project to IndexedDB and export builds a ZIP', async () => {
  await cdp.eval("document.dispatchEvent(new KeyboardEvent('keydown', { key: 's', ctrlKey: true, bubbles: true }))");
  await sleep(900);
  const summary = await cdp.eval(`(async () => {
    const projects = await SNIO.listProjects();
    if (!projects.length) return { error: 'no saved projects' };
    const project = projects[0];
    const files = SNStore.toExportFiles(project);
    const bytes = await SNZip.build(files);
    const back = await SNZip.read(bytes);
    return {
      id: project.manifest.id,
      contentFiles: project.contentFiles.length,
      definitions: project.contentFiles.reduce((sum, file) => sum + file.definitions.length, 0),
      localized: project.localization.length,
      exportFiles: files.length,
      zipEntries: back.length,
      zipPrefix: back.every((entry) => entry.path.startsWith('mods/smoke_mod/')),
    };
  })()`);
  if (summary.error) throw new Error(summary.error);
  if (summary.id !== 'smoke_mod') throw new Error(`bad saved id: ${summary.id}`);
  if (summary.definitions < 2) throw new Error(`bad definition count: ${summary.definitions}`);
  if (!summary.zipPrefix) throw new Error('ZIP entries are not namespaced');
});

await check('importing exported files reproduces the project', async () => {
  const result = await cdp.eval(`(async () => {
    const projects = await SNIO.listProjects();
    const files = SNStore.toExportFiles(projects[0]);
    const imported = SNStore.fromFiles(files);
    const validation = SNValidate.validateProject(imported.project);
    return {
      warnings: imported.warnings.length,
      errors: validation.counts.error,
      definitions: imported.project.contentFiles.reduce((sum, file) => sum + file.definitions.length, 0),
      assets: imported.project.assets.length,
    };
  })()`);
  if (result.errors) throw new Error(`imported project has ${result.errors} errors`);
  if (result.definitions < 2) throw new Error('import lost definitions');
});

await check('asset picker adds an asset and writes manifest.assets', async () => {
  await cdp.eval("document.querySelector('[data-nav=\"assets\"]').click()");
  await waitFor(cdp, "!!document.querySelector('.assets-view')", 3000, 'assets view');
  await cdp.eval(`(() => {
    SNIO.openFilePicker = async () => [{
      path: 'tea.svg',
      data: new TextEncoder().encode('<svg xmlns="http://www.w3.org/2000/svg"><rect width="16" height="16" fill="#d9a441"/></svg>'),
    }];
  })()`);
  await cdp.eval("document.querySelector('[data-action=\"add-asset\"]').click()");
  await waitFor(cdp, "document.querySelectorAll('.asset-card').length === 1", 5000, 'asset card');
  const key = await cdp.eval("document.querySelector('[data-asset-key]')?.value");
  if (key !== 'icon.tea') throw new Error(`unexpected asset key: ${key}`);
  await sleep(1100);
  const saved = await cdp.eval(`(async () => {
    const project = (await SNIO.listProjects())[0];
    return {
      assets: project.assets.length,
      manifestKeys: Object.keys(project.manifest.assets || {}),
      errors: SNValidate.validateProject(project).counts.error,
    };
  })()`);
  if (saved.assets !== 1) throw new Error(`asset was not saved: ${JSON.stringify(saved)}`);
  if (!saved.manifestKeys.includes('icon.tea')) throw new Error('manifest.assets missing icon.tea');
  if (saved.errors) throw new Error(`asset project has ${saved.errors} errors`);
  await cdp.eval("document.querySelector('[data-nav=\"content:goods\"]').click()");
  await waitFor(cdp, "!!document.querySelector('#definition-editor [data-asset-kind=\"image\"]')", 3000, 'custom image picker');
  const pickerShape = await cdp.eval(`(() => ({
    nativeList: document.querySelector('#definition-editor [data-field="information.texture"]')?.hasAttribute('list'),
    imageHasAsset: !!document.querySelector('#definition-editor [data-asset-kind="image"] [data-value="icon.tea"]'),
    modelHasImage: !!document.querySelector('#definition-editor [data-asset-kind="model"] [data-value="icon.tea"]'),
  }))()`);
  if (pickerShape.nativeList || !pickerShape.imageHasAsset || pickerShape.modelHasImage) {
    throw new Error(`custom asset picker filtering failed: ${JSON.stringify(pickerShape)}`);
  }
  await cdp.eval("document.querySelector('#definition-editor [data-asset-kind=\"image\"] [data-action=\"asset-picker-toggle\"]').click()");
  await waitFor(cdp, "!document.querySelector('#definition-editor [data-asset-kind=\"image\"] .asset-picker-menu').hidden", 2000, 'asset picker menu');
  await cdp.eval("document.querySelector('#definition-editor [data-asset-kind=\"image\"] [data-value=\"icon.tea\"]').click()");
  const selectedTexture = await cdp.eval("document.querySelector('#definition-editor [data-field=\"information.texture\"]')?.value");
  if (selectedTexture !== 'icon.tea') throw new Error(`asset picker did not select texture: ${selectedTexture}`);
});

await check('event editor adds a condition and an effect', async () => {
  await cdp.eval("document.querySelector('[data-nav=\"content:events\"]').click()");
  await waitFor(cdp, "!!document.querySelector('.content-view')", 3000, 'event view');
  await cdp.eval("document.querySelector('.content-view [data-action=\"add-definition\"]').click()");
  await waitFor(cdp, "!!document.querySelector('#definition-editor .option-card [data-action=\"condition-add\"]')", 5000, 'event form');
  await cdp.eval("document.querySelector('#definition-editor .option-card [data-action=\"condition-add\"]').click()");
  await waitFor(cdp, "!!document.querySelector('#definition-editor .option-card .condition-box')", 3000, 'condition box');
  await cdp.eval(`(() => {
    const select = document.querySelector('#definition-editor .option-card [data-action="condition-op"]');
    select.value = 'has_item';
    select.dispatchEvent(new Event('change', { bubbles: true }));
  })()`);
  await waitFor(cdp, "!!document.querySelector('#definition-editor [data-field=\"data.options.0.condition.item_id\"]')", 3000, 'condition fields');
  const before = await cdp.eval("document.querySelectorAll('#definition-editor .effect-row').length");
  await cdp.eval("document.querySelector('#definition-editor [data-action=\"array-add\"][data-path=\"data.options.0.effects\"]').click()");
  await waitFor(cdp, `document.querySelectorAll('#definition-editor .effect-row').length > ${before}`, 3000, 'effect added');
});

await check('patch editor exposes target and operations', async () => {
  await cdp.eval("document.querySelector('[data-nav=\"content:patches\"]').click()");
  await waitFor(cdp, "!!document.querySelector('.content-view')", 3000, 'patch view');
  await cdp.eval("document.querySelector('.content-view [data-action=\"add-definition\"]').click()");
  await waitFor(cdp, "!!document.querySelector('#definition-editor [data-field=\"target\"]')", 4000, 'patch target field');
  const target = await cdp.eval("document.querySelector('#definition-editor [data-field=\"target\"]')?.value");
  if (target !== 'core:boiler/small_efficient') throw new Error(`unexpected patch target: ${target}`);
  const hasOperation = await cdp.eval("!!document.querySelector('#definition-editor [data-field=\"operations.0.path\"]')");
  if (!hasOperation) throw new Error('patch operation editor missing');
});

await check('undo reverts a field edit', async () => {
  await cdp.eval("document.querySelector('[data-nav=\"content:goods\"]').click()");
  await sleep(300);
  await cdp.eval(`(() => {
    const input = document.querySelector('#definition-editor [data-field="data.base_price"]');
    input.value = '88';
    input.dispatchEvent(new Event('input', { bubbles: true }));
  })()`);
  await sleep(400);
  await cdp.eval("document.dispatchEvent(new KeyboardEvent('keydown', { key: 'z', ctrlKey: true, bubbles: true }))");
  await sleep(500);
  const value = await cdp.eval("document.querySelector('#definition-editor [data-field=\"data.base_price\"]')?.value");
  if (value === '88') throw new Error('undo did not revert data.base_price');
});

await check('import modal accepts an exported ZIP and reloads the project', async () => {
  await cdp.eval("document.dispatchEvent(new KeyboardEvent('keydown', { key: 's', ctrlKey: true, bubbles: true }))");
  await sleep(900);
  const built = await cdp.eval(`(async () => {
    const projects = await SNIO.listProjects();
    const files = SNStore.toExportFiles(projects[0]);
    window.__smokeZip = await SNZip.build(files);
    SNIO.openFilePicker = async () => [{ path: 'smoke.snavmod.zip', data: window.__smokeZip }];
    return { files: files.length, bytes: window.__smokeZip.length };
  })()`);
  if (!built || built.files < 3) throw new Error('could not build import ZIP');
  await cdp.eval("document.querySelector('.topbar-actions [data-action=\"import\"]').click()");
  await waitFor(cdp, "!!document.querySelector('[data-action=\"import-file\"]')", 3000, 'import modal');
  await cdp.eval("document.querySelector('[data-action=\"import-file\"]').click()");
  await waitFor(cdp, "!!document.querySelector('.overview-view')", 8000, 'overview after import');
  const chip = await cdp.eval("document.querySelector('#project-chip')?.textContent || ''");
  if (!chip.includes('smoke_mod')) throw new Error(`imported project chip is wrong: ${chip}`);
  const counts = await cdp.eval("({ events: [...document.querySelectorAll('[data-nav=\"content:events\"] .count')].map(e=>e.textContent)[0], patches: [...document.querySelectorAll('[data-nav=\"content:patches\"] .count')].map(e=>e.textContent)[0] })");
  if (String(counts.events) === '0' || String(counts.patches) === '0') {
    throw new Error(`import lost content: ${JSON.stringify(counts)}`);
  }
});

await check('folder export writes the same tree through File System Access handles', async () => {
  await cdp.eval(`(() => {
    const files = new Map();
    const makeDir = (prefix) => ({
      getDirectoryHandle: async (name) => makeDir(prefix + name + '/'),
      getFileHandle: async (name) => ({
        createWritable: async () => ({
          write: async (data) => files.set(prefix + name, data),
          close: async () => {},
        }),
      }),
    });
    window.showDirectoryPicker = async () => makeDir('');
    window.__writtenTree = files;
  })()`);
  await cdp.eval("document.querySelector('.topbar-actions [data-action=\"export\"]').click()");
  await waitFor(cdp, "!!document.querySelector('[data-action=\"export-folder\"]')", 3000, 'export modal');
  await cdp.eval("document.querySelector('[data-action=\"export-folder\"]').click()");
  await waitFor(cdp, "window.__writtenTree && window.__writtenTree.size > 0", 5000, 'folder export');
  const keys = await cdp.eval("[...window.__writtenTree.keys()].sort()");
  if (!keys.some((key) => key.endsWith('/manifest.json'))) throw new Error(`missing manifest: ${keys.join(',')}`);
  if (!keys.some((key) => key.includes('/content/'))) throw new Error('missing content file');
});

await check('local disk API saves projects, exports and deploys to game mods', async () => {
  const backend = await cdp.eval('SNIO.detectBackend()');
  if (!backend || !backend.ok) throw new Error('local disk API is not available');
  await cdp.eval("document.dispatchEvent(new KeyboardEvent('keydown', { key: 's', ctrlKey: true, bubbles: true }))");
  await sleep(1400);
  const disk = await cdp.eval(`(async () => {
    const rows = await SNIO.listDiskProjects();
    const project = await SNIO.getDiskProject('smoke_mod');
    const manifest = await (await fetch('mods/smoke_mod/manifest.json')).text();
    return {
      ids: rows.map((row) => row.id),
      definitions: project ? project.contentFiles.reduce((sum, file) => sum + file.definitions.length, 0) : 0,
      manifestOk: manifest.includes('smoke_mod'),
    };
  })()`);
  if (!disk.ids.includes('smoke_mod')) throw new Error(`disk project missing: ${disk.ids.join(',')}`);
  if (!disk.definitions) throw new Error('disk project has no definitions');
  if (!disk.manifestOk) throw new Error('disk manifest missing');

  await cdp.eval("document.querySelector('[data-action=\"project-library\"]').click()");
  await waitFor(cdp, "!!document.querySelector('[data-action=\"open-disk-project\"][data-id=\"smoke_mod\"]')", 4000, 'disk project in library');
  await cdp.eval("document.querySelector('#modal [data-modal-close]').click()");

  await cdp.eval("document.querySelector('.topbar-actions [data-action=\"export\"]').click()");
  await waitFor(cdp, "!!document.querySelector('[data-action=\"export-disk\"]')", 3000, 'disk export option');
  await cdp.eval("document.querySelector('[data-action=\"export-disk\"]').click()");
  await sleep(1000);
  const exports = await cdp.eval('SNIO.listExports()');
  const exported = exports.find((entry) => entry.name.startsWith('smoke_mod-') && entry.name.endsWith('.zip'));
  if (!exported) throw new Error(`exports/ missing zip: ${JSON.stringify(exports)}`);

  await cdp.eval("document.querySelector('.topbar-actions [data-action=\"export\"]').click()");
  await waitFor(cdp, "!!document.querySelector('[data-action=\"deploy-game-mod\"]')", 3000, 'game deploy option');
  await cdp.eval("document.querySelector('[data-action=\"deploy-game-mod\"]').click()");
  await waitFor(cdp, "SNIO.listGameMods().then(rows => rows.some(row => row.name === 'smoke_mod.snavmod.zip'))", 6000, 'deployed game mod');

  await cdp.eval(`(async () => {
    await SNIO.deleteDiskProject('smoke_mod');
    await SNIO.deleteGameMod('smoke_mod');
    const rows = await SNIO.listExports();
    for (const row of rows) {
      if (row.name.startsWith('smoke_mod-')) await SNIO.deleteExport(row.name);
    }
  })()`);
});

await check('native workspace opens dev_mods/core in place', async () => {
  const backend = await cdp.eval('SNIO.detectBackend()');
  if (!backend || !backend.workspaceDir) throw new Error('backend does not expose dev_mods workspace');
  await cdp.eval("document.querySelector('[data-action=\"welcome\"]').click()");
  await waitFor(cdp, "!!document.querySelector('.welcome')", 5000, 'welcome for workspace');
  await waitFor(
    cdp,
    "[...document.querySelectorAll('.recent-row')].some((row) => row.querySelector('.recent-badge')?.textContent.trim() === '工作区')",
    6000,
    'workspace row in recent projects',
  );
  const opened = await cdp.eval(`(() => {
    const row = [...document.querySelectorAll('.recent-row')].find((item) =>
      item.querySelector('.recent-badge')?.textContent.trim() === '工作区'
      && item.querySelector('.recent-main')?.dataset.id === 'core');
    if (!row) return false;
    row.querySelector('.recent-main').click();
    return true;
  })()`);
  if (!opened) throw new Error('workspace core row is missing');
  await waitFor(cdp, "!!document.querySelector('.view.overview-view h1')", 8000, 'workspace overview');
  const title = await cdp.eval("document.querySelector('.view.overview-view h1').textContent.trim()");
  if (!title.includes('Steam Navigator')) throw new Error(`unexpected workspace title: ${title}`);
  const hasAssetsTab = await cdp.eval("document.body.textContent.includes('资源')");
  if (!hasAssetsTab) throw new Error('workspace project did not render the editor tabs');
});

const shot = await cdp.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
fs.writeFileSync(screenshotPath, Buffer.from(shot.data, 'base64'));

if (consoleErrors.length) {
  console.error('\nBrowser console errors:');
  for (const error of consoleErrors) console.error(` - ${error}`);
}

console.log(`\nBrowser tests: ${passed} passed, ${failed} failed, ${passed + failed} total`);
console.log(`Screenshot: ${screenshotPath}`);
try {
  cdp.ws.close();
} catch (error) {
  /* ignore */
}
if (failed || consoleErrors.length) process.exitCode = 1;
else setTimeout(() => process.exit(0), 100);
