#!/usr/bin/env node
// Generate docs/static from the curated metadata in static_docs_data.mjs.
//
// Run from the repository root:
//   node tools/gen_static_docs.mjs
//
// The generator is intentionally conservative: it emits a mirrored per-file
// index for curated files, a module README for everything else, and a manifest
// with SHA-256 hashes for incremental updates.

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { FILE_DOCS, MODULES, GROUPED_ROLES } from "./static_docs_data.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DOC_ROOT = path.join(ROOT, "docs", "static");
const MODE = "compact";
const RULE_VERSION = "2.0";
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

function extractSymbols(relativePath, text) {
  const symbols = [];
  const classMatch = /^class_name\s+(\w+)/m.exec(text);
  if (classMatch) {
    symbols.push({ label: classMatch[1], line: lineAt(text, classMatch.index), kind: "class" });
  }
  const signalRegex = /^signal\s+([a-z_][a-z0-9_]*)/gm;
  for (const match of text.matchAll(signalRegex)) {
    symbols.push({ label: `${match[1]} (signal)`, line: lineAt(text, match.index), kind: "signal" });
  }
  const constRegex = /^const\s+([A-Z][A-Z0-9_]*)\s*(?::[^=]+)?=/gm;
  for (const match of text.matchAll(constRegex)) {
    symbols.push({ label: match[1], line: lineAt(text, match.index), kind: "const" });
  }
  const functionRegex = /^func\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)\s*(?:->\s*([^:]+?))?:/gm;
  for (const match of text.matchAll(functionRegex)) {
    const name = match[1];
    if (name.startsWith("_") && name !== "_init") continue;
    const args = match[2].split("\n").map((line) => line.trim()).filter(Boolean).join(", ");
    const returnType = (match[3] || "").trim();
    const label = returnType ? `${name}(${args}) -> ${returnType}` : `${name}(${args})`;
    symbols.push({ label, line: lineAt(text, match.index), kind: "func" });
  }

  if (relativePath.endsWith(".js") || relativePath.endsWith(".mjs")) {
    const jsFunctionRegex = /^(?: {2})?(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(([^)]*)\)/gm;
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

function writeDoc(relativePath, content) {
  const target = path.join(DOC_ROOT, relativePath);
  ensureDir(path.dirname(target));
  fs.writeFileSync(target, content, "utf8");
}

function perFileDoc(source) {
  const metadata = FILE_DOCS[source];
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
  const modulePath = MODULE_OF(source);
  if (modulePath !== "root") {
    const docDir = path.join(ROOT, "docs/static", path.dirname(source));
    const moduleReadme = path.join(ROOT, "docs/static", modulePath, "README.md");
    let link = path.relative(docDir, moduleReadme).replaceAll("\\", "/");
    if (!link.startsWith(".")) link = "./" + link;
    lines.push(`模块索引：[${modulePath}](${link})`);
    lines.push("");
  }
  const docRelative = `${source}.md`;
  writeDoc(docRelative, lines.join("\n"));
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

function renderModuleReadme(modulePath) {
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
    if (FILE_DOCS[source]) {
      const docAbsolute = path.join(ROOT, "docs/static", docRelative);
      const moduleDocDir = path.join(ROOT, "docs/static", modulePath);
      let link = path.relative(moduleDocDir, docAbsolute).replaceAll("\\", "/");
      if (!link.startsWith(".")) link = "./" + link;
      docCell = `[查看](${link})`;
    }
    const role = FILE_DOCS[source]?.role || fallbackRole(source);
    lines.push(`| \`${relative}\` | ${role} | ${docCell} |`);
  }
  lines.push("");
  if (metadata.contracts && metadata.contracts.length) {
    lines.push("## 模块契约");
    lines.push("");
    for (const contract of metadata.contracts) lines.push(`- ${contract}`);
    lines.push("");
  }
  const target = path.join(DOC_ROOT, modulePath, "README.md");
  ensureDir(path.dirname(target));
  fs.writeFileSync(target, lines.join("\n"), "utf8");
}

function moduleDescription(modulePath) {
  return MODULES[modulePath]?.intro || "见模块 README。";
}

function main() {
  fs.rmSync(DOC_ROOT, { recursive: true, force: true });
  ensureDir(DOC_ROOT);

  let documented = 0;
  for (const source of Object.keys(FILE_DOCS)) {
    if (!fs.existsSync(path.join(ROOT, source))) {
      console.warn(`[skip] missing source: ${source}`);
      continue;
    }
    if (perFileDoc(source)) documented += 1;
  }
  for (const modulePath of MODULE_PATHS) {
    renderModuleReadme(modulePath);
  }
  for (const [source, target] of STATIC_COPY_PAGES) {
    if (fs.existsSync(path.join(ROOT, source))) writeDoc(target, read(source));
  }

  const commit = (() => {
    try {
      return execSync("git rev-parse --short HEAD", { cwd: ROOT, stdio: ["ignore", "pipe", "ignore"] })
        .toString()
        .trim();
    } catch {
      return "uncommitted";
    }
  })();
  const generatedAt = new Date().toISOString();

  const l0 = [];
  l0.push("# Steam Navigator — 静态代码文档");
  l0.push("");
  l0.push("> 面向阅读者与 AI 的代码索引：先看模块，再看文件，最后按需查看重点函数。");
  l0.push("");
  l0.push("## 项目入口");
  l0.push("");
  l0.push("- 启动：[project.godot](project.godot.md)、[Bootstrap](framework/bootstrap/bootstrap.gd.md)、[AppBootstrap](framework/bootstrap/app_bootstrap.gd.md)");
  l0.push("- 内容管线：[ModLoader](framework/modding/mod_loader.gd.md)、[ContentCompiler](framework/modding/content_compiler.gd.md)、[SchemaValidator](framework/modding/schema_validator.gd.md)");
  l0.push("- 运行时：[AppContext](framework/bootstrap/app_context.gd.md)、[GameState](framework/state/game_state.gd.md)");
  l0.push("- 主界面：[main.gd](framework/ui/shell/main.gd.md)");
  l0.push("- 3D 港口样片：[dev_scenes](dev_scenes/README.md)");
  l0.push("- 官方内容：[Core 内容包](dev_mods/core/README.md)");
  l0.push("- 迭代 1 契约：[MVP 闭环](../design/ITERATION_1_MVP_LOOP.md)");
  l0.push("- SDK：[打包/校验/模板](sdk/README.md)");
  l0.push("- 模组制作器：[SNModMaker](SNModMaker/README.md)");
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
  l0.push("- 更新方式：修改代码后同步维护 `tools/static_docs_data.mjs`，运行 `node tools/gen_static_docs.mjs`。");
  l0.push("- 增量依据：[manifest.json](manifest.json) 记录每个源文件的 SHA-256、文档位置与分组。");
  l0.push("");
  writeDoc("README.md", l0.join("\n"));

  const sourceSet = new Set();
  for (const modulePath of MODULE_PATHS) {
    for (const source of moduleSources(modulePath)) sourceSet.add(source);
  }
  for (const extra of ["project.godot", "README.md", "todo.md", "tools/test.ps1", "tools/pack_core.ps1", "tools/gen_static_docs.mjs", "tools/static_docs_data.mjs", "assets/ui/theme/steam_navigator_theme.tres", "assets/shaders/water/harbor_water.gdshader", "assets/materials/water/harbor_water.tres", "assets/materials/water/harbor_water_far.tres", "docs/design/UI_PROTOTYPE.md"]) {
    if (fs.existsSync(path.join(ROOT, extra))) sourceSet.add(extra);
  }

  const manifestEntries = [];
  for (const source of [...sourceSet].sort()) {
    if (!fs.existsSync(path.join(ROOT, source))) continue;
    if (fs.statSync(path.join(ROOT, source)).isDirectory()) continue;
    const modulePath = MODULE_OF(source);
    const doc = FILE_DOCS[source] ? `docs/static/${source}.md` : GROUP_README(modulePath);
    const status = FILE_DOCS[source] ? "documented" : "grouped";
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
  fs.writeFileSync(path.join(DOC_ROOT, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n", "utf8");

  console.log(
    `generated ${manifest.counts.documented} file docs, ${MODULE_PATHS.length} module indexes, ` +
      `${manifest.counts.sources} manifest entries (${manifest.counts.grouped} grouped)`
  );
}

main();
