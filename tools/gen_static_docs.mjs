#!/usr/bin/env node
// Generate docs/static from the curated metadata in static_docs_data.mjs.
//
// Run from the repository root:
//   node tools/gen_static_docs.mjs
//
// The generator is intentionally conservative: it emits a mirrored per-file
// index for documented files, a module README for everything else, and a
// manifest with SHA-256 hashes for freshness checks.
// @static-doc
// 作用：从源码静态文档注释、sidecar 头文件和旧策展数据生成镜像文档、模块索引与 SHA-256 manifest。
//
// ## 契约与约束
// - 新源码优先在前 120 行维护 `@static-doc`；不能写注释的格式使用 `docs/static_headers/<源码路径>.md`。
// - 旧 `FILE_DOCS` 只作为迁移兼容层，优先级低于源码注释和 sidecar。
// - 默认在临时目录完成构建后原子替换 `docs/static`；`--check` 只比较，不写工作区。
// - GDScript 符号提取支持普通/静态函数、推断/显式类型常量、类与信号。
// @end-static-doc

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { FILE_DOCS as LEGACY_FILE_DOCS, MODULES, GROUPED_ROLES } from "./static_docs_data.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DOC_ROOT = path.join(ROOT, "docs", "static");
const HEADER_ROOT = path.join(ROOT, "docs", "static_headers");
const MODE = "compact";
const RULE_VERSION = "3.0";
const STATIC_COPY_PAGES = [
  ["docs/design/UI_PROTOTYPE.md", "design-prototype.md"],
];

const MODULE_PATHS = [
  "framework/bootstrap",
  "framework/core",
  "framework/modding",
  "framework/application",
  "framework/domain",
  "framework/services",
  "framework/state",
  "framework/ui",
  "framework/tests",
  "sdk",
  "schemas",
  "dev_mods/core",
  "dev_scenes",
  "tools",
  "SNModMaker",
];

// Generated bundles are reproduced from schemas/ and dev_mods/core; they are
// intentionally excluded from per-file docs and from the manifest.
const SKIP_SOURCES = new Set([
  "SNModMaker/js/schema-bundle.js",
  "SNModMaker/js/core-index.js",
  "SNModMaker/js/content-types.js",
  "SNModMaker/mods/.gitignore",
  "SNModMaker/exports/.gitignore",
]);

const MODULE_OF = (source) => {
  for (const modulePath of MODULE_PATHS) {
    if (source === modulePath || source.startsWith(modulePath + "/")) {
      return modulePath;
    }
  }
  return "root";
};

const GROUP_README = (modulePath) =>
  modulePath === "root" ? "docs/static/README.md" : `docs/static/${modulePath}/README.md`;

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === ".git" || entry.name === ".godot" || entry.name === "node_modules" || entry.name === "__pycache__") continue;
    if (entry.name.endsWith(".import") || entry.name.endsWith(".uid") || entry.name.endsWith(".tmp") || entry.name.endsWith(".pyc")) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full, out);
    } else {
      const relative = path.relative(ROOT, full).replaceAll("\\", "/");
      if (SKIP_SOURCES.has(relative)) continue;
      out.push(full);
    }
  }
  return out;
}

function read(relativePath) {
  return fs.readFileSync(path.join(ROOT, relativePath), "utf8");
}

function sha256(relativePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(path.join(ROOT, relativePath))).digest("hex");
}

function lineAt(text, index) {
  return text.slice(0, index).split("\n").length;
}

