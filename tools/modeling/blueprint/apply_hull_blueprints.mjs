#!/usr/bin/env node
// @static-doc
// 作用：把离线蓝图线稿接入 Core 船体内容：拷贝 side/top PNG、登记 manifest 资源键、写入 `data.blueprint_views`，并用生成器 metadata 的正交相机把船体武器 socket 的 `position` 投影成 `blueprint` 归一化坐标。
//
// ## 契约与约束
// - 输入是 `tools/modeling/blueprint/blueprint_batch.py` 的产物目录（每船含 `side.png` / `top.png` / `metadata.json`）；不重新渲染、不改 PNG。
// - 坐标空间 = 裁切后线稿纹理的归一化 uv（`space: "trimmed"`，左上原点 0..1）；投影使用 metadata 的相机旋转/位置、`orthographic_scale`、`render_resolution` 与 `crop.crop_bounds`，与蓝图生成器共用同一组数字。
// - 武器 socket 的 `position` 取内容侧 `[x, y, deck_z]` 镜像（Blender 船体局部坐标）；脚本只读内容，不回读 GLB。
// - 写入 hulls.json 时通过 `SNModMaker/tools/content_json.mjs` 保留原文件风格；manifest 用 2 空格 JSON 重写。
// - `--check` 只比较、不写盘：有差异退出码 1，供 CI / 发布门禁使用。
//
// ## 重点逻辑
// ### `projectPoint(position, viewMetadata)`
// - Blender Euler XYZ → 相机基向量，按正交投影得到像素坐标，再经 crop 归一化；越界钳制到 0..1。
// ### `buildPlan(input)`
// - 由 hull 的 `information.model` → manifest 资源路径 → GLB 文件名找到线稿目录；输出每船的 blueprint_views、asset 键与 socket 坐标。
// ### `applyPlan(plan, options)`
// - 依次替换/插入 hulls.json 的 `data.blueprint_views` 与 `data.weapon_sockets[N].blueprint`；`--check` 时只比对。
// @end-static-doc

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import {
  parseSource,
  findNode,
  replaceNodeValue,
  insertObjectMember,
  formatStyled,
} from '../../../SNModMaker/tools/content_json.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..', '..', '..');

const VIEWS = ['side', 'top'];

function usage() {
  console.log(`Usage: node tools/modeling/blueprint/apply_hull_blueprints.mjs [options]

  --hull-content <path>   hulls.json (default dev_mods/core/content/hulls.json)
  --manifest <path>       manifest.json (default dev_mods/core/manifest.json)
  --blueprint-root <dir>  generated line-art root (default .design/blueprint/ships_core)
  --asset-dir <dir>       copied PNG root (default dev_mods/core/assets/blueprints/ships)
  --write                 write hulls.json / manifest.json / PNG copies
  --check                 compare only; exit 1 when out of date (implies no writes)
  --json                  print machine-readable summary
  -h, --help`);
}

function parseArgs(argv) {
  const options = {
    hullContent: path.join(repoRoot, 'dev_mods/core/content/hulls.json'),
    manifest: path.join(repoRoot, 'dev_mods/core/manifest.json'),
    blueprintRoot: path.join(repoRoot, '.design/blueprint/ships_core'),
    assetDir: path.join(repoRoot, 'dev_mods/core/assets/blueprints/ships'),
    write: false,
    check: false,
    json: false,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const next = () => {
      index += 1;
      if (index >= argv.length) throw new Error(`缺少参数值: ${arg}`);
      return argv[index];
    };
    if (arg === '--hull-content') options.hullContent = path.resolve(next());
    else if (arg === '--manifest') options.manifest = path.resolve(next());
    else if (arg === '--blueprint-root') options.blueprintRoot = path.resolve(next());
    else if (arg === '--asset-dir') options.assetDir = path.resolve(next());
    else if (arg === '--write') options.write = true;
    else if (arg === '--check') options.check = true;
    else if (arg === '--json') options.json = true;
    else if (arg === '-h' || arg === '--help') {
      usage();
      process.exit(0);
    } else {
      throw new Error(`未知参数: ${arg}`);
    }
  }
  if (options.check) options.write = false;
  if (!options.write && !options.check) options.check = true;
  return options;
}

function mat3FromEuler([ex, ey, ez]) {
  const cx = Math.cos(ex);
  const sx = Math.sin(ex);
  const cy = Math.cos(ey);
  const sy = Math.sin(ey);
  const cz = Math.cos(ez);
  const sz = Math.sin(ez);
  // Blender Euler XYZ: R = Rz * Ry * Rx.
  return [
    [cz * cy, cz * sy * sx - sz * cx, cz * sy * cx + sz * sx],
    [sz * cy, sz * sy * sx + cz * cx, sz * sy * cx - cz * sx],
    [-sy, cy * sx, cy * cx],
  ];
}

