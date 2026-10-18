/*
 * Minimal ZIP reader/writer for .snavmod.zip packages.
 *
 * Zero dependencies: the browser's CompressionStream("deflate-raw") is used when
 * available, otherwise entries are stored uncompressed. No Zip64 support, with
 * explicit limits so a hostile package cannot exhaust memory.
 */
(function (root) {
  'use strict';

  const LOCAL_SIG = 0x04034b50;
  const CENTRAL_SIG = 0x02014b50;
  const EOCD_SIG = 0x06054b50;
  const UTF8_FLAG = 0x0800;
  const MAX_ENTRIES = 2000;
  const MAX_TOTAL_UNCOMPRESSED = 64 * 1024 * 1024;

  let CRC_TABLE = null;

  function crcTable() {
    if (CRC_TABLE) return CRC_TABLE;
    CRC_TABLE = new Uint32Array(256);
    for (let n = 0; n < 256; n += 1) {
      let c = n;
      for (let k = 0; k < 8; k += 1) {
        c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      }
      CRC_TABLE[n] = c >>> 0;
    }
    return CRC_TABLE;
  }

  function crc32(bytes) {
    const table = crcTable();
    let crc = 0xffffffff;
    for (let i = 0; i < bytes.length; i += 1) {
      crc = table[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);
    }
    return (crc ^ 0xffffffff) >>> 0;
  }

  function normalizePath(path) {
    const clean = String(path || '').replace(/\\/g, '/').replace(/^\/+/, '');
    if (!clean || clean.includes(':') || clean.includes('\0')
      || clean.split('/').some((part) => part === '' || part === '.' || part === '..')) {
      throw new Error(`非法 ZIP 路径: ${path}`);
    }
    return clean;
  }

  function dosDateTime(date) {
    const d = date || new Date();
    const year = Math.min(2107, Math.max(1980, d.getFullYear()));
    const time = (d.getHours() << 11) | (d.getMinutes() << 5) | Math.floor(d.getSeconds() / 2);
    const day = ((year - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate();
    return { time, day };
  }

  async function deflateRaw(bytes) {
    if (typeof CompressionStream === 'undefined' || bytes.length < 64) return null;
    try {
      const stream = new Blob([bytes]).stream().pipeThrough(new CompressionStream('deflate-raw'));
      const compressed = new Uint8Array(await new Response(stream).arrayBuffer());
      return compressed.length < bytes.length ? compressed : null;
    } catch (error) {
      return null;
    }
  }

  async function inflateRaw(bytes) {
    if (typeof DecompressionStream === 'undefined') {
      throw new Error('当前浏览器不支持解压 deflate 条目，请使用较新的 Chrome / Edge / Firefox。');
    }
    const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('deflate-raw'));
    return new Uint8Array(await new Response(stream).arrayBuffer());
  }

  function encodeText(text) {
    return new TextEncoder().encode(String(text));
  }

  /**
   * Build a ZIP archive.
   * @param {Array<{path:string,data:Uint8Array|string}>} entries
   * @returns {Promise<Uint8Array>}
   */
  async function build(entries) {
    if (!Array.isArray(entries) || entries.length === 0) {
      throw new Error('ZIP 内容为空');
    }
    const { time, day } = dosDateTime(new Date());
    const records = [];
    let offset = 0;

    for (const entry of entries) {
      const nameBytes = encodeText(normalizePath(entry.path));
      const raw = typeof entry.data === 'string' ? encodeText(entry.data) : new Uint8Array(entry.data);
      const crc = crc32(raw);
      const compressed = await deflateRaw(raw);
      const method = compressed ? 8 : 0;
      const payload = compressed || raw;

      const local = new Uint8Array(30 + nameBytes.length + payload.length);
      const lv = new DataView(local.buffer);
      lv.setUint32(0, LOCAL_SIG, true);
      lv.setUint16(4, 20, true);
      lv.setUint16(6, UTF8_FLAG, true);
      lv.setUint16(8, method, true);
      lv.setUint16(10, time, true);
      lv.setUint16(12, day, true);
      lv.setUint32(14, crc, true);
      lv.setUint32(18, payload.length, true);
      lv.setUint32(22, raw.length, true);
      lv.setUint16(26, nameBytes.length, true);
      lv.setUint16(28, 0, true);
      local.set(nameBytes, 30);
      local.set(payload, 30 + nameBytes.length);

      records.push({
        nameBytes,
        method,
        crc,
        compressedSize: payload.length,
        uncompressedSize: raw.length,
        offset,
        local,
      });
      offset += local.length;
    }

    const centralSize = records.reduce((sum, record) => sum + 46 + record.nameBytes.length, 0);
    const output = new Uint8Array(offset + centralSize + 22);
    let cursor = 0;
    for (const record of records) {
      output.set(record.local, cursor);
      cursor += record.local.length;
    }

    const centralOffset = cursor;
    for (const record of records) {
      const view = new DataView(output.buffer, cursor, 46);
      view.setUint32(0, CENTRAL_SIG, true);
      view.setUint16(4, 20, true);
      view.setUint16(6, 20, true);
      view.setUint16(8, UTF8_FLAG, true);
      view.setUint16(10, record.method, true);
      view.setUint16(12, time, true);
      view.setUint16(14, day, true);
      view.setUint32(16, record.crc, true);
      view.setUint32(20, record.compressedSize, true);
      view.setUint32(24, record.uncompressedSize, true);
      view.setUint16(28, record.nameBytes.length, true);
      view.setUint16(30, 0, true);
      view.setUint16(32, 0, true);
      view.setUint16(34, 0, true);
      view.setUint16(36, 0, true);
      view.setUint32(38, 0, true);
      view.setUint32(42, record.offset, true);
      output.set(record.nameBytes, cursor + 46);
      cursor += 46 + record.nameBytes.length;
    }

    const eocd = new DataView(output.buffer, cursor, 22);
    eocd.setUint32(0, EOCD_SIG, true);
    eocd.setUint16(4, 0, true);
    eocd.setUint16(6, 0, true);
    eocd.setUint16(8, records.length, true);
    eocd.setUint16(10, records.length, true);
    eocd.setUint32(12, centralSize, true);
    eocd.setUint32(16, centralOffset, true);
    eocd.setUint16(20, 0, true);
    return output;
  }

  function findEocd(view) {
    const min = Math.max(0, view.byteLength - 22 - 0xffff);
    for (let i = view.byteLength - 22; i >= min; i -= 1) {
      if (view.getUint32(i, true) === EOCD_SIG) return i;
    }
    return -1;
  }

  /**
   * Read a ZIP archive.
   * @param {Uint8Array|ArrayBuffer} input
   * @returns {Promise<Array<{path:string, data:Uint8Array}>>}
   */
  async function read(input) {
    const bytes = input instanceof Uint8Array ? input : new Uint8Array(input);
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const eocd = findEocd(view);
    if (eocd < 0) throw new Error('不是有效的 ZIP 文件（找不到中央目录）');
    const count = view.getUint16(eocd + 10, true);
    const centralSize = view.getUint32(eocd + 12, true);
    const centralOffset = view.getUint32(eocd + 16, true);
    if (count > MAX_ENTRIES) throw new Error(`ZIP 条目过多（${count}）`);
    if (centralOffset + centralSize > bytes.length) throw new Error('ZIP 中央目录越界');

    const decoder = new TextDecoder('utf-8');
    const entries = [];
    let cursor = centralOffset;
    let total = 0;

    for (let i = 0; i < count; i += 1) {
      if (view.getUint32(cursor, true) !== CENTRAL_SIG) throw new Error('ZIP 中央目录损坏');
      const method = view.getUint16(cursor + 10, true);
      const crc = view.getUint32(cursor + 16, true);
      const compressedSize = view.getUint32(cursor + 20, true);
      const uncompressedSize = view.getUint32(cursor + 24, true);
      const nameLength = view.getUint16(cursor + 28, true);
      const extraLength = view.getUint16(cursor + 30, true);
      const commentLength = view.getUint16(cursor + 32, true);
      const localOffset = view.getUint32(cursor + 42, true);
      const path = decoder.decode(bytes.subarray(cursor + 46, cursor + 46 + nameLength));
      cursor += 46 + nameLength + extraLength + commentLength;

      if (compressedSize === 0xffffffff || uncompressedSize === 0xffffffff || localOffset === 0xffffffff) {
        throw new Error('暂不支持 Zip64 包');
      }
      if (path.endsWith('/')) continue;

      if (view.getUint32(localOffset, true) !== LOCAL_SIG) throw new Error(`ZIP 条目损坏: ${path}`);
      const localNameLength = view.getUint16(localOffset + 26, true);
      const localExtraLength = view.getUint16(localOffset + 28, true);
      const dataStart = localOffset + 30 + localNameLength + localExtraLength;
      const compressed = bytes.subarray(dataStart, dataStart + compressedSize);

      let data;
      if (method === 0) {
        data = compressed;
      } else if (method === 8) {
        data = await inflateRaw(compressed);
      } else {
        throw new Error(`不支持的 ZIP 压缩方式 ${method}: ${path}`);
      }

      total += data.length;
      if (total > MAX_TOTAL_UNCOMPRESSED) throw new Error('ZIP 解压后体积超过 64 MB 限制');
      if (crc32(data) !== crc) throw new Error(`ZIP 校验失败: ${path}`);
      entries.push({ path: normalizePath(path), data });
    }
    return entries;
  }

  root.SNZip = { build, read, crc32, normalizePath };
})(typeof globalThis !== 'undefined' ? globalThis : this);