export function extractSymbols(relativePath, text) {
  const symbols = [];
  const classMatch = /^class_name\s+(\w+)/m.exec(text);
  if (classMatch) {
    symbols.push({ label: classMatch[1], line: lineAt(text, classMatch.index), kind: "class" });
  }
  const signalRegex = /^signal\s+([a-z_][a-z0-9_]*)/gm;
  for (const match of text.matchAll(signalRegex)) {
    symbols.push({ label: `${match[1]} (signal)`, line: lineAt(text, match.index), kind: "signal" });
  }
  const constRegex = /^const\s+([A-Z][A-Z0-9_]*)\s*(?::=|:\s*[^=\n]+?\s*=|=)/gm;
  for (const match of text.matchAll(constRegex)) {
    symbols.push({ label: match[1], line: lineAt(text, match.index), kind: "const" });
  }
  const functionRegex = /^(?:static\s+)?func\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)\s*(?:->\s*([^:]+?))?:/gm;
  for (const match of text.matchAll(functionRegex)) {
    const name = match[1];
    if (name.startsWith("_") && name !== "_init") continue;
    const args = match[2].split("\n").map((line) => line.trim()).filter(Boolean).join(", ");
    const returnType = (match[3] || "").trim();
    const label = returnType ? `${name}(${args}) -> ${returnType}` : `${name}(${args})`;
    symbols.push({ label, line: lineAt(text, match.index), kind: "func" });
  }

  if (relativePath.endsWith(".js") || relativePath.endsWith(".mjs")) {
    const jsFunctionRegex = /^(?:export\s+)?(?: {2})?(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(([^)]*)\)/gm;
    for (const match of text.matchAll(jsFunctionRegex)) {
      const args = match[2].split(",").map((arg) => arg.trim()).filter(Boolean).join(", ");
      symbols.push({ label: `${match[1]}(${args})`, line: lineAt(text, match.index), kind: "func" });
    }
    const jsConstRegex = /^ {2}const\s+([A-Z][A-Z0-9_]+)\s*=/gm;
    for (const match of text.matchAll(jsConstRegex)) {
      symbols.push({ label: match[1], line: lineAt(text, match.index), kind: "const" });
    }
    const exportRegex = /root\.(SN[A-Za-z]+)\s*=\s*\{/g;
    for (const match of text.matchAll(exportRegex)) {
      symbols.push({ label: `${match[1]} (global)`, line: lineAt(text, match.index), kind: "export" });
    }
  }

  const seen = new Set();
  const unique = symbols.filter((symbol) => {
    const key = `${symbol.label}@${symbol.line}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
  unique.sort((left, right) => left.line - right.line);
  return unique;
}

function stripStaticDocComment(line) {
  const value = line.trimStart();
  if (/^\/\//.test(value)) return value.replace(/^\/\/\/?\s?/, "").trimEnd();
  if (/^#/.test(value)) return value.replace(/^#{1,3}\s?/, "").trimEnd();
  if (/^;/.test(value)) return value.replace(/^;\s?/, "").trimEnd();
  if (/^<!--/.test(value)) return value.replace(/^<!--\s?/, "").replace(/\s*-->$/, "").trimEnd();
  if (/^\/\*/.test(value)) return value.replace(/^\/\*+\s?/, "").replace(/\s*\*\/$/, "").trimEnd();
  if (/^\*/.test(value)) return value.replace(/^\*\s?/, "").replace(/\s*\*\/$/, "").trimEnd();
  return value.trimEnd();
}

function parseStaticDocFragment(lines, source) {
  while (lines.length && !lines[0].trim()) lines.shift();
  while (lines.length && !lines.at(-1).trim()) lines.pop();
  const roleIndex = lines.findIndex((line) => /^(?:作用|role)\s*[：:]/i.test(line.trim()));
  if (roleIndex < 0) {
    throw new Error(`${source}: static doc block must contain \"作用：...\" or \"role: ...\"`);
  }
  const role = lines[roleIndex].trim().replace(/^(?:作用|role)\s*[：:]\s*/i, "").trim();
  if (!role) throw new Error(`${source}: static doc role must not be empty`);
  lines.splice(roleIndex, 1);
  while (lines.length && !lines[0].trim()) lines.shift();
  while (lines.length && !lines.at(-1).trim()) lines.pop();
  return { role, fragment: lines.join("\n") };
}

export function extractStaticDoc(relativePath, text) {
  const lines = text.split(/\r?\n/);
  let start = -1;
  for (let index = 0; index < Math.min(lines.length, 120); index += 1) {
    if (stripStaticDocComment(lines[index]) === "@static-doc") {
      start = index + 1;
      break;
    }
  }
  if (start < 0) return null;
  const content = [];
  for (let index = start; index < lines.length; index += 1) {
    const line = stripStaticDocComment(lines[index]);
    if (line === "@end-static-doc") return parseStaticDocFragment(content, relativePath);
    content.push(line);
  }
  throw new Error(`${relativePath}: missing @end-static-doc`);
}

function readSidecarDoc(source) {
  const sidecar = path.join(HEADER_ROOT, `${source}.md`);
  if (!fs.existsSync(sidecar)) return null;
  return parseStaticDocFragment(fs.readFileSync(sidecar, "utf8").split(/\r?\n/), `${source} sidecar`);
}

const metadataCache = new Map();

function metadataFor(source) {
  if (metadataCache.has(source)) return metadataCache.get(source);
  let metadata = null;
  const absolute = path.join(ROOT, source);
  if (fs.existsSync(absolute) && fs.statSync(absolute).isFile()) {
    try {
      metadata = extractStaticDoc(source, fs.readFileSync(absolute, "utf8"));
    } catch (error) {
      if (error instanceof TypeError || error?.code === "ERR_INVALID_ARG_VALUE") metadata = null;
      else throw error;
    }
  }
  metadata ||= readSidecarDoc(source);
  metadata ||= LEGACY_FILE_DOCS[source] || null;
  metadataCache.set(source, metadata);
  return metadata;
}

function sourceTypeLabel(source) {
  if (source.endsWith(".gd")) return "GDScript 源文件";
  if (source.endsWith(".gdshader")) return "Godot 着色器";
  if (source.endsWith(".tscn")) return "Godot 场景";
  if (source.endsWith(".tres")) return "Godot 资源";
  if (source.endsWith(".js")) return "浏览器经典脚本";
  if (source.endsWith(".mjs")) return "Node ES 模块";
  if (source.endsWith(".html")) return "HTML 应用外壳";
  if (source.endsWith(".css")) return "样式表";
  if (source.endsWith(".json")) return "JSON 数据/配置";
  return "项目配置/数据文件";
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function writeDoc(docRoot, relativePath, content) {
  const target = path.join(docRoot, relativePath);
  ensureDir(path.dirname(target));
  fs.writeFileSync(target, content, "utf8");
}

function perFileDoc(docRoot, source) {
  const metadata = metadataFor(source);
  if (!metadata) return null;
  const text = read(source);
  const symbols = extractSymbols(source, text);
  const lines = [];
  lines.push(`# \`${source}\``);
  lines.push("");
  lines.push(`> 作用：${metadata.role}`);
  lines.push("");
  if (metadata.dependencies && metadata.dependencies.length) {
    lines.push(`- 关键依赖：${metadata.dependencies.map((dep) => `\`${dep}\``).join("、")}`);
  }
  lines.push(`- 类型：${sourceTypeLabel(source)}`);
  lines.push("");
  if (symbols.length) {
    lines.push("## 关键符号");
    lines.push("");
    lines.push("| 符号 | 位置 |");
    lines.push("| --- | --- |");
    for (const symbol of symbols) {
      const escaped = symbol.label.replaceAll("|", "\\|");
      lines.push(`| \`${escaped}\` | L${symbol.line} |`);
    }
    lines.push("");
  }
  if (metadata.contracts && metadata.contracts.length) {
    lines.push("## 契约与约束");
    lines.push("");
    for (const contract of metadata.contracts) lines.push(`- ${contract}`);
    lines.push("");
  }
  if (metadata.l2 && Object.keys(metadata.l2).length) {
    lines.push("## 重点逻辑");
    lines.push("");
    for (const [name, bullets] of Object.entries(metadata.l2)) {
      lines.push(`### \`${name}\``);
      lines.push("");
      for (const bullet of bullets) lines.push(`- ${bullet}`);
      lines.push("");
    }
  }
  if (metadata.fragment) {
    lines.push(metadata.fragment);
    lines.push("");
  }
  const modulePath = MODULE_OF(source);
  if (modulePath !== "root") {
    const docDir = path.join(docRoot, path.dirname(source));
    const moduleReadme = path.join(docRoot, modulePath, "README.md");
    let link = path.relative(docDir, moduleReadme).replaceAll("\\", "/");
    if (!link.startsWith(".")) link = "./" + link;
    lines.push(`模块索引：[${modulePath}](${link})`);
    lines.push("");
  }
  const docRelative = `${source}.md`;
  writeDoc(docRoot, docRelative, lines.join("\n"));
  return `docs/static/${docRelative}`;
}

