/*
 * Steam Navigator Mod Maker - application controller.
 *
 * Owns UI state, mutations, undo history, autosave and event delegation.
 * Rendering is intentionally "HTML in, DOM out": views are rebuilt on structural
 * changes; text fields update the model in place so focus is never stolen.
 */
(function (root) {
  'use strict';

  const Store = root.SNStore;
  const UI = root.SNUI;
  const V = root.SNValidate;
  const IO = root.SNIO;
  const Cat = root.SNCatalog;
  const MODULE_PAGE_TYPES = ['hulls', 'boilers', 'cargo_modules', 'navigation_modules', 'safety_modules', 'cabins', 'roles', 'strategies'];

  const state = {
    project: null,
    view: { name: 'welcome' },
    selected: null,
    locale: 'zh_CN',
    search: '',
    locSearch: '',
    missingOnly: false,
    validFilter: 'all',
    issues: { issues: [], counts: { error: 0, warning: 0, info: 0, total: 0 }, stats: {} },
    issueByDef: new Map(),
    rawOpen: false,
    inspector: false,
    dirty: false,
    saving: false,
    savedAt: null,
    storageMode: 'idb',
    backend: null,
    workspace: false,
    diskSaving: false,
    diskQueued: false,
    diskSavedAt: null,
    diskError: '',
    revision: 0,
    saveQueued: false,
    typing: false,
    history: { past: [], future: [], max: 40 },
    focusAfter: null,
    localizationDrafts: new Map(),
  };

  const scheduleValidate = UI.debounce(() => {
    if (!state.project) return;
    runValidation();
    renderSidebar();
    renderStatus();
    if (state.view.name === 'validate') render({ preserveScroll: true });
  }, 240);

  const scheduleSave = UI.debounce(() => saveNow(), 800);

  const scheduleDiskSave = UI.debounce(() => flushDiskSave(), 1600);

  const scheduleInspector = UI.debounce(() => {
    if (state.inspector) renderInspector();
  }, 150);

  /* ------------------------------------------------------------------ */
  /* Boot                                                                */
  /* ------------------------------------------------------------------ */

  document.addEventListener('DOMContentLoaded', init);

  async function init() {
    bindEvents();
    render();
    await probeBackend();
    await loadInitialProject();
  }

  async function probeBackend() {
    const info = await IO.detectBackend();
    if (!info) return;
    state.backend = info;
    renderChrome();
    renderSidebar();
    renderStatus();
    if (state.view.name === 'welcome') loadRecent();
  }

  async function loadInitialProject() {
    try {
      const rows = await IO.listProjects();
      const uid = IO.currentUid() || (rows[0] && rows[0].uid);
      let project = uid ? await IO.getProject(uid) : null;
      if (!project && rows.length) project = await IO.getProject(rows[0].uid);
      if (project) {
        setProject(project);
        return;
      }
    } catch (error) {
      state.storageMode = 'unavailable';
    }
    if (state.backend) {
      try {
        const diskRows = await IO.listDiskProjects();
        if (diskRows.length) {
          const project = await IO.getDiskProject(diskRows[0].id);
          if (project) {
            setProject(project, { fromDisk: true });
            return;
          }
        }
      } catch (error) {
        /* fall through to browser storage */
      }
    }
    const fallback = loadFallbackProject();
    if (fallback) setProject(fallback);
    else render();
  }

  function setProject(project, options) {
    const opts = options || {};
    state.project = Store.normalizeProject(project);
    Store.syncManifest(state.project);
    state.workspace = Boolean(opts.workspace);
    state.view = opts.view || { name: 'overview' };
    state.selected = firstSelection(state.project);
    state.locale = (state.project.localization[0] && state.project.localization[0].locale) || 'zh_CN';
    state.dirty = Boolean(opts.dirty);
    state.revision = 0;
    state.saveQueued = false;
    state.savedAt = opts.savedAt || new Date();
    state.diskSavedAt = opts.fromDisk ? new Date() : null;
    state.diskSaving = false;
    state.diskQueued = false;
    state.diskError = '';
    state.rawOpen = false;
    state.inspector = false;
    state.history = { past: [], future: [], max: 40 };
    state.search = '';
    state.locSearch = '';
    state.missingOnly = false;
    state.focusAfter = null;
    state.localizationDrafts = new Map();
    runValidation();
    IO.rememberCurrent(state.project.uid);
    render();
  }

  function clearProject() {
    state.project = null;
    state.view = { name: 'welcome' };
    state.selected = null;
    state.issues = { issues: [], counts: { error: 0, warning: 0, info: 0, total: 0 }, stats: {} };
    state.issueByDef = new Map();
    state.dirty = false;
    state.savedAt = null;
    state.localizationDrafts = new Map();
    render();
  }

  function firstSelection(project) {
    if (!project) return null;
    for (const file of project.contentFiles) {
      if (file.definitions && file.definitions.length) {
        return { type: file.content_type, file: file.path, index: 0 };
      }
    }
    return null;
  }

  /* ------------------------------------------------------------------ */
  /* Model helpers                                                       */
  /* ------------------------------------------------------------------ */

  function currentFile() {
    if (!state.project || !state.selected) return null;
    return state.project.contentFiles.find((file) => file.path === state.selected.file) || null;
  }

  function currentDefinition() {
    const file = currentFile();
    if (!file || !state.selected) return null;
    return file.definitions[state.selected.index] || null;
  }

  function selectedTypeInfo() {
    const file = currentFile();
    return file ? Cat.BY_KEY[file.content_type] : null;
  }

  function selectedDefinitionKey() {
    return state.selected ? `${state.selected.file}#${state.selected.index}` : '';
  }

  function localizationDraft(definition, oldId, syncToId) {
    const file = currentFile();
    if (!definition || !file || file.content_type === 'patches') return null;
    const key = selectedDefinitionKey();
    let draft = state.localizationDrafts.get(key);
    if (!draft) {
      const localId = Store.localPart(oldId || definition.id);
      draft = {
        sourceBase: Store.keyBaseOf(definition, file.content_type, state.project.manifest.id, localId),
        previewBase: '',
        values: {},
      };
      state.localizationDrafts.set(key, draft);
    }
    if (syncToId) {
      draft.previewBase = Store.keyBase(file.content_type, state.project.manifest.id, Store.localPart(definition.id));
    } else if (!draft.previewBase) {
      draft.previewBase = draft.sourceBase;
    }
    return draft;
  }

  function currentLocalizationDraft() {
    return state.localizationDrafts.get(selectedDefinitionKey()) || null;
  }

  function previewLocalizationValue(key, draft) {
    if (!key || !draft || !draft.sourceBase || !draft.previewBase) return key || '';
    if (key === draft.sourceBase || key.startsWith(`${draft.sourceBase}.`)) {
      return draft.previewBase + key.slice(draft.sourceBase.length);
    }
    return key;
  }

  function previewLocalizationKey(definition, field, draft) {
    return previewLocalizationValue(definition && definition[field], draft);
  }

  function setByPath(object, path, value) {
    const parts = String(path).split('.');
    let cursor = object;
    for (let i = 0; i < parts.length; i += 1) {
      const key = parts[i];
      if (i === parts.length - 1) {
        cursor[key] = value;
        return;
      }
      if (cursor[key] == null || typeof cursor[key] !== 'object') {
        cursor[key] = /^\d+$/.test(parts[i + 1]) ? [] : {};
      }
      cursor = cursor[key];
    }
  }

  function getByPath(object, path) {
    const parts = String(path).split('.');
    let cursor = object;
    for (const key of parts) {
      if (cursor == null) return undefined;
      cursor = cursor[key];
    }
    return cursor;
  }

  function deleteByPath(object, path) {
    const parts = String(path).split('.');
    let cursor = object;
    for (let i = 0; i < parts.length - 1; i += 1) {
      if (cursor == null) return;
      cursor = cursor[parts[i]];
    }
    if (!cursor || typeof cursor !== 'object') return;
    const last = parts[parts.length - 1];
    if (Array.isArray(cursor) && /^\d+$/.test(last)) cursor.splice(Number(last), 1);
    else delete cursor[last];
  }

  function snapshot() {
    return JSON.parse(JSON.stringify(state.project));
  }

  function pushHistory() {
    if (!state.project) return;
    try {
      state.history.past.push(snapshot());
      if (state.history.past.length > state.history.max) state.history.past.shift();
      state.history.future = [];
    } catch (error) {
      /* ignore oversized snapshots */
    }
  }

  function undo() {
    if (!state.history.past.length || !state.project) return;
    state.history.future.push(snapshot());
    state.project = state.history.past.pop();
    state.project = Store.normalizeProject(state.project);
    state.localizationDrafts = new Map();
    state.dirty = true;
    state.revision += 1;
    state.typing = false;
    ensureSelection();
    runValidation();
    render();
    scheduleSave();
    UI.toast('已撤销', 'info', 1400);
  }

  function redo() {
    if (!state.history.future.length || !state.project) return;
    state.history.past.push(snapshot());
    state.project = state.history.future.pop();
    state.project = Store.normalizeProject(state.project);
    state.localizationDrafts = new Map();
    state.dirty = true;
    state.revision += 1;
    state.typing = false;
    ensureSelection();
    runValidation();
    render();
    scheduleSave();
    UI.toast('已重做', 'info', 1400);
  }

  function ensureSelection() {
    if (!state.project) return;
    if (state.selected) {
      const file = state.project.contentFiles.find((item) => item.path === state.selected.file);
      if (file && file.definitions[state.selected.index]) {
        state.selected.type = file.content_type;
        return;
      }
    }
    state.selected = firstSelection(state.project);
  }

  /* ------------------------------------------------------------------ */
  /* Persistence                                                         */
  /* ------------------------------------------------------------------ */

  function fallbackKey(uid) {
    return `snmodmaker.fallback.${uid}`;
  }

  function loadFallbackProject() {
    try {
      const uid = root.localStorage.getItem('snmodmaker.fallback.current');
      if (!uid) return null;
      const text = root.localStorage.getItem(fallbackKey(uid));
      return text ? Store.deserialize(text) : null;
    } catch (error) {
      return null;
    }
  }

  async function saveNow(options) {
    const opts = options || {};
    if (!state.project) return;
    if (state.saving) {
      state.saveQueued = true;
      return;
    }
    state.saving = true;
    const revision = state.revision;
    updateSaveState();
    try {
      await IO.putProject(state.project);
      state.storageMode = 'idb';
    } catch (error) {
      try {
        root.localStorage.setItem(fallbackKey(state.project.uid), Store.serialize(state.project));
        root.localStorage.setItem('snmodmaker.fallback.current', state.project.uid);
        state.storageMode = 'local';
      } catch (inner) {
        state.storageMode = 'unavailable';
        UI.toast('无法保存到浏览器存储，请导出项目文件备份。', 'error', 6000);
      }
    } finally {
      state.saving = false;
      state.savedAt = new Date();
      if (state.revision === revision) {
        state.dirty = false;
      } else {
        state.dirty = true;
        state.saveQueued = true;
      }
      IO.rememberCurrent(state.project.uid);
      updateSaveState();
      if (state.saveQueued) {
        state.saveQueued = false;
        scheduleSave();
      }
    }
    if (state.backend) {
      if (opts.disk) await flushDiskSave(true);
      else scheduleDiskSave();
    }
  }

  async function flushDiskSave(options) {
    if (!state.project || !state.backend) return;
    if (state.diskSaving) {
      state.diskQueued = true;
      return;
    }
    const validate = options === true;
    state.diskSaving = true;
    updateSaveState();
    try {
      const result = state.workspace
        ? await IO.putWorkspaceProject(state.project, { validate })
        : await IO.putDiskProject(state.project);
      state.diskSavedAt = new Date();
      state.diskError = '';
      if (validate && result && result.validation) {
        const counts = result.validation.counts || {};
        if (counts.error > 0) {
          UI.toast(`工作区已写入，但校验有 ${counts.error} 个错误；先修掉再打包。`, 'warning', 6000);
        } else if (counts.warning > 0) {
          UI.toast(`工作区已写入（${counts.warning} 个警告）`, 'info', 2600);
        } else {
          UI.toast('工作区已写入并通过校验', 'success', 2200);
        }
      }
      if (validate && result && result.indexSynced) {
        UI.toast('Core 索引已重新生成', 'info', 2200);
      }
    } catch (error) {
      state.diskError = error.message || '写入磁盘失败';
      const target = state.workspace
        ? (state.backend.workspaceDir || 'dev_mods')
        : (state.backend.modsDir || 'mods');
      UI.toast(`写入 ${target}/ 失败：${state.diskError}`, 'warning', 5000);
    } finally {
      state.diskSaving = false;
      updateSaveState();
      if (state.diskQueued || state.dirty) {
        state.diskQueued = false;
        scheduleDiskSave();
      }
    }
  }

  async function openProject(uid) {
    if (!uid) return;
    try {
      if (state.dirty && state.project) await saveNow({ disk: true });
      const project = await IO.getProject(uid);
      if (!project) {
        UI.toast('项目不存在或已被删除。', 'error');
        return;
      }
      setProject(project);
      UI.closeModal();
      UI.toast(`已打开 ${project.manifest.name}`, 'success');
    } catch (error) {
      UI.toast(error.message || '打开项目失败', 'error', 5000);
    }
  }

  async function deleteProject(uid) {
    if (!uid) return;
    const ok = await UI.confirm({
      title: '删除项目',
      message: '会从浏览器本地存储中删除这个项目，无法撤销。建议先导出项目文件。',
      confirmLabel: '删除',
      danger: true,
    });
    if (!ok) return;
    try {
      await IO.deleteProject(uid);
      try {
        root.localStorage.removeItem(fallbackKey(uid));
        if (root.localStorage.getItem('snmodmaker.fallback.current') === uid) {
          root.localStorage.removeItem('snmodmaker.fallback.current');
        }
      } catch (error) {
        /* ignore */
      }
      if (state.project && state.project.uid === uid) clearProject();
      loadRecent();
      UI.toast('项目已删除', 'success');
    } catch (error) {
      UI.toast(error.message || '删除失败', 'error');
    }
  }

  /* ------------------------------------------------------------------ */
  /* Rendering: chrome                                                   */
  /* ------------------------------------------------------------------ */

  function render(options) {
    const opts = options || {};
    const workspace = document.getElementById('workspace');
    const scrollTop = workspace ? workspace.scrollTop : 0;
    const list = document.querySelector('.def-list');
    const listScroll = list ? list.scrollTop : 0;

    renderChrome();
    renderSidebar();
    renderWorkspace();
    if (state.view.name === 'assets') paintModelThumbnails();
    renderStatus();
    renderInspector();

    const datalists = document.getElementById('datalists');
    if (datalists) datalists.innerHTML = state.project ? UI.renderDatalists(state.project) : '';

    if (opts.preserveScroll) {
      const nextWorkspace = document.getElementById('workspace');
      if (nextWorkspace) nextWorkspace.scrollTop = scrollTop;
      const nextList = document.querySelector('.def-list');
      if (nextList) nextList.scrollTop = listScroll;
    }

    if (state.focusAfter) {
      const target = state.focusAfter;
      state.focusAfter = null;
      requestAnimationFrame(() => {
        const element = document.querySelector(target.selector);
        if (!element) return;
        element.scrollIntoView({ block: 'center', behavior: 'smooth' });
        if (typeof element.focus === 'function') element.focus({ preventScroll: true });
      });
    }
  }

  function renderChrome() {
    const project = state.project;
    const app = document.getElementById('app');
    app.classList.toggle('no-project', !project);
    app.classList.toggle('welcome-mode', !project || state.view.name === 'welcome');
    const chip = document.getElementById('project-chip');
    if (project) {
      const manifest = project.manifest;
      chip.innerHTML = `<button type="button" class="project-chip" data-action="project-library" title="打开项目库">
        <span class="unsaved-dot ${state.dirty ? 'on' : ''}"></span>
        <span class="project-chip-name">${UI.esc(manifest.name || '未命名模组')}</span>
        <span class="project-chip-meta mono">${UI.esc(manifest.id)} · v${UI.esc(manifest.version)}</span>
      </button>`;
    } else {
      chip.innerHTML = '<span class="brand-tag">未打开项目</span>';
    }

    const actions = [
      `<button type="button" class="btn small" data-action="new-project">新建</button>`,
      `<button type="button" class="btn small" data-action="import">导入</button>`,
    ];
    if (project) actions.push('<button type="button" class="btn small" data-action="export">导出</button>');
    actions.push('<button type="button" class="btn small ghost" data-action="project-library">项目</button>');
    actions.push('<button type="button" class="btn small ghost" data-action="help">帮助</button>');
    document.getElementById('topbar-actions').innerHTML = actions.join('');
  }

  function renderStatus() {
    const host = document.getElementById('topbar-status');
    if (!host) return;
    if (!state.project) {
      host.innerHTML = '';
      return;
    }
    const counts = state.issues.counts;
    host.innerHTML = `
      <span id="save-state" class="save-state ${state.dirty ? 'dirty' : ''}" title="${UI.attr(saveStateTitle())}">${UI.esc(saveStateText())}</span>
      <button type="button" class="status-pill ${counts.error ? 'has-error' : 'ok'}" data-nav="validate" title="错误">
        <span class="status-dot"></span>${counts.error}
      </button>
      <button type="button" class="status-pill ${counts.warning ? 'has-warning' : 'ok'}" data-nav="validate" title="警告">
        <span class="status-dot"></span>${counts.warning}
      </button>
      <button type="button" class="icon-btn inspector-toggle ${state.inspector ? 'active' : ''}" data-action="toggle-inspector" title="JSON 检视">JSON</button>`;
  }

  function saveStateText() {
    if (state.saving || state.diskSaving) return '保存中…';
    if (state.dirty) return '未保存';
    const base = state.savedAt ? `已保存 ${timeText(state.savedAt)}` : '已保存';
    if (!state.backend) return base;
    if (state.diskError) return `${base} · 磁盘失败`;
    if (state.diskSavedAt) return `${base} · 磁盘`;
    return `${base} · 待写入磁盘`;
  }

  function saveStateTitle() {
    if (!state.backend) return '自动保存到浏览器 IndexedDB';
    return `浏览器 IndexedDB；同时写入 ${state.backend.modsDir || 'mods'}/`;
  }

  function updateSaveState() {
    const node = document.getElementById('save-state');
    if (!node) return;
    node.textContent = saveStateText();
    node.title = saveStateTitle();
    node.classList.toggle('dirty', state.dirty);
  }

  function timeText(date) {
    try {
      return new Date(date).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', hour12: false });
    } catch (error) {
      return '';
    }
  }

  function renderSidebar() {
    const host = document.getElementById('sidebar');
    if (!host) return;
    if (!state.project) {
      host.innerHTML = '';
      return;
    }
    const counts = new Map();
    const typeIssues = new Map();
    for (const file of state.project.contentFiles) {
      counts.set(file.content_type, (counts.get(file.content_type) || 0) + (file.definitions || []).length);
    }
    for (const issue of state.issues.issues) {
      if (issue.view && issue.view.name === 'content' && issue.view.type) {
        const bucket = typeIssues.get(issue.view.type) || { error: 0, warning: 0 };
        if (issue.severity === 'error') bucket.error += 1;
        if (issue.severity === 'warning') bucket.warning += 1;
        typeIssues.set(issue.view.type, bucket);
      }
    }

    const groups = Cat.GROUPS.map((group) => {
      const types = Cat.TYPES.filter((type) => type.group === group);
      return `<div class="side-group">
        <h3>${UI.esc(group)}</h3>
        ${types.map((type) => sideTypeLink(type, counts.get(type.key) || 0, typeIssues.get(type.key))).join('')}
      </div>`;
    }).join('');

    const draftGroup = renderDraftSideGroup(counts, typeIssues);

    const localeLinks = state.project.localization.map((entry) => `
      <button type="button" class="side-link ${activeLocale(entry.locale) ? 'active' : ''}" data-nav="localization:${UI.attr(entry.locale)}">
        <span class="abbr loc">文</span><span class="side-label">${UI.esc(entry.locale)}</span>
        <span class="count">${Object.keys(entry.entries || {}).length}</span>
      </button>`).join('');

    host.innerHTML = `
      <button type="button" class="side-link ${state.view.name === 'overview' ? 'active' : ''}" data-nav="overview">
        <span class="abbr">MN</span><span class="side-label">模组概览</span>
      </button>
      ${groups}
      ${draftGroup}
      <div class="side-group">
        <h3>文本与资源</h3>
        ${localeLinks || '<p class="side-empty">没有本地化文件</p>'}
        <button type="button" class="side-link ${state.view.name === 'assets' ? 'active' : ''}" data-nav="assets">
          <span class="abbr">AS</span><span class="side-label">资源</span>
          <span class="count">${state.project.assets.length}</span>
        </button>
        <button type="button" class="side-link ${state.view.name === 'validate' ? 'active' : ''}" data-nav="validate">
          <span class="abbr">CK</span><span class="side-label">校验</span>
          <span class="count ${state.issues.counts.error ? 'bad' : state.issues.counts.warning ? 'warn' : ''}">${state.issues.counts.total}</span>
        </button>
      </div>
      <div class="side-foot">
        <p>零依赖 · ${state.backend ? `磁盘 ${UI.esc(state.backend.modsDir || 'mods')}/ + ${UI.esc(state.backend.exportsDir || 'exports')}/` : '浏览器存储 IndexedDB'}</p>
        <p class="mono">${draftSchemaFootText()}</p>
      </div>`;
  }

  function draftSchemaFootText() {
    if (!Cat.DRAFT_TYPES || !Cat.DRAFT_TYPES.length) return 'Schema 1.0 / 2.0 / API 1.0';
    return 'Schema 1.0 / 2.0 运行时 + 草案 / API 1.0';
  }

  function renderDraftSideGroup(counts, typeIssues) {
    if (!Cat.DRAFT_TYPES || !Cat.DRAFT_TYPES.length) return '';
    const links = Cat.DRAFT_TYPES.map((type) => sideTypeLink(type, counts.get(type.key) || 0, typeIssues.get(type.key), true)).join('');
    return `<div class="side-group side-group-draft">
      <h3 class="side-draft-head">
        <span>Schema 2.0 草案</span>
        <span class="side-draft-tag">运行时不加载</span>
      </h3>
      ${links}
    </div>`;
  }

  function sideTypeLink(type, count, issues, draft) {
    const active = state.view.name === 'content' && state.view.type === type.key;
    const dot = issues && issues.error ? 'error' : issues && issues.warning ? 'warning' : '';
    const isDraftType = Boolean(draft || type.draft);
    const draftClass = isDraftType ? ' draft-type' : '';
    const title = isDraftType ? ' title="Schema 2.0 草案 · 当前游戏运行时不加载"' : '';
    return `<button type="button" class="side-link${draftClass} ${active ? 'active' : ''}" data-nav="content:${UI.attr(type.key)}"${title}>
      <span class="abbr" style="--abbr:${UI.attr(type.color)}">${UI.esc(type.abbr)}</span>
      <span class="side-label">${UI.esc(type.label)}</span>
      <span class="count">${count}</span>
      ${dot ? `<span class="issue-dot ${dot}"></span>` : ''}
    </button>`;
  }

  function activeLocale(locale) {
    return state.view.name === 'localization' && state.view.locale === locale;
  }

  /* ------------------------------------------------------------------ */
  /* Rendering: workspace                                                */
  /* ------------------------------------------------------------------ */

  function renderWorkspace() {
    const host = document.getElementById('workspace');
    if (!host) return;
    if (!state.project || state.view.name === 'welcome') {
      host.className = 'workspace view-welcome';
      host.innerHTML = renderWelcome();
      loadRecent();
      return;
    }
    host.className = `workspace view-${state.view.name}`;
    if (state.view.name === 'overview') host.innerHTML = renderOverview();
    else if (state.view.name === 'content') host.innerHTML = renderContent();
    else if (state.view.name === 'localization') host.innerHTML = renderLocalization();
    else if (state.view.name === 'assets') host.innerHTML = renderAssets();
    else if (state.view.name === 'validate') host.innerHTML = renderValidation();
    else host.innerHTML = renderOverview();
  }

  /* ------------------------------------------------------------------ */
  /* Welcome                                                             */
  /* ------------------------------------------------------------------ */

  function renderWelcome() {
    const hasProject = Boolean(state.project);
    return `<div class="welcome">
      <section class="welcome-intro">
        <p class="eyebrow">STEAM NAVIGATOR</p>
        <h1>模组制作器</h1>
        <p class="lede">可视化编辑 Manifest、内容、本地化与资源，按官方 Schema 校验，然后导出 <code>.snavmod.zip</code>。</p>
        <div class="hero-actions">
          <button type="button" class="btn primary" data-action="new-project">新建模组</button>
          <button type="button" class="btn" data-action="import">导入现有模组</button>
          ${hasProject ? `<button type="button" class="btn ghost" data-action="resume-project">继续编辑 ${UI.esc(state.project.manifest.name)}</button>` : ''}
        </div>
        <p class="tiny">零依赖，离线可用。项目默认保存在浏览器；启动本地服务后，也会写入 <code>SNModMaker/mods/</code>。</p>
      </section>

      <section class="recent-panel">
        <header class="panel-head">
          <div><h2>最近项目</h2><p>浏览器项目库，以及本地服务可用的磁盘工作区</p></div>
          <button type="button" class="btn small ghost" data-action="refresh-recent">刷新</button>
        </header>
        <div id="recent-list" class="recent-list"><p class="loading-text">读取本地项目…</p></div>
      </section>
    </div>`;
  }

  async function loadRecent() {
    const host = document.getElementById('recent-list');
    if (!host) return;
    try {
      const rows = await IO.listProjects();
      let diskRows = [];
      if (state.backend) {
        try {
          diskRows = await IO.listDiskProjects();
        } catch (error) {
          diskRows = [];
        }
      }
      if (!document.body.contains(host)) return;
      if (!rows.length && !diskRows.length) {
        host.innerHTML = '<div class="empty-inline large">还没有本地项目。新建一个，或导入现有模组。</div>';
        return;
      }
      const diskHtml = diskRows.map((item) => `
        <div class="recent-row">
          <button type="button" class="recent-main" data-action="${item.workspace ? 'open-workspace-project' : 'open-disk-project'}" data-id="${UI.attr(item.id)}">
            <span class="recent-name">${UI.esc(item.name)}</span>
            <span class="recent-meta mono">${UI.esc(item.id)} · v${UI.esc(item.version)} · ${item.definitions} 条定义</span>
          </button>
          <span class="recent-time">${UI.esc(UI.fmtDate(item.updatedAt))}</span>
          <span class="recent-badge">${item.workspace ? '工作区' : 'mods/'}</span>
          ${item.workspace ? '' : `<button type="button" class="icon-btn tiny danger" data-action="delete-disk-project" data-id="${UI.attr(item.id)}" title="删除磁盘项目">✕</button>`}
        </div>`).join('');
      const browserHtml = rows.map((project) => {
        const manifest = project.manifest || {};
        const counts = state.project && state.project.uid === project.uid ? state.issues.counts : null;
        return `<div class="recent-row">
          <button type="button" class="recent-main" data-action="open-project" data-uid="${UI.attr(project.uid)}">
            <span class="recent-name">${UI.esc(manifest.name || '未命名模组')}</span>
            <span class="recent-meta mono">${UI.esc(manifest.id || '')} · v${UI.esc(manifest.version || '')}</span>
          </button>
          <span class="recent-time">${UI.esc(UI.fmtDate(project.meta && project.meta.updatedAt))}</span>
          ${counts ? `<span class="recent-issues">${counts.error} 错 / ${counts.warning} 警</span>` : ''}
          <button type="button" class="icon-btn tiny danger" data-action="delete-project" data-uid="${UI.attr(project.uid)}" title="删除项目">✕</button>
        </div>`;
      }).join('');
      host.innerHTML = `
        ${state.backend ? `<p class="recent-label mono">磁盘 · ${UI.esc(state.backend.modsDir || 'mods')}/ 与工作区 ${UI.esc(state.backend.workspaceDir || 'dev_mods')}/</p>${diskHtml || '<p class="empty-inline">还没有写入磁盘的项目。保存后会自动出现在这里。</p>'}` : ''}
        <p class="recent-label mono">浏览器 · IndexedDB</p>
        ${browserHtml || '<p class="empty-inline">没有浏览器项目。</p>'}`;
    } catch (error) {
      if (document.body.contains(host)) {
        host.innerHTML = '<div class="empty-inline large">无法读取浏览器项目库。你仍然可以新建或导入项目，并导出项目文件备份。</div>';
      }
    }
  }

  /* ------------------------------------------------------------------ */
  /* Overview                                                            */
  /* ------------------------------------------------------------------ */

  function renderOverview() {
    const project = state.project;
    const manifest = project.manifest;
    const mismatch = project.contentFiles.some((file) => (file.definitions || []).some((definition) => {
      const id = definition && definition.id;
      return id && !String(id).startsWith(`${manifest.id}:`);
    }));
    return `<div class="view overview-view">
      <header class="view-head">
        <div>
          <p class="eyebrow">MOD MANIFEST</p>
          <h1>${UI.esc(manifest.name || '未命名模组')}</h1>
          <p class="view-sub">${UI.esc(manifest.description || '还没有填写描述。建议写清楚这个模组新增或修改了什么。')}</p>
        </div>
        <div class="head-actions">
          <button type="button" class="btn small" data-action="import">导入</button>
          <button type="button" class="btn small" data-action="export">导出</button>
        </div>
      </header>

      ${mismatch ? `<div class="notice warning">
        <div><strong>有定义不在当前模组命名空间内。</strong><span>修改模组 ID 后，已有定义的 ID 与本地化键不会自动重写。</span></div>
        <button type="button" class="btn small" data-action="sync-namespace">同步命名空间</button>
      </div>` : ''}

      <div class="overview-grid">
        <section class="panel">
          <header class="panel-head"><div><h2>基本信息</h2><p>Manifest 的身份与加载顺序</p></div></header>
          <div class="field-grid">
            ${ovField('模组 ID', UI.inputText('manifest.id', manifest.id, { className: 'mono', spellcheck: false }), '小写字母开头，3–32 位，仅 a-z / 0-9 / _。一旦发布不要更改。')}
            ${ovField('显示名称', UI.inputText('manifest.name', manifest.name))}
            ${ovField('版本', UI.inputText('manifest.version', manifest.version, { className: 'mono', spellcheck: false }), 'SemVer 2.0，例如 1.2.0。')}
            ${ovField('API 版本', UI.inputText('manifest.api_version', manifest.api_version, { className: 'mono', spellcheck: false }), '当前框架为 1.0。')}
            ${ovField('加载优先级', UI.inputText('manifest.load_priority', manifest.load_priority, { parse: 'int', className: 'mono' }), '-100 到 100；不能替代依赖声明。')}
            <div class="field">
              <label class="field-label">类型 / 必需</label>
              <div class="inline-row">
                <span class="static-chip mono">content</span>
                ${UI.toggle('manifest.required', Boolean(manifest.required), 'required')}
              </div>
              <p class="field-hint">第三方模组不能声明 required = true。</p>
            </div>
            ${ovField('描述', `<textarea class="input" rows="3" data-field="manifest.description" data-parse="text">${UI.esc(manifest.description || '')}</textarea>`, '', true)}
          </div>
        </section>

        <section class="panel">
          <header class="panel-head"><div><h2>依赖</h2><p>版本范围使用 SemVer 比较器</p></div>
            <button type="button" class="btn small ghost" data-action="add-dep" data-list="dependencies">+ 依赖</button>
          </header>
          <div class="dep-list">
            ${(manifest.dependencies || []).map((dependency, index) => depRow('dependencies', dependency, index)).join('') || '<p class="empty-inline">没有依赖。引用 Core 内容时通常应依赖 core。</p>'}
          </div>
          <details class="sub-panel">
            <summary>可选依赖 <span class="count">${(manifest.optional_dependencies || []).length}</span></summary>
            <div class="dep-list">
              ${(manifest.optional_dependencies || []).map((dependency, index) => depRow('optional_dependencies', dependency, index)).join('') || '<p class="empty-inline">没有可选依赖。</p>'}
            </div>
            <button type="button" class="btn small ghost" data-action="add-dep" data-list="optional_dependencies">+ 可选依赖</button>
          </details>
          <details class="sub-panel">
            <summary>冲突模组 <span class="count">${(manifest.conflicts || []).length}</span></summary>
            ${UI.stringList('manifest.conflicts', manifest.conflicts || [], { placeholder: '输入模组 ID 后回车' })}
          </details>
        </section>

        <section class="panel">
          <header class="panel-head"><div><h2>打包清单</h2><p>由内容文件、本地化与资源自动生成</p></div></header>
          <div class="file-list">
            ${project.contentFiles.map((file) => {
              const info = Cat.BY_KEY[file.content_type];
              return `<button type="button" class="file-row" data-nav="content:${UI.attr(file.content_type)}">
                <span class="file-type" style="--abbr:${UI.attr(info ? info.color : '#888')}">${UI.esc(info ? info.abbr : '??')}</span>
                <span class="file-path mono">${UI.esc(file.path)}</span>
                ${info && info.draft ? '<span class="mini-badge draft">2.0 草案</span>' : ''}
                <span class="file-count">${(file.definitions || []).length} 条</span>
              </button>`;
            }).join('') || '<p class="empty-inline">还没有内容文件。</p>'}
          </div>
          <div class="file-list secondary">
            ${project.localization.map((entry) => `<div class="file-row static">
              <span class="file-type loc">文</span><span class="file-path mono">${UI.esc(entry.path)}</span>
              <span class="file-count">${Object.keys(entry.entries || {}).length} 键</span>
            </div>`).join('')}
            <div class="file-row static">
              <span class="file-type">AS</span><span class="file-path mono">assets/</span><span class="file-count">${project.assets.length} 个资源</span>
            </div>
          </div>
          <div class="structure-preview"><pre>${UI.esc(structureTree(project))}</pre></div>
        </section>

        <section class="panel">
          <header class="panel-head"><div><h2>元信息</h2><p>作者、许可与能力声明</p></div></header>
          <div class="field-grid">
            <div class="field">
              <label class="field-label">作者</label>
              ${UI.stringList('manifest.authors', manifest.authors || [], { placeholder: '输入作者名后回车' })}
            </div>
            ${ovField('许可', UI.inputText('manifest.license', manifest.license || '', { className: 'mono' }))}
            <div class="field">
              <label class="field-label">能力声明</label>
              ${UI.stringList('manifest.capabilities', manifest.capabilities || [], { placeholder: 'content.event.choice_pool.v1' })}
            </div>
            ${ovField('校验和', UI.inputText('manifest.checksum', manifest.checksum || '', { className: 'mono', placeholder: 'sha256:…（打包时生成）' }), '可由 SDK 生成；网页端不自动计算。')}
          </div>
        </section>
      </div>
    </div>`;
  }

  function ovField(labelText, control, hintText, wide) {
    return `<div class="field ${wide ? 'field-wide' : ''}">
      <label class="field-label">${UI.esc(labelText)}</label>
      ${control}
      ${hintText ? `<p class="field-hint">${UI.esc(hintText)}</p>` : ''}
    </div>`;
  }

  function depRow(list, dependency, index) {
    return `<div class="dep-row">
      <input class="input mono" type="text" value="${UI.attr(dependency.id || '')}" data-field="manifest.${list}.${index}.id" data-parse="text" placeholder="core" spellcheck="false">
      <input class="input mono" type="text" value="${UI.attr(dependency.version || '')}" data-field="manifest.${list}.${index}.version" data-parse="text" placeholder=">=1.0.0 <2.0.0" spellcheck="false">
      <button type="button" class="icon-btn tiny danger" data-action="remove-dep" data-list="${UI.attr(list)}" data-index="${index}" title="移除">✕</button>
    </div>`;
  }

  function structureTree(project) {
    const lines = [`mods/${project.manifest.id}/`, '├─ manifest.json'];
    lines.push('├─ content/');
    project.contentFiles.forEach((file, index) => {
      const last = index === project.contentFiles.length - 1;
      lines.push(`${last ? '│  └─' : '│  ├─'} ${file.path.replace(/^content\//, '')} (${(file.definitions || []).length})`);
    });
    if (project.localization.length) {
      lines.push('├─ localization/');
      project.localization.forEach((entry, index) => {
        lines.push(`${index === project.localization.length - 1 ? '│  └─' : '│  ├─'} ${entry.path.replace(/^localization\//, '')}`);
      });
    }
    if (project.assets.length) {
      lines.push('└─ assets/');
      project.assets.slice(0, 6).forEach((asset, index) => {
        const last = index === Math.min(project.assets.length, 6) - 1;
        lines.push(`${last ? '   └─' : '   ├─'} ${asset.path.replace(/^assets\//, '')}`);
      });
      if (project.assets.length > 6) lines.push(`   └─ … 另有 ${project.assets.length - 6} 个资源`);
    }
    return lines.join('\n');
  }

  /* ------------------------------------------------------------------ */
  /* Content type view                                                   */
  /* ------------------------------------------------------------------ */

  function renderModuleTabs(activeType) {
    if (!MODULE_PAGE_TYPES.includes(activeType)) return '';
    return `<nav class="module-tabs" aria-label="船只与模块子分页">
      <span class="module-tabs-label">船只与模块</span>
      ${MODULE_PAGE_TYPES.map((typeKey) => {
        const type = Cat.BY_KEY[typeKey];
        const count = state.project.contentFiles
          .filter((file) => file.content_type === typeKey)
          .reduce((sum, file) => sum + (file.definitions || []).length, 0);
        return `<button type="button" class="module-tab ${activeType === typeKey ? 'active' : ''}" data-nav="content:${UI.attr(typeKey)}">
          ${UI.esc(type.label)}<span>${count}</span>
        </button>`;
      }).join('')}
    </nav>`;
  }

  function renderContent() {
    const typeKey = state.view.type;
    const info = Cat.BY_KEY[typeKey];
    if (!info) return '<div class="empty inline large">未知的内容类型。</div>';
    ensureSelection();
    const files = state.project.contentFiles.filter((file) => file.content_type === typeKey);
    const all = [];
    files.forEach((file) => (file.definitions || []).forEach((definition, index) => {
      all.push({ file, definition, index });
    }));
    if (state.selected && state.selected.type !== typeKey) {
      state.selected = all.length ? { type: typeKey, file: all[0].file.path, index: all[0].index } : null;
    }
    const selected = all.find((item) => state.selected && item.file.path === state.selected.file && item.index === state.selected.index) || all[0];
    if (selected) state.selected = { type: typeKey, file: selected.file.path, index: selected.index };

    const cards = all.map((item) => {
      const key = `${item.file.path}#${item.index}`;
      const badge = state.issueByDef.get(key) || { error: 0, warning: 0 };
      const title = Store.definitionTitle(state.project, item.definition);
      const localId = item.definition.id ? Store.localPart(item.definition.id) : (item.definition.target || 'patch');
      const search = `${title} ${item.definition.id || ''} ${(item.definition.tags || []).join(' ')}`.toLowerCase();
      const active = selected && selected.file.path === item.file.path && selected.index === item.index;
      const query = state.search.trim().toLowerCase();
      const hidden = Boolean(query) && !search.includes(query);
      return `<div class="def-card ${active ? 'active' : ''} ${item.definition.enabled === false ? 'disabled' : ''}"
          data-select-def data-file="${UI.attr(item.file.path)}" data-index="${item.index}" data-search="${UI.attr(search)}" tabindex="0" role="button" ${hidden ? 'hidden' : ''}>
        <div class="def-card-top">
          <span class="def-title">${UI.esc(title)}</span>
          <span class="def-badges">
            ${badge.error ? `<span class="mini-badge error">${badge.error}</span>` : ''}
            ${badge.warning ? `<span class="mini-badge warning">${badge.warning}</span>` : ''}
          </span>
        </div>
        <div class="def-card-meta">
          <span class="mono">${UI.esc(localId)}</span>
          <span class="def-file">${UI.esc(item.file.path)}</span>
        </div>
        ${(item.definition.tags || []).length ? `<div class="def-tags">${item.definition.tags.slice(0, 4).map((tag) => `<span class="tag">${UI.esc(tag)}</span>`).join('')}</div>` : ''}
      </div>`;
    }).join('');

    return `<div class="view content-view">
      <header class="view-head">
        <div class="type-heading">
          <span class="type-mark" style="--abbr:${UI.attr(info.color)}">${UI.esc(info.abbr)}</span>
          <div>
            <h1>${UI.esc(info.label)} <span class="singular mono">${UI.esc(info.singular)}</span>${info.draft ? ' <span class="draft-badge">Schema 2.0 草案</span>' : ''}</h1>
            <p class="view-sub">${UI.esc(info.summary)}</p>
            ${info.draft ? `<div class="draft-notice" role="note">
              <span class="draft-dot"></span>
              <span><strong>Schema 2.0 草案 · 当前游戏运行时不加载。</strong>
              导出内容使用 <code>schema_version: "2.0"</code>，可用于起草、编辑与校验；已提升为运行时类型的 2.0 内容（世界 / 战役）不受影响，草案内容不会被游戏加载。</span>
            </div>` : ''}
          </div>
        </div>
        <div class="head-actions">
          ${info.draft ? '' : '<button type="button" class="btn small ghost" data-action="core-clone">从 Core 复制</button>'}
          <button type="button" class="btn primary small" data-action="add-definition">+ 新增定义</button>
        </div>
      </header>

      ${renderModuleTabs(typeKey)}

      <div class="content-layout">
        <section class="def-list-panel">
          <div class="list-tools">
            <input class="input search" type="search" placeholder="搜索名称、ID 或标签…" value="${UI.attr(state.search)}" data-filter="content">
            <span class="list-count">${all.length} 条</span>
          </div>
          <div class="def-list">${cards || `<div class="empty-inline large">还没有${UI.esc(info.label)}定义。</div>`}</div>
          <button type="button" class="btn ghost block" data-action="add-definition">+ 新增${UI.esc(info.label)}</button>
        </section>
        <section class="editor-panel" id="definition-editor">
          ${selected ? renderDefinitionEditor(selected, info) : `<div class="empty-editor"><h3>还没有可编辑的定义</h3><p>点击「新增${UI.esc(info.label)}」开始；已有模组也可以从 Core 复制一个条目再改。</p><button type="button" class="btn primary" data-action="add-definition">+ 新增定义</button></div>`}
        </section>
      </div>
    </div>`;
  }

  function renderDefinitionEditor(selected, info) {
    const { file, index, definition } = selected;
    const title = Store.definitionTitle(state.project, definition);
    const typeKey = file.content_type;
    const key = `${file.path}#${index}`;
    const badge = state.issueByDef.get(key) || { error: 0, warning: 0 };
    const locDraft = currentLocalizationDraft();
    if (state.rawOpen) {
      return `<div class="editor-head">
        <div><h2>${UI.esc(title)}</h2><p class="mono muted-sm">${UI.esc(definition.id || definition.target || '')}</p></div>
        <div class="head-actions">
          <button type="button" class="btn small primary" data-action="apply-raw">应用 JSON</button>
          <button type="button" class="btn small ghost" data-action="cancel-raw">取消</button>
        </div>
      </div>
      <div class="editor-body raw-body">
        <p class="field-hint">直接编辑单条定义。保存时会整体替换当前定义，并立即重新校验。</p>
        <textarea class="input mono code raw-json" id="raw-json" spellcheck="false">${UI.esc(JSON.stringify(definition, null, 2))}</textarea>
        <p class="form-error" id="raw-error"></p>
      </div>`;
    }
    return `<div class="editor-head">
      <div>
        <div class="editor-eyebrow">
          <span class="mono">${UI.esc(definition.id || definition.target || '')}</span>
          <span class="dot-sep">·</span><span class="mono muted-sm">${UI.esc(file.path)}</span>
        </div>
        <h2>${UI.esc(title)}</h2>
      </div>
      <div class="head-actions">
        ${info.draft ? '<span class="mini-badge draft">2.0 草案</span>' : ''}
        ${badge.error ? `<span class="mini-badge error">${badge.error} 错误</span>` : ''}
        ${badge.warning ? `<span class="mini-badge warning">${badge.warning} 警告</span>` : ''}
        <span class="mini-badge warning" data-localization-pending ${locDraft ? '' : 'hidden'}>多语言待保存</span>
        ${typeKey !== 'patches' ? `<button type="button" class="btn small ${locDraft ? 'primary' : ''}" data-action="save-definition">保存条目</button>` : ''}
        <button type="button" class="btn small ghost" data-action="toggle-raw">JSON</button>
        <button type="button" class="btn small ghost" data-action="duplicate-definition">复制</button>
        <button type="button" class="btn small danger ghost" data-action="delete-definition">删除</button>
      </div>
    </div>
    <div class="editor-body">
      ${UI.renderDefinitionForm({
        project: state.project,
        typeKey,
        definition,
        file,
        index,
        schemaFile: info.schema,
        localizationDraft: locDraft,
      })}
    </div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Localization view                                                   */
  /* ------------------------------------------------------------------ */

  function collectNeededKeys(project) {
    const map = new Map();
    for (const file of project.contentFiles) {
      if (file.content_type === 'patches') continue;
      (file.definitions || []).forEach((definition, index) => {
        for (const key of Store.collectDefinitionKeys(definition)) {
          const refs = map.get(key) || [];
          refs.push({ file: file.path, index, type: file.content_type });
          map.set(key, refs);
        }
      });
    }
    return map;
  }

  function renderLocalization() {
    if (!state.project.localization.length) {
      return `<div class="view">
        <header class="view-head"><div><p class="eyebrow">LOCALIZATION</p><h1>本地化</h1><p class="view-sub">内容名称与描述通过本地化键引用。</p></div>
        <div class="head-actions"><button class="btn primary small" data-action="add-locale">新建语言</button></div></header>
        <div class="empty-editor large"><h3>还没有本地化文件</h3><p>至少添加一个语言，否则所有名称/描述键都会回退为键名。</p></div>
      </div>`;
    }
    const locale = state.project.localization.some((entry) => entry.locale === state.locale)
      ? state.locale
      : state.project.localization[0].locale;
    state.locale = locale;
    const entry = Store.getLoc(state.project, locale);
    const needed = collectNeededKeys(state.project);
    const existing = entry ? entry.entries : {};
    const allKeys = new Set([...needed.keys(), ...Object.keys(existing)]);
    const query = state.locSearch.toLowerCase();
    let rows = [...allKeys].sort((a, b) => a.localeCompare(b));
    const missingTotal = [...needed.keys()].filter((key) => !String(existing[key] || '').trim()).length;
    const translated = [...needed.keys()].filter((key) => String(existing[key] || '').trim()).length;
    const coverage = needed.size ? Math.round((translated / needed.size) * 100) : 100;

    rows = rows.filter((key) => {
      const value = existing[key];
      const missing = needed.has(key) && !String(value || '').trim();
      if (state.missingOnly && !missing) return false;
      if (!query) return true;
      return `${key} ${value || ''}`.toLowerCase().includes(query);
    });

    const tabs = state.project.localization.map((item) => {
      const itemEntry = item.entries || {};
      const itemNeeded = [...needed.keys()].filter((key) => !String(itemEntry[key] || '').trim()).length;
      return `<button type="button" class="tab ${item.locale === locale ? 'active' : ''}" data-nav="localization:${UI.attr(item.locale)}">
        ${UI.esc(item.locale)} ${itemNeeded ? `<span class="tab-badge">${itemNeeded}</span>` : ''}
      </button>`;
    }).join('');

    return `<div class="view localization-view">
      <header class="view-head">
        <div><p class="eyebrow">LOCALIZATION</p><h1>本地化</h1><p class="view-sub">名称键与描述键必须在这里有对应文本，导出后游戏才能显示可读名称。</p></div>
        <div class="head-actions">
          <button type="button" class="btn small ghost" data-action="add-locale">新建语言</button>
          <button type="button" class="btn small ghost" data-action="add-loc-key">+ 键</button>
          <button type="button" class="btn small" data-action="fill-missing">补齐缺失键</button>
        </div>
      </header>
      <div class="tabs">${tabs}</div>
      <div class="coverage-card">
        <div class="coverage-head"><strong>${UI.esc(locale)}</strong><span>${translated} / ${needed.size} 个必需键已翻译</span><span class="coverage-pct">${coverage}%</span></div>
        <div class="coverage-bar"><span style="width:${coverage}%"></span></div>
      </div>
      <div class="list-tools">
        <input class="input search" type="search" placeholder="搜索键或文本…" value="${UI.attr(state.locSearch)}" data-filter="loc">
        <label class="checkbox-line"><input type="checkbox" data-filter-toggle="missing" ${state.missingOnly ? 'checked' : ''}> 只看缺失</label>
        <span class="list-count">${rows.length} 个键</span>
      </div>
      <div class="loc-table">
        <div class="loc-head"><span>键</span><span>${UI.esc(locale)} 文本</span><span>引用</span><span></span></div>
        ${rows.map((key) => {
          const value = existing[key] == null ? '' : existing[key];
          const isNeeded = needed.has(key);
          const missing = isNeeded && !String(value).trim();
          const refs = needed.get(key) || [];
          return `<div class="loc-row ${missing ? 'missing' : ''}">
            <div class="loc-key"><span class="mono">${UI.esc(key)}</span>${missing ? '<span class="mini-badge warning">缺失</span>' : ''}${!isNeeded ? '<span class="mini-badge ghost">未引用</span>' : ''}</div>
            <input class="input" type="text" value="${UI.attr(value)}" data-locale-input="${UI.attr(key)}" placeholder="输入 ${UI.esc(locale)} 文本">
            <div class="loc-refs">${refs.length ? refs.map((ref, refIndex) => `<button type="button" class="link-btn" data-action="goto-key-def" data-file="${UI.attr(ref.file)}" data-index="${ref.index}">${UI.esc(Cat.BY_KEY[ref.type] ? Cat.BY_KEY[ref.type].label : ref.type)}${refs.length > 1 ? ` #${refIndex + 1}` : ''}</button>`).join('') : '<span class="muted-sm">—</span>'}</div>
            <button type="button" class="icon-btn tiny danger" data-action="delete-loc-key" data-key="${UI.attr(key)}" title="删除这个键">✕</button>
          </div>`;
        }).join('') || '<div class="empty-inline large">没有匹配的键。</div>'}
      </div>
    </div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Assets view                                                         */
  /* ------------------------------------------------------------------ */

  function renderAssets() {
    const assets = state.project.assets;
    const cards = assets.map((asset) => {
      const isImage = /^image\//.test(asset.mime || '') && asset.dataUrl;
      const isModel = !isImage && asset.dataUrl && (/model\/gltf-binary/i.test(asset.mime || '') || /\.glb$/i.test(asset.path));
      const preview = isImage
        ? `<img src="${UI.attr(asset.dataUrl)}" alt="">`
        : isModel
          ? `<span class="asset-model-thumb" data-model-thumb="${UI.attr(asset.path)}"><span class="asset-ext">GLB</span></span>`
          : `<span class="asset-ext">${UI.esc((asset.path.split('.').pop() || '?').toUpperCase())}</span>`;
      return `<article class="asset-card">
        <div class="asset-preview">${preview}</div>
        <div class="asset-body">
          <label class="field-label">资源键</label>
          <input class="input mono" type="text" value="${UI.attr(asset.key || '')}" data-asset-key="${UI.attr(asset.path)}" spellcheck="false">
          <p class="mono asset-path">${UI.esc(asset.path)}</p>
          <p class="muted-sm">${UI.fmtSize(asset.size || 0)}${asset.dataUrl ? '' : ' · 没有附件内容'}</p>
        </div>
        <div class="asset-actions">
          <button type="button" class="btn small ghost" data-action="download-asset" data-path="${UI.attr(asset.path)}">下载</button>
          <button type="button" class="icon-btn tiny danger" data-action="remove-asset" data-path="${UI.attr(asset.path)}" title="删除资源">✕</button>
        </div>
      </article>`;
    }).join('');

    return `<div class="view assets-view">
      <header class="view-head">
        <div><p class="eyebrow">ASSETS</p><h1>资源</h1><p class="view-sub">图标、贴图、音频与实体模型。允许 png / webp / svg / ogg / wav / glb；GLB 会生成自动取景缩略图，资源键会自动写入 manifest.assets。</p></div>
        <div class="head-actions"><button type="button" class="btn primary small" data-action="add-asset">添加资源</button></div>
      </header>
      <div class="asset-grid">${cards || `<div class="empty-inline large">还没有资源。图标是可选的；内容定义里的 icon 字段可以引用这里的资源键。</div>`}</div>
      <p class="field-hint">单个资源建议不超过 2 MB，全部资源会随 ZIP 一起打包。网页端不导入 Godot 的 .import 元数据。</p>
    </div>`;
  }

  /* ------------------------------------------------------------------ */
  /* GLB thumbnails                                                      */
  /* ------------------------------------------------------------------ */

  const modelThumbQueue = [];
  let modelThumbBusy = false;

  function paintModelThumbnails() {
    if (!state.project || !root.SNModelThumb) return;
    for (const node of document.querySelectorAll('[data-model-thumb]')) {
      if (node.dataset.thumbReady) continue;
      const path = node.getAttribute('data-model-thumb');
      const asset = state.project.assets.find((item) => item.path === path);
      if (!asset) continue;
      const image = root.SNModelThumb.cached(asset);
      if (image) {
        setModelThumbImage(node, image);
        continue;
      }
      if (node.dataset.thumbQueued) continue;
      node.dataset.thumbQueued = '1';
      modelThumbQueue.push({ node, asset });
    }
    if (!modelThumbBusy) runModelThumbQueue();
  }

  async function runModelThumbQueue() {
    if (modelThumbBusy) return;
    modelThumbBusy = true;
    while (modelThumbQueue.length) {
      const job = modelThumbQueue.shift();
      await new Promise((resolve) => setTimeout(resolve, 0));
      if (!job.node.isConnected) continue;
      try {
        const image = root.SNModelThumb.render(job.asset);
        if (image && job.node.isConnected) setModelThumbImage(job.node, image);
        else job.node.classList.add('is-failed');
      } catch (error) {
        job.node.classList.add('is-failed');
        job.node.title = error && error.message ? error.message : '模型缩略图生成失败';
      }
    }
    modelThumbBusy = false;
  }

  function setModelThumbImage(node, dataUrl) {
    node.innerHTML = `<img src="${UI.attr(dataUrl)}" alt="">`;
    node.dataset.thumbReady = '1';
    node.classList.add('is-rendered');
  }

  /* ------------------------------------------------------------------ */
  /* Validation view                                                     */
  /* ------------------------------------------------------------------ */

  function renderValidation() {
    const issues = state.issues.issues.filter((issue) => state.validFilter === 'all' || issue.severity === state.validFilter);
    const counts = state.issues.counts;
    return `<div class="view validation-view">
      <header class="view-head">
        <div><p class="eyebrow">VALIDATION</p><h1>校验</h1><p class="view-sub">Schema 与语义检查在每次修改后自动运行；错误会阻止游戏加载该模组。</p></div>
        <div class="head-actions"><button type="button" class="btn small" data-action="revalidate">重新校验</button></div>
      </header>
      <div class="summary-grid">
        <button type="button" class="summary-card ${state.validFilter === 'error' ? 'active' : ''}" data-action="valid-filter" data-value="error"><span class="summary-num bad">${counts.error}</span><span>错误</span></button>
        <button type="button" class="summary-card ${state.validFilter === 'warning' ? 'active' : ''}" data-action="valid-filter" data-value="warning"><span class="summary-num warn">${counts.warning}</span><span>警告</span></button>
        <button type="button" class="summary-card ${state.validFilter === 'all' ? 'active' : ''}" data-action="valid-filter" data-value="all"><span class="summary-num">${counts.total}</span><span>全部</span></button>
        <div class="summary-card static"><span class="summary-num">${state.issues.stats.definitions || 0}</span><span>定义</span></div>
      </div>
      <div class="issue-list">
        ${issues.map((issue, index) => {
          const globalIndex = state.issues.issues.indexOf(issue);
          return `<button type="button" class="issue-row severity-${issue.severity}" data-action="goto-issue" data-index="${globalIndex}">
            <span class="issue-sev">${issue.severity === 'error' ? '错误' : issue.severity === 'warning' ? '警告' : '提示'}</span>
            <span class="issue-body"><strong>${UI.esc(issue.message)}</strong><span class="mono issue-code">${UI.esc(issue.code)}</span></span>
            <span class="issue-loc">${UI.esc(issueLocation(issue))}</span>
          </button>`;
        }).join('') || `<div class="empty-inline large">${state.validFilter === 'all' ? '没有发现问题。可以导出了。' : '这个级别下没有条目。'}</div>`}
      </div>
      <section class="panel explain-panel">
        <h3>检查范围</h3>
        <ul>
          <li>Manifest 字段、SemVer、依赖版本范围、内容/本地化/资源清单一致性。</li>
          <li>每条定义的 JSON Schema：类型、枚举、范围、必填字段与额外字段。</li>
          <li>ID 命名空间与类型段、跨文件重复 ID、本模组内引用是否存在。</li>
          <li>本地化键覆盖情况、空翻译与未引用键。</li>
          <li>补丁目标、来源版本与操作安全性。</li>
        </ul>
        ${Cat.DRAFT_TYPES && Cat.DRAFT_TYPES.length ? '<p class="muted-sm">Schema 2.0 草案类型（舰载武器 / 剧情篇章 / 剧情关卡）按 <code>schemas/v2</code> 校验；导出会写 <code>schema_version: "2.0"</code>，但游戏运行时不会加载草案类型，这类文件不会生效。已提升为运行时类型的 2.0 内容（世界 / 战役）不受影响。</p>' : ''}
        <p class="muted-sm">导出时不会自动修复任何问题；校验结果与 Godot 的加载校验保持同一套 Schema，但网页端不会运行领域规则或 Core 完整性检查。</p>
      </section>
    </div>`;
  }

  function issueLocation(issue) {
    const view = issue.view || {};
    if (view.name === 'content') {
      const info = Cat.BY_KEY[view.type];
      return `${info ? info.label : view.type} · ${view.file || ''}${view.index != null && view.index >= 0 ? ` #${view.index + 1}` : ''}`;
    }
    if (view.name === 'localization') return `本地化 · ${view.locale || ''} · ${view.key || ''}`;
    if (view.name === 'assets') return `资源 · ${view.path || ''}`;
    if (view.name === 'overview') return `Manifest${view.field ? ` · ${view.field}` : ''}`;
    return '项目';
  }

  function gotoIssue(index) {
    const issue = state.issues.issues[index];
    if (!issue) return;
    const view = issue.view || {};
    if (view.name === 'content' && view.type) {
      const file = state.project.contentFiles.find((item) => item.path === view.file);
      const definition = file && file.definitions[view.index];
      if (file && definition) {
        state.view = { name: 'content', type: view.type };
        state.selected = { type: view.type, file: file.path, index: view.index };
        if (view.field) {
          const fieldPath = String(view.field).replace(/\//g, '.').replace(/^\./, '');
          state.focusAfter = { selector: `[data-field="${attrSelector(fieldPath)}"]` };
        }
        render();
        return;
      }
      navigate('content', view.type);
      return;
    }
    if (view.name === 'localization') {
      state.locale = view.locale || state.locale;
      state.view = { name: 'localization', locale: state.locale };
      state.locSearch = '';
      state.missingOnly = false;
      if (view.key) state.focusAfter = { selector: `[data-locale-input="${attrSelector(view.key)}"]` };
      render();
      return;
    }
    if (view.name === 'assets') {
      navigate('assets');
      state.focusAfter = view.path ? { selector: `[data-asset-key="${attrSelector(view.path)}"]` } : null;
      render();
      return;
    }
    state.view = { name: 'overview' };
    if (view.field) state.focusAfter = { selector: `[data-field="manifest.${attrSelector(view.field)}"]` };
    render();
  }

  function attrSelector(value) {
    return String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  }

  /* ------------------------------------------------------------------ */
  /* Inspector                                                           */
  /* ------------------------------------------------------------------ */

  function inspectorData() {
    if (!state.project) return null;
    if (state.view.name === 'content') {
      const definition = currentDefinition();
      if (definition) return definition;
    }
    if (state.view.name === 'localization') {
      const entry = Store.getLoc(state.project, state.locale);
      return entry ? entry.entries : {};
    }
    if (state.view.name === 'assets') return state.project.assets.map(({ dataUrl, ...rest }) => ({ ...rest, hasData: Boolean(dataUrl) }));
    return state.project.manifest;
  }

  function renderInspector() {
    const inspector = document.getElementById('inspector');
    if (!inspector) return;
    const app = document.getElementById('app');
    if (!state.project || !state.inspector) {
      inspector.hidden = true;
      inspector.innerHTML = '';
      app.classList.remove('inspector-open');
      return;
    }
    inspector.hidden = false;
    app.classList.add('inspector-open');
    const data = inspectorData();
    inspector.innerHTML = `<header class="inspector-head">
      <div><h3>JSON 检视</h3><p class="mono">${UI.esc(inspectorLabel())}</p></div>
      <div class="head-actions">
        <button type="button" class="btn small ghost" data-action="copy-inspector">复制</button>
        <button type="button" class="icon-btn" data-action="toggle-inspector" title="关闭">✕</button>
      </div>
    </header>
    <pre class="json-view">${UI.esc(JSON.stringify(data, null, 2))}</pre>`;
  }

  function inspectorLabel() {
    if (state.view.name === 'content') {
      const def = currentDefinition();
      return def ? (def.id || def.target || 'definition') : 'definition';
    }
    if (state.view.name === 'localization') return `localization/${state.locale}.json`;
    if (state.view.name === 'assets') return 'manifest.assets';
    return 'manifest.json';
  }

  /* ------------------------------------------------------------------ */
  /* Show view                                                           */
  /* ------------------------------------------------------------------ */

  /* ------------------------------------------------------------------ */
  /* Events                                                              */
  /* ------------------------------------------------------------------ */

  function bindEvents() {
    document.addEventListener('click', onClick);
    document.addEventListener('input', onInput);
    document.addEventListener('change', onChange);
    document.addEventListener('keydown', onKeyDown, true);
    document.addEventListener('focusout', onFocusOut);
    window.addEventListener('dragenter', onDragEnter);
    window.addEventListener('dragover', onDragOver);
    window.addEventListener('dragleave', onDragLeave);
    window.addEventListener('drop', onDrop);
    window.addEventListener('beforeunload', (event) => {
      if (!state.dirty) return;
      event.preventDefault();
      event.returnValue = '';
    });
  }

  function closeAssetPickers(except) {
    document.querySelectorAll('.asset-picker-menu').forEach((menu) => {
      if (except && menu === except) return;
      menu.hidden = true;
      const toggle = menu.parentElement && menu.parentElement.querySelector('[data-action="asset-picker-toggle"]');
      if (toggle) toggle.setAttribute('aria-expanded', 'false');
    });
  }

  function openAssetPicker(picker) {
    if (!picker) return;
    const menu = picker.querySelector('.asset-picker-menu');
    if (!menu) return;
    closeAssetPickers(menu);
    menu.hidden = false;
    const toggle = picker.querySelector('[data-action="asset-picker-toggle"]');
    if (toggle) toggle.setAttribute('aria-expanded', 'true');
  }

  function filterAssetPicker(input) {
    const picker = input.closest('.asset-picker');
    if (!picker) return;
    openAssetPicker(picker);
    const query = input.value.trim().toLowerCase();
    let visible = 0;
    picker.querySelectorAll('.asset-picker-option[data-asset-search]').forEach((option) => {
      if (option.classList.contains('asset-picker-clear')) return;
      option.hidden = Boolean(query) && !String(option.dataset.assetSearch || '').includes(query);
      if (!option.hidden) visible += 1;
    });
    const noMatch = picker.querySelector('.asset-picker-no-match');
    if (noMatch) noMatch.hidden = visible > 0;
  }

  function onClick(event) {
    const picker = event.target.closest('.asset-picker');
    if (!picker) closeAssetPickers();
    if (event.target.matches('[data-asset-picker-input]')) {
      filterAssetPicker(event.target);
      return;
    }
    const actionEl = event.target.closest('[data-action]');
    if (actionEl && actionEl.tagName !== 'SELECT' && actionEl.tagName !== 'INPUT' && actionEl.tagName !== 'TEXTAREA') {
      Promise.resolve(handleAction(actionEl, event)).catch((error) => {
        console.error(error);
        UI.toast(error.message || '操作失败', 'error', 5000);
      });
      return;
    }
    const issueEl = event.target.closest('[data-action="goto-issue"]');
    if (issueEl) {
      gotoIssue(Number(issueEl.dataset.index));
      return;
    }
    const selectEl = event.target.closest('[data-select-def]');
    if (selectEl && !event.target.closest('button')) {
      selectDefinition(selectEl.dataset.file, Number(selectEl.dataset.index));
      return;
    }
    const navEl = event.target.closest('[data-nav]');
    if (navEl) {
      const [kind, argument] = navEl.dataset.nav.split(':');
      navigate(kind, argument);
    }
  }

  function selectDefinition(filePath, index) {
    const file = state.project.contentFiles.find((item) => item.path === filePath);
    if (!file || !file.definitions[index]) return;
    state.selected = { type: file.content_type, file: filePath, index };
    state.rawOpen = false;
    state.typing = false;
    render();
  }

  function navigate(kind, argument) {
    if (!state.project) {
      state.view = { name: 'welcome' };
      render();
      return;
    }
    if (kind === 'overview') state.view = { name: 'overview' };
    else if (kind === 'welcome') state.view = { name: 'welcome' };
    else if (kind === 'content' && argument) {
      state.view = { name: 'content', type: argument };
      state.search = '';
      ensureSelection();
      const items = [];
      state.project.contentFiles
        .filter((file) => file.content_type === argument)
        .forEach((file) => (file.definitions || []).forEach((definition, index) => items.push({ file, index })));
      state.selected = items.length ? { type: argument, file: items[0].file.path, index: items[0].index } : null;
      state.rawOpen = false;
    } else if (kind === 'localization' && argument) {
      if (!state.project.localization.some((entry) => entry.locale === argument)) {
        Store.addLocale(state.project, argument);
      }
      state.locale = argument;
      state.view = { name: 'localization', locale: argument };
      state.locSearch = '';
      state.missingOnly = false;
    } else if (kind === 'assets') state.view = { name: 'assets' };
    else if (kind === 'validate') state.view = { name: 'validate' };
    else state.view = { name: 'overview' };

    state.typing = false;
    const workspace = document.getElementById('workspace');
    if (workspace) workspace.scrollTop = 0;
    render();
  }

  function onInput(event) {
    const element = event.target;
    if (element.matches('[data-filter="content"]')) {
      state.search = element.value;
      filterDefinitionCards();
      return;
    }
    if (element.matches('[data-filter="loc"]')) {
      state.locSearch = element.value;
      renderLocalizationListOnly();
      return;
    }
    if (element.matches('[data-entity-locale]')) {
      updateEntityLocaleDraft(element);
      return;
    }
    if (element.matches('[data-locale-input]')) {
      updateLocaleValue(element);
      return;
    }
    if (element.matches('[data-asset-key]')) {
      const asset = state.project.assets.find((item) => item.path === element.dataset.assetKey);
      if (!asset) return;
      if (!state.typing) {
        pushHistory();
        state.typing = true;
      }
      asset.key = element.value.trim();
      markChanged(false);
      return;
    }
    if (element.matches('[data-core-search]')) {
      filterCoreList(element.value);
      return;
    }
    if (element.matches('[data-asset-picker-input]')) {
      filterAssetPicker(element);
    }
    if (element.matches('[data-modal-field="np-name"]')) {
      autoProjectId(element.value);
      return;
    }
    if (element.matches('[data-field]')) {
      if (element.tagName === 'SELECT' || element.type === 'checkbox' || element.type === 'radio') return;
      applyField(element);
    }
  }

  function onChange(event) {
    const element = event.target;
    if (element.matches('[data-field]')) {
      applyField(element, true);
      if (element.dataset.rerender === 'true' || element.dataset.field === 'enabled') render({ preserveScroll: true });
      return;
    }
    if (element.matches('[data-filter-toggle="missing"]')) {
      state.missingOnly = element.checked;
      render({ preserveScroll: true });
      return;
    }
    if (element.dataset.action === 'condition-kind') {
      changeConditionKind(element);
      return;
    }
    if (element.dataset.action === 'condition-op') {
      changeConditionOp(element);
      return;
    }
    if (element.dataset.action === 'effect-op') {
      changeEffectOp(element);
    }
  }

  function onKeyDown(event) {
    const element = event.target && typeof event.target.matches === 'function' ? event.target : document.body;
    if (element.matches('[data-list-input]') && event.key === 'Enter') {
      event.preventDefault();
      const path = element.dataset.listInput;
      const button = element.parentElement && element.parentElement.querySelector('[data-action="list-add"]');
      if (button) addListValue(path, element, button);
      return;
    }
    if (event.key === 'Enter' && element.matches('[data-select-def]')) {
      event.preventDefault();
      selectDefinition(element.dataset.file, Number(element.dataset.index));
      return;
    }
    if (event.key === 'Escape') {
      closeAssetPickers();
      UI.closeModal();
      if (state.inspector) {
        state.inspector = false;
        renderInspector();
        renderStatus();
      }
      return;
    }
    const meta = event.ctrlKey || event.metaKey;
    if (meta && event.key.toLowerCase() === 's') {
      event.preventDefault();
      saveNow({ disk: true });
      return;
    }
    if (meta && event.key.toLowerCase() === 'n') {
      event.preventDefault();
      showNewProject();
      return;
    }
    if (meta && event.key.toLowerCase() === 'o') {
      event.preventDefault();
      showImport();
      return;
    }
    if (meta && event.key.toLowerCase() === 'e') {
      event.preventDefault();
      exportZip();
      return;
    }
    if (meta && !element.matches('input, textarea')) {
      if (event.key.toLowerCase() === 'z' && !event.shiftKey) {
        event.preventDefault();
        undo();
        return;
      }
      if ((event.key.toLowerCase() === 'z' && event.shiftKey) || event.key.toLowerCase() === 'y') {
        event.preventDefault();
        redo();
      }
    }
  }

  function onFocusOut(event) {
    if (event.target && event.target.matches && event.target.matches('[data-field], [data-locale-input], [data-entity-locale], [data-asset-key]')) {
      setTimeout(() => {
        state.typing = false;
      }, 0);
    }
  }

  function applyField(element, fromChange) {
    const project = state.project;
    if (!project) return;
    const path = element.dataset.field;
    if (!path) return;
    const isManifest = path.startsWith('manifest.');
    const definition = currentDefinition();
    if (!isManifest && !definition) return;
    const target = isManifest ? project.manifest : definition;
    let relative = isManifest ? path.slice('manifest.'.length) : path;
    let value;
    try {
      value = readValue(element);
    } catch (error) {
      return;
    }

    if (!isManifest && path === 'id' && element.dataset.prefix) {
      const prefix = element.dataset.prefix;
      let local = String(value || '').trim();
      if (local.startsWith(prefix)) local = local.slice(prefix.length);
      value = prefix + local;
    }

    if (!state.typing && !fromChange) {
      pushHistory();
      state.typing = true;
    } else if (fromChange) {
      pushHistory();
      state.typing = false;
    }

    const oldId = !isManifest && path === 'id' && definition ? definition.id : null;
    const draft = oldId ? localizationDraft(definition, oldId, true) : null;
    setByPath(target, relative, value);
    if (value === '' && !isManifest && relative === 'description_key') delete target.description_key;
    if (value === '' && !isManifest && (relative === 'information.texture' || relative === 'information.model')) {
      deleteByPath(target, relative);
      if (target.information && Object.keys(target.information).length === 0) delete target.information;
    }
    if (value === '' && isManifest && relative === 'checksum') delete target.checksum;
    if (draft) {
      draft.previewBase = Store.keyBase(currentFile().content_type, project.manifest.id, Store.localPart(definition.id));
      updateDefinitionLocalizationPreview(definition, draft);
    }
    markChanged(false);
  }

  function readValue(element) {
    const parse = element.dataset.parse || 'text';
    if (parse === 'bool') return Boolean(element.checked);
    if (parse === 'number') {
      if (element.value === '') return null;
      const value = Number(element.value);
      return Number.isFinite(value) ? value : null;
    }
    if (parse === 'int') {
      if (element.value === '') return null;
      const value = Number.parseInt(element.value, 10);
      return Number.isFinite(value) ? value : null;
    }
    if (parse === 'json') {
      const text = element.value.trim();
      if (!text) return null;
      try {
        element.classList.remove('invalid');
        return JSON.parse(text);
      } catch (error) {
        element.classList.add('invalid');
        throw error;
      }
    }
    return element.value;
  }

  function markChanged(structural) {
    state.dirty = true;
    state.revision += 1;
    Store.syncManifest(state.project);
    updateSaveState();
    scheduleValidate();
    scheduleSave();
    scheduleInspector();
    if (state.backend) scheduleDiskSave();
    if (structural) state.typing = false;
  }

  function updateDefinitionLocalizationPreview(definition, draft) {
    const idPreview = document.querySelector('[data-id-preview]');
    if (idPreview) idPreview.textContent = definition.id || '';
    document.querySelectorAll('[data-key-preview-field]').forEach((input) => {
      input.value = previewLocalizationKey(definition, input.dataset.keyPreviewField, draft);
    });
    document.querySelectorAll('[data-nested-key-preview]').forEach((input) => {
      input.value = previewLocalizationValue(input.dataset.sourceKey, draft);
    });
    document.querySelectorAll('.nested-key-title').forEach((label) => {
      const input = label.parentElement && label.parentElement.querySelector('[data-nested-key-preview]');
      if (input) label.textContent = input.value;
    });
    const badge = document.querySelector('.editor-head [data-localization-pending]');
    if (badge) badge.hidden = false;
    const saveButton = document.querySelector('[data-action="save-definition"]');
    if (saveButton) saveButton.classList.add('primary');
  }

  function updateEntityLocaleDraft(element) {
    const definition = currentDefinition();
    if (!definition) return;
    const draft = localizationDraft(definition, definition.id, false);
    const locale = element.dataset.entityLocale;
    const field = element.dataset.entityLocaleField;
    if (!locale || !field) return;
    if (!draft.values[locale]) draft.values[locale] = {};
    draft.values[locale][field] = element.value;
    const badge = document.querySelector('[data-localization-pending]');
    if (badge) badge.hidden = false;
    const saveButton = document.querySelector('[data-action="save-definition"]');
    if (saveButton) saveButton.classList.add('primary');
  }

  function updateLocaleValue(element) {
    if (!state.project) return;
    const locale = state.locale;
    const key = element.dataset.localeInput;
    const entry = Store.getLoc(state.project, locale);
    if (!entry) return;
    if (!state.typing) {
      pushHistory();
      state.typing = true;
    }
    if (element.value === '') delete entry.entries[key];
    else entry.entries[key] = element.value;
    state.dirty = true;
    state.revision += 1;
    updateSaveState();
    scheduleValidate();
    scheduleSave();
    scheduleInspector();
  }

  function filterDefinitionCards() {
    const query = state.search.trim().toLowerCase();
    document.querySelectorAll('[data-select-def]').forEach((card) => {
      card.hidden = Boolean(query) && !String(card.dataset.search || '').includes(query);
    });
  }

  function renderLocalizationListOnly() {
    const workspace = document.getElementById('workspace');
    if (!workspace || state.view.name !== 'localization') return;
    const scroll = workspace.scrollTop;
    workspace.innerHTML = renderLocalization();
    workspace.scrollTop = scroll;
    const input = workspace.querySelector('[data-filter="loc"]');
    if (input) {
      input.focus();
      input.setSelectionRange(input.value.length, input.value.length);
    }
  }

  function autoProjectId(name) {
    const idInput = document.getElementById('np-id');
    if (!idInput || idInput.dataset.auto === 'false') return;
    idInput.value = Store.slugify(name, 'my_mod').slice(0, 32);
  }

  function filterCoreList(query) {
    const text = String(query || '').trim().toLowerCase();
    document.querySelectorAll('[data-core-id]').forEach((row) => {
      row.hidden = Boolean(text) && !String(row.dataset.coreSearch || '').includes(text);
    });
  }

  /* ------------------------------------------------------------------ */
  /* Actions                                                             */
  /* ------------------------------------------------------------------ */

  async function handleAction(element, event) {
    const action = element.dataset.action;
    switch (action) {
      case 'welcome':
        navigate('welcome');
        return;
      case 'resume-project':
        state.view = { name: 'overview' };
        render();
        return;
      case 'new-project':
        showNewProject();
        return;
      case 'import':
        showImport();
        return;
      case 'export':
        showExport();
        return;
      case 'help':
        showHelp();
        return;
      case 'project-library':
        showProjectLibrary();
        return;
      case 'save':
        await saveNow({ disk: true });
        return;
      case 'save-definition':
        await saveDefinitionAction();
        return;
      case 'goto-definition-localization':
        gotoDefinitionLocalization(element.dataset.field || 'name_key', element.dataset.key || '');
        return;
      case 'asset-picker-toggle': {
        const picker = element.closest('.asset-picker');
        const menu = picker && picker.querySelector('.asset-picker-menu');
        if (!menu) return;
        if (menu.hidden) openAssetPicker(picker);
        else closeAssetPickers();
        return;
      }
      case 'asset-picker-value': {
        const picker = element.closest('.asset-picker');
        const input = picker && picker.querySelector('[data-asset-picker-input]');
        if (!input) return;
        input.value = element.dataset.value || '';
        applyField(input, true);
        closeAssetPickers();
        return;
      }
      case 'undo':
        undo();
        return;
      case 'redo':
        redo();
        return;
      case 'toggle-inspector':
        state.inspector = !state.inspector;
        renderInspector();
        renderStatus();
        return;
      case 'copy-inspector':
        copyText(document.querySelector('.json-view') ? document.querySelector('.json-view').textContent : '');
        return;
      case 'add-definition':
        addDefinitionAction();
        return;
      case 'core-clone':
        showCoreClone();
        return;
      case 'clone-core':
        cloneCoreAction(element.dataset.coreId);
        return;
      case 'duplicate-definition':
        duplicateDefinitionAction();
        return;
      case 'delete-definition':
        await deleteDefinitionAction();
        return;
      case 'toggle-raw':
        state.rawOpen = !state.rawOpen;
        render({ preserveScroll: true });
        return;
      case 'apply-raw':
        applyRawJson();
        return;
      case 'cancel-raw':
        state.rawOpen = false;
        render({ preserveScroll: true });
        return;
      case 'add-dep':
        addDependency(element.dataset.list || 'dependencies');
        return;
      case 'remove-dep':
        removeDependency(element.dataset.list || 'dependencies', Number(element.dataset.index));
        return;
      case 'sync-namespace':
        syncNamespace();
        return;
      case 'add-locale':
        showAddLocale();
        return;
      case 'add-loc-key':
        showAddLocaleKey();
        return;
      case 'fill-missing':
        fillMissingKeys();
        return;
      case 'delete-loc-key':
        deleteLocaleKey(element.dataset.key);
        return;
      case 'goto-key-def':
        gotoKeyDefinition(element.dataset.file, Number(element.dataset.index));
        return;
      case 'add-asset':
        addAssets();
        return;
      case 'remove-asset':
        await removeAsset(element.dataset.path);
        return;
      case 'download-asset':
        downloadAsset(element.dataset.path);
        return;
      case 'revalidate':
        runValidation();
        render();
        UI.toast('已重新校验', 'info', 1400);
        return;
      case 'valid-filter':
        state.validFilter = element.dataset.value || 'all';
        render({ preserveScroll: true });
        return;
      case 'goto-issue':
        gotoIssue(Number(element.dataset.index));
        return;
      case 'open-project':
        openProject(element.dataset.uid);
        return;
      case 'delete-project':
        deleteProject(element.dataset.uid);
        return;
      case 'open-disk-project':
        openDiskProject(element.dataset.id);
        return;
      case 'open-workspace-project':
        openWorkspaceProject(element.dataset.id);
        return;
      case 'delete-disk-project':
        deleteDiskProject(element.dataset.id);
        return;
      case 'save-disk':
        if (!state.backend) {
          UI.toast('当前没有本地服务，只能保存在浏览器。', 'warning');
          return;
        }
        await saveNow({ disk: true });
        UI.toast('已写入磁盘', 'success', 1800);
        return;
      case 'export-disk':
        UI.closeModal();
        await exportZipToDisk();
        return;
      case 'deploy-game-mod':
        UI.closeModal();
        await deployGameMod();
        return;
      case 'refresh-recent':
        loadRecent();
        return;
      case 'create-project':
        await createProjectFromModal();
        return;
      case 'create-locale':
        createLocale();
        return;
      case 'create-locale-key':
        createLocaleKey();
        return;
      case 'import-folder':
        UI.closeModal();
        await importFolder();
        return;
      case 'import-file':
        UI.closeModal();
        await importFile();
        return;
      case 'export-zip':
        UI.closeModal();
        await exportZip();
        return;
      case 'export-project':
        UI.closeModal();
        exportProjectFile();
        return;
      case 'export-folder':
        UI.closeModal();
        await exportFolder();
        return;
      case 'array-add':
        arrayAdd(element.dataset.path);
        return;
      case 'array-remove':
        arrayRemove(element.dataset.path, Number(element.dataset.index));
        return;
      case 'array-move':
        arrayMove(element.dataset.path, Number(element.dataset.index), Number(element.dataset.dir));
        return;
      case 'list-add': {
        const path = element.dataset.path;
        const input = element.parentElement && element.parentElement.querySelector('[data-list-input]');
        if (input) addListValue(path, input, element);
        return;
      }
      case 'list-remove':
        listRemove(element.dataset.path, Number(element.dataset.index));
        return;
      case 'enum-toggle':
        enumToggle(element.dataset.path, element.dataset.value, element);
        return;
      case 'condition-add':
        addCondition(element.dataset.path, element.dataset.kind || 'leaf');
        return;
      case 'condition-remove':
        removeCondition(element.dataset.path);
        return;
      default:
        return;
    }
  }

  /* ------------------------------------------------------------------ */
  /* Content mutations                                                   */
  /* ------------------------------------------------------------------ */

  async function saveDefinitionAction() {
    const definition = currentDefinition();
    const file = currentFile();
    if (!definition || !file || file.content_type === 'patches') return;
    const draft = currentLocalizationDraft();
    if (draft) {
      const translations = {};
      for (const [locale, fields] of Object.entries(draft.values || {})) {
        translations[locale] = {};
        for (const [field, value] of Object.entries(fields || {})) {
          const sourceKey = field.startsWith('key:') ? field.slice(4) : definition[field];
          const key = previewLocalizationValue(sourceKey, draft);
          if (key) translations[locale][key] = value;
        }
      }
      pushHistory();
      try {
        Store.commitDefinitionLocalization(
          state.project,
          definition,
          file.content_type,
          draft.sourceBase,
          draft.previewBase,
          translations,
        );
      } catch (error) {
        UI.toast(error.message || '保存多语言键失败', 'error', 4200);
        return;
      }
      state.localizationDrafts.delete(selectedDefinitionKey());
      markChanged(false);
      render({ preserveScroll: true });
    }
    await saveNow({ disk: true });
    UI.toast('条目与多语言键已保存', 'success', 1800);
  }

  function gotoDefinitionLocalization(field, keyOverride) {
    const definition = currentDefinition();
    if (!definition) return;
    const key = keyOverride || definition[field];
    const locale = state.locale || (state.project.localization[0] && state.project.localization[0].locale);
    if (!locale || !key) {
      UI.toast('这个字段还没有可打开的多语言键。', 'warning');
      return;
    }
    state.locale = locale;
    state.view = { name: 'localization', locale };
    state.locSearch = '';
    state.missingOnly = false;
    state.focusAfter = { selector: `[data-locale-input="${attrSelector(key)}"]` };
    render();
  }

  function addDefinitionAction() {
    if (!state.project || state.view.name !== 'content') return;
    const typeKey = state.view.type;
    pushHistory();
    const result = Store.addDefinition(state.project, typeKey, {});
    state.selected = { type: typeKey, file: result.file.path, index: result.index };
    markChanged(true);
    render();
    UI.toast(`已新增${Cat.BY_KEY[typeKey].label}定义`, 'success', 1800);
  }

  function cloneCoreAction(coreId) {
    if (!state.project || !coreId) return;
    pushHistory();
    const result = Store.cloneCoreDefinition(state.project, coreId);
    if (!result) {
      UI.toast('复制失败：Core 中没有这个定义。', 'error');
      return;
    }
    UI.closeModal();
    state.view = { name: 'content', type: result.file.content_type };
    state.selected = { type: result.file.content_type, file: result.file.path, index: result.index };
    markChanged(true);
    render();
    UI.toast('已从 Core 复制，记得调整数值与名称。', 'success', 2600);
  }

  async function deleteDefinitionAction() {
    if (!state.selected) return;
    const definition = currentDefinition();
    const title = definition ? Store.definitionTitle(state.project, definition) : '';
    const ok = await UI.confirm({
      title: '删除定义',
      message: `确定删除「${title}」？本地化键会保留，可能变成未引用键。`,
      confirmLabel: '删除',
      danger: true,
    });
    if (!ok) return;
    pushHistory();
    const filePath = state.selected.file;
    const index = state.selected.index;
    Store.removeDefinition(state.project, filePath, index);
    const file = state.project.contentFiles.find((item) => item.path === filePath);
    if (file && file.definitions.length) {
      state.selected = { type: file.content_type, file: filePath, index: Math.min(index, file.definitions.length - 1) };
    } else {
      state.selected = firstSelection(state.project);
    }
    markChanged(true);
    render();
  }

  function duplicateDefinitionAction() {
    if (!state.selected) return;
    pushHistory();
    const result = Store.duplicateDefinition(state.project, state.selected.file, state.selected.index);
    if (!result) return;
    state.selected = { type: result.file.content_type, file: result.file.path, index: result.index };
    markChanged(true);
    render();
    UI.toast('已复制定义', 'success', 1600);
  }

  function applyRawJson() {
    const textarea = document.getElementById('raw-json');
    const errorNode = document.getElementById('raw-error');
    if (!textarea || !state.selected) return;
    try {
      const parsed = JSON.parse(textarea.value);
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('定义必须是 JSON 对象');
      pushHistory();
      const file = state.project.contentFiles.find((item) => item.path === state.selected.file);
      file.definitions[state.selected.index] = parsed;
      state.rawOpen = false;
      state.typing = false;
      markChanged(true);
      render();
      UI.toast('JSON 已应用', 'success', 1600);
    } catch (error) {
      if (errorNode) {
        errorNode.textContent = `无法应用：${error.message}`;
      }
      if (textarea) textarea.classList.add('invalid');
    }
  }

  function addDependency(list) {
    if (!state.project) return;
    pushHistory();
    const key = list === 'optional_dependencies' ? 'optional_dependencies' : 'dependencies';
    if (!Array.isArray(state.project.manifest[key])) state.project.manifest[key] = [];
    state.project.manifest[key].push({ id: 'core', version: '>=1.0.0 <2.0.0' });
    markChanged(true);
    render({ preserveScroll: true });
  }

  function removeDependency(list, index) {
    if (!state.project) return;
    pushHistory();
    const key = list === 'optional_dependencies' ? 'optional_dependencies' : 'dependencies';
    if (Array.isArray(state.project.manifest[key])) state.project.manifest[key].splice(index, 1);
    markChanged(true);
    render({ preserveScroll: true });
  }

  function syncNamespace() {
    if (!state.project) return;
    pushHistory();
    const modId = state.project.manifest.id;
    for (const file of state.project.contentFiles) {
      const info = Cat.BY_KEY[file.content_type];
      if (!info || file.content_type === 'patches') continue;
      for (const definition of file.definitions || []) {
        const local = Store.localPart(definition.id);
        if (!local) continue;
        const oldNamespace = Store.namespaceOf(definition.id);
        const oldBase = Store.keyBaseOf(definition, file.content_type, oldNamespace, local);
        const newBase = Store.keyBase(file.content_type, modId, local);
        definition.id = `${modId}:${info.singular}/${local}`;
        const walk = (value) => {
          if (Array.isArray(value)) return value.forEach(walk);
          if (value && typeof value === 'object') {
            for (const key of Object.keys(value)) {
              if (typeof value[key] === 'string' && key.endsWith('_key')) {
                if (value[key] === oldBase || value[key].startsWith(`${oldBase}.`)) {
                  value[key] = newBase + value[key].slice(oldBase.length);
                }
              } else walk(value[key]);
            }
          }
        };
        walk(definition);
        for (const entry of state.project.localization) {
          for (const [key, value] of Object.entries(entry.entries || {})) {
            if (key === oldBase || key.startsWith(`${oldBase}.`)) {
              entry.entries[newBase + key.slice(oldBase.length)] = value;
            }
          }
        }
      }
    }
    markChanged(true);
    render();
    UI.toast('命名空间已同步', 'success');
  }

  /* ------------------------------------------------------------------ */
  /* Localization mutations                                              */
  /* ------------------------------------------------------------------ */

  function gotoKeyDefinition(filePath, index) {
    const file = state.project.contentFiles.find((item) => item.path === filePath);
    if (!file || !file.definitions[index]) return;
    state.view = { name: 'content', type: file.content_type };
    state.selected = { type: file.content_type, file: filePath, index };
    state.typing = false;
    render();
  }

  function deleteLocaleKey(key) {
    if (!state.project) return;
    const entry = Store.getLoc(state.project, state.locale);
    if (!entry || !(key in entry.entries)) return;
    pushHistory();
    delete entry.entries[key];
    markChanged(true);
    render({ preserveScroll: true });
  }

  function fillMissingKeys() {
    if (!state.project) return;
    const entry = Store.getLoc(state.project, state.locale);
    if (!entry) return;
    pushHistory();
    const needed = collectNeededKeys(state.project);
    let added = 0;
    for (const key of needed.keys()) {
      if (!(key in entry.entries)) {
        entry.entries[key] = '';
        added += 1;
      }
    }
    markChanged(true);
    render({ preserveScroll: true });
    UI.toast(added ? `已创建 ${added} 个待翻译键` : '没有缺失的键', added ? 'success' : 'info');
  }

  /* ------------------------------------------------------------------ */
  /* Array / chip editors                                                */
  /* ------------------------------------------------------------------ */

  function arrayAdd(path) {
    const definition = currentDefinition();
    if (!definition) return;
    pushHistory();
    let array = getByPath(definition, path);
    if (!Array.isArray(array)) {
      setByPath(definition, path, []);
      array = getByPath(definition, path);
    }
    array.push(defaultArrayItem(path, definition));
    markChanged(true);
    render({ preserveScroll: true });
  }

  /** 新安装点行的默认值：序号接在现有最大序号之后，节点名避免与已有行重复。 */
  function nextSocketItem(existing, kind) {
    const items = Array.isArray(existing) ? existing : [];
    const nextIndex = items.reduce((max, item) => {
      const value = Number(item && item.socket_index);
      return Number.isFinite(value) ? Math.max(max, value) : max;
    }, -1) + 1;
    const names = new Set(items.map((item) => item && item.name).filter(Boolean));
    const prefix = kind === 'weapon' ? 'SN_Socket_Weapon_New' : 'SN_Socket_Mast_New';
    let suffix = nextIndex + 1;
    while (names.has(`${prefix}_${suffix}`)) suffix += 1;
    const item = {
      name: `${prefix}_${suffix}`,
      socket_index: nextIndex,
      position: [0, 0, 0],
    };
    if (kind === 'weapon') {
      item.socket_class = 'Light';
      item.clearance_r = 1;
      item.clearance_x = 1;
      item.clearance_y = 1;
      item.clearance_h = 20;
      item.mount_scale = 1;
    } else {
      item.socket_kind = 'mast';
      item.mast_id = 'fore';
    }
    return item;
  }

  function defaultArrayItem(path, definition) {
    const tail = path.split('.').filter((segment) => !/^\d+$/.test(segment)).pop();
    if (tail === 'modifiers') return { stat: 'speed', op: 'mul', value: 1.02 };
    if (tail === 'materials') return { id: 'core:good/brass', amount: 1 };
    if (tail === 'payloads') return { kind: 'cargo', weight_range: [8, 16] };
    if (tail === 'effects') return { op: 'add_money', amount: 50 };
    if (tail === 'operations') return { op: 'replace', path: '/data/purchase_price', value: 100 };
    if (tail === 'market') return { good: 'core:good/brass', stock_range: [40, 80], price_bias: 1 };
    if (tail === 'weapon_sockets') return nextSocketItem(getByPath(definition, path), 'weapon');
    if (tail === 'rig_sockets') return nextSocketItem(getByPath(definition, path), 'rig');
    if (tail === 'options') {
      const info = selectedTypeInfo();
      const local = Store.localPart(definition.id);
      const base = Store.keyBase(info.key, state.project.manifest.id, local);
      const index = (getByPath(definition, path) || []).length + 1;
      const item = { id: `option_${index}`, name_key: `${base}.option_${index}`, weight: 1, effects: [{ op: 'add_money', amount: 50 }] };
      const zh = Store.getLoc(state.project, 'zh_CN');
      const en = Store.getLoc(state.project, 'en');
      if (zh) zh.entries[item.name_key] = `新选项 ${index}`;
      if (en) en.entries[item.name_key] = `New option ${index}`;
      return item;
    }
    return {};
  }

  function arrayRemove(path, index) {
    const definition = currentDefinition();
    if (!definition) return;
    const array = getByPath(definition, path);
    if (!Array.isArray(array)) return;
    pushHistory();
    array.splice(index, 1);
    markChanged(true);
    render({ preserveScroll: true });
  }

  function arrayMove(path, index, direction) {
    const definition = currentDefinition();
    if (!definition) return;
    const array = getByPath(definition, path);
    if (!Array.isArray(array)) return;
    const next = index + direction;
    if (next < 0 || next >= array.length) return;
    pushHistory();
    const item = array.splice(index, 1)[0];
    array.splice(next, 0, item);
    markChanged(true);
    render({ preserveScroll: true });
  }

  function addListValue(path, input, button) {
    const definition = currentDefinition();
    const isManifest = path.startsWith('manifest.');
    const target = isManifest ? state.project.manifest : definition;
    if (!target) return;
    const relative = isManifest ? path.slice('manifest.'.length) : path;
    const value = input.value.trim();
    if (!value) return;
    let array = getByPath(target, relative);
    if (!Array.isArray(array)) {
      setByPath(target, relative, []);
      array = getByPath(target, relative);
    }
    if (array.includes(value)) {
      input.value = '';
      return;
    }
    pushHistory();
    array.push(value);
    input.value = '';
    markChanged(true);
    render({ preserveScroll: true });
  }

  function listRemove(path, index) {
    const isManifest = path.startsWith('manifest.');
    const target = isManifest ? state.project.manifest : currentDefinition();
    if (!target) return;
    const relative = isManifest ? path.slice('manifest.'.length) : path;
    const array = getByPath(target, relative);
    if (!Array.isArray(array)) return;
    pushHistory();
    array.splice(index, 1);
    markChanged(true);
    render({ preserveScroll: true });
  }

  function enumToggle(path, value, element) {
    const definition = currentDefinition();
    if (!definition) return;
    let array = getByPath(definition, path);
    if (!Array.isArray(array)) {
      setByPath(definition, path, []);
      array = getByPath(definition, path);
    }
    pushHistory();
    const index = array.indexOf(value);
    if (index >= 0) array.splice(index, 1);
    else array.push(value);
    if (element) element.classList.toggle('active');
    markChanged(true);
    render({ preserveScroll: true });
  }

  function addCondition(path, kind) {
    const definition = currentDefinition();
    if (!definition) return;
    const node = kind === 'all' ? { all: [{ op: 'money_gte', value: 0 }] } : { op: 'money_gte', value: 0 };
    pushHistory();
    const existing = getByPath(definition, path);
    if (Array.isArray(existing)) existing.push(node);
    else setByPath(definition, path, node);
    markChanged(true);
    render({ preserveScroll: true });
  }

  function removeCondition(path) {
    const definition = currentDefinition();
    if (!definition) return;
    pushHistory();
    deleteByPath(definition, path);
    markChanged(true);
    render({ preserveScroll: true });
  }

  function changeConditionKind(element) {
    const definition = currentDefinition();
    if (!definition) return;
    const path = element.dataset.path;
    const current = getByPath(definition, path) || { op: 'money_gte', value: 0 };
    const kind = element.value;
    let next;
    if (kind === 'leaf') next = current.op ? current : { op: 'money_gte', value: 0 };
    else if (kind === 'all' || kind === 'any') {
      const children = Array.isArray(current.all) ? current.all : Array.isArray(current.any) ? current.any : [current];
      next = { [kind]: children };
    } else {
      next = { not: current.not || current };
    }
    pushHistory();
    setByPath(definition, path, next);
    markChanged(true);
    render({ preserveScroll: true });
  }

  function changeConditionOp(element) {
    const definition = currentDefinition();
    if (!definition) return;
    const path = element.dataset.path;
    const current = getByPath(definition, path) || {};
    const op = element.value;
    const fields = Cat.CONDITION_FIELDS[op] || [];
    const next = { op };
    for (const field of fields) {
      if (current[field] !== undefined) next[field] = current[field];
      else if (field === 'value' || field === 'amount') next[field] = 0;
      else if (field === 'role_kind') next[field] = 'engineer';
      else next[field] = '';
    }
    pushHistory();
    setByPath(definition, path, next);
    markChanged(true);
    render({ preserveScroll: true });
  }

  function changeEffectOp(element) {
    const definition = currentDefinition();
    if (!definition) return;
    const path = element.dataset.path;
    const nodePath = path.replace(/\.op$/, '');
    const current = getByPath(definition, nodePath) || {};
    const op = element.value;
    const fields = Cat.EFFECT_FIELDS[op] || [];
    const next = { op };
    for (const field of fields) {
      if (current[field] !== undefined) next[field] = current[field];
      else if (field === 'amount') next[field] = 0;
      else next[field] = '';
    }
    pushHistory();
    setByPath(definition, nodePath, next);
    markChanged(true);
    render({ preserveScroll: true });
  }

  /* ------------------------------------------------------------------ */
  /* Assets                                                              */
  /* ------------------------------------------------------------------ */

  async function addAssets() {
    if (!state.project) return;
    try {
      const entries = await IO.openFilePicker({ accept: '.png,.webp,.svg,.ogg,.wav,.glb' });
      if (!entries.length) return;
      pushHistory();
      let added = 0;
      for (const entry of entries) {
        const file = entry.file || new File([entry.data], entry.path.split('/').pop() || 'asset');
        const isModel = /\.glb$/i.test(file.name);
        const maxBytes = isModel ? 20 * 1024 * 1024 : 5 * 1024 * 1024;
        if (entry.data.length > maxBytes) {
          UI.toast(`${file.name} 超过 ${isModel ? 20 : 5} MB，已跳过`, 'warning');
          continue;
        }
        const mime = Store.mimeFor(file.name);
        const safeName = String(file.name).replace(/[^A-Za-z0-9._-]+/g, '_');
        const folder = mime.startsWith('image/') ? 'assets/icons' : mime.startsWith('audio/') ? 'assets/audio' : isModel ? 'assets/models' : 'assets/files';
        let path = `${folder}/${safeName}`;
        let counter = 2;
        while (state.project.assets.some((asset) => asset.path === path)) {
          path = `${folder}/${safeName.replace(/(\.[^.]+)?$/, `_${counter}$1`)}`;
          counter += 1;
        }
        const dataUrl = Store.bytesToDataUrl(entry.data, mime);
        Store.addAsset(state.project, {
          key: `${mime.startsWith('image/') ? 'icon' : isModel ? 'model' : 'asset'}.${Store.slugify(safeName.replace(/\.[^.]+$/, ''), 'file')}`,
          path,
          mime,
          size: entry.data.length,
          dataUrl,
        });
        added += 1;
      }
      markChanged(true);
      render();
      if (added) UI.toast(`已添加 ${added} 个资源`, 'success');
    } catch (error) {
      UI.toast(error.message || '添加资源失败', 'error');
    }
  }

  async function removeAsset(path) {
    if (!path) return;
    const ok = await UI.confirm({
      title: '删除资源',
      message: `从项目中移除 ${path}？manifest.assets 中的对应键也会删除。`,
      confirmLabel: '删除',
      danger: true,
    });
    if (!ok) return;
    pushHistory();
    Store.removeAsset(state.project, path);
    if (root.SNModelThumb) root.SNModelThumb.forget(path);
    markChanged(true);
    render();
  }

  function downloadAsset(path) {
    const asset = state.project.assets.find((item) => item.path === path);
    if (!asset || !asset.dataUrl) return;
    IO.downloadBytes(Store.dataUrlToBytes(asset.dataUrl), asset.path.split('/').pop(), asset.mime);
  }

  /* ------------------------------------------------------------------ */
  /* Modals: new / import / export / library / core / locale / help      */
  /* ------------------------------------------------------------------ */

  function showNewProject() {
    const templates = Cat.TEMPLATES.map((template, index) => `
      <label class="template-card ${index === 0 ? 'selected' : ''}">
        <input type="radio" name="np-template" value="${UI.attr(template.key)}" ${index === 0 ? 'checked' : ''}>
        <span class="template-name">${UI.esc(template.name)}</span>
        <span class="template-desc">${UI.esc(template.description)}</span>
        <span class="template-type mono">${UI.esc(template.type)}</span>
      </label>`).join('');
    UI.modal({
      title: '新建模组',
      subtitle: '从一个可运行的最小结构开始。',
      size: 'md',
      body: `<div class="template-grid">${templates}</div>
        <div class="field-grid modal-fields">
          <div class="field"><label class="field-label">模组 ID<span class="req">*</span></label>
            <input class="input mono" id="np-id" value="my_mod" data-auto="true" data-modal-field="np-id" spellcheck="false">
            <p class="field-hint">小写字母开头，3–32 位，只能包含 a-z / 0-9 / _。会成为所有定义 ID 的命名空间。</p>
          </div>
          <div class="field"><label class="field-label">显示名称<span class="req">*</span></label>
            <input class="input" id="np-name" value="My Content Mod" data-modal-field="np-name">
          </div>
        </div>
        <label class="checkbox-line"><input type="checkbox" id="np-core" checked> 依赖 core（引用官方商品 / 船体 / 委托时必需）</label>
        <p class="form-error" id="np-error"></p>`,
      footer: `<button type="button" class="btn ghost" data-modal-close>取消</button>
        <button type="button" class="btn primary" data-action="create-project">创建项目</button>`,
    });
    const idInput = document.getElementById('np-id');
    if (idInput) idInput.addEventListener('input', () => {
      idInput.dataset.auto = 'false';
    });
  }

  async function createProjectFromModal() {
    const idInput = document.getElementById('np-id');
    const nameInput = document.getElementById('np-name');
    const errorNode = document.getElementById('np-error');
    const checkedTemplate = document.querySelector('input[name="np-template"]:checked');
    const coreInput = document.getElementById('np-core');
    const id = (idInput ? idInput.value : '').trim();
    const name = (nameInput ? nameInput.value : '').trim();
    if (!V.MOD_ID_RE.test(id)) {
      if (errorNode) errorNode.textContent = '模组 ID 必须是小写字母开头、3–32 位的 a-z / 0-9 / _。';
      return;
    }
    if (id === 'core') {
      if (errorNode) errorNode.textContent = 'ID "core" 保留给官方内容包。';
      return;
    }
    if (!name) {
      if (errorNode) errorNode.textContent = '请填写显示名称。';
      return;
    }
    try {
      const project = Store.createProject({
        id,
        name,
        template: checkedTemplate ? checkedTemplate.value : 'goods',
        dependencies: Boolean(coreInput && coreInput.checked),
      });
      UI.closeModal();
      setProject(project);
      await saveNow({ disk: true });
      UI.toast(`已创建 ${name}`, 'success');
    } catch (error) {
      if (errorNode) errorNode.textContent = error.message;
    }
  }

  function showImport() {
    UI.modal({
      title: '导入模组',
      subtitle: '支持松散目录、.snavmod.zip 与 .snmodproj.json 项目文件。',
      size: 'sm',
      body: `<div class="import-options">
        <button type="button" class="import-option" data-action="import-folder">
          <span class="import-icon">DIR</span>
          <span><strong>选择模组文件夹</strong><small>含 manifest.json、content/、localization/</small></span>
        </button>
        <button type="button" class="import-option" data-action="import-file">
          <span class="import-icon">ZIP</span>
          <span><strong>选择 ZIP 或项目文件</strong><small>.snavmod.zip / .zip / .snmodproj.json</small></span>
        </button>
      </div>
      <p class="field-hint">也可以直接把文件夹或 ZIP 拖进窗口。导入会新建一个本地项目，不会覆盖原文件。</p>`,
      footer: '<button type="button" class="btn ghost" data-modal-close>取消</button>',
    });
  }

  async function importFolder() {
    const entries = await IO.openFilePicker({ directory: true });
    if (entries.length) await importEntries(entries);
  }

  async function importFile() {
    const entries = await IO.openFilePicker({ accept: '.zip,.json' });
    if (entries.length) await importEntries(entries);
  }

  async function importEntries(entries) {
    if (!entries || !entries.length) return;
    UI.setBusy(true, '正在解析并校验…');
    try {
      await new Promise((resolve) => setTimeout(resolve, 30));
      let files = entries;
      if (files.length === 1 && /\.zip$/i.test(files[0].path)) {
        const bytes = files[0].data instanceof Uint8Array ? files[0].data : new Uint8Array(files[0].data);
        files = await root.SNZip.read(bytes);
      }
      if (files.length === 1 && /\.json$/i.test(files[0].path)) {
        const parsed = JSON.parse(Store.decodeText(files[0].data));
        if (parsed && (parsed.format === Store.FORMAT || parsed.contentFiles || parsed.manifest)) {
          if (!parsed.manifest) throw new Error('项目文件缺少 manifest');
          setProject(Store.normalizeProject(parsed));
          await saveNow();
          UI.toast('项目文件已导入', 'success');
          return;
        }
        throw new Error('这个 JSON 不是项目文件。导入模组请选择包含 manifest.json 的文件夹或 ZIP。');
      }
      const result = Store.fromFiles(files);
      setProject(result.project);
      await saveNow({ disk: true });
      if (result.warnings.length) {
        UI.modal({
          title: '导入完成，但有需要注意的地方',
          body: `<ul class="warning-list">${result.warnings.map((warning) => `<li>${UI.esc(warning)}</li>`).join('')}</ul>`,
          footer: '<button type="button" class="btn primary" data-modal-close>知道了</button>',
        });
      } else {
        UI.toast(`已导入 ${result.project.manifest.name}`, 'success');
      }
    } catch (error) {
      UI.toast(error.message || '导入失败', 'error', 6500);
    } finally {
      UI.setBusy(false);
    }
  }

  /* ------------------------------------------------------------------ */
  /* Runtime-unsupported content export/deploy guards                    */
  /* ------------------------------------------------------------------ */

  function unsupportedContentFiles() {
    return state.project ? Store.unsupportedContentFiles(state.project) : [];
  }

  function unsupportedContentLabel(files) {
    return files.map((file) => file.path).join('、');
  }

  function unsupportedExportNotice(files) {
    if (!files.length) return '';
    return `<div class="notice warning" role="note">
      <div>
        <strong>包含 ${files.length} 个当前运行时不支持的内容文件：</strong>
        <span>${UI.esc(unsupportedContentLabel(files))}。这些内容（草案类型或 schema_version 与类型不符）不会被游戏加载；「导出并覆盖到发布包 mods/」已禁用。</span>
      </div>
    </div>`;
  }

  async function confirmUnsupportedExport(files, actionLabel) {
    if (!files.length) return true;
    return UI.confirm({
      title: '包含当前运行时不支持的内容',
      message: `${actionLabel}包含 ${files.length} 个当前运行时不支持的内容文件（${unsupportedContentLabel(files)}）。这些内容（草案类型或 schema_version 与类型不符）不会被游戏加载。仍要继续吗？`,
      confirmLabel: '仍然导出',
      danger: true,
    });
  }

  function showExport() {
    const unsupported = unsupportedContentFiles();
    const deployOption = unsupported.length
      ? `<button type="button" class="import-option" disabled>
          <span class="import-icon">GAME</span>
          <span><strong>导出并覆盖到发布包 mods/</strong><small>项目包含当前运行时不支持的内容（草案或版本不匹配）：游戏无法加载，不能部署到发布包；请先移除或修正这些内容</small></span>
        </button>`
      : state.backend
        ? `<button type="button" class="import-option" data-action="deploy-game-mod">
          <span class="import-icon">GAME</span>
          <span><strong>导出并覆盖到发布包 mods/</strong><small>写入 <code>${UI.esc(state.backend.gameModsDir || '../dist/build/windows/mods')}/&lt;id&gt;.snavmod.zip</code>，并清理该 ID 的旧版本包</small></span>
        </button>`
        : `<button type="button" class="import-option" disabled>
          <span class="import-icon">GAME</span>
          <span><strong>导出并覆盖到发布包 mods/</strong><small>需要本地服务：先运行 <code>node SNModMaker/tools/serve.mjs</code>，再从 http://127.0.0.1:8099/ 打开</small></span>
        </button>`;
    UI.modal({
      title: '导出',
      subtitle: '发布用 ZIP，或保留一个可再次编辑的项目文件。',
      size: 'sm',
      body: `${unsupportedExportNotice(unsupported)}<div class="import-options">
        <button type="button" class="import-option" data-action="export-zip">
          <span class="import-icon">ZIP</span>
          <span><strong>下载 .snavmod.zip</strong><small>mods/&lt;id&gt;/ 结构，可直接放入 mods 或 user://mods</small></span>
        </button>
        ${state.backend ? `<button type="button" class="import-option" data-action="export-disk">
          <span class="import-icon">DIR</span>
          <span><strong>保存到 ${UI.esc(state.backend.exportsDir || 'exports')}/</strong><small>写入本地 <code>SNModMaker/${UI.esc(state.backend.exportsDir || 'exports')}/</code></small></span>
        </button>` : ''}
        ${deployOption}
        <button type="button" class="import-option" data-action="export-project">
          <span class="import-icon">JSON</span>
          <span><strong>保存项目文件</strong><small>.snmodproj.json，包含所有内容、本地化与附件</small></span>
        </button>
        <button type="button" class="import-option" data-action="export-folder" ${IO.supportsFolderExport() ? '' : 'disabled'}>
          <span class="import-icon">DIR</span>
          <span><strong>写入本地目录</strong><small>${IO.supportsFolderExport() ? '选择父目录，创建 <id>/ 并写入松散文件' : '当前浏览器不支持文件夹写入，请用 ZIP'}</small></span>
        </button>
      </div>`,
      footer: '<button type="button" class="btn ghost" data-modal-close>取消</button>',
    });
  }

  async function exportZip() {
    if (!state.project) return;
    if (state.issues.counts.error) {
      const ok = await UI.confirm({
        title: '仍有错误',
        message: `当前有 ${state.issues.counts.error} 个错误。游戏会拒绝加载带错误的模组，仍要导出吗？`,
        confirmLabel: '仍然导出',
      });
      if (!ok) return;
    }
    if (!(await confirmUnsupportedExport(unsupportedContentFiles(), '下载 .snavmod.zip '))) return;
    try {
      UI.setBusy(true, '正在打包 ZIP…');
      await saveNow();
      const result = await IO.exportZip(state.project);
      UI.toast(`已生成 ${result.filename}（${UI.fmtSize(result.size)}）`, 'success', 4200);
    } catch (error) {
      UI.toast(error.message || '导出失败', 'error');
    } finally {
      UI.setBusy(false);
    }
  }

  async function exportZipToDisk() {
    if (!state.project) return;
    if (state.issues.counts.error) {
      const ok = await UI.confirm({
        title: '仍有错误',
        message: `当前有 ${state.issues.counts.error} 个错误。仍要写入 ${state.backend.exportsDir || 'exports'}/ 吗？`,
        confirmLabel: '仍然导出',
      });
      if (!ok) return;
    }
    if (!(await confirmUnsupportedExport(unsupportedContentFiles(), `保存到 ${state.backend.exportsDir || 'exports'}/ `))) return;
    try {
      UI.setBusy(true, '正在写入 exports/…');
      await saveNow({ disk: true });
      const result = await IO.buildZip(state.project);
      const saved = await IO.saveExportToDisk(result.filename, result.bytes);
      UI.toast(`已写入 ${saved.name}（${UI.fmtSize(saved.size)}）`, 'success', 4200);
    } catch (error) {
      UI.toast(error.message || '写入 exports/ 失败', 'error');
    } finally {
      UI.setBusy(false);
    }
  }

  async function deployGameMod() {
    if (!state.project || !state.backend) return;
    if (unsupportedContentFiles().length) {
      UI.toast('项目包含当前运行时不支持的内容（草案或版本不匹配），不能部署到发布包 mods/。', 'error', 6500);
      return;
    }
    const target = `${state.backend.gameModsDir}/${state.project.manifest.id}.snavmod.zip`;
    if (state.issues.counts.error) {
      const ok = await UI.confirm({
        title: '仍有错误',
        message: `当前有 ${state.issues.counts.error} 个错误。游戏可能拒绝加载；仍要覆盖 ${target} 吗？`,
        confirmLabel: '仍然覆盖',
        danger: true,
      });
      if (!ok) return;
    }
    try {
      UI.setBusy(true, '正在部署到游戏模组目录…');
      await saveNow({ disk: true });
      const result = await IO.buildZip(state.project);
      const deployed = await IO.deployGameMod(state.project.manifest.id, result.bytes);
      const cleanup = deployed.removed ? `，已清理 ${deployed.removed} 个旧版本包` : '';
      UI.toast(`已覆盖 ${deployed.name}（${UI.fmtSize(deployed.size)}）${cleanup}`, 'success', 5200);
    } catch (error) {
      UI.toast(error.message || '部署到游戏模组目录失败', 'error', 6500);
    } finally {
      UI.setBusy(false);
    }
  }

  function exportProjectFile() {
    if (!state.project) return;
    try {
      const result = IO.exportProjectFile(state.project);
      UI.toast(`已生成 ${result.filename}`, 'success');
    } catch (error) {
      UI.toast(error.message || '导出失败', 'error');
    }
  }

  async function exportFolder() {
    if (!state.project) return;
    if (!(await confirmUnsupportedExport(unsupportedContentFiles(), '写入本地目录 '))) return;
    try {
      await saveNow();
      const result = await IO.exportFolder(state.project);
      UI.toast(`已写入 ${result.folder}/（${result.files} 个文件）`, 'success', 4200);
    } catch (error) {
      if (error && error.name === 'AbortError') return;
      UI.toast(error.message || '写入目录失败', 'error');
    }
  }

  async function showProjectLibrary() {
    if (state.dirty) await saveNow({ disk: true });
    const dialog = UI.modal({
      title: '项目库',
      subtitle: state.backend
        ? `浏览器项目 + 磁盘 ${state.backend.modsDir || 'mods'}/；保存时两边都会写入。`
        : '项目保存在当前浏览器；导出的项目文件才是长期备份。',
      size: 'md',
      body: '<div id="library-list" class="library-list"><p class="loading-text">读取本地项目…</p></div>',
      footer: `<button type="button" class="btn ghost" data-modal-close>关闭</button>
        ${state.backend && state.project ? '<button type="button" class="btn" data-action="save-disk">写入 mods/</button>' : ''}
        <button type="button" class="btn" data-action="new-project">新建</button>
        <button type="button" class="btn" data-action="import">导入</button>`,
    });
    if (!dialog) return;
    const host = dialog.querySelector('#library-list');
    try {
      const [rows, diskRows] = await Promise.all([
        IO.listProjects().catch(() => []),
        state.backend ? IO.listDiskProjects().catch(() => []) : Promise.resolve([]),
      ]);
      if (!rows.length && !diskRows.length) {
        host.innerHTML = '<div class="empty-inline large">还没有本地项目。</div>';
        return;
      }
      const diskHtml = diskRows.map((item) => `
        <div class="library-row">
          <div class="library-main">
            <div class="library-name">${UI.esc(item.name)} <span class="mini-badge">mods/</span></div>
            <div class="library-meta mono">${UI.esc(item.id)} · v${UI.esc(item.version)} · ${item.definitions} 条定义</div>
            <div class="library-time">${UI.esc(UI.fmtDate(item.updatedAt))}</div>
          </div>
          <div class="library-actions">
            <button type="button" class="btn small primary" data-action="open-disk-project" data-id="${UI.attr(item.id)}">打开</button>
            <button type="button" class="icon-btn tiny danger" data-action="delete-disk-project" data-id="${UI.attr(item.id)}" title="删除磁盘项目">✕</button>
          </div>
        </div>`).join('');
      const browserHtml = rows.map((project) => {
        const manifest = project.manifest || {};
        const current = state.project && state.project.uid === project.uid;
        return `<div class="library-row ${current ? 'current' : ''}">
          <div class="library-main">
            <div class="library-name">${UI.esc(manifest.name || '未命名模组')} ${current ? '<span class="mini-badge">当前</span>' : ''}</div>
            <div class="library-meta mono">${UI.esc(manifest.id || '')} · v${UI.esc(manifest.version || '')} · ${Object.keys(project.contentFiles || []).length ? (project.contentFiles || []).reduce((sum, file) => sum + (file.definitions || []).length, 0) : 0} 条定义</div>
            <div class="library-time">${UI.esc(UI.fmtDate(project.meta && project.meta.updatedAt))}</div>
          </div>
          <div class="library-actions">
            <button type="button" class="btn small ${current ? 'ghost' : 'primary'}" data-action="open-project" data-uid="${UI.attr(project.uid)}">${current ? '重新载入' : '打开'}</button>
            <button type="button" class="icon-btn tiny danger" data-action="delete-project" data-uid="${UI.attr(project.uid)}" title="删除">✕</button>
          </div>
        </div>`;
      }).join('');
      host.innerHTML = `
        ${state.backend ? `<p class="recent-label mono">磁盘 · ${UI.esc(state.backend.modsDir || 'mods')}/</p>${diskHtml || '<div class="empty-inline">还没有写入磁盘的项目。点击下方「写入 mods/」。</div>'}` : ''}
        <p class="recent-label mono">浏览器 · IndexedDB</p>
        ${browserHtml || '<div class="empty-inline">没有浏览器项目。</div>'}`;
    } catch (error) {
      host.innerHTML = '<div class="empty-inline large">无法读取项目库。</div>';
    }
  }

  async function openDiskProject(id) {
    if (!id) return;
    try {
      if (state.dirty) await saveNow({ disk: true });
      const project = await IO.getDiskProject(id);
      if (!project) {
        UI.toast('磁盘项目不存在。', 'error');
        return;
      }
      setProject(project, { fromDisk: true });
      UI.closeModal();
      UI.toast(`已打开 ${project.manifest.name}`, 'success');
    } catch (error) {
      UI.toast(error.message || '打开磁盘项目失败', 'error');
    }
  }

  /** Opens dev_mods/<id> in place; saves write back into the game's native mod
   *  directory instead of SNModMaker/mods/ or a packaged ZIP. */
  async function openWorkspaceProject(id) {
    if (!id) return;
    try {
      if (state.dirty) await saveNow({ disk: true });
      const project = await IO.getWorkspaceProject(id);
      if (!project) {
        UI.toast('工作区不存在。', 'error');
        return;
      }
      setProject(project, { fromDisk: true, workspace: true });
      UI.closeModal();
      const rootDir = (state.backend && state.backend.workspaceDir) || 'dev_mods';
      UI.toast(`已打开工作区 ${rootDir}/${id}；保存会直接写回该目录`, 'success', 3200);
    } catch (error) {
      UI.toast(error.message || '打开工作区失败', 'error', 5000);
    }
  }

  async function deleteDiskProject(id) {
    if (!id) return;
    const ok = await UI.confirm({
      title: '删除磁盘项目',
      message: `会删除 ${state.backend && state.backend.modsDir ? state.backend.modsDir : 'mods'}/${id}/ 及其中的模组文件，无法撤销。`,
      confirmLabel: '删除',
      danger: true,
    });
    if (!ok) return;
    try {
      await IO.deleteDiskProject(id);
      if (state.project && state.project.manifest.id === id) clearProject();
      showProjectLibrary();
      UI.toast('磁盘项目已删除', 'success');
    } catch (error) {
      UI.toast(error.message || '删除失败', 'error');
    }
  }

  function showCoreClone() {
    if (!state.project || state.view.name !== 'content') return;
    const typeKey = state.view.type;
    const typeInfo = Cat.BY_KEY[typeKey];
    if (typeInfo && typeInfo.draft) {
      UI.toast('Schema 2.0 草案类型在 Core 中没有可复制的定义。', 'warning');
      return;
    }
    const core = root.SN_CORE_INDEX;
    if (!core) {
      UI.toast('Core 索引未加载。', 'error');
      return;
    }
    const definitions = core.definitions.filter((definition) => definition.content_type === typeKey);
    const rows = definitions.map((definition) => `
      <button type="button" class="core-row" data-core-id="${UI.attr(definition.id)}" data-action="clone-core"
        data-core-search="${UI.attr(`${definition.id} ${definition.name_zh} ${definition.name_en}`.toLowerCase())}">
        <span class="core-name">${UI.esc(definition.name_zh || definition.name_en || definition.id)}</span>
        <span class="mono core-id">${UI.esc(definition.id)}</span>
        <span class="core-tags">${(definition.tags || []).map((tag) => `<span class="tag">${UI.esc(tag)}</span>`).join('')}</span>
      </button>`).join('');
    UI.modal({
      title: `从 Core 复制${Cat.BY_KEY[typeKey].label}`,
      subtitle: '会复制完整定义与本地化，换成本模组的 ID / 键，再按需改数值。',
      size: 'md',
      body: `<input class="input search" type="search" placeholder="搜索 Core 定义…" data-core-search>
        <div class="core-list">${rows || '<div class="empty-inline large">Core 中没有这种类型的定义。</div>'}</div>`,
      footer: '<button type="button" class="btn ghost" data-modal-close>取消</button>',
    });
  }

  function showAddLocale() {
    UI.modal({
      title: '新建语言',
      size: 'sm',
      body: `<div class="field">
        <label class="field-label">语言代码</label>
        <input class="input mono" id="new-locale" placeholder="ja" value="">
        <p class="field-hint">例如 zh_CN、en、ja。文件会写到 localization/&lt;code&gt;.json。</p>
      </div>
      <p class="form-error" id="locale-error"></p>`,
      footer: `<button type="button" class="btn ghost" data-modal-close>取消</button>
        <button type="button" class="btn primary" data-action="create-locale">创建</button>`,
    });
  }

  function createLocale() {
    const input = document.getElementById('new-locale');
    const errorNode = document.getElementById('locale-error');
    const code = input ? input.value.trim() : '';
    if (!/^[A-Za-z]{2,3}(_[A-Za-z]{2})?$/.test(code)) {
      if (errorNode) errorNode.textContent = '语言代码形如 en、zh_CN、ja。';
      return;
    }
    if (state.project.localization.some((entry) => entry.locale === code)) {
      if (errorNode) errorNode.textContent = '这个语言已经存在。';
      return;
    }
    pushHistory();
    Store.addLocale(state.project, code);
    state.locale = code;
    state.view = { name: 'localization', locale: code };
    markChanged(true);
    UI.closeModal();
    render();
  }

  function showAddLocaleKey() {
    UI.modal({
      title: '添加本地化键',
      size: 'sm',
      body: `<div class="field"><label class="field-label">键</label><input class="input mono" id="new-key" placeholder="good.my_mod.tea.name"></div>
        <div class="field"><label class="field-label">${UI.esc(state.locale)} 文本</label><input class="input" id="new-key-value"></div>
        <p class="form-error" id="key-error"></p>`,
      footer: `<button type="button" class="btn ghost" data-modal-close>取消</button>
        <button type="button" class="btn primary" data-action="create-locale-key">添加</button>`,
    });
  }

  function createLocaleKey() {
    const keyInput = document.getElementById('new-key');
    const valueInput = document.getElementById('new-key-value');
    const errorNode = document.getElementById('key-error');
    const key = keyInput ? keyInput.value.trim() : '';
    if (!key) {
      if (errorNode) errorNode.textContent = '键不能为空。';
      return;
    }
    const entry = Store.getLoc(state.project, state.locale) || Store.addLocale(state.project, state.locale);
    pushHistory();
    entry.entries[key] = valueInput ? valueInput.value : '';
    markChanged(true);
    UI.closeModal();
    render({ preserveScroll: true });
  }

  function showHelp() {
    UI.modal({
      title: '使用说明',
      subtitle: 'Steam Navigator Mod Maker · 零依赖网页端',
      size: 'md',
      body: `<div class="help-grid">
        <section><h4>工作流</h4><ol>
          <li>新建或导入一个模组项目。</li>
          <li>在「模组概览」确认 ID、版本、依赖与描述。</li>
          <li>按类型新增定义；引用 Core 内容时保留完整 ID。</li>
          <li>补齐本地化键，修正校验错误。</li>
          <li>导出 .snavmod.zip，放进游戏的 mods/ 或 user://mods/。</li>
        </ol></section>
        <section><h4>规则要点</h4><ul>
          <li>ID 形如 <code>my_mod:boiler/compound</code>，命名空间必须等于模组 ID。</li>
          <li>修改其他模组只能写 patches 文件，不能直接改目标定义。</li>
          <li>内容模组是纯数据：没有脚本、DLL、场景或路径穿越。</li>
          <li>第三方模组不能声明 required = true。</li>
        </ul></section>
        <section><h4>快捷键</h4><ul class="kbd-list">
          <li><kbd>Ctrl</kbd>+<kbd>S</kbd> 立即保存</li>
          <li><kbd>Ctrl</kbd>+<kbd>Z</kbd> 撤销 / <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Z</kbd> 重做</li>
          <li><kbd>Ctrl</kbd>+<kbd>N</kbd> 新建 / <kbd>Ctrl</kbd>+<kbd>O</kbd> 导入</li>
          <li><kbd>Ctrl</kbd>+<kbd>E</kbd> 导出 ZIP</li>
        </ul></section>
        <section><h4>浏览器与数据</h4><ul>
          <li>项目保存在 IndexedDB，不上传服务器。</li>
          <li>ZIP 读写、文件夹导出使用浏览器原生能力。</li>
          <li>可以直接双击 index.html 使用；文件夹导出需要 Chrome / Edge。</li>
          <li>Schema 与 Core 索引由仓库内脚本生成，见 README。</li>
        </ul></section>
      </div>`,
      footer: '<button type="button" class="btn primary" data-modal-close>知道了</button>',
    });
  }

  /* ------------------------------------------------------------------ */
  /* Drag and drop                                                       */
  /* ------------------------------------------------------------------ */

  let dragDepth = 0;

  function onDragEnter(event) {
    if (!event.dataTransfer || !Array.from(event.dataTransfer.types || []).includes('Files')) return;
    dragDepth += 1;
    const overlay = document.getElementById('drop-overlay');
    if (overlay) overlay.classList.add('visible');
  }

  function onDragOver(event) {
    if (event.dataTransfer) event.preventDefault();
  }

  function onDragLeave() {
    dragDepth = Math.max(0, dragDepth - 1);
    if (dragDepth === 0) {
      const overlay = document.getElementById('drop-overlay');
      if (overlay) overlay.classList.remove('visible');
    }
  }

  async function onDrop(event) {
    event.preventDefault();
    dragDepth = 0;
    const overlay = document.getElementById('drop-overlay');
    if (overlay) overlay.classList.remove('visible');
    try {
      const entries = await IO.dataTransferToEntries(event.dataTransfer);
      await importEntries(entries);
    } catch (error) {
      UI.toast(error.message || '导入失败', 'error');
    }
  }

  /* ------------------------------------------------------------------ */
  /* Misc                                                                */
  /* ------------------------------------------------------------------ */

  function runValidation() {
    if (!state.project) return;
    state.issues = V.validateProject(state.project);
    state.issueByDef = V.byDefinition(state.issues.issues);
  }

  async function copyText(text) {
    try {
      await navigator.clipboard.writeText(text || '');
      UI.toast('已复制到剪贴板', 'success', 1600);
    } catch (error) {
      UI.toast('复制失败，请手动选择文本。', 'error');
    }
  }

})(typeof globalThis !== 'undefined' ? globalThis : this);