function applyMat3(matrix, vector) {
  return [
    matrix[0][0] * vector[0] + matrix[0][1] * vector[1] + matrix[0][2] * vector[2],
    matrix[1][0] * vector[0] + matrix[1][1] * vector[1] + matrix[1][2] * vector[2],
    matrix[2][0] * vector[0] + matrix[2][1] * vector[1] + matrix[2][2] * vector[2],
  ];
}

const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const clamp01 = (value) => Math.min(1, Math.max(0, value));
const round4 = (value) => Math.round(clamp01(value) * 10000) / 10000;

/** Projects a Blender-space point through the blueprint camera into cropped-image uv. */
function projectPoint(position, viewMetadata) {
  if (!Array.isArray(position) || position.length < 3) return null;
  const rotation = mat3FromEuler(viewMetadata.camera_rotation_euler || [0, 0, 0]);
  const right = applyMat3(rotation, [1, 0, 0]);
  const up = applyMat3(rotation, [0, 1, 0]);
  const location = viewMetadata.camera_location || [0, 0, 0];
  const delta = [
    Number(position[0]) - location[0],
    Number(position[1]) - location[1],
    Number(position[2]) - location[2],
  ];
  const cameraX = dot(delta, right);
  const cameraY = dot(delta, up);
  const resolution = viewMetadata.render_resolution || [2048, 2048];
  const width = Number(resolution[0]) || 2048;
  const height = Number(resolution[1]) || 2048;
  const orthoScale = Number(viewMetadata.orthographic_scale) || 1;
  const worldPerPixel = orthoScale / Math.max(width, height);
  const pixelX = width / 2 + cameraX / worldPerPixel;
  const pixelY = height / 2 - cameraY / worldPerPixel;
  const crop = viewMetadata.crop || {};
  const bounds = Array.isArray(crop.crop_bounds) ? crop.crop_bounds : [0, 0, width, height];
  const output = Array.isArray(crop.output_size) ? crop.output_size : [width, height];
  const u = (pixelX - Number(bounds[0])) / (Number(output[0]) || width);
  const v = (pixelY - Number(bounds[1])) / (Number(output[1]) || height);
  return [round4(u), round4(v)];
}

function modelKeyToGlb(manifest, modelKey) {
  const relative = manifest && manifest.assets ? manifest.assets[modelKey] : '';
  if (!relative) return '';
  return path.basename(relative, path.extname(relative));
}