function fallbackRole(source) {
  if (GROUPED_ROLES[source]) return GROUPED_ROLES[source];
  for (const [key, role] of Object.entries(GROUPED_ROLES)) {
    if (source.startsWith(key + "/")) return role;
  }
  if (source.startsWith("schemas/")) return `Schema：${path.basename(source)}`;
  if (source.startsWith("dev_mods/core/content/")) return `Core 内容：${path.basename(source)}`;
  if (source.startsWith("dev_mods/core/localization/")) return `Core 本地化：${path.basename(source)}`;
  if (source.startsWith("dev_mods/core/assets/")) return `Core 占位资源：${path.basename(source)}`;
  if (source.startsWith("sdk/templates/")) return `模组模板文件：${path.basename(source)}`;
  if (source.startsWith("sdk/examples/")) return `第三方示例文件：${path.basename(source)}`;
  if (source.startsWith("framework/tests/cases/")) return `测试用例：${path.basename(source, ".gd")}`;
  if (source.startsWith("tools/")) return `工具脚本：${path.basename(source)}`;
  if (source.startsWith("framework/")) return `框架源文件：${path.basename(source)}`;
  return `源文件：${path.basename(source)}`;
}

function moduleSources(modulePath) {
  const absolute = path.join(ROOT, modulePath);
  return walk(absolute)
    .map((full) => path.relative(ROOT, full).replaceAll("\\", "/"))
    .sort();
}

