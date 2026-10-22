#!/usr/bin/env node
/*
 * SNModMaker Content CLI（零依赖，Node >= 18，ESM）。
 *
 * 面向 agent / CI / 维护者的无头内容增删改工具：
 *   node SNModMaker/tools/content.mjs <command> [options]
 *
 * 约定：
 *   - --json 时 stdout 只输出一个 JSON 对象，日志/提示走 stderr 或 notes。
 *   - 写操作全部复用 js/store.js 与 js/validate.js，写回时用 content_json.mjs
 *     做保源编辑：只增删目标节点所在字节，既有定义逐字节不变。
 *   - 写入前校验源文件 SHA-256；加载后被改动则整批不写并报 conflict。
 */

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import * as CJ from './content_json.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..', '..');
const SNMODMAKER = path.resolve(here, '..');

/* 经典脚本通过 globalThis 暴露；加载顺序不能变（catalog 依赖 content-types）。 */
const require = createRequire(import.meta.url);
for (const name of ['schema-bundle.js', 'core-index.js', 'content-types.js', 'catalog.js', 'validate.js', 'store.js']) {
  require(path.join(SNMODMAKER, 'js', name));
}
const Store = globalThis.SNStore;
const Validate = globalThis.SNValidate;
const Catalog = globalThis.SNCatalog;
const Types = globalThis.SNContentTypes;

/* Schema 2.0 类型来自生成的 content-types.js：运行时类型（TYPES，含 Content Schema
 * 1.0 与已接入运行时的 2.0 类型）与剩余草案类型（DRAFT_TYPES，游戏运行时不加载）
 * 共用同一套编辑与校验链路；两者都由 Schema 版本与 capability 区分。 */
function draftTypes() {
  if (Types && Array.isArray(Types.DRAFT_TYPES)) return Types.DRAFT_TYPES;
  if (Catalog && Array.isArray(Catalog.DRAFT_TYPES)) return Catalog.DRAFT_TYPES;
  return [];
}

function allTypeInfos() {
  return [...Catalog.TYPES, ...draftTypes()];
}

function findTypeInfo(typeKey) {
  if (!typeKey) return null;
  return Catalog.BY_KEY[typeKey] || draftTypes().find((info) => info.key === typeKey) || null;
}

function knownTypeKeys() {
  return allTypeInfos().map((info) => info.key);
}

/** 内容文件/类型期望的 schema 版本：优先复用 validate.js 的推导，缺失时回退。 */
function schemaVersionFor(target) {
  if (Validate && typeof Validate.schemaVersionFor === 'function') {
    const version = Validate.schemaVersionFor(target);
    if (version) return version;
  }
  if (target && typeof target === 'object') {
    if (typeof target.schema_version === 'string' && target.schema_version) return target.schema_version;
    return schemaVersionFor(target.content_type);
  }
  const info = findTypeInfo(String(target || ''));
  return (info && (info.schemaVersion || info.schema_version)) || '1.0';
}

const USAGE = `SNModMaker 内容 CLI（v1）

用法：
  node SNModMaker/tools/content.mjs <command> [options]

命令：
  types                                   列出全部内容类型（运行时 20 类 + 3 类 Schema 2.0 草案）
  describe <type>                         查看类型的 ID / 键 / 字段 / 默认值与骨架
  list --mod <dir> [--type <key>]         列出模组内的全部定义
  add --mod <dir> --type <key> --id <local_id> [选项]
  set --mod <dir> <definition-id> <path=value>...
  loc --mod <dir> <definition-id> [--field name|description] [--zh <text>] [--en <text>]
  loc --mod <dir> --key <loc-key> --locale <zh_CN|en> --text <text>
  rm --mod <dir> <definition-id> --yes [--keep-loc]
  clone --mod <dir> --from <core-definition-id> [--id <local_id>] [--name-zh <text>] [--name-en <text>]
  validate --mod <dir> [--strict] [--godot]
  new --mod <dir> --id <mod_id> --name <name> [--template items|boiler|event|weapons|starter_kit|blank]
      [--draft <content_type>]...          用 Schema 2.0 草案类型新建项目（可重复；纯 2.0 项目）

add 选项：
  --name-zh <text> --name-en <text>       标准定义必须同时提供双语名称
  --desc-zh <text> --desc-en <text>       描述可同时省略（则不写 description_key）
  --tag <tag>...                          可重复；缺省取标签建议第一条
  --data <path>=<value>...                可重复；path 支持 a.b / a[2].b / /data/x
  --data-json <json|@file>                与默认值深合并
  --file <content/path.json>              指定写入的内容文件（不存在则新建）
  --namespace <id>                        必须等于 manifest.id
  --suffix                                local id 冲突时自动加 _2 后缀
  --target / --requires-mod / --requires-version / --operations-json  仅 patches
  --sync                                  core 模组真实写入后重新生成 core 索引
  --test                                  真实写入后运行 Node 测试
  --dry-run / --force

通用选项：--json  --quiet  --help/-h
退出码：0 成功；1 执行失败 / 校验未通过 / 冲突；2 用法错误。

Schema 2.0 运行时类型共 12 类：Phase B 的 9 类（world_profiles / map_configs / regions /
sites / route_templates / weather_profiles / factions / discoveries / start_profiles）+
C1 的 hulls / modules + C2 的 items。它们已接入游戏运行时，可以像 1.0 类型一样
list / add / set / describe / validate，内容文件写 schema_version "2.0"。
CLI 不会自动声明 capability：内容使用 Schema 2.0 但未在 manifest.capabilities 声明对应
能力时，校验给出 capability_undeclared 警告（按类型去重，每个 capability 一条）。

剩余 Schema 2.0 草案类型（weapons / story_arcs / story_levels）同样可编辑、可校验，
内容文件写 schema_version "2.0"；但游戏运行时不加载，校验给出 draft_content 警告。
草案模组使用 capability 时还需在 manifest.capabilities 声明对应能力（weapons →
content.combat.v1，剧情 → content.story.v1）。剧情包是白名单模组：同一包里出现故事
内容之外的类型会报 story_pack_off_whitelist。

新建项目时用 --draft 直接创建纯 Schema 2.0 草案项目（每类生成一个 content 文件、
schema_version "2.0" 与起始定义，并把 capability 写入 manifest；不与 --template 同时
指定时不会附带默认 items 起始定义）：
  node SNModMaker/tools/content.mjs new --mod my_weapon_mod --id my_weapon_mod \\
    --name "我的武器包" --draft weapons
  node SNModMaker/tools/content.mjs new --mod my_story_mod --id my_story_mod \\
    --name "我的剧情包" --draft story_arcs --draft story_levels
`;

/* ------------------------------------------------------------------ */
/* 错误与参数解析                                                       */
/* ------------------------------------------------------------------ */

class CliError extends Error {
  constructor(code, message, exitCode = 1) {
    super(message);
    this.name = 'CliError';
    this.code = code;
    this.exitCode = exitCode;
  }
}

const usageError = (message) => new CliError('usage', message, 2);

const BOOLEAN_FLAGS = new Set([
  'json', 'quiet', 'help', 'dry-run', 'force', 'suffix', 'yes', 'keep-loc',
  'strict', 'godot', 'sync', 'test',
]);

function parseArgv(argv) {
  const flags = new Map();
  const positional = [];
  let afterSeparator = false;
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (afterSeparator) {
      positional.push(token);
      continue;
    }
    if (token === '--') {
      afterSeparator = true;
      continue;
    }
    if (token === '-h' || token === '--help') {
      flags.set('help', true);
      continue;
    }
    if (!token.startsWith('--')) {
      positional.push(token);
      continue;
    }
    const equal = token.indexOf('=');
    const name = equal >= 0 ? token.slice(2, equal) : token.slice(2);
    let value;
    if (equal >= 0) {
      value = token.slice(equal + 1);
    } else if (!BOOLEAN_FLAGS.has(name) && i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
      i += 1;
      value = argv[i];
    } else {
      value = true;
    }
    if (flags.has(name)) {
      const previous = flags.get(name);
      flags.set(name, Array.isArray(previous) ? [...previous, value] : [previous, value]);
    } else {
      flags.set(name, value);
    }
  }
  return { flags, positional };
}

function flagTrue(ctx, name) {
  const value = ctx.flags.get(name);
  if (value === true) return true;
  if (Array.isArray(value)) return value.some((item) => item === true || item === 'true');
  return value === 'true';
}

function flagValue(ctx, name) {
  const value = ctx.flags.get(name);
  if (value === undefined) return undefined;
  const list = Array.isArray(value) ? value : [value];
  for (let i = list.length - 1; i >= 0; i -= 1) {
    if (list[i] !== true) return String(list[i]);
  }
  return undefined;
}

function flagValues(ctx, name) {
  const value = ctx.flags.get(name);
  if (value === undefined) return [];
  return (Array.isArray(value) ? value : [value]).filter((item) => item !== true).map(String);
}

function requireFlag(ctx, name, label) {
  const value = flagValue(ctx, name);
  if (value === undefined || value === '') {
    throw usageError(`缺少 --${name}${label ? `（${label}）` : ''}`);
  }
  return value;
}

/* ------------------------------------------------------------------ */
/* 通用工具                                                             */
/* ------------------------------------------------------------------ */

const deepClone = (value) => (value == null ? value : JSON.parse(JSON.stringify(value)));