function assetKeyFor(hullLocalId, view) {
  return `blueprint.ship.${String(hullLocalId).replace(/[^a-z0-9_]/g, '_')}.${view}`;
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function readText(file) {
  return fs.readFileSync(file, 'utf8');
}

// formatStyled(value, indentLevel) 的 indentLevel 既接受缩进字符串，也接受列号；
// insertObjectMember 传的是成员缩进，replaceNodeValue 传的是节点起始列。
const formatFormatter = formatStyled;

/** Replaces or inserts one object member, keeping the source formatting. */
function setMember(text, memberPath, value) {
  const root = parseSource(text).root;
  const existing = findNode(root, memberPath);
  if (existing) return replaceNodeValue(text, existing, value, formatFormatter);
  const parent = findNode(root, memberPath.slice(0, -1));
  if (!parent || parent.type !== 'object') throw new Error(`无法定位 ${memberPath.join('.')} 的父对象`);
  return insertObjectMember(text, parent, memberPath[memberPath.length - 1], value, formatFormatter);
}

function buildPlan(options) {
  const manifest = readJson(options.manifest);
  const source = readText(options.hullContent);
  const hullContent = JSON.parse(source);
  const definitions = Array.isArray(hullContent.definitions) ? hullContent.definitions : [];
  const plan = [];

  for (const definition of definitions) {
    if (!definition || !definition.data) continue;
    const data = definition.data;
    const modelKey = String(definition.information && definition.information.model || '');
    const modelName = modelKeyToGlb(manifest, modelKey);
    if (!modelName) continue;
    const blueprintDir = path.join(options.blueprintRoot, modelName);
    const metadataPath = path.join(blueprintDir, 'metadata.json');
    if (!fs.existsSync(metadataPath)) continue;
    const metadata = readJson(metadataPath);
    const localId = String(definition.id || '').split('/').pop();
    const views = {};
    const copies = [];
    for (const view of VIEWS) {
      const viewMeta = metadata.views && metadata.views[view];
      const png = path.join(blueprintDir, `${view}.png`);
      if (!viewMeta || !fs.existsSync(png)) continue;
      const resolution = Array.isArray(viewMeta.resolution) ? viewMeta.resolution : [0, 0];
      const key = assetKeyFor(localId, view);
      // 文件名带上模型名，素材页里不同船的 side/top 不再同名。
      const targetPng = path.join(options.assetDir, modelName, `${modelName}.${view}.png`);
      const relativePng = path.relative(path.dirname(options.manifest), targetPng).replace(/\\/g, '/');
      views[view] = {
        image: key,
        width: Number(resolution[0]) || 0,
        height: Number(resolution[1]) || 0,
        space: 'trimmed',
      };
      copies.push({ key, source: png, relative: relativePng, target: targetPng });
    }
    if (!Object.keys(views).length) continue;

    const sockets = Array.isArray(data.weapon_sockets) ? data.weapon_sockets : [];
    const socketPlans = [];
    sockets.forEach((socket, index) => {
      if (!socket || !Array.isArray(socket.position)) return;
      const blueprint = {};
      for (const view of VIEWS) {
        const viewMeta = metadata.views && metadata.views[view];
        if (!viewMeta) continue;
        const point = projectPoint(socket.position, viewMeta);
        if (point) blueprint[view] = point;
      }
      if (Object.keys(blueprint).length) socketPlans.push({ index, socket, blueprint });
    });
    plan.push({
      id: definition.id,
      localId,
      modelName,
      blueprintDir,
      views,
      copies,
      sockets: socketPlans,
    });
  }
  return { source, manifest, plan };
}

function applyPlan(built, options) {
  const changes = [];
  let text = built.source;
  for (const entry of built.plan) {
    const definitionIndex = JSON.parse(text).definitions.findIndex((item) => item && item.id === entry.id);
    if (definitionIndex < 0) throw new Error(`找不到定义 ${entry.id}`);
    const viewData = {};
    for (const [view, value] of Object.entries(entry.views)) viewData[view] = value;
    text = setMember(text, ['definitions', definitionIndex, 'data', 'blueprint_views'], viewData);
    for (const socketPlan of entry.sockets) {
      text = setMember(
        text,
        ['definitions', definitionIndex, 'data', 'weapon_sockets', socketPlan.index, 'blueprint'],
        socketPlan.blueprint,
      );
    }
    changes.push({
      id: entry.id,
      model: entry.modelName,
      views: entry.views,
      sockets: entry.sockets.map((socketPlan) => ({
        socket: String(socketPlan.socket.name || ''),
        blueprint: socketPlan.blueprint,
      })),
    });
  }

  const manifest = JSON.parse(JSON.stringify(built.manifest));
  for (const entry of built.plan) {
    for (const copy of entry.copies) {
      manifest.assets = manifest.assets || {};
      if (manifest.assets[copy.key] !== copy.relative) {
        manifest.assets[copy.key] = copy.relative;
        changes.push({ manifestAsset: copy.key, path: copy.relative });
      }
    }
  }
  const manifestText = `${JSON.stringify(manifest, null, 2)}\n`;
  const sourceChanged = text !== built.source;
  const manifestChanged = manifestText !== readText(options.manifest);
  return { text, manifestText, changed: sourceChanged || manifestChanged, changes };
}

function main() {
  let options;
  try {
    options = parseArgs(process.argv.slice(2));
    const built = buildPlan(options);
    if (!built.plan.length) {
      console.error('没有找到可应用的线稿产物；先运行 blueprint_batch.py。');
      process.exit(1);
    }
    const applied = applyPlan(built, options);
    if (options.json) {
      console.log(JSON.stringify({ changed: applied.changed, hulls: applied.changes.filter((item) => item.id), manifest: applied.changes.filter((item) => item.manifestAsset) }, null, 2));
    } else {
      for (const hull of applied.changes.filter((item) => item.id)) {
        console.log(`[hull] ${hull.id} ← ${hull.model}`);
        for (const view of Object.keys(hull.views)) {
          console.log(`        ${view}: ${hull.views[view].image} ${hull.views[view].width}x${hull.views[view].height}`);
        }
        for (const socket of hull.sockets) {
          console.log(`        ${socket.socket}: side=${JSON.stringify(socket.blueprint.side)} top=${JSON.stringify(socket.blueprint.top)}`);
        }
      }
      for (const asset of applied.changes.filter((item) => item.manifestAsset)) {
        console.log(`[asset] ${asset.manifestAsset} → ${asset.path}`);
      }
    }
    if (options.check) {
      console.log(applied.changed ? 'blueprint content is out of date' : 'blueprint content is up to date');
      process.exit(applied.changed ? 1 : 0);
    }
    if (!applied.changed) {
      console.log('blueprint content is already up to date');
      return;
    }
    for (const entry of built.plan) {
      for (const copy of entry.copies) {
        fs.mkdirSync(path.dirname(copy.target), { recursive: true });
        fs.copyFileSync(copy.source, copy.target);
      }
    }
    fs.writeFileSync(options.hullContent, applied.text, 'utf8');
    fs.writeFileSync(options.manifest, applied.manifestText, 'utf8');
    console.log('wrote hulls.json, manifest.json and line-art PNG copies');
  } catch (error) {
    console.error(error.message);
    process.exit(2);
  }
}

main();