function renderModuleReadme(docRoot, modulePath) {
  const metadata = MODULES[modulePath] || { intro: "", contracts: [] };
  const docPath = GROUP_README(modulePath);
  const lines = [];
  lines.push(`# \`${modulePath}\``);
  lines.push("");
  if (metadata.intro) {
    lines.push(`> ${metadata.intro}`);
    lines.push("");
  }
  lines.push("## 文件索引");
  lines.push("");
  lines.push("| 文件 | 职责 | 文档 |");
  lines.push("| --- | --- | --- |");
  const sources = moduleSources(modulePath);
  for (const source of sources) {
    const relative = path.relative(modulePath, source).replaceAll("\\", "/");
    const docRelative = `${source}.md`;
    let docCell = "本页";
    if (metadataFor(source)) {
      const docAbsolute = path.join(docRoot, docRelative);
      const moduleDocDir = path.join(docRoot, modulePath);
      let link = path.relative(moduleDocDir, docAbsolute).replaceAll("\\", "/");
      if (!link.startsWith(".")) link = "./" + link;
      docCell = `[查看](${link})`;
    }
    const role = metadataFor(source)?.role || fallbackRole(source);
    lines.push(`| \`${relative}\` | ${role} | ${docCell} |`);
  }
  lines.push("");
  if (metadata.contracts && metadata.contracts.length) {
    lines.push("## 模块契约");
    lines.push("");
    for (const contract of metadata.contracts) lines.push(`- ${contract}`);
    lines.push("");
  }
  const target = path.join(docRoot, modulePath, "README.md");
  ensureDir(path.dirname(target));
  fs.writeFileSync(target, lines.join("\n"), "utf8");
}

function moduleDescription(modulePath) {
  return MODULES[modulePath]?.intro || "见模块 README。";
}

function collectSources() {
  const sourceSet = new Set();
  for (const modulePath of MODULE_PATHS) {
    for (const source of moduleSources(modulePath)) sourceSet.add(source);
  }
  for (const extra of ["project.godot", "content_types.json", "README.md", "todo.md", "export_presets.cfg", "docker-compose.yml", ".github/workflows/release.yml", "tools/test.ps1", "tools/pack_core.ps1", "tools/gen_static_docs.mjs", "tools/static_docs_data.mjs", "assets/ui/theme/steam_navigator_theme.tres", "assets/shaders/water/harbor_water.gdshader", "assets/materials/water/harbor_water.tres", "assets/materials/water/harbor_water_far.tres", "docs/design/UI_PROTOTYPE.md"]) {
    if (fs.existsSync(path.join(ROOT, extra))) sourceSet.add(extra);
  }
  return [...sourceSet].sort();
}