function jsonEqual(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

function isPlainObject(value) {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function splitLines(text) {
  if (!text) return [];
  const lines = String(text).split('\n');
  if (lines.length && lines[lines.length - 1] === '') lines.pop();
  return lines;
}

/** 行级 LCS unified diff；文件很小，单个 hunk 即可满足 CLI 展示。 */
function unifiedDiff(oldText, newText, context = 3) {
  const before = splitLines(oldText);
  const after = splitLines(newText);
  if (oldText === newText) return '';
  if (before.length * after.length > 4_000_000) {
    return ['--- a', '+++ b', `@@ -1,${before.length} +1,${after.length} @@`,
      ...before.map((line) => `-${line}`), ...after.map((line) => `+${line}`)].join('\n');
  }
  const n = before.length;
  const m = after.length;
  const dp = Array.from({ length: n + 1 }, () => new Uint32Array(m + 1));
  for (let i = n - 1; i >= 0; i -= 1) {
    for (let j = m - 1; j >= 0; j -= 1) {
      dp[i][j] = before[i] === after[j]
        ? dp[i + 1][j + 1] + 1
        : Math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  const ops = [];
  let i = 0;
  let j = 0;
  while (i < n && j < m) {
    if (before[i] === after[j]) {
      ops.push({ type: 'same', text: before[i] });
      i += 1;
      j += 1;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      ops.push({ type: 'del', text: before[i] });
      i += 1;
    } else {
      ops.push({ type: 'ins', text: after[j] });
      j += 1;
    }
  }
  while (i < n) ops.push({ type: 'del', text: before[i++] });
  while (j < m) ops.push({ type: 'ins', text: after[j++] });
  let first = 0;
  while (first < ops.length && ops[first].type === 'same') first += 1;
  if (first >= ops.length) return '';
  let last = ops.length - 1;
  while (last >= 0 && ops[last].type === 'same') last -= 1;
  const start = Math.max(0, first - context);
  const end = Math.min(ops.length, last + 1 + context);
  let oldStart = 1;
  let newStart = 1;
  for (let k = 0; k < start; k += 1) {
    if (ops[k].type !== 'ins') oldStart += 1;
    if (ops[k].type !== 'del') newStart += 1;
  }
  let oldCount = 0;
  let newCount = 0;
  for (let k = start; k < end; k += 1) {
    if (ops[k].type !== 'ins') oldCount += 1;
    if (ops[k].type !== 'del') newCount += 1;
  }
  const lines = [`--- a`, `+++ b`, `@@ -${oldStart},${oldCount} +${newStart},${newCount} @@`];
  for (let k = start; k < end; k += 1) {
    const op = ops[k];
    lines.push(`${op.type === 'same' ? ' ' : op.type === 'del' ? '-' : '+'}${op.text}`);
  }
  return lines.join('\n');
}

/* ------------------------------------------------------------------ */
/* 输出                                                                 */
/* ------------------------------------------------------------------ */

function printJson(payload) {
  process.stdout.write(`${JSON.stringify(payload)}\n`);
}

function stripChanges(changes) {
  return changes.map((change) => {
    const output = { path: change.path, action: change.action, bytes: change.bytes };
    if (change.diff) output.diff = change.diff;
    return output;
  });
}

function changeLines(changes) {
  return changes.map((change) => {
    const suffix = change.detail ? `  ${change.detail}` : '';
    return `  ${change.path.padEnd(28)} ${change.action}${suffix}`;
  }).join('\n');
}

function issueSummary(after, newIssues) {
  return {
    errors: after.counts.error,
    warnings: after.counts.warning,
    newErrors: newIssues.filter((issue) => issue.severity === 'error').length,
    newWarnings: newIssues.filter((issue) => issue.severity === 'warning').length,
    list: newIssues.map((issue) => {
      const row = { severity: issue.severity, code: issue.code, message: issue.message };
      if (issue.view) row.view = issue.view;
      return row;
    }),
  };
}

function buildStats(project) {
  return {
    definitions: Store.allDefinitions(project).length,
    contentFiles: project.contentFiles.length,
    locales: project.localization.length,
  };
}

function respond(ctx, payload, humanText, exitCode = 0) {
  if (ctx.json) {
    printJson(payload);
  } else if (humanText) {
    process.stdout.write(humanText.endsWith('\n') ? humanText : `${humanText}\n`);
  }
  if (!ctx.json && !ctx.quiet) {
    for (const note of ctx.notes) process.stderr.write(`note: ${note}\n`);
  }
  return exitCode;
}

function issueKey(issue) {
  return `${issue.severity}|${issue.code}|${issue.message}|${JSON.stringify(issue.view || {})}`;
}

function newIssuesBetween(baseline, after) {
  const seen = new Set(baseline.issues.map(issueKey));
  return after.issues.filter((issue) => !seen.has(issueKey(issue)));
}

/* ------------------------------------------------------------------ */
/* 模组加载                                                             */
/* ------------------------------------------------------------------ */

function listFilesRecursive(root) {
  const output = [];
  const walk = (relative) => {
    const absolute = relative ? path.join(root, relative) : root;
    const entries = fs.readdirSync(absolute, { withFileTypes: true })
      .sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
    for (const entry of entries) {
      const rel = relative ? `${relative}/${entry.name}` : entry.name;
      if (entry.isDirectory()) walk(rel);
      else if (entry.isFile()) output.push(rel);
    }
  };
  walk('');
  return output;
}

function loadMod(ctx, modArg) {
  const resolved = path.resolve(modArg);
  if (!fs.existsSync(resolved) || !fs.statSync(resolved).isDirectory()) {
    throw new CliError('not_found', `模组目录不存在：${modArg}`);
  }
  if (!fs.existsSync(path.join(resolved, 'manifest.json'))) {
    throw new CliError('not_found', `模组根目录缺少 manifest.json：${modArg}`);
  }
  const files = new Map();
  const entries = [];
  for (const rel of listFilesRecursive(resolved)) {
    const buffer = fs.readFileSync(path.join(resolved, rel));
    files.set(rel, { buffer, sha256: sha256(buffer), text: undefined });
    entries.push({ path: rel, data: buffer });
  }
  let loaded;
  try {
    loaded = Store.fromFiles(entries);
  } catch (error) {
    throw new CliError('load', `读取模组失败：${error.message}`);
  }
  for (const warning of loaded.warnings) ctx.notes.push(warning);
  return { abs: resolved, files, project: loaded.project, warnings: loaded.warnings };
}

function fileText(load, rel) {
  const file = load.files.get(rel);
  if (!file) throw new CliError('not_found', `文件不在模组中：${rel}`);
  if (file.text === undefined) file.text = file.buffer.toString('utf8');
  return file.text;
}

function resolveInside(root, relative) {
  const clean = String(relative || '').replace(/\\/g, '/');
  if (!clean || clean.startsWith('/') || clean.includes(':') || /(^|\/)\.\.(\/|$)/.test(clean)) {
    throw new CliError('path', `非法的模组内相对路径：${relative}`);
  }
  const absolute = path.resolve(root, clean);
  const normalizedRoot = path.resolve(root);
  if (absolute !== normalizedRoot && !absolute.startsWith(normalizedRoot + path.sep)) {
    throw new CliError('path', `路径越出模组目录：${relative}`);
  }
  return absolute;
}

function validateContentFilePath(filePath) {
  if (!Validate.safePath(filePath) || !/\.json$/i.test(filePath)) {
    throw usageError(`--file 必须是模组内的 .json 相对路径（不含 ..）：${filePath}`);
  }
}

/* ------------------------------------------------------------------ */
/* 写入事务：变更收集 / 冲突检测 / 原子写                               */
/* ------------------------------------------------------------------ */

function atomicWrite(absolute, buffer) {
  const directory = path.dirname(absolute);
  fs.mkdirSync(directory, { recursive: true });
  const temp = path.join(directory, `.tmp-${process.pid}-${crypto.randomBytes(4).toString('hex')}`);
  try {
    fs.writeFileSync(temp, buffer);
    fs.renameSync(temp, absolute);
  } finally {
    if (fs.existsSync(temp)) {
      try {
        fs.unlinkSync(temp);
      } catch (error) {
        /* 清理失败不掩盖原始错误 */
      }
    }
  }
}

function collectChanges(load, writes, deletes, wouldWrite) {
  const changes = [];
  const prefix = wouldWrite ? 'would-' : '';
  for (const [rel, item] of writes) {
    const buffer = Buffer.from(item.text, 'utf8');
    const old = load.files.get(rel);
    if (old && old.buffer.equals(buffer)) continue;
    changes.push({
      path: rel,
      action: `${prefix}${old ? 'update' : 'create'}`,
      bytes: buffer.length,
      diff: unifiedDiff(old ? fileText(load, rel) : '', item.text),
      detail: item.detail || '',
    });
  }
  for (const [rel, item] of deletes) {
    const old = load.files.get(rel);
    if (!old) continue;
    changes.push({
      path: rel,
      action: `${prefix}delete`,
      bytes: 0,
      diff: unifiedDiff(fileText(load, rel), ''),
      detail: item.detail || '',
    });
  }
  return changes;
}

function verifyBaseline(load, writes, deletes) {
  for (const rel of [...writes.keys(), ...deletes.keys()]) {
    const expected = load.files.get(rel) ? load.files.get(rel).sha256 : null;
    const absolute = resolveInside(load.abs, rel);
    const actual = fs.existsSync(absolute) ? sha256(fs.readFileSync(absolute)) : null;
    if (actual !== expected) {
      throw new CliError('conflict', `检测到并发修改：${rel} 在加载后发生变化，已取消整批写入；请重试。`);
    }
  }
}

function commitChanges(load, writes, deletes) {
  verifyBaseline(load, writes, deletes);
  for (const [rel, item] of writes) {
    atomicWrite(resolveInside(load.abs, rel), Buffer.from(item.text, 'utf8'));
  }
  for (const rel of deletes.keys()) {
    fs.unlinkSync(resolveInside(load.abs, rel));
  }
}

/* ------------------------------------------------------------------ */
/* 保源写回：内容文件 / 本地化 / manifest                               */
/* ------------------------------------------------------------------ */

function planAppendDefinition(load, project, file, definition, index, writes, detail) {
  const old = load.files.get(file.path);
  let text;
  if (old) {
    const oldText = fileText(load, file.path);
    const doc = CJ.parseSource(oldText);
    const definitions = CJ.findNode(doc.root, ['definitions']);
    if (!definitions || definitions.type !== 'array') {
      throw new CliError('load', `${file.path} 的 definitions 不是数组`);
    }
    if (index !== definitions.items.length) {
      throw new CliError('internal', `新增定义索引 ${index} 与源文件 ${file.path} 的数组长度 ${definitions.items.length} 不一致`);
    }
    text = CJ.insertArrayItem(oldText, definitions, definition, CJ.formatStyled);
  } else {
    const payload = {
      schema_version: schemaVersionFor(file),
      content_type: file.content_type,
      definitions: file.definitions,
    };
    text = `${JSON.stringify(payload, null, 2)}\n`;
  }
  writes.set(file.path, { text, detail });
}

/**
 * 纯新增键时把成员插到最后一个成员之前：既保持已有行逐字节不变，
 * 也避免给文件末行补逗号，是 flat map 本地化最省的写法。
 * 返回 null 表示文件不是普通的对象字面量，调用方退回整份序列化。
 */
function insertLocaleEntries(oldText, oldEntries, newEntries) {
  const added = Object.keys(newEntries).filter((key) => !Object.prototype.hasOwnProperty.call(oldEntries, key));
  if (!added.length) return null;
  const doc = CJ.parseSource(oldText);
  const root = doc.root;
  if (!root || root.type !== 'object') return null;
  if (root.members.length === 0) return `${CJ.formatStyled(newEntries, 0)}\n`;
  const last = root.members[root.members.length - 1];
  const multiline = oldText.slice(root.open, root.close + 1).includes('\n');
  const indent = CJ.lineIndentAt(oldText, last.keyStart);
  const members = added.map((key) => `${JSON.stringify(key)}: ${JSON.stringify(newEntries[key])}`);
  if (!multiline) {
    return `${oldText.slice(0, last.keyStart)}${members.join(', ')}, ${oldText.slice(last.keyStart)}`;
  }
  const insertion = `${members.join(`,\n${indent}`)},\n${indent}`;
  return `${oldText.slice(0, last.keyStart)}${insertion}${oldText.slice(last.keyStart)}`;
}

/** 只把真正变化的 locale 文件加入写计划；flat map 允许整体规范化序列化。 */
function planLocaleChanges(load, project, writes, localeNames) {
  for (const locale of localeNames) {
    const entry = Store.getLoc(project, locale);
    if (!entry) continue;
    const old = load.files.get(entry.path);
    const oldEntries = old ? JSON.parse(fileText(load, entry.path)) : {};
    if (old && jsonEqual(oldEntries, entry.entries)) continue;
    if (!old && Object.keys(entry.entries).length === 0) continue;
    const oldKeys = Object.keys(oldEntries);
    const newKeys = Object.keys(entry.entries);
    const removed = oldKeys.filter((key) => !Object.prototype.hasOwnProperty.call(entry.entries, key));
    const changed = oldKeys.filter((key) => Object.prototype.hasOwnProperty.call(entry.entries, key)
      && oldEntries[key] !== entry.entries[key]);
    const added = newKeys.filter((key) => !Object.prototype.hasOwnProperty.call(oldEntries, key));
    if (old && !removed.length && !changed.length && added.length) {
      const preserved = insertLocaleEntries(fileText(load, entry.path), oldEntries, entry.entries);
      if (preserved !== null) {
        writes.set(entry.path, {
          text: preserved,
          detail: `新增 ${added.length} 个键`,
        });
        continue;
      }
    }
    const oldCount = oldKeys.length;
    const newCount = newKeys.length;
    writes.set(entry.path, {
      text: `${JSON.stringify(entry.entries, null, 2)}\n`,
      detail: old ? `本地化键 ${oldCount} → ${newCount}` : `新增 ${newCount} 个键`,
    });
  }
}

/** 只增量插入/删除 manifest.content / manifest.localization 的元素。 */
function patchManifestText(originalText, manifest) {
  let text = originalText;
  for (const key of ['content', 'localization']) {
    const desired = Array.isArray(manifest[key]) ? manifest[key].slice() : [];
    let doc = CJ.parseSource(text);
    let node = CJ.findNode(doc.root, [key]);
    if (!node) {
      if (desired.length) text = CJ.insertObjectMember(text, doc.root, key, desired, CJ.formatStyled);
      continue;
    }
    if (node.type !== 'array') throw new CliError('manifest', `manifest.${key} 不是数组`);
    let current = CJ.nodePathToValue(node, text);
    for (let index = current.length - 1; index >= 0; index -= 1) {
      if (desired.includes(current[index])) continue;
      doc = CJ.parseSource(text);
      node = CJ.findNode(doc.root, [key]);
      text = CJ.removeArrayItem(text, node, index);
      current = CJ.nodePathToValue(CJ.findNode(CJ.parseSource(text).root, [key]), text);
    }
    for (const value of desired) {
      if (current.includes(value)) continue;
      doc = CJ.parseSource(text);
      node = CJ.findNode(doc.root, [key]);
      text = CJ.insertArrayItem(text, node, value, CJ.formatStyled);
      current = CJ.nodePathToValue(CJ.findNode(CJ.parseSource(text).root, [key]), text);
    }
  }
  return text;
}

function planManifest(load, project, writes) {
  const old = load.files.get('manifest.json');
  if (!old) throw new CliError('not_found', '模组根目录缺少 manifest.json');
  const oldText = fileText(load, 'manifest.json');
  const newText = patchManifestText(oldText, project.manifest);
  if (newText !== oldText) writes.set('manifest.json', { text: newText, detail: '更新 manifest 声明' });
}

/* ------------------------------------------------------------------ */
/* 外部命令                                                             */
/* ------------------------------------------------------------------ */

function runSyncCoreIndex(ctx) {
  const script = path.join(here, 'sync-core-index.mjs');
  const result = spawnSync(process.execPath, [script], { cwd: repoRoot, encoding: 'utf8' });
  if (result.error) return { ok: false, message: `无法运行 sync-core-index.mjs：${result.error.message}` };
  if (result.status !== 0) {
    const output = `${result.stderr || ''}${result.stdout || ''}`.trim();
    return { ok: false, message: `sync-core-index.mjs 失败（退出码 ${result.status}）${output ? `：${output.split('\n').slice(-3).join(' / ')}` : ''}` };
  }
  ctx.notes.push('已运行 sync-core-index.mjs 更新 Core 索引');
  return { ok: true };
}

function runNodeTests(ctx) {
  const script = path.join(SNMODMAKER, 'tests', 'run-tests.js');
  const result = spawnSync(process.execPath, [script], { cwd: repoRoot, encoding: 'utf8' });
  if (result.error) return { ok: false, message: `无法运行测试：${result.error.message}` };
  if (result.status !== 0) {
    const output = `${result.stderr || ''}${result.stdout || ''}`.trim();
    return { ok: false, message: `Node 测试失败（退出码 ${result.status}）${output ? `：${output.split('\n').slice(-5).join(' / ')}` : ''}` };
  }
  ctx.notes.push('Node 测试通过');
  return { ok: true };
}

/* ------------------------------------------------------------------ */
/* 写命令的公共收尾                                                     */
/* ------------------------------------------------------------------ */

function finalizeWrite(ctx, options) {
  const {
    command, load, project, baseline, after, newIssues, writes, deletes, title,
  } = options;
  const force = flagTrue(ctx, 'force');
  const dryRun = flagTrue(ctx, 'dry-run');
  const hasNewErrors = newIssues.some((issue) => issue.severity === 'error');
  const blocked = hasNewErrors && !force;
  const wouldWrite = dryRun || blocked;
  const changes = collectChanges(load, writes, deletes, wouldWrite);
  let wrote = false;
  if (!blocked && !dryRun) {
    commitChanges(load, writes, deletes);
    wrote = changes.length > 0;
  }

  let syncFailure = null;
  if (flagTrue(ctx, 'sync')) {
    if (wouldWrite || !wrote) {
      ctx.notes.push('--sync 未执行：没有真实写入');
    } else if (project.manifest.id !== 'core') {
      ctx.notes.push('--sync 已忽略：只有 core 模组需要重新生成索引');
    } else {
      const result = runSyncCoreIndex(ctx);
      if (!result.ok) syncFailure = result.message;
    }
  }
  let testFailure = null;
  if (flagTrue(ctx, 'test')) {
    if (!wrote) {
      ctx.notes.push('--test 未执行：没有真实写入');
    } else {
      const result = runNodeTests(ctx);
      if (!result.ok) testFailure = result.message;
    }
  }

  let error = null;
  if (blocked) {
    error = {
      code: 'validation',
      message: `新增 ${newIssues.filter((issue) => issue.severity === 'error').length} 个校验错误，未写入任何文件；如确认要写入请加 --force`,
    };
  } else if (hasNewErrors) {
    error = { code: 'validation', message: `已写入，但新增 ${newIssues.filter((issue) => issue.severity === 'error').length} 个校验错误` };
  } else if (syncFailure) {
    error = { code: 'sync', message: syncFailure };
  } else if (testFailure) {
    error = { code: 'test', message: testFailure };
  }

  const payload = {
    ok: !error,
    command,
    mod: ctx.modArg,
    changes: stripChanges(changes),
    issues: issueSummary(after, newIssues),
    stats: buildStats(project),
    notes: ctx.notes,
  };
  if (error) payload.error = error;

  const summary = `${title}\n${changeLines(changes)}${changes.length ? '\n' : ''}`
    + `validate: ${after.counts.error} errors / ${after.counts.warning} warnings `
    + `(new: ${payload.issues.newErrors} / ${payload.issues.newWarnings})\n`
    + `stats: definitions ${payload.stats.definitions} · contentFiles ${payload.stats.contentFiles} · locales ${payload.stats.locales}`;
  if (error) process.stderr.write(`错误（${error.code}）：${error.message}\n`);
  return respond(ctx, payload, summary, error ? 1 : 0);
}

/* ------------------------------------------------------------------ */
/* 数据 / 路径解析                                                      */
/* ------------------------------------------------------------------ */

function parseDataPath(input) {
  const text = String(input == null ? '' : input).trim();
  if (!text) throw usageError('路径不能为空');
  if (text.startsWith('/')) {
    return text.slice(1).split('/').map((raw) => {
      const unescaped = raw.replace(/~1/g, '/').replace(/~0/g, '~');
      return /^\d+$/.test(unescaped) ? Number(unescaped) : unescaped;
    });
  }
  const segments = [];
  let buffer = '';
  let index = 0;
  const push = () => {
    if (buffer) {
      segments.push(buffer);
      buffer = '';
    }
  };
  while (index < text.length) {
    const char = text[index];
    if (char === '.') {
      push();
      index += 1;
      continue;
    }
    if (char === '[') {
      push();
      const end = text.indexOf(']', index);
      if (end < 0) throw usageError(`路径中的 [ 没有闭合：${input}`);
      const inner = text.slice(index + 1, end).trim();
      if (/^\d+$/.test(inner)) segments.push(Number(inner));
      else if (/^".*"$/.test(inner)) segments.push(JSON.parse(inner));
      else if (inner) segments.push(inner);
      else throw usageError(`路径中的 [] 不能为空：${input}`);
      index = end + 1;
      continue;
    }
    buffer += char;
    index += 1;
  }
  push();
  if (!segments.length) throw usageError(`路径无效：${input}`);
  return segments;
}

function resolveTokenFile(reference) {
  const clean = String(reference || '').trim();
  if (!clean) throw usageError('@file 后缺少文件路径');
  const candidates = [clean];
  if (!path.isAbsolute(clean)) candidates.push(path.resolve(process.cwd(), clean), path.resolve(repoRoot, clean));
  for (const candidate of candidates) {
    const absolute = path.resolve(candidate);
    if (fs.existsSync(absolute) && fs.statSync(absolute).isFile()) return absolute;
  }
  throw usageError(`@file 指向的文件不存在：${clean}`);
}

function readTextFile(reference) {
  const text = fs.readFileSync(resolveTokenFile(reference), 'utf8');
  return text.charCodeAt(0) === 0xfeff ? text.slice(1) : text;
}

/** 解析 --data / --data-json / set 的值：布尔、null、数字、JSON、@file、字符串。 */
function parseValueToken(raw) {
  const text = String(raw == null ? '' : raw);
  if (text.startsWith('@')) {
    const content = readTextFile(text.slice(1)).trim();
    try {
      return JSON.parse(content);
    } catch (error) {
      return content;
    }
  }
  if (text === 'true') return true;
  if (text === 'false') return false;
  if (text === 'null') return null;
  if (/^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$/.test(text)) return Number(text);
  const head = text[0];
  if (head === '{' || head === '[' || head === '"') {
    try {
      return JSON.parse(text);
    } catch (error) {
      throw usageError(`值不是合法 JSON：${text}（${error.message}）`);
    }
  }
  return text;
}

function parseJsonOrFile(raw, label) {
  const text = String(raw);
  const content = text.startsWith('@') ? readTextFile(text.slice(1)) : text;
  try {
    return JSON.parse(content);
  } catch (error) {
    throw usageError(`${label} 不是合法 JSON：${error.message}`);
  }
}

function parseAssignmentSpec(raw) {
  const text = String(raw);
  const equal = text.indexOf('=');
  if (equal < 0) throw usageError(`赋值表达式缺少 =：${text}`);
  let operator = '=';
  let pathText = text.slice(0, equal);
  if (pathText.endsWith('+')) {
    operator = '+=';
    pathText = pathText.slice(0, -1);
  } else if (pathText.endsWith('-')) {
    operator = '-=';
    pathText = pathText.slice(0, -1);
  }
  if (!pathText) throw usageError(`赋值表达式缺少路径：${text}`);
  return {
    op: operator,
    path: parseDataPath(pathText),
    value: parseValueToken(text.slice(equal + 1)),
    source: text,
  };
}

function setByPath(target, pathSegments, value) {
  if (!pathSegments.length) throw new Error('设置路径为空');
  let cursor = target;
  for (let i = 0; i < pathSegments.length - 1; i += 1) {
    const segment = pathSegments[i];
    const nextSegment = pathSegments[i + 1];
    if (cursor[segment] == null || typeof cursor[segment] !== 'object') {
      cursor[segment] = typeof nextSegment === 'number' ? [] : {};
    }
    cursor = cursor[segment];
  }
  cursor[pathSegments[pathSegments.length - 1]] = value;
}

function getByPath(target, pathSegments) {
  let cursor = target;
  for (const segment of pathSegments) {
    if (cursor == null || typeof cursor !== 'object') return undefined;
    cursor = cursor[segment];
  }
  return cursor;
}

function deepMerge(base, extra) {
  if (isPlainObject(base) && isPlainObject(extra)) {
    const merged = deepClone(base);
    for (const [key, value] of Object.entries(extra)) {
      merged[key] = key in merged ? deepMerge(merged[key], value) : deepClone(value);
    }
    return merged;
  }
  return deepClone(extra);
}

/* C1 modules: the requested category drives the default data block and tag. */
const MODULE_CATEGORY_VALUES = ['boiler', 'cargo', 'utility', 'cabin', 'crew'];

function requestedModuleCategory(ctx) {
  for (const spec of flagValues(ctx, 'data')) {
    const equal = spec.indexOf('=');
    if (equal < 0) continue;
    const pathText = spec.slice(0, equal).trim().replace(/^data\./, '').replace(/^\/?data\//, '').replace(/^\//, '');
    if (pathText !== 'v2_category') continue;
    const raw = spec.slice(equal + 1).trim().replace(/^['"]|['"]$/g, '');
    if (MODULE_CATEGORY_VALUES.includes(raw)) return raw;
  }
  const dataJson = flagValue(ctx, 'data-json');
  if (dataJson !== undefined) {
    try {
      const parsed = parseJsonOrFile(dataJson, '--data-json');
      if (isPlainObject(parsed) && MODULE_CATEGORY_VALUES.includes(parsed.v2_category)) return parsed.v2_category;
    } catch (error) {
      /* buildData reports the JSON error with the proper CLI message. */
    }
  }
  return '';
}

function buildData(typeKey, ctx) {
  const defaults = Catalog.DEFAULTS[typeKey];
  let data;
  if (!defaults) data = {};
  else if (typeKey === 'modules') data = defaults({ v2_category: requestedModuleCategory(ctx) });
  else data = defaults();
  const dataJson = flagValue(ctx, 'data-json');
  if (dataJson !== undefined) {
    const parsed = parseJsonOrFile(dataJson, '--data-json');
    if (!isPlainObject(parsed)) throw usageError('--data-json 必须是 JSON 对象');
    data = deepMerge(data, parsed);
  }
  for (const spec of flagValues(ctx, 'data')) {
    const equal = spec.indexOf('=');
    if (equal < 0) throw usageError(`--data 需要 <path>=<value> 形式：${spec}`);
    let pathSegments = parseDataPath(spec.slice(0, equal));
    const value = parseValueToken(spec.slice(equal + 1));
    if (pathSegments[0] === 'data') pathSegments = pathSegments.slice(1);
    if (!pathSegments.length) throw usageError(`--data 路径不能只指向 data：${spec}`);
    setByPath(data, pathSegments, value);
  }
  return data;
}

function findLocalIdConflict(project, info, localId, exclude) {
  for (const item of Store.allDefinitions(project)) {
    if (exclude && item.definition === exclude) continue;
    const itemInfo = findTypeInfo(item.file.content_type);
    if (item.file.content_type !== info.key && (!itemInfo || itemInfo.keyPrefix !== info.keyPrefix)) continue;
    if (typeof item.definition.id === 'string' && Store.localPart(item.definition.id) === localId) return item;
  }
  return null;
}

function validateLocalId(localId) {
  if (!/^[a-z0-9][a-z0-9_]*$/.test(localId)) {
    throw usageError(`--id 必须是 /^[a-z0-9][a-z0-9_]*$/（小写字母/数字/下划线，数字不能开头）：${localId}`);
  }
  if (localId.length > 40) throw usageError(`--id 长度不能超过 40：${localId}`);
}

function collectStrings(value, output, depth = 0) {
  if (depth > 24 || value == null) return output;
  if (typeof value === 'string') {
    output.add(value);
    return output;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectStrings(item, output, depth + 1);
    return output;
  }
  if (typeof value === 'object') {
    for (const child of Object.values(value)) collectStrings(child, output, depth + 1);
  }
  return output;
}

/* ------------------------------------------------------------------ */
/* set：把赋值同时应用到内存模型与源文本                                 */
/* ------------------------------------------------------------------ */

function applyValueAssignment(definition, assignment) {
  const { op, path: pathSegments, value } = assignment;
  if (op === '=') {
    setByPath(definition, pathSegments, value);
    return { changed: true };
  }
  const current = getByPath(definition, pathSegments);
  if (op === '+=') {
    if (current === undefined) {
      setByPath(definition, pathSegments, [value]);
      return { changed: true };
    }
    if (!Array.isArray(current)) {
      throw new CliError('invalid', `路径 ${assignment.source.split('=')[0]} 当前不是数组，不能使用 +=`);
    }
    current.push(value);
    return { changed: true };
  }
  if (op === '-=') {
    if (!Array.isArray(current)) {
      throw new CliError('invalid', `路径 ${assignment.source.split('=')[0]} 当前不是数组，不能使用 -=`);
    }
    const index = current.findIndex((item) => jsonEqual(item, value));
    if (index < 0) return { changed: false, note: `未找到可删除的数组项：${JSON.stringify(value)}` };
    current.splice(index, 1);
    return { changed: true };
  }
  throw new CliError('internal', `未知赋值操作：${op}`);
}

function nestValue(segments, value) {
  let output = value;
  for (let i = segments.length - 1; i >= 0; i -= 1) {
    const segment = segments[i];
    if (typeof segment === 'number') {
      const array = new Array(segment + 1).fill(null);
      array[segment] = output;
      output = array;
    } else {
      output = { [segment]: output };
    }
  }
  return output;
}

/** 在文本里给缺失路径补值：找最深的已存在父节点，插入成员/数组项。 */
function insertValueAtPath(text, rootNode, pathSegments, value) {
  let node = rootNode;
  let depth = 0;
  while (depth < pathSegments.length) {
    const next = CJ.findNode(node, [pathSegments[depth]]);
    if (!next) break;
    node = next;
    depth += 1;
  }
  if (depth === pathSegments.length) throw new CliError('internal', '路径实际存在，无法走插入分支');
  const rest = pathSegments.slice(depth);
  const head = rest[0];
  if (node.type === 'object') {
    if (typeof head !== 'string') throw usageError('对象内部路径段必须是字符串');
    const nested = rest.length > 1 ? nestValue(rest.slice(1), value) : value;
    return CJ.insertObjectMember(text, node, head, nested, CJ.formatStyled);
  }
  if (node.type === 'array') {
    if (typeof head !== 'number') throw usageError('数组内部路径段必须是数字下标');
    if (head < node.items.length) {
      // 已存在但 findNode 找不到说明是空洞（null 占位），按替换处理。
      return CJ.replaceNodeValue(text, node.items[head], nestValue(rest.slice(1), value), CJ.formatStyled);
    }
    if (head !== node.items.length) {
      throw new CliError('invalid', `数组下标必须连续，当前长度 ${node.items.length}，目标下标 ${head}`);
    }
    const nested = rest.length > 1 ? nestValue(rest.slice(1), value) : value;
    return CJ.insertArrayItem(text, node, nested, CJ.formatStyled);
  }
  throw new CliError('invalid', '目标路径的父节点不是对象或数组');
}

function applyAssignmentToText(text, definitionNode, assignment) {
  const { op, path: pathSegments, value } = assignment;
  const node = CJ.findNode(definitionNode, pathSegments);
  if (op === '=') {
    if (node) return CJ.replaceNodeValue(text, node, value, CJ.formatStyled);
    return insertValueAtPath(text, definitionNode, pathSegments, value);
  }
  if (op === '+=') {
    if (node) {
      if (node.type === 'array') return CJ.insertArrayItem(text, node, value, CJ.formatStyled);
      throw new CliError('invalid', `路径 ${assignment.source.split('=')[0]} 当前不是数组，不能使用 +=`);
    }
    return insertValueAtPath(text, definitionNode, pathSegments, [value]);
  }
  if (op === '-=') {
    if (!node) return text;
    if (node.type !== 'array') {
      throw new CliError('invalid', `路径 ${assignment.source.split('=')[0]} 当前不是数组，不能使用 -=`);
    }
    const current = CJ.nodePathToValue(node, text);
    const index = current.findIndex((item) => jsonEqual(item, value));
    if (index < 0) return text;
    return CJ.removeArrayItem(text, node, index);
  }
  throw new CliError('internal', `未知赋值操作：${op}`);
}

function editDefinitionText(load, file, index, assignments, expectedDefinitions) {
  const oldText = fileText(load, file.path);
  let text = oldText;
  for (const assignment of assignments) {
    const doc = CJ.parseSource(text);
    const definitions = CJ.findNode(doc.root, ['definitions']);
    if (!definitions || definitions.type !== 'array' || !definitions.items[index]) {
      throw new CliError('internal', `${file.path} 中找不到第 ${index + 1} 个定义`);
    }
    const definitionNode = definitions.items[index];
    text = applyAssignmentToText(text, definitionNode, assignment);
  }
  const expected = {
    schema_version: schemaVersionFor(file),
    content_type: file.content_type,
    definitions: expectedDefinitions,
  };
  let parsed = null;
  try {
    parsed = JSON.parse(text);
  } catch (error) {
    parsed = null;
  }
  if (!jsonEqual(parsed, expected)) {
    // 兜底：保源替换整个定义节点（仍只改目标定义的字节）。
    const doc = CJ.parseSource(oldText);
    const definitions = CJ.findNode(doc.root, ['definitions']);
    const definitionNode = definitions && definitions.items[index];
    if (!definitionNode || !expectedDefinitions[index]) {
      throw new CliError('internal', `无法在 ${file.path} 中定位第 ${index + 1} 个定义`);
    }
    text = CJ.replaceNodeValue(oldText, definitionNode, expectedDefinitions[index], CJ.formatStyled);
    try {
      parsed = JSON.parse(text);
    } catch (error) {
      throw new CliError('internal', `保源写入后 ${file.path} 不是合法 JSON：${error.message}`);
    }
    if (!jsonEqual(parsed, expected)) {
      throw new CliError('internal', `保源写入结果与内存模型不一致：${file.path}`);
    }
  }
  return text;
}

/* ------------------------------------------------------------------ */
/* describe：从 Schema 推导字段表                                       */
/* ------------------------------------------------------------------ */

function describeFields(info) {
  const schemaFile = info.schema;
  const schema = globalThis.SN_SCHEMAS[schemaFile];
  const rows = [];
  if (!schema) return rows;
  const definitionsSchema = schema.properties && schema.properties.definitions;
  const itemsSchema = definitionsSchema && definitionsSchema.items;

  /**
   * 合并对象 Schema 的 allOf / $ref，同时保留每个属性所属的 Schema 文件，
   * 否则跨文件 $ref（common.schema.json）会被当成当前文件的本地引用。
   */
  function collectObject(node, file) {
    const resolved = Validate.deref(node, file);
    const target = resolved.schema || {};
    const currentFile = resolved.file || file;
    const properties = new Map();
    const required = new Set();
    const branches = Array.isArray(target.allOf) ? target.allOf : [target];
    for (const branch of branches) {
      const sub = Validate.deref(branch, currentFile);
      const subSchema = sub.schema || {};
      const subFile = sub.file || currentFile;
      if (Array.isArray(subSchema.allOf)) {
        const nested = collectObject(subSchema, subFile);
        for (const [key, value] of nested.properties) properties.set(key, value);
        for (const key of nested.required) required.add(key);
        continue;
      }
      for (const [key, value] of Object.entries(subSchema.properties || {})) {
        properties.set(key, { node: value, file: subFile });
      }
      for (const key of subSchema.required || []) required.add(key);
    }
    return { target, file: currentFile, properties, required };
  }

  const constraintKeys = ['enum', 'const', 'pattern', 'minimum', 'maximum', 'minLength',
    'maxLength', 'minItems', 'maxItems', 'uniqueItems'];

  function inferType(target, raw) {
    if (target.type) return target.type;
    if (raw.type) return raw.type;
    if (raw.const !== undefined) {
      if (raw.const === null) return 'null';
      if (typeof raw.const === 'number') return Number.isInteger(raw.const) ? 'integer' : 'number';
      if (typeof raw.const === 'string') return 'string';
      return typeof raw.const;
    }
    if (Array.isArray(raw.enum) && raw.enum.length) {
      const kinds = [...new Set(raw.enum.map((value) => {
        if (value === null) return 'null';
        if (typeof value === 'number') return Number.isInteger(value) ? 'integer' : 'number';
        return typeof value;
      }))];
      return kinds.length === 1 ? kinds[0] : kinds.join('|');
    }
    if (target.properties || target.allOf) return 'object';
    if (target.items) return 'array';
    if (typeof raw.$ref === 'string') return 'object';
    return 'any';
  }

  function expand(pathText, node, isRequired, file, depth) {
    const resolved = Validate.deref(node, file);
    const target = resolved.schema || {};
    const resolvedFile = resolved.file || file;
    const raw = node && typeof node === 'object' ? node : {};
    const type = inferType(target, raw);
    const row = { path: pathText, type, required: Boolean(isRequired) };
    if (raw.$ref) row.$ref = raw.$ref;
    for (const key of constraintKeys) {
      if (raw[key] !== undefined) row[key] = raw[key];
      else if (target[key] !== undefined) row[key] = target[key];
    }
    rows.push(row);
    if (depth >= 4) return;
    if (target.properties || target.allOf) {
      const objectSchema = collectObject(target, resolvedFile);
      for (const [childName, child] of objectSchema.properties) {
        expand(`${pathText}.${childName}`, child.node, objectSchema.required.has(childName), child.file, depth + 1);
      }
      return;
    }
    if (target.type === 'array' && target.items && !Array.isArray(target.items)) {
      const itemResolved = Validate.deref(target.items, resolvedFile);
      const itemTarget = itemResolved.schema || {};
      const itemIsObject = itemTarget.type === 'object' || itemTarget.properties || itemTarget.allOf;
      if (itemIsObject || itemTarget.type === 'array') {
        expand(`${pathText}[]`, target.items, false, resolvedFile, depth + 1);
      }
    }
  }

  const rootObject = collectObject(itemsSchema, schemaFile);
  for (const [name, child] of rootObject.properties) {
    expand(name, child.node, rootObject.required.has(name), child.file, 1);
  }
  return rows;
}

function describePayload(typeKey) {
  const info = findTypeInfo(typeKey);
  const defaults = Catalog.DEFAULTS[typeKey];
  const defaultsValue = defaults ? defaults() : null;
  const keyPrefix = info.keyPrefix;
  const baseKey = `${keyPrefix}.my_mod.tea`;
  let skeleton;
  if (info.key === 'patches') {
    skeleton = {
      target: 'core:module/small_efficient',
      requires: { mod: 'core', version: '>=1.0.0 <2.0.0' },
      operations: [{ op: 'replace', path: '/data/purchase_price', value: 380 }],
    };
  } else {
    skeleton = {
      id: `my_mod:${info.singular}/tea`,
      name_key: `${baseKey}.name`,
      description_key: `${baseKey}.description`,
      tags: [(Catalog.TAG_SUGGESTIONS[typeKey] || [])[0] || `${info.singular}.custom`],
      enabled: true,
      data: deepClone(defaultsValue),
    };
  }
  const typeRow = {
    key: info.key,
    singular: info.singular,
    keyPrefix: info.keyPrefix,
    label: info.label,
    file: info.file,
    schema: info.schema,
    schema_version: schemaVersionFor(info.key),
  };
  if (info.special) typeRow.special = true;
  if (info.draft) typeRow.draft = true;
  if (info.capability) typeRow.capability = info.capability;
  return {
    ok: true,
    command: 'describe',
    type: typeRow,
    id: {
      // 正则字面量会把 / 转义成 \/，输出契约要求未转义的 JSON Schema pattern。
      pattern: Validate.ID_REF_RE.source.replace(/\\\//g, '/'),
      singular: info.singular,
      example: `my_mod:${info.singular}/tea`,
    },
    keys: {
      base: baseKey,
      name: `${baseKey}.name`,
      description: `${baseKey}.description`,
    },
    fields: describeFields(info),
    defaults: deepClone(defaultsValue),
    suggestions: { tags: (Catalog.TAG_SUGGESTIONS[typeKey] || []).slice() },
    skeleton,
  };
}

/* ------------------------------------------------------------------ */
/* 命令实现                                                             */
/* ------------------------------------------------------------------ */

function commandTypes(ctx) {
  const types = allTypeInfos().map((type) => {
    const row = {
      key: type.key,
      singular: type.singular,
      keyPrefix: type.keyPrefix,
      label: type.label,
      en: type.en,
      file: type.file,
      schema: type.schema,
      group: type.group,
      summary: type.summary,
      schema_version: schemaVersionFor(type.key),
    };
    if (type.special) row.special = true;
    if (type.draft) row.draft = true;
    if (type.capability) row.capability = type.capability;
    return row;
  });
  const active = types.filter((type) => !type.draft);
  const drafts = types.filter((type) => type.draft);
  const runtimeV2 = active.filter((type) => type.schema_version === '2.0');
  const payload = { ok: true, command: 'types', types, activeTypes: active.length, draftTypes: drafts.length };
  if (ctx.json) return respond(ctx, payload, '', 0);
  const width = Math.max(...types.map((type) => type.key.length));
  const formatRow = (type) => {
    let marker = '';
    if (type.draft) marker = `  [draft ${type.schema_version}]`;
    else if (type.schema_version === '2.0') marker = `  [runtime ${type.schema_version}]`;
    return `${type.key.padEnd(width)}  ${type.label.padEnd(8)} ${type.singular.padEnd(20)} ${type.file}${marker}`;
  };
  const lines = [
    `运行时内容类型（${active.length}；其中 ${runtimeV2.length} 类为运行时 Schema 2.0）：`,
    ...active.map(formatRow),
  ];
  if (drafts.length) {
    lines.push(
      '',
      `Schema 2.0 草案类型（${drafts.length}）：编辑器 / CLI 可编辑，游戏运行时不加载`,
      ...drafts.map(formatRow),
    );
  }
  return respond(ctx, payload, lines.join('\n'), 0);
}

function commandDescribe(ctx) {
  const typeKey = ctx.positional[1];
  if (!typeKey) throw usageError('缺少 <type>，例如 describe items');
  const info = findTypeInfo(typeKey);
  if (!info) {
    throw usageError(`未知内容类型 "${typeKey}"。可用类型：${knownTypeKeys().join(', ')}`);
  }
  const payload = describePayload(typeKey);
  const fieldLines = payload.fields.map((field) => {
    const constraints = ['enum', 'const', 'pattern', 'minimum', 'maximum', 'minLength', 'maxLength',
      'minItems', 'maxItems', 'uniqueItems'].filter((key) => field[key] !== undefined)
      .map((key) => `${key}=${JSON.stringify(field[key])}`);
    return `  ${field.path.padEnd(36)} ${String(field.type).padEnd(9)} ${field.required ? 'required' : '        '} ${constraints.join(' ')}`;
  });
  const version = payload.type.schema_version;
  const capabilityNote = payload.type.capability ? `，capability ${payload.type.capability}` : '';
  const subtitle = info.draft
    ? `  草案 Schema ${version}（游戏运行时不加载${capabilityNote}）`
    : (version === '2.0' ? `  运行时 Schema ${version}（已接入运行时${capabilityNote}）` : '');
  const human = [
    `类型：${info.key}（${info.label}）  文件：${info.file}  Schema：${info.schema}${subtitle}`,
    `ID 模式：${payload.id.pattern}`,
    `键：${payload.keys.base}.name / ${payload.keys.base}.description`,
    `骨架：`,
    CJ.formatStyled(payload.skeleton, 0),
    '',
    `字段（${payload.fields.length}）：`,
    ...fieldLines,
  ].join('\n');
  return respond(ctx, payload, human, 0);
}

function commandList(ctx) {
  const modArg = requireFlag(ctx, 'mod', '松散模组根目录');
  const typeFilter = flagValue(ctx, 'type');
  if (typeFilter !== undefined && !findTypeInfo(typeFilter)) {
    throw usageError(`未知内容类型 "${typeFilter}"。可用类型：${knownTypeKeys().join(', ')}`);
  }
  const load = loadMod(ctx, modArg);
  const rows = [];
  for (const item of Store.allDefinitions(load.project)) {
    const typeKey = item.file.content_type;
    if (typeFilter && typeKey !== typeFilter) continue;
    const definition = item.definition;
    const row = {
      id: typeof definition.id === 'string' ? definition.id : '',
      type: typeKey,
      file: item.file.path,
      index: item.index,
      name_zh: Store.localizationValue(load.project, definition, 'name_key', 'zh_CN'),
      name_en: Store.localizationValue(load.project, definition, 'name_key', 'en'),
      enabled: definition.enabled !== false,
      keys: {
        name: definition.name_key || '',
        description: definition.description_key || '',
      },
    };
    if (typeKey === 'patches') row.target = definition.target || '';
    rows.push(row);
  }
  const payload = { ok: true, command: 'list', mod: modArg, count: rows.length, definitions: rows };
  if (ctx.json) return respond(ctx, payload, '', 0);
  const groups = new Map();
  for (const row of rows) {
    if (!groups.has(row.type)) groups.set(row.type, []);
    groups.get(row.type).push(row);
  }
  const lines = [];
  for (const [typeKey, groupRows] of groups) {
    const info = findTypeInfo(typeKey);
    lines.push(`[${typeKey}] ${info ? info.label : ''} (${groupRows.length})`);
    for (const row of groupRows) {
      const id = row.target ? `${row.id || '(patch)'} → ${row.target}` : row.id;
      const names = [row.name_zh, row.name_en].filter(Boolean).join(' / ');
      lines.push(`  ${id.padEnd(42)} ${names}${row.enabled ? '' : '  [disabled]'}`);
    }
  }
  return respond(ctx, payload, lines.join('\n'), 0);
}

function commandAdd(ctx) {
  const modArg = requireFlag(ctx, 'mod', '松散模组根目录');
  const typeKey = requireFlag(ctx, 'type');
  const info = findTypeInfo(typeKey);
  if (!info) throw usageError(`未知内容类型 "${typeKey}"。可用类型：${knownTypeKeys().join(', ')}`);
  const isPatch = typeKey === 'patches';
  const rawLocalId = flagValue(ctx, 'id');
  if (rawLocalId === undefined) {
    // patches 定义没有 id 字段，本地 ID 仅用于占位；标准定义仍强制要求。
    if (!isPatch) throw usageError('缺少 --id（本地 ID，不含模组命名空间）');
  } else {
    validateLocalId(rawLocalId);
  }
  let requestedLocalId = rawLocalId === undefined ? 'patch' : rawLocalId;
  const load = loadMod(ctx, modArg);
  const project = load.project;
  const baseline = Validate.validateProject(project);
  const modId = project.manifest.id;
  const namespace = flagValue(ctx, 'namespace');
  if (namespace !== undefined && namespace !== modId) {
    throw usageError(`--namespace 必须等于 manifest.id "${modId}"：${namespace}`);
  }
  if (!isPatch) {
    for (const name of ['target', 'requires-mod', 'requires-version', 'operations-json']) {
      if (ctx.flags.has(name)) throw usageError(`--${name} 仅用于 --type patches`);
    }
  }

  let nameZh;
  let nameEn;
  let descZh;
  let descEn;
  if (!isPatch) {
    nameZh = flagValue(ctx, 'name-zh');
    nameEn = flagValue(ctx, 'name-en');
    descZh = flagValue(ctx, 'desc-zh');
    descEn = flagValue(ctx, 'desc-en');
    if (nameZh === undefined || nameEn === undefined) {
      throw usageError('标准定义必须同时提供 --name-zh 与 --name-en（双语名称）');
    }
    if ((descZh === undefined) !== (descEn === undefined)) {
      throw usageError('--desc-zh 与 --desc-en 必须同时提供或同时省略');
    }
  } else if (flagValues(ctx, 'tag').length) {
    ctx.notes.push('patches 定义不使用 tags，--tag 已忽略');
  }

  let localId = requestedLocalId;
  const conflict = findLocalIdConflict(project, info, requestedLocalId);
  if (conflict) {
    if (flagTrue(ctx, 'suffix')) localId = Store.uniqueLocalId(project, typeKey, requestedLocalId);
    else throw new CliError('conflict', `本地 ID "${requestedLocalId}" 已存在于 ${info.keyPrefix} 域；可加 --suffix 自动生成新 ID`);
  }

  let tags = flagValues(ctx, 'tag');
  if (!isPatch && !tags.length) {
    if (typeKey === 'modules') {
      const category = requestedModuleCategory(ctx) || 'boiler';
      tags = [Catalog.MODULE_CATEGORY_TAGS[category] || 'module.boiler'];
    } else {
      tags = [(Catalog.TAG_SUGGESTIONS[typeKey] || [])[0] || `${info.singular}.custom`];
    }
  }
  const data = isPatch ? undefined : buildData(typeKey, ctx);

  let filePath = flagValue(ctx, 'file');
  if (filePath !== undefined) {
    validateContentFilePath(filePath);
    const existing = project.contentFiles.find((file) => file.path === filePath);
    if (existing && existing.content_type !== typeKey) {
      throw usageError(`--file ${filePath} 的 content_type 是 ${existing.content_type}，不能写入 ${typeKey}`);
    }
    if (!existing) {
      if (load.files.has(filePath)) {
        throw usageError(`--file ${filePath} 存在于磁盘但未被 manifest.content 声明，无法安全保源写入`);
      }
      project.contentFiles.push({ path: filePath, content_type: typeKey, schema_version: schemaVersionFor(typeKey), definitions: [] });
      Store.syncManifest(project);
    }
  }

  const result = Store.addDefinition(project, typeKey, {
    localId,
    nameZh,
    nameEn,
    descriptionZh: descZh,
    descriptionEn: descEn,
    tags,
    data,
    filePath,
    descriptionKey: descZh === undefined ? false : undefined,
  });

  if (isPatch) {
    const requiresMod = flagValue(ctx, 'requires-mod');
    const requiresVersion = flagValue(ctx, 'requires-version');
    if (requiresMod !== undefined) result.definition.requires.mod = requiresMod;
    if (requiresVersion !== undefined) result.definition.requires.version = requiresVersion;
    const operationsRaw = flagValue(ctx, 'operations-json');
    if (operationsRaw !== undefined) {
      const operations = parseJsonOrFile(operationsRaw, '--operations-json');
      if (!Array.isArray(operations)) throw usageError('--operations-json 必须是 JSON 数组');
      result.definition.operations = operations;
    }
  }

  const after = Validate.validateProject(project);
  const newIssues = newIssuesBetween(baseline, after);
  const writes = new Map();
  const deletes = new Map();
  const detail = isPatch ? '+1 patch' : '+1 definition';
  planAppendDefinition(load, project, result.file, result.definition, result.index, writes, detail);
  if (!isPatch) planLocaleChanges(load, project, writes, ['zh_CN', 'en']);
  planManifest(load, project, writes);
  const label = isPatch ? `patch → ${result.definition.target}` : result.definition.id;
  return finalizeWrite(ctx, {
    command: 'add',
    load,
    project,
    baseline,
    after,
    newIssues,
    writes,
    deletes,
    title: `add ${info.key} ${label}`,
  });
}

function commandSet(ctx) {
  const modArg = requireFlag(ctx, 'mod', '松散模组根目录');
  const definitionId = ctx.positional[1];
  if (!definitionId) throw usageError('缺少 <definition-id>');
  const rawAssignments = ctx.positional.slice(2);
  if (!rawAssignments.length) throw usageError('缺少赋值表达式，例如 data.base_price=123');
  const assignments = rawAssignments.map(parseAssignmentSpec);
  for (const assignment of assignments) {
    const last = assignment.path[assignment.path.length - 1];
    if (typeof last === 'string' && last.endsWith('_key')) {
      throw usageError(`禁止用 set 修改本地化键字段 "${last}"；请使用 loc 命令`);
    }
  }
  const load = loadMod(ctx, modArg);
  const project = load.project;
  const baseline = Validate.validateProject(project);
  const found = Store.allDefinitions(project).find((item) => item.definition && item.definition.id === definitionId);
  if (!found) throw new CliError('not_found', `找不到定义 ${definitionId}`);

  const working = Store.deepClone(found.definition);
  for (const assignment of assignments) {
    const outcome = applyValueAssignment(working, assignment);
    if (outcome.note) ctx.notes.push(outcome.note);
  }
  found.file.definitions[found.index] = working;

  const after = Validate.validateProject(project);
  const newIssues = newIssuesBetween(baseline, after);
  const writes = new Map();
  const deletes = new Map();
  const old = load.files.get(found.file.path);
  let text;
  if (old) {
    text = editDefinitionText(load, found.file, found.index, assignments, found.file.definitions);
  } else {
    const payload = {
      schema_version: schemaVersionFor(found.file),
      content_type: found.file.content_type,
      definitions: found.file.definitions,
    };
    text = `${JSON.stringify(payload, null, 2)}\n`;
  }
  writes.set(found.file.path, { text, detail: '修改 1 个定义' });
  return finalizeWrite(ctx, {
    command: 'set',
    load,
    project,
    baseline,
    after,
    newIssues,
    writes,
    deletes,
    title: `set ${definitionId}`,
  });
}

function commandLoc(ctx) {
  const modArg = requireFlag(ctx, 'mod', '松散模组根目录');
  const load = loadMod(ctx, modArg);
  const project = load.project;
  const baseline = Validate.validateProject(project);
  const keyFlag = flagValue(ctx, 'key');
  let locales;
  let title;
  if (keyFlag !== undefined) {
    const locale = requireFlag(ctx, 'locale');
    const text = flagValue(ctx, 'text');
    if (text === undefined) throw usageError('--key 形式需要 --text <text>');
    if (!/^[A-Za-z][A-Za-z0-9_]*$/.test(locale)) throw usageError(`locale 名无效：${locale}`);
    Store.setLocalization(project, locale, keyFlag, text);
    locales = [locale];
    title = `loc ${keyFlag} [${locale}]`;
  } else {
    const definitionId = ctx.positional[1];
    if (!definitionId) throw usageError('缺少 <definition-id>，或使用 --key 形式');
    const field = flagValue(ctx, 'field') || 'name';
    if (field !== 'name' && field !== 'description') throw usageError('--field 只能是 name 或 description');
    const zh = flagValue(ctx, 'zh');
    const en = flagValue(ctx, 'en');
    if (zh === undefined && en === undefined) throw usageError('至少提供 --zh 或 --en');
    const found = Store.allDefinitions(project).find((item) => item.definition && item.definition.id === definitionId);
    if (!found) throw new CliError('not_found', `找不到定义 ${definitionId}`);
    const key = field === 'name' ? found.definition.name_key : found.definition.description_key;
    if (!key) throw new CliError('not_found', `定义 ${definitionId} 没有 ${field === 'name' ? 'name_key' : 'description_key'}`);
    if (zh !== undefined) Store.setLocalization(project, 'zh_CN', key, zh);
    if (en !== undefined) Store.setLocalization(project, 'en', key, en);
    locales = ['zh_CN', 'en'];
    title = `loc ${definitionId}.${field}`;
  }
  const after = Validate.validateProject(project);
  const newIssues = newIssuesBetween(baseline, after);
  const writes = new Map();
  const deletes = new Map();
  planLocaleChanges(load, project, writes, locales);
  planManifest(load, project, writes);
  return finalizeWrite(ctx, {
    command: 'loc',
    load,
    project,
    baseline,
    after,
    newIssues,
    writes,
    deletes,
    title,
  });
}

function commandRm(ctx) {
  const modArg = requireFlag(ctx, 'mod', '松散模组根目录');
  if (!flagTrue(ctx, 'yes')) throw usageError('删除定义必须显式传 --yes（防误删）');
  const definitionId = ctx.positional[1];
  if (!definitionId) throw usageError('缺少 <definition-id>');
  const load = loadMod(ctx, modArg);
  const project = load.project;
  const baseline = Validate.validateProject(project);
  const found = Store.allDefinitions(project).find((item) => item.definition && item.definition.id === definitionId);
  if (!found) throw new CliError('not_found', `找不到定义 ${definitionId}`);
  const file = found.file;
  const index = found.index;
  const removedKeys = Store.collectDefinitionKeys(found.definition);
  const keepLoc = flagTrue(ctx, 'keep-loc');

  Store.removeDefinition(project, file.path, index);

  let removedLocKeys = 0;
  if (!keepLoc) {
    const retained = new Set();
    for (const item of Store.allDefinitions(project)) {
      for (const key of Store.collectDefinitionKeys(item.definition)) retained.add(key);
      collectStrings(item.definition, retained);
    }
    for (const entry of project.localization) {
      for (const key of removedKeys) {
        if (retained.has(key)) continue;
        if (Object.prototype.hasOwnProperty.call(entry.entries, key)) {
          delete entry.entries[key];
          removedLocKeys += 1;
        }
      }
    }
  }

  const after = Validate.validateProject(project);
  const newIssues = newIssuesBetween(baseline, after);
  const writes = new Map();
  const deletes = new Map();
  if (file.definitions.length > 0) {
    const oldText = fileText(load, file.path);
    const doc = CJ.parseSource(oldText);
    const definitions = CJ.findNode(doc.root, ['definitions']);
    if (!definitions || definitions.type !== 'array' || !definitions.items[index]) {
      throw new CliError('internal', `${file.path} 中找不到第 ${index + 1} 个定义`);
    }
    writes.set(file.path, {
      text: CJ.removeArrayItem(oldText, definitions, index),
      detail: '-1 definition',
    });
  } else {
    deletes.set(file.path, { detail: '内容文件已空，删除文件' });
  }
  if (!keepLoc) planLocaleChanges(load, project, writes, ['zh_CN', 'en']);
  planManifest(load, project, writes);
  if (removedLocKeys) ctx.notes.push(`删除专属本地化键 ${removedLocKeys} 个`);
  if (keepLoc) ctx.notes.push('--keep-loc：保留本地化键');
  return finalizeWrite(ctx, {
    command: 'rm',
    load,
    project,
    baseline,
    after,
    newIssues,
    writes,
    deletes,
    title: `rm ${definitionId}`,
  });
}

function commandClone(ctx) {
  const modArg = requireFlag(ctx, 'mod', '松散模组根目录');
  const fromId = requireFlag(ctx, 'from', 'Core 定义完整 ID');
  const load = loadMod(ctx, modArg);
  const project = load.project;
  const baseline = Validate.validateProject(project);
  const result = Store.cloneCoreDefinition(project, fromId);
  if (!result) throw new CliError('not_found', `Core 索引中找不到定义 ${fromId}`);
  const typeKey = result.file.content_type;
  const info = findTypeInfo(typeKey);
  if (!info) throw new CliError('internal', `Core 定义 ${fromId} 的类型 ${typeKey} 未注册`);
  const modId = project.manifest.id;
  const idFlag = flagValue(ctx, 'id');
  if (idFlag !== undefined) {
    validateLocalId(idFlag);
    let newLocal = idFlag;
    const conflict = findLocalIdConflict(project, info, newLocal, result.definition);
    if (conflict) {
      if (flagTrue(ctx, 'suffix')) newLocal = Store.uniqueLocalId(project, typeKey, newLocal);
      else throw new CliError('conflict', `本地 ID "${newLocal}" 已存在于 ${info.keyPrefix} 域；可加 --suffix 自动生成新 ID`);
    }
    const oldBase = Store.keyBaseOf(result.definition, typeKey, modId, result.localId);
    const newBase = Store.keyBase(typeKey, modId, newLocal);
    if (oldBase !== newBase) {
      try {
        Store.commitDefinitionLocalization(project, result.definition, typeKey, oldBase, newBase);
      } catch (error) {
        throw new CliError('conflict', error.message);
      }
    }
    result.definition.id = `${modId}:${info.singular}/${newLocal}`;
    result.localId = newLocal;
  }
  const nameKey = result.definition.name_key;
  const nameZh = flagValue(ctx, 'name-zh');
  const nameEn = flagValue(ctx, 'name-en');
  if (nameZh !== undefined) Store.setLocalization(project, 'zh_CN', nameKey, nameZh);
  if (nameEn !== undefined) Store.setLocalization(project, 'en', nameKey, nameEn);

  const after = Validate.validateProject(project);
  const newIssues = newIssuesBetween(baseline, after);
  const writes = new Map();
  const deletes = new Map();
  planAppendDefinition(load, project, result.file, result.definition, result.index, writes, '+1 definition');
  planLocaleChanges(load, project, writes, ['zh_CN', 'en']);
  planManifest(load, project, writes);
  return finalizeWrite(ctx, {
    command: 'clone',
    load,
    project,
    baseline,
    after,
    newIssues,
    writes,
    deletes,
    title: `clone ${fromId} → ${result.definition.id}`,
  });
}

function commandValidate(ctx) {
  const modArg = requireFlag(ctx, 'mod', '松散模组根目录');
  const load = loadMod(ctx, modArg);
  const result = Validate.validateProject(load.project);
  const issues = result.issues.map((issue) => {
    const row = { severity: issue.severity, code: issue.code, message: issue.message };
    if (issue.view) row.view = issue.view;
    return row;
  });
  const stats = {
    definitions: result.stats.definitions,
    contentFiles: result.stats.contentFiles,
    locales: result.stats.locales,
    assets: result.stats.assets,
  };
  let godotFailed = false;
  if (flagTrue(ctx, 'godot')) {
    const godotBin = process.env.GODOT_BIN;
    if (!godotBin) {
      ctx.notes.push('未设置 GODOT_BIN，已跳过 Godot 校验。');
    } else {
      const spawned = spawnSync(godotBin, [
        '--headless', '--path', repoRoot, '--script', 'res://sdk/validate.gd',
        '--', `--mod-root=${load.abs}`,
      ], { encoding: 'utf8', timeout: 180_000 });
      if (spawned.error) {
        godotFailed = true;
        ctx.notes.push(`Godot 校验无法执行：${spawned.error.message}`);
      } else {
        const output = `${spawned.stdout || ''}${spawned.stderr || ''}`.trim();
        ctx.notes.push(`Godot 校验退出码：${spawned.status}`);
        if (output) ctx.notes.push(...output.split('\n').slice(-20));
        if (spawned.status !== 0) godotFailed = true;
      }
    }
  }
  const errorCount = result.counts.error;
  const warningCount = result.counts.warning;
  const strictFailure = flagTrue(ctx, 'strict') && warningCount > 0;
  const failed = errorCount > 0 || strictFailure || godotFailed;
  const payload = {
    ok: !failed,
    command: 'validate',
    mod: modArg,
    issues: { errors: errorCount, warnings: warningCount, list: issues },
    stats,
    notes: ctx.notes,
  };
  if (failed) {
    payload.error = {
      code: 'validation',
      message: errorCount > 0
        ? `存在 ${errorCount} 个校验错误`
        : (strictFailure ? '--strict：存在警告' : 'Godot 校验失败'),
    };
  }
  if (ctx.json) return respond(ctx, payload, '', failed ? 1 : 0);
  const lines = result.issues.map((issue) => `[${issue.severity}] ${issue.code}: ${issue.message}`);
  lines.push(`validate: ${errorCount} errors / ${warningCount} warnings`);
  lines.push(`stats: definitions ${stats.definitions} · contentFiles ${stats.contentFiles} · locales ${stats.locales} · assets ${stats.assets}`);
  if (failed) process.stderr.write(`错误（${payload.error.code}）：${payload.error.message}\n`);
  return respond(ctx, payload, lines.join('\n'), failed ? 1 : 0);
}

function commandNew(ctx) {
  const modArg = requireFlag(ctx, 'mod', '目标模组目录');
  const modId = requireFlag(ctx, 'id', '模组 ID');
  const name = requireFlag(ctx, 'name', '模组显示名');
  if (!Validate.MOD_ID_RE.test(modId)) {
    throw usageError(`模组 ID 必须匹配 ${Validate.MOD_ID_RE.source}（小写字母开头，3–32 位）：${modId}`);
  }
  const draftKeys = flagValues(ctx, 'draft');
  for (const draftKey of draftKeys) {
    const info = draftTypes().find((item) => item.key === draftKey);
    if (!info) {
      throw usageError(`未知 Schema 2.0 草案类型 "${draftKey}"。可用：${draftTypes().map((item) => item.key).join(', ')}`);
    }
  }
  const explicitTemplate = flagValue(ctx, 'template');
  // 只指定 --draft 时创建纯 2.0 草案项目（不附带默认物品起始定义）。
  const template = explicitTemplate || (draftKeys.length ? null : 'items');
  if (template && !Catalog.TEMPLATES.some((item) => item.key === template)) {
    throw usageError(`未知模板 "${template}"。可用：${Catalog.TEMPLATES.map((item) => item.key).join(', ')}`);
  }
  const description = flagValue(ctx, 'description') || '';
  const authors = flagValues(ctx, 'author');
  const target = path.resolve(modArg);
  const force = flagTrue(ctx, 'force');
  const dryRun = flagTrue(ctx, 'dry-run');
  if (fs.existsSync(target)) {
    if (!fs.statSync(target).isDirectory()) throw new CliError('exists', `目标路径不是目录：${modArg}`);
    if (fs.readdirSync(target).length > 0 && !force) {
      throw new CliError('exists', `目标目录非空：${modArg}；如需覆盖请加 --force`);
    }
  }
  const project = Store.createProject({
    id: modId,
    name,
    template,
    drafts: draftKeys,
    description,
    authors: authors.length ? authors : undefined,
  });
  if (draftKeys.length) {
    ctx.notes.push(`Schema 2.0 草案项目：${draftKeys.join(', ')}（运行时不加载，capability 已写入 manifest）。`);
  }
  const exportFiles = Store.toExportFiles(project, { prefix: false });
  const contentPaths = new Set(project.contentFiles.map((file) => file.path));
  const changes = [];
  for (const file of exportFiles) {
    const relative = String(file.path);
    const absolute = resolveInside(target, relative);
    // 内容文件用与 add/set 插入一致的 formatStyled 规范化风格：
    // 纯标量数组保持单行，避免新模组里模板定义与后续新增定义风格不一致。
    const data = typeof file.data === 'string'
      ? (contentPaths.has(relative) ? `${CJ.formatStyled(JSON.parse(file.data), 0)}\n` : file.data)
      : file.data;
    const buffer = typeof data === 'string' ? Buffer.from(data, 'utf8') : Buffer.from(data);
    const exists = fs.existsSync(absolute);
    changes.push({
      path: relative,
      action: dryRun ? 'would-create' : (exists ? 'update' : 'create'),
      bytes: buffer.length,
      diff: unifiedDiff(exists ? fs.readFileSync(absolute, 'utf8') : '', buffer.toString('utf8')),
      detail: '新建',
    });
    if (!dryRun) atomicWrite(absolute, buffer);
  }
  let after;
  let verificationProject = project;
  if (dryRun) {
    after = Validate.validateProject(project);
  } else {
    const reloaded = loadMod(ctx, modArg);
    verificationProject = reloaded.project;
    after = Validate.validateProject(verificationProject);
  }
  const newIssues = after.issues;
  const errorCount = after.counts.error;
  const error = errorCount > 0 ? { code: 'validation', message: `新模组存在 ${errorCount} 个校验错误` } : null;
  const payload = {
    ok: !error,
    command: 'new',
    mod: modArg,
    changes: stripChanges(changes),
    issues: issueSummary(after, newIssues),
    stats: buildStats(verificationProject),
    notes: ctx.notes,
  };
  if (error) payload.error = error;
  if (!dryRun) ctx.notes.push(`已写入 ${changes.length} 个文件`);
  const summary = `new ${modId} → ${modArg}\n${changeLines(changes)}\n`
    + `validate: ${after.counts.error} errors / ${after.counts.warning} warnings`;
  if (error) process.stderr.write(`错误（${error.code}）：${error.message}\n`);
  return respond(ctx, payload, summary, error ? 1 : 0);
}

/* ------------------------------------------------------------------ */
/* 入口                                                                 */
/* ------------------------------------------------------------------ */

const COMMANDS = {
  types: commandTypes,
  describe: commandDescribe,
  list: commandList,
  add: commandAdd,
  set: commandSet,
  loc: commandLoc,
  rm: commandRm,
  clone: commandClone,
  validate: commandValidate,
  new: commandNew,
};

function handleError(ctx, error) {
  if (error instanceof CliError) {
    if (ctx.json) {
      printJson({ ok: false, command: ctx.command || null, error: { code: error.code, message: error.message } });
    } else {
      process.stderr.write(`错误（${error.code}）：${error.message}\n`);
    }
    return error.exitCode;
  }
  const message = error && error.message ? error.message : String(error);
  if (ctx.json) {
    printJson({ ok: false, command: ctx.command || null, error: { code: 'internal', message } });
  } else {
    process.stderr.write(`内部错误：${message}\n${error && error.stack ? `${error.stack}\n` : ''}`);
  }
  return 1;
}

async function main(argv) {
  const parsed = parseArgv(argv);
  const ctx = {
    flags: parsed.flags,
    positional: parsed.positional,
    command: parsed.positional[0] || '',
    json: false,
    quiet: false,
    notes: [],
    modArg: undefined,
  };
  ctx.json = flagTrue(ctx, 'json');
  ctx.quiet = flagTrue(ctx, 'quiet');
  ctx.modArg = flagValue(ctx, 'mod');
  if (flagTrue(ctx, 'help')) {
    process.stdout.write(USAGE);
    return 0;
  }
  if (!ctx.command) {
    if (!ctx.json) process.stderr.write(USAGE);
    return handleError(ctx, usageError('缺少命令；用 --help 查看用法'));
  }
  const command = COMMANDS[ctx.command];
  if (!command) {
    return handleError(ctx, usageError(`未知命令 "${ctx.command}"；可用命令：${Object.keys(COMMANDS).join(', ')}`));
  }
  try {
    return await command(ctx);
  } catch (error) {
    return handleError(ctx, error);
  }
}

const invokedDirectly = (() => {
  if (!process.argv[1]) return false;
  try {
    return path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
  } catch (error) {
    return false;
  }
})();

if (invokedDirectly) {
  main(process.argv.slice(2)).then((code) => {
    process.exitCode = code;
  }).catch((error) => {
    process.stderr.write(`内部错误：${error && error.stack ? error.stack : String(error)}\n`);
    process.exitCode = 1;
  });
}

export {
  main,
  loadMod,
  collectChanges,
  verifyBaseline,
  commitChanges,
  patchManifestText,
  parseDataPath,
  parseAssignmentSpec,
  CliError,
};
