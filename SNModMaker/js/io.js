/*
 * Browser I/O: project persistence (IndexedDB), file/folder/ZIP import,
 * downloads and directory export. No third-party code.
 */
(function (root) {
  'use strict';

  const DB_NAME = 'snmodmaker';
  const DB_VERSION = 1;
  const PROJECT_STORE = 'projects';
  const LS_PREFIX = 'snmodmaker.';

  let dbPromise = null;

  function openDB() {
    if (dbPromise) return dbPromise;
    dbPromise = new Promise((resolve, reject) => {
      if (typeof root.indexedDB === 'undefined') {
        reject(new Error('IndexedDB 不可用'));
        return;
      }
      const timeout = setTimeout(() => reject(new Error('IndexedDB 打开超时（浏览器可能禁用了本地存储）')), 3000);
      const fail = (error) => {
        clearTimeout(timeout);
        reject(error);
      };
      const request = root.indexedDB.open(DB_NAME, DB_VERSION);
      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains(PROJECT_STORE)) {
          const store = db.createObjectStore(PROJECT_STORE, { keyPath: 'uid' });
          store.createIndex('updatedAt', 'meta.updatedAt', { unique: false });
        }
      };
      request.onsuccess = () => {
        clearTimeout(timeout);
        resolve(request.result);
      };
      request.onerror = () => fail(request.error || new Error('无法打开本地数据库'));
      request.onblocked = () => fail(new Error('本地数据库被其他标签页占用'));
    });
    return dbPromise;
  }

  async function withStore(mode, callback) {
    const db = await openDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(PROJECT_STORE, mode);
      const store = transaction.objectStore(PROJECT_STORE);
      let result;
      try {
        result = callback(store);
      } catch (error) {
        reject(error);
        return;
      }
      transaction.oncomplete = () => resolve(result);
      transaction.onerror = () => reject(transaction.error || new Error('数据库事务失败'));
      transaction.onabort = () => reject(transaction.error || new Error('数据库事务取消'));
    });
  }

  function putProject(project) {
    return withStore('readwrite', (store) => store.put(project));
  }

  function getProject(uid) {
    return new Promise((resolve, reject) => {
      openDB().then((db) => {
        const request = db.transaction(PROJECT_STORE, 'readonly').objectStore(PROJECT_STORE).get(uid);
        request.onsuccess = () => resolve(request.result || null);
        request.onerror = () => reject(request.error);
      }).catch(reject);
    });
  }

  function deleteProject(uid) {
    return withStore('readwrite', (store) => store.delete(uid));
  }

  function listProjects() {
    return new Promise((resolve, reject) => {
      openDB().then((db) => {
        const request = db.transaction(PROJECT_STORE, 'readonly').objectStore(PROJECT_STORE).getAll();
        request.onsuccess = () => {
          const rows = (request.result || []).slice();
          rows.sort((a, b) => String((b.meta && b.meta.updatedAt) || '').localeCompare(String((a.meta && a.meta.updatedAt) || '')));
          resolve(rows);
        };
        request.onerror = () => reject(request.error);
      }).catch(reject);
    });
  }

  function rememberCurrent(uid) {
    try {
      root.localStorage.setItem(`${LS_PREFIX}current`, uid || '');
      root.localStorage.setItem(`${LS_PREFIX}lastOpenedAt`, new Date().toISOString());
    } catch (error) {
      /* private mode */
    }
  }

  function currentUid() {
    try {
      return root.localStorage.getItem(`${LS_PREFIX}current`) || '';
    } catch (error) {
      return '';
    }
  }

  function setPreference(key, value) {
    try {
      root.localStorage.setItem(LS_PREFIX + key, String(value));
    } catch (error) {
      /* ignore */
    }
  }

  function getPreference(key, fallback) {
    try {
      const value = root.localStorage.getItem(LS_PREFIX + key);
      return value == null ? fallback : value;
    } catch (error) {
      return fallback;
    }
  }

  function downloadBytes(bytes, filename, mime) {
    const blob = new Blob([bytes], { type: mime || 'application/octet-stream' });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = filename;
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    setTimeout(() => URL.revokeObjectURL(url), 4000);
  }

  function downloadText(text, filename, mime) {
    downloadBytes(new TextEncoder().encode(text), filename, mime || 'application/json');
  }

  async function fileToBytes(file) {
    return new Uint8Array(await file.arrayBuffer());
  }

  /** Convert a FileList (from input[type=file] or a folder input) into entries. */
  async function fileListToEntries(fileList) {
    const files = Array.from(fileList || []);
    const entries = [];
    for (const file of files) {
      const path = (file.webkitRelativePath || file.name).replace(/\\/g, '/');
      entries.push({ path, data: await fileToBytes(file), file });
    }
    return entries;
  }

  function readDirectoryEntry(reader) {
    return new Promise((resolve, reject) => {
      const collect = (acc) => {
        reader.readEntries((batch) => {
          if (!batch.length) {
            resolve(acc);
            return;
          }
          collect(acc.concat(Array.from(batch)));
        }, reject);
      };
      collect([]);
    });
  }

  async function readEntry(entry, prefix) {
    if (entry.isFile) {
      const file = await new Promise((resolve, reject) => entry.file(resolve, reject));
      const path = `${prefix}${entry.name}`;
      return [{ path, data: await fileToBytes(file), file }];
    }
    if (entry.isDirectory) {
      const reader = entry.createReader();
      const children = await readDirectoryEntry(reader);
      const results = [];
      for (const child of children) {
        results.push(...await readEntry(child, `${prefix}${entry.name}/`));
      }
      return results;
    }
    return [];
  }

  /** Resolve a drop event to logical entries, preserving directory paths. */
  async function dataTransferToEntries(dataTransfer) {
    const items = Array.from((dataTransfer && dataTransfer.items) || []);
    const canUseEntries = items.length && items[0].webkitGetAsEntry;
    if (canUseEntries) {
      const entries = [];
      for (const item of items) {
        if (item.kind !== 'file') continue;
        const entry = item.webkitGetAsEntry();
        if (!entry) continue;
        entries.push(...await readEntry(entry, ''));
      }
      if (entries.length) return entries;
    }
    return fileListToEntries((dataTransfer && dataTransfer.files) || []);
  }

  async function importZip(file) {
    const bytes = await fileToBytes(file);
    const entries = await root.SNZip.read(bytes);
    return entries;
  }

  function openFilePicker(options) {
    const opts = options || {};
    return new Promise((resolve) => {
      const input = document.createElement('input');
      input.type = 'file';
      input.multiple = true;
      if (opts.accept) input.accept = opts.accept;
      if (opts.directory) {
        input.webkitdirectory = true;
        input.setAttribute('webkitdirectory', '');
      }
      input.style.position = 'fixed';
      input.style.left = '-9999px';
      document.body.appendChild(input);
      input.addEventListener('change', async () => {
        const entries = await fileListToEntries(input.files);
        input.remove();
        resolve(entries);
      });
      input.addEventListener('cancel', () => {
        input.remove();
        resolve([]);
      });
      input.click();
    });
  }

  async function buildZip(project) {
    const files = root.SNStore.toExportFiles(project);
    if (!files.length) throw new Error('没有可导出的文件');
    const bytes = await root.SNZip.build(files);
    return {
      bytes,
      filename: `${project.manifest.id}-${project.manifest.version}.snavmod.zip`,
    };
  }

  async function exportZip(project) {
    const result = await buildZip(project);
    downloadBytes(result.bytes, result.filename, 'application/zip');
    return { filename: result.filename, size: result.bytes.length };
  }

  function exportProjectFile(project) {
    const text = root.SNStore.serialize(project);
    const filename = `${project.manifest.id}-${project.manifest.version}.snmodproj.json`;
    downloadText(text, filename, 'application/json');
    return { filename, size: text.length };
  }

  async function writeFileTree(rootHandle, entries) {
    for (const entry of entries) {
      const parts = entry.path.split('/');
      const filename = parts.pop();
      let directory = rootHandle;
      for (const part of parts) {
        directory = await directory.getDirectoryHandle(part, { create: true });
      }
      const handle = await directory.getFileHandle(filename, { create: true });
      const writable = await handle.createWritable();
      const data = typeof entry.data === 'string' ? new TextEncoder().encode(entry.data) : entry.data;
      await writable.write(data);
      await writable.close();
    }
  }

  async function exportFolder(project) {
    if (typeof root.showDirectoryPicker !== 'function') {
      throw new Error('当前浏览器不支持选择文件夹。请使用 Chrome / Edge，或改用 ZIP 导出。');
    }
    const parent = await root.showDirectoryPicker({ mode: 'readwrite' });
    const modRoot = await parent.getDirectoryHandle(project.manifest.id, { create: true });
    const files = root.SNStore.toExportFiles(project, { prefix: false });
    await writeFileTree(modRoot, files);
    return { folder: project.manifest.id, files: files.length };
  }

  async function pickSchemaDirectory() {
    return openFilePicker({ directory: true, accept: '.json' });
  }

  /* ------------------------------------------------------------------ */
  /* Optional local disk workspace (tools/serve.mjs API)                 */
  /* ------------------------------------------------------------------ */

  async function detectBackend() {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 1500);
    try {
      const response = await fetch('api/status', { cache: 'no-store', signal: controller.signal });
      if (!response.ok) return null;
      const data = await response.json();
      return data && data.ok ? data : null;
    } catch (error) {
      return null;
    } finally {
      clearTimeout(timer);
    }
  }

  async function apiJson(url, options) {
    const response = await fetch(url, Object.assign({ cache: 'no-store' }, options || {}));
    let data = null;
    try {
      data = await response.json();
    } catch (error) {
      data = null;
    }
    if (!response.ok || !data || data.ok === false) {
      throw new Error((data && data.error) || `本地服务返回 ${response.status}`);
    }
    return data;
  }

  async function listDiskProjects() {
    const data = await apiJson('api/projects');
    return Array.isArray(data.projects) ? data.projects : [];
  }

  async function getDiskProject(id) {
    const data = await apiJson(`api/projects/${encodeURIComponent(id)}`);
    return data.project || null;
  }

  async function putDiskProject(project) {
    const files = root.SNStore.toExportFiles(project, { prefix: false });
    const payload = {
      project: root.SNStore.normalizeProject(project),
      files: files.map((file) => ({
        path: file.path,
        encoding: typeof file.data === 'string' ? 'utf8' : 'base64',
        data: typeof file.data === 'string' ? file.data : root.SNStore.bytesToBase64(file.data),
      })),
    };
    return apiJson(`api/projects/${encodeURIComponent(project.manifest.id)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  }

  async function deleteDiskProject(id) {
    return apiJson(`api/projects/${encodeURIComponent(id)}`, { method: 'DELETE' });
  }

  async function listExports() {
    const data = await apiJson('api/exports');
    return Array.isArray(data.exports) ? data.exports : [];
  }

  async function saveExportToDisk(filename, bytes) {
    return apiJson(`api/exports?filename=${encodeURIComponent(filename)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/octet-stream' },
      body: bytes,
    });
  }

  async function deleteExport(name) {
    return apiJson(`api/exports/${encodeURIComponent(name)}`, { method: 'DELETE' });
  }

  root.SNIO = {
    openDB,
    putProject,
    getProject,
    deleteProject,
    listProjects,
    rememberCurrent,
    currentUid,
    setPreference,
    getPreference,
    downloadBytes,
    downloadText,
    fileToBytes,
    fileListToEntries,
    dataTransferToEntries,
    importZip,
    openFilePicker,
    buildZip,
    exportZip,
    exportProjectFile,
    exportFolder,
    writeFileTree,
    detectBackend,
    listDiskProjects,
    getDiskProject,
    putDiskProject,
    deleteDiskProject,
    listExports,
    saveExportToDisk,
    deleteExport,
    supportsFolderExport: () => typeof root.showDirectoryPicker === 'function',
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