function validateSidecars(sources) {
  if (!fs.existsSync(HEADER_ROOT)) return;
  const sourceSet = new Set(sources);
  for (const absolute of walk(HEADER_ROOT)) {
    const relative = path.relative(HEADER_ROOT, absolute).replaceAll("\\", "/");
    if (relative === "README.md") continue;
    if (!relative.endsWith(".md")) throw new Error(`static doc sidecar must be Markdown: ${relative}`);
    const source = relative.slice(0, -3);
    if (!sourceSet.has(source)) throw new Error(`orphan static doc sidecar: ${relative} (missing ${source})`);
  }
}

function inputDigests(sources) {
  const inputs = sources.map((source) => path.join(ROOT, source));
  if (fs.existsSync(HEADER_ROOT)) inputs.push(...walk(HEADER_ROOT));
  const result = new Map();
  for (const absolute of inputs) {
    result.set(absolute, crypto.createHash("sha256").update(fs.readFileSync(absolute)).digest("hex"));
  }
  return result;
}

function assertInputsUnchanged(before) {
  for (const [absolute, digest] of before) {
    if (!fs.existsSync(absolute)) throw new Error(`documentation input disappeared during generation: ${absolute}`);
    const current = crypto.createHash("sha256").update(fs.readFileSync(absolute)).digest("hex");
    if (current !== digest) throw new Error(`documentation input changed during generation: ${absolute}`);
  }
}

function currentCommit() {
  try {
    return execSync("git rev-parse --short HEAD", { cwd: ROOT, stdio: ["ignore", "pipe", "ignore"] })
      .toString()
      .trim();
  } catch {
    return "uncommitted";
  }
}

