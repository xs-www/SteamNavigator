// @static-doc
// 作用：为本地服务和 CLI 安全读取散装或 ZIP 形式的 SNBattleSim 模组，并导出游戏可识别的模组包。
//
// ## 契约与约束
// - 散装模组只处理 mods 的直接子目录；ZIP 必须只含一个 mods/<id>/manifest.json。
// - ZIP 限 128 MB 包体、2000 个条目和 64 MB 解压总量，拒绝 Zip64、加密、路径穿越与非 store/deflate 压缩。
// - 目录与 ZIP 导出均默认拒绝覆盖，由调用方生成唯一模组 ID。
// @end-static-doc
import fs from "node:fs";
import path from "node:path";
import { deflateRawSync, inflateRawSync } from "node:zlib";

const readJson = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const inside = (root, target) => target === root || target.startsWith(root + path.sep);
const ZIP_LOCAL = 0x04034b50; const ZIP_CENTRAL = 0x02014b50; const ZIP_EOCD = 0x06054b50;
const MAX_ARCHIVE_BYTES = 128 * 1024 * 1024; const MAX_ENTRIES = 2000; const MAX_UNCOMPRESSED_BYTES = 64 * 1024 * 1024;

let crcTableCache;
function crc32(buffer) {
  if (!crcTableCache) {
    crcTableCache = Array.from({ length: 256 }, (_, index) => {
      let value = index;
      for (let bit = 0; bit < 8; bit += 1) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
      return value >>> 0;
    });
  }
  let crc = 0xffffffff;
  for (const byte of buffer) crc = crcTableCache[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function zipPath(value) {
  const normalized = String(value || "").replaceAll("\\", "/").replace(/^\/+/, "");
  if (!normalized || normalized.includes(":") || normalized.includes("\0") || normalized.split("/").some((part) => !part || part === "." || part === "..")) throw new Error(`非法 ZIP 路径：${value}`);
  return normalized;
}

function findEocd(buffer) {
  const minimum = Math.max(0, buffer.length - 22 - 0xffff);
  for (let offset = buffer.length - 22; offset >= minimum; offset -= 1) if (buffer.readUInt32LE(offset) === ZIP_EOCD) return offset;
  return -1;
}

function readZipEntries(file) {
  if (fs.statSync(file).size > MAX_ARCHIVE_BYTES) throw new Error("ZIP 包体超过 128 MB 限制");
  const archive = fs.readFileSync(file); const eocd = findEocd(archive);
  if (eocd < 0) throw new Error("不是有效的 ZIP 文件（找不到中央目录）");
  const disk = archive.readUInt16LE(eocd + 4); const centralDisk = archive.readUInt16LE(eocd + 6);
  const diskCount = archive.readUInt16LE(eocd + 8); const count = archive.readUInt16LE(eocd + 10);
  const centralSize = archive.readUInt32LE(eocd + 12); const centralOffset = archive.readUInt32LE(eocd + 16);
  if (disk || centralDisk || diskCount !== count) throw new Error("不支持分卷 ZIP 包");
  if (count === 0xffff || centralSize === 0xffffffff || centralOffset === 0xffffffff) throw new Error("暂不支持 Zip64 包");
  if (count > MAX_ENTRIES) throw new Error(`ZIP 条目过多（${count}）`);
  if (centralOffset + centralSize > archive.length) throw new Error("ZIP 中央目录越界");
  const entries = new Map(); let cursor = centralOffset; let total = 0;
  for (let index = 0; index < count; index += 1) {
    if (cursor + 46 > archive.length || archive.readUInt32LE(cursor) !== ZIP_CENTRAL) throw new Error("ZIP 中央目录损坏");
    const flags = archive.readUInt16LE(cursor + 8); const method = archive.readUInt16LE(cursor + 10); const expectedCrc = archive.readUInt32LE(cursor + 16);
    const compressedSize = archive.readUInt32LE(cursor + 20); const uncompressedSize = archive.readUInt32LE(cursor + 24);
    const nameLength = archive.readUInt16LE(cursor + 28); const extraLength = archive.readUInt16LE(cursor + 30); const commentLength = archive.readUInt16LE(cursor + 32); const localOffset = archive.readUInt32LE(cursor + 42);
    const recordEnd = cursor + 46 + nameLength + extraLength + commentLength;
    if (recordEnd > archive.length) throw new Error("ZIP 中央目录越界");
    const rawName = archive.subarray(cursor + 46, cursor + 46 + nameLength).toString("utf8"); cursor = recordEnd;
    if (rawName.endsWith("/")) continue;
    const name = zipPath(rawName);
    if (flags & 1) throw new Error(`不支持加密 ZIP 条目：${name}`);
    if (compressedSize === 0xffffffff || uncompressedSize === 0xffffffff || localOffset === 0xffffffff) throw new Error("暂不支持 Zip64 包");
    if (localOffset + 30 > archive.length || archive.readUInt32LE(localOffset) !== ZIP_LOCAL) throw new Error(`ZIP 条目损坏：${name}`);
    const localNameLength = archive.readUInt16LE(localOffset + 26); const localExtraLength = archive.readUInt16LE(localOffset + 28); const dataStart = localOffset + 30 + localNameLength + localExtraLength;
    if (dataStart + compressedSize > archive.length) throw new Error(`ZIP 条目越界：${name}`);
    const compressed = archive.subarray(dataStart, dataStart + compressedSize); let data;
    if (method === 0) data = Buffer.from(compressed);
    else if (method === 8) data = inflateRawSync(compressed, { maxOutputLength: MAX_UNCOMPRESSED_BYTES - total });
    else throw new Error(`不支持的 ZIP 压缩方式 ${method}：${name}`);
    if (data.length !== uncompressedSize || crc32(data) !== expectedCrc) throw new Error(`ZIP 校验失败：${name}`);
    total += data.length;
    if (total > MAX_UNCOMPRESSED_BYTES) throw new Error("ZIP 解压后体积超过 64 MB 限制");
    if (entries.has(name)) throw new Error(`ZIP 包含重复路径：${name}`);
    entries.set(name, data);
  }
  return entries;
}

function packageFromZip(file, displayName) {
  const entries = readZipEntries(file);
  const manifests = [...entries.keys()].filter((name) => name === "manifest.json" || name.endsWith("/manifest.json"));
  if (manifests.length !== 1) throw new Error(`ZIP 必须且只能包含一个 manifest.json（当前 ${manifests.length} 个）`);
  const manifestPath = manifests[0];
  if (!/^mods\/[^/]+\/manifest\.json$/.test(manifestPath)) throw new Error(`ZIP manifest 路径必须是 mods/<mod_id>/manifest.json：${manifestPath}`);
  const prefix = manifestPath.slice(0, -"manifest.json".length); const pathId = prefix.split("/")[1];
  const manifest = JSON.parse(entries.get(manifestPath).toString("utf8"));
  if (String(manifest.id || "") !== pathId) throw new Error(`manifest.id 与 ZIP 路径不一致：${manifest.id || "(空)"} != ${pathId}`);
  const content = {};
  for (const relative of Array.isArray(manifest.content) ? manifest.content : []) {
    const safeRelative = zipPath(relative); const target = prefix + safeRelative;
    if (!entries.has(target)) throw new Error(`缺失内容文件：${relative}`);
    content[relative] = JSON.parse(entries.get(target).toString("utf8"));
  }
  return { directory: displayName, source: "zip", manifest, content };
}

export function readModPackages(modsRoot) {
  if (!fs.existsSync(modsRoot)) return [];
  return fs.readdirSync(modsRoot, { withFileTypes: true }).filter((entry) => entry.isDirectory() || (entry.isFile() && entry.name.toLowerCase().endsWith(".zip"))).sort((a, b) => a.name.localeCompare(b.name)).flatMap((entry) => {
    if (entry.isFile()) {
      try { return [packageFromZip(path.join(modsRoot, entry.name), entry.name)]; }
      catch (error) { return [{ directory: entry.name, source: "zip", error: error.message, manifest: { id: entry.name.replace(/(?:\.snavmod)?\.zip$/i, "") }, content: {} }]; }
    }
    const modRoot = path.resolve(modsRoot, entry.name); const manifestPath = path.join(modRoot, "manifest.json");
    if (!fs.existsSync(manifestPath)) return [];
    try {
      const manifest = readJson(manifestPath); const content = {};
      for (const relative of Array.isArray(manifest.content) ? manifest.content : []) {
        const target = path.resolve(modRoot, relative);
        if (!inside(modRoot, target) || !fs.existsSync(target)) throw new Error(`非法或缺失内容路径：${relative}`);
        content[relative] = readJson(target);
      }
      return [{ directory: entry.name, source: "directory", manifest, content }];
    } catch (error) { return [{ directory: entry.name, source: "directory", error: error.message, manifest: { id: entry.name }, content: {} }]; }
  });
}

export function writeModBundle(modsRoot, bundle) {
  const id = String(bundle?.manifest?.id || "").replace(/[^a-zA-Z0-9_-]/g, "_");
  if (!id) throw new Error("导出模组缺少合法 ID");
  const targetRoot = path.resolve(modsRoot, id); const resolvedMods = path.resolve(modsRoot);
  if (!inside(resolvedMods, targetRoot)) throw new Error("导出路径越界");
  if (fs.existsSync(targetRoot)) throw new Error(`模组目录已存在：${id}`);
  for (const [relative, value] of Object.entries(bundle.files || {})) {
    const target = path.resolve(targetRoot, relative);
    if (!inside(targetRoot, target)) throw new Error(`文件路径越界：${relative}`);
    fs.mkdirSync(path.dirname(target), { recursive: true }); fs.writeFileSync(target, `${JSON.stringify(value, null, 2)}\n`, "utf8");
  }
  return targetRoot;
}

export function writeModArchive(modsRoot, bundle) {
  const id = String(bundle?.manifest?.id || "").replace(/[^a-zA-Z0-9_-]/g, "_");
  if (!id) throw new Error("导出模组缺少合法 ID");
  const resolvedMods = path.resolve(modsRoot); const target = path.resolve(modsRoot, `${id}.snavmod.zip`);
  if (!inside(resolvedMods, target)) throw new Error("导出路径越界");
  if (fs.existsSync(target)) throw new Error(`模组包已存在：${path.basename(target)}`);
  const records = Object.entries(bundle.files || {}).map(([relative, value]) => {
    const name = `mods/${id}/${zipPath(relative)}`; const data = Buffer.from(`${JSON.stringify(value, null, 2)}\n`, "utf8");
    const compressed = deflateRawSync(data); const payload = compressed.length < data.length ? compressed : data;
    return { name: Buffer.from(name, "utf8"), data, payload, method: payload === data ? 0 : 8, crc: crc32(data) };
  });
  if (!records.length) throw new Error("导出模组没有文件");
  let localOffset = 0; const locals = []; const centrals = [];
  for (const record of records) {
    const local = Buffer.alloc(30 + record.name.length + record.payload.length);
    local.writeUInt32LE(ZIP_LOCAL, 0); local.writeUInt16LE(20, 4); local.writeUInt16LE(0x0800, 6); local.writeUInt16LE(record.method, 8);
    local.writeUInt32LE(record.crc, 14); local.writeUInt32LE(record.payload.length, 18); local.writeUInt32LE(record.data.length, 22); local.writeUInt16LE(record.name.length, 26);
    record.name.copy(local, 30); record.payload.copy(local, 30 + record.name.length); locals.push(local);
    const central = Buffer.alloc(46 + record.name.length);
    central.writeUInt32LE(ZIP_CENTRAL, 0); central.writeUInt16LE(20, 4); central.writeUInt16LE(20, 6); central.writeUInt16LE(0x0800, 8); central.writeUInt16LE(record.method, 10);
    central.writeUInt32LE(record.crc, 16); central.writeUInt32LE(record.payload.length, 20); central.writeUInt32LE(record.data.length, 24); central.writeUInt16LE(record.name.length, 28); central.writeUInt32LE(localOffset, 42);
    record.name.copy(central, 46); centrals.push(central); localOffset += local.length;
  }
  const centralSize = centrals.reduce((sum, record) => sum + record.length, 0); const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(ZIP_EOCD, 0); eocd.writeUInt16LE(records.length, 8); eocd.writeUInt16LE(records.length, 10); eocd.writeUInt32LE(centralSize, 12); eocd.writeUInt32LE(localOffset, 16);
  fs.mkdirSync(resolvedMods, { recursive: true }); fs.writeFileSync(target, Buffer.concat([...locals, ...centrals, eocd]));
  return target;
}