function renderRootReadme(docRoot, generatedAt, commit) {
  const l0 = [];
  l0.push("# Steam Navigator — 静态代码文档");
  l0.push("");
  l0.push("> 面向阅读者与 AI 的代码索引：先看模块，再看文件，最后按需查看重点函数。");
  l0.push("");
  l0.push("## 项目入口");
  l0.push("");
  l0.push("- 启动：[project.godot](project.godot.md)、[Bootstrap](framework/bootstrap/bootstrap.gd.md)、[AppBootstrap](framework/bootstrap/app_bootstrap.gd.md)");
  l0.push("- 内容契约：[content_types.json](content_types.json.md)、[Entity Contract v2](../design/ENTITY_CONTRACT_V2.md)");
  l0.push("- 内容管线：[ModLoader](framework/modding/mod_loader.gd.md)、[ContentCompiler](framework/modding/content_compiler.gd.md)、[SchemaValidator](framework/modding/schema_validator.gd.md)");
  l0.push("- 运行时：[AppContext](framework/bootstrap/app_context.gd.md)、[GameState](framework/state/game_state.gd.md)");
  l0.push("- 主界面：[main.gd](framework/ui/shell/main.gd.md)");
  l0.push("- 3D 港口样片：[dev_scenes](dev_scenes/README.md)");
  l0.push("- 官方内容：[Core 内容包](dev_mods/core/README.md)");
  l0.push("- 迭代 1 契约：[MVP 闭环](../design/ITERATION_1_MVP_LOOP.md)");
  l0.push("- SDK：[打包/校验/模板](sdk/README.md)");
  l0.push("- 释放与导出：[export_presets.cfg](export_presets.cfg.md)、[release.yml](.github/workflows/release.yml.md)");
  l0.push("- 模组制作器：[SNModMaker](SNModMaker/README.md)");
  l0.push("- 内容 CLI：[content.mjs](SNModMaker/tools/content.mjs.md)（agent 无头增删改内容）");
  l0.push("- 容器部署：[docker-compose.yml](docker-compose.yml.md)、[Dockerfile](SNModMaker/Dockerfile.md)（数据在容器卷，配合 tailscale serve）");
  l0.push("- 本地美术原型：[`.design` 美术与交互原型](design-prototype.md)");
  l0.push("");
  l0.push("## 模块索引");
  l0.push("");
  l0.push("| 模块 | 内容 |");
  l0.push("| --- | --- |");
  for (const modulePath of MODULE_PATHS) {
    l0.push(`| [\`${modulePath}\`](${modulePath}/README.md) | ${moduleDescription(modulePath)} |`);
  }
  l0.push("");
  l0.push("## 主要数据流");
  l0.push("");
  l0.push("```text");
  l0.push("启动：AppBootstrap → Bootstrap → ModScanner → DependencyResolver");
  l0.push("      → ContentCompiler（Schema/注册/Patch）→ CrossReferenceValidator");
  l0.push("      → CoreCompletenessChecker → RegistryHub.freeze → FrameworkApi");
  l0.push("");
  l0.push("新局：CommandBus(run.start) → RunFactory → MapGenerator + MarketOps + NPC");
  l0.push("      → ContractOps(主线 1) → GameState 提交 → autosave");
  l0.push("");
  l0.push("航行：voyage.preview → VoyageCalculator → voyage.start → VoyageService");
  l0.push("      → 风险事件/EffectExecutor → _complete_arrival → ContractOps + NPC + Debt");
  l0.push("      → 普通委托池刷新（ContractOps.refresh_normal_offers）");
  l0.push("");
  l0.push("建造：ship.install_module(source=purchase|warehouse|transit) / ship.craft_module");
  l0.push("      → ShipOps/CraftOps/WarehouseOps（旧件入当前港仓库、transit 计重不占货舱）");
  l0.push("      → VictoryService.check（主线完成 + 大型船体/锅炉/货舱 → 通关）");
  l0.push("");
  l0.push("UI：QueryBus → ViewModel → CommandBus → 事务克隆提交 → DomainEventBus");
  l0.push("```");
  l0.push("");
  l0.push("## 架构不变量");
  l0.push("");
  l0.push("- 框架不硬编码具体 `core:*` ID；官方内容通过普通模组注册表进入。");
  l0.push("- 注册表加载完成后冻结；运行态数值只在 `GameState`。");
  l0.push("- 命令在状态深拷贝上执行，成功才提交；查询使用临时克隆。");
  l0.push("- 所有随机来自命名流；同 seed + 模组清单 + 命令序列结果一致。");
  l0.push("- 港口仓库/随船运输/通关标记只存在于 GameState；注册表冻结后仍可自由存取。");
  l0.push("- 存档头记录模组版本；缺失关键模组的存档拒绝加载。");
  l0.push("");
  l0.push("## 生成信息");
  l0.push("");
  l0.push(`- 生成时间：${generatedAt}`);
  l0.push(`- 生成 commit：\`${commit}\``);
  l0.push(`- 模式：\`${MODE}\`；规则版本：\`${RULE_VERSION}\``);
  l0.push("- 更新方式：在源码头部维护 `@static-doc` 注释，运行 `node tools/gen_static_docs.mjs`；无注释格式使用 `docs/static_headers/<源码路径>.md` sidecar。");
  l0.push("- 检查方式：`node tools/gen_static_docs.mjs --check`；旧的 `tools/static_docs_data.mjs` 仅作为尚未迁移文件的兼容层。");
  l0.push("- 变更依据：[manifest.json](manifest.json) 记录每个源文件的 SHA-256、文档位置与分组。");
  l0.push("");
  writeDoc(docRoot, "README.md", l0.join("\n"));
}

function buildDocs(docRoot, options = {}) {
  ensureDir(docRoot);
  metadataCache.clear();
  const sources = collectSources();
  validateSidecars(sources);
  const inputsBefore = inputDigests(sources);
  for (const source of sources) {
    if (metadataFor(source)) perFileDoc(docRoot, source);
  }
  for (const modulePath of MODULE_PATHS) renderModuleReadme(docRoot, modulePath);
  for (const [source, target] of STATIC_COPY_PAGES) {
    if (fs.existsSync(path.join(ROOT, source))) writeDoc(docRoot, target, read(source));
  }

  const generatedAt = options.generatedAt || new Date().toISOString();
  const commit = options.commit || currentCommit();
  renderRootReadme(docRoot, generatedAt, commit);

  const manifestEntries = [];
  for (const source of sources) {
    const modulePath = MODULE_OF(source);
    const status = metadataFor(source) ? "documented" : "grouped";
    const doc = status === "documented" ? `docs/static/${source}.md` : GROUP_README(modulePath);
    manifestEntries.push({
      source,
      sha256: sha256(source),
      doc,
      status,
      group: status === "grouped" ? GROUP_README(modulePath) : undefined,
    });
  }

  const manifest = {
    rule_version: RULE_VERSION,
    mode: MODE,
    generated_at: generatedAt,
    commit,
    project_root: ".",
    doc_root: "docs/static",
    counts: {
      sources: manifestEntries.length,
      documented: manifestEntries.filter((entry) => entry.status === "documented").length,
      grouped: manifestEntries.filter((entry) => entry.status === "grouped").length,
    },
    files: manifestEntries,
  };
  fs.writeFileSync(path.join(docRoot, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n", "utf8");
  assertInputsUnchanged(inputsBefore);
  return manifest;
}

function fileDigests(root) {
  const result = new Map();
  if (!fs.existsSync(root)) return result;
  for (const absolute of walk(root)) {
    const relative = path.relative(root, absolute).replaceAll("\\", "/");
    result.set(relative, crypto.createHash("sha256").update(fs.readFileSync(absolute)).digest("hex"));
  }
  return result;
}

function compareDocTrees(expectedRoot, actualRoot) {
  const expected = fileDigests(expectedRoot);
  const actual = fileDigests(actualRoot);
  const paths = new Set([...expected.keys(), ...actual.keys()]);
  return [...paths].sort().filter((relative) => expected.get(relative) !== actual.get(relative));
}

function replaceDocsAtomically(tempRoot) {
  const backupRoot = path.join(path.dirname(DOC_ROOT), `.static-backup-${process.pid}-${Date.now()}`);
  let movedExisting = false;
  try {
    if (fs.existsSync(DOC_ROOT)) {
      fs.renameSync(DOC_ROOT, backupRoot);
      movedExisting = true;
    }
    fs.renameSync(tempRoot, DOC_ROOT);
    if (movedExisting) fs.rmSync(backupRoot, { recursive: true, force: true });
  } catch (error) {
    if (!fs.existsSync(DOC_ROOT) && movedExisting && fs.existsSync(backupRoot)) fs.renameSync(backupRoot, DOC_ROOT);
    throw error;
  }
}

function baselineGenerationInfo() {
  const manifestPath = path.join(DOC_ROOT, "manifest.json");
  if (!fs.existsSync(manifestPath)) return { generatedAt: new Date(0).toISOString(), commit: "uncommitted" };
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  return { generatedAt: manifest.generated_at, commit: manifest.commit };
}

function printHelp() {
  console.log(`Usage: node tools/gen_static_docs.mjs [--check]\n\n` +
    `  no args   Build docs/static atomically from source annotations, sidecars, and legacy metadata.\n` +
    `  --check   Rebuild in a temporary directory and fail when docs/static is stale.\n` +
    `  --help    Show this help without generating files.`);
}

function main(args = process.argv.slice(2)) {
  if (args.includes("--help") || args.includes("-h")) {
    printHelp();
    return;
  }
  const unknown = args.filter((arg) => arg !== "--check");
  if (unknown.length) throw new Error(`unknown argument(s): ${unknown.join(", ")}`);

  const tempRoot = fs.mkdtempSync(path.join(path.dirname(DOC_ROOT), ".static-build-"));
  try {
    if (args.includes("--check")) {
      buildDocs(tempRoot, baselineGenerationInfo());
      const changed = compareDocTrees(DOC_ROOT, tempRoot);
      if (changed.length) {
        console.error(`static docs are stale (${changed.length} changed path(s)):`);
        for (const relative of changed.slice(0, 30)) console.error(`  ${relative}`);
        process.exitCode = 1;
        return;
      }
      console.log("static docs are up to date");
      return;
    }

    const manifest = buildDocs(tempRoot);
    replaceDocsAtomically(tempRoot);
    console.log(
      `generated ${manifest.counts.documented} file docs, ${MODULE_PATHS.length} module indexes, ` +
        `${manifest.counts.sources} manifest entries (${manifest.counts.grouped} grouped)`
    );
  } finally {
    if (fs.existsSync(tempRoot)) fs.rmSync(tempRoot, { recursive: true, force: true });
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
