/*
 * Minimal GLB (binary glTF 2.0) parser for thumbnail previews.
 *
 * Scope is deliberately small: it reads the scene graph, triangle primitives,
 * vertex positions/normals and material base colors. Textures, skinning,
 * morph targets, sparse accessors and compressed geometry are not decoded.
 * Unsupported details are skipped so a partly supported model still previews.
 *
 * Exposes `globalThis.SNGLB = { parse }`.
 */
(function (root) {
  'use strict';

  const COMPONENTS = {
    5120: { size: 1, read: (view, offset) => view.getInt8(offset) },
    5121: { size: 1, read: (view, offset) => view.getUint8(offset) },
    5122: { size: 2, read: (view, offset) => view.getInt16(offset, true) },
    5123: { size: 2, read: (view, offset) => view.getUint16(offset, true) },
    5125: { size: 4, read: (view, offset) => view.getUint32(offset, true) },
    5126: { size: 4, read: (view, offset) => view.getFloat32(offset, true) },
  };
  const TYPE_COMPONENTS = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT2: 4, MAT3: 9, MAT4: 16 };
  const GLB_MAGIC = 0x46546c67;
  const JSON_CHUNK = 0x4e4f534a;
  const BIN_CHUNK = 0x004e4942;

  function identity() {
    return [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
  }

  /* Column-major 4x4 multiply: returns a * b. */
  function multiply(a, b) {
    const out = new Array(16);
    for (let column = 0; column < 4; column += 1) {
      for (let row = 0; row < 4; row += 1) {
        out[column * 4 + row] =
          a[row] * b[column * 4] +
          a[4 + row] * b[column * 4 + 1] +
          a[8 + row] * b[column * 4 + 2] +
          a[12 + row] * b[column * 4 + 3];
      }
    }
    return out;
  }

  function fromTRS(node) {
    const t = node.translation || [0, 0, 0];
    const s = node.scale || [1, 1, 1];
    const q = node.rotation || [0, 0, 0, 1];
    const [x, y, z, w] = q;
    const x2 = x + x;
    const y2 = y + y;
    const z2 = z + z;
    const xx = x * x2;
    const xy = x * y2;
    const xz = x * z2;
    const yy = y * y2;
    const yz = y * z2;
    const zz = z * z2;
    const wx = w * x2;
    const wy = w * y2;
    const wz = w * z2;
    return [
      (1 - (yy + zz)) * s[0], (xy + wz) * s[0], (xz - wy) * s[0], 0,
      (xy - wz) * s[1], (1 - (xx + zz)) * s[1], (yz + wx) * s[1], 0,
      (xz + wy) * s[2], (yz - wx) * s[2], (1 - (xx + yy)) * s[2], 0,
      t[0], t[1], t[2], 1,
    ];
  }

  function localMatrix(node) {
    if (Array.isArray(node.matrix) && node.matrix.length === 16) return node.matrix.slice();
    return fromTRS(node);
  }

  function transformPoint(matrix, x, y, z) {
    return [
      matrix[0] * x + matrix[4] * y + matrix[8] * z + matrix[12],
      matrix[1] * x + matrix[5] * y + matrix[9] * z + matrix[13],
      matrix[2] * x + matrix[6] * y + matrix[10] * z + matrix[14],
    ];
  }

  function transformNormal(matrix, x, y, z) {
    const nx = matrix[0] * x + matrix[4] * y + matrix[8] * z;
    const ny = matrix[1] * x + matrix[5] * y + matrix[9] * z;
    const nz = matrix[2] * x + matrix[6] * y + matrix[10] * z;
    const length = Math.hypot(nx, ny, nz) || 1;
    return [nx / length, ny / length, nz / length];
  }

  function decodeDataUri(uri) {
    const comma = uri.indexOf(',');
    if (comma < 0) throw new Error('无效的数据 URI');
    const meta = uri.slice(0, comma);
    const body = uri.slice(comma + 1);
    if (/;base64/i.test(meta)) {
      const text = atob(body);
      const bytes = new Uint8Array(text.length);
      for (let i = 0; i < text.length; i += 1) bytes[i] = text.charCodeAt(i);
      return bytes;
    }
    return new TextEncoder().encode(decodeURIComponent(body));
  }

  function resolveBuffers(gltf, bin) {
    return (gltf.buffers || []).map((buffer, index) => {
      if (buffer.uri) {
        if (buffer.uri.startsWith('data:')) return decodeDataUri(buffer.uri);
        throw new Error(`不支持外部 buffer：${buffer.uri}`);
      }
      if (index === 0 && bin) return bin;
      return new Uint8Array(0);
    });
  }

  function readAccessor(gltf, buffers, index) {
    const accessor = gltf.accessors && gltf.accessors[index];
    if (!accessor) throw new Error(`缺少 accessor ${index}`);
    const components = TYPE_COMPONENTS[accessor.type];
    const component = COMPONENTS[accessor.componentType];
    if (!components || !component) throw new Error(`不支持的 accessor 类型 ${accessor.type}`);
    const values = accessor.count * components;
    const out = new Float32Array(values);
    if (accessor.bufferView == null) return out;
    const bufferView = gltf.bufferViews[accessor.bufferView];
    const source = buffers[bufferView.buffer || 0] || new Uint8Array(0);
    const view = new DataView(source.buffer, source.byteOffset, source.byteLength);
    const stride = bufferView.byteStride || component.size * components;
    const base = (bufferView.byteOffset || 0) + (accessor.byteOffset || 0);
    for (let element = 0; element < accessor.count; element += 1) {
      for (let part = 0; part < components; part += 1) {
        out[element * components + part] = component.read(view, base + element * stride + part * component.size);
      }
    }
    return out;
  }

  function materialColor(gltf, materialIndex) {
    const material = gltf.materials && gltf.materials[materialIndex];
    const pbr = material && material.pbrMetallicRoughness;
    const factor = pbr && Array.isArray(pbr.baseColorFactor) ? pbr.baseColorFactor : null;
    if (factor) return [factor[0], factor[1], factor[2]];
    return [0.62, 0.52, 0.36];
  }

  function buildPrimitive(gltf, buffers, primitive, world) {
    if (primitive.mode != null && primitive.mode !== 4) return null;
    const attributes = primitive.attributes || {};
    if (attributes.POSITION == null) return null;
    const sourcePositions = readAccessor(gltf, buffers, attributes.POSITION);
    const positions = new Float32Array(sourcePositions.length);
    for (let i = 0; i < sourcePositions.length; i += 3) {
      const point = transformPoint(world, sourcePositions[i], sourcePositions[i + 1], sourcePositions[i + 2]);
      positions[i] = point[0];
      positions[i + 1] = point[1];
      positions[i + 2] = point[2];
    }
    let normals;
    if (attributes.NORMAL != null) {
      const sourceNormals = readAccessor(gltf, buffers, attributes.NORMAL);
      normals = new Float32Array(sourceNormals.length);
      for (let i = 0; i < sourceNormals.length; i += 3) {
        const normal = transformNormal(world, sourceNormals[i], sourceNormals[i + 1], sourceNormals[i + 2]);
        normals[i] = normal[0];
        normals[i + 1] = normal[1];
        normals[i + 2] = normal[2];
      }
    } else {
      normals = new Float32Array(positions.length);
      for (let i = 0; i < normals.length; i += 3) normals[i + 2] = 1;
    }
    let indices = null;
    if (primitive.indices != null) {
      const source = readAccessor(gltf, buffers, primitive.indices);
      let highest = 0;
      for (let i = 0; i < source.length; i += 1) {
        if (source[i] > highest) highest = source[i];
      }
      indices = highest > 65535 ? new Uint32Array(source) : new Uint16Array(source);
    }
    return {
      positions,
      normals,
      indices,
      color: materialColor(gltf, primitive.material),
    };
  }

  function parse(input) {
    const bytes = input instanceof Uint8Array ? input : new Uint8Array(input);
    if (bytes.byteLength < 20) throw new Error('GLB 文件过短');
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    if (view.getUint32(0, true) !== GLB_MAGIC) throw new Error('不是 GLB 文件');
    const version = view.getUint32(4, true);
    if (version !== 2) throw new Error(`不支持的 glTF 版本 ${version}`);
    const totalLength = view.getUint32(8, true);
    let offset = 12;
    let json = null;
    let bin = null;
    while (offset + 8 <= Math.min(totalLength, bytes.byteLength)) {
      const chunkLength = view.getUint32(offset, true);
      const chunkType = view.getUint32(offset + 4, true);
      offset += 8;
      if (offset + chunkLength > bytes.byteLength) break;
      if (chunkType === JSON_CHUNK) {
        const text = new TextDecoder().decode(bytes.subarray(offset, offset + chunkLength));
        json = JSON.parse(text.replace(/\0+$/g, '').trim());
      } else if (chunkType === BIN_CHUNK) {
        bin = bytes.subarray(offset, offset + chunkLength);
      }
      offset += chunkLength;
    }
    if (!json) throw new Error('GLB 缺少 JSON chunk');
    const buffers = resolveBuffers(json, bin);
    const primitives = [];
    const min = [Infinity, Infinity, Infinity];
    const max = [-Infinity, -Infinity, -Infinity];
    let triangles = 0;

    const visit = (nodeIndex, parent) => {
      const node = json.nodes && json.nodes[nodeIndex];
      if (!node) return;
      const world = multiply(parent, localMatrix(node));
      if (node.mesh != null && json.meshes && json.meshes[node.mesh]) {
        for (const primitive of json.meshes[node.mesh].primitives || []) {
          const built = buildPrimitive(json, buffers, primitive, world);
          if (!built) continue;
          primitives.push(built);
          triangles += built.indices ? built.indices.length / 3 : built.positions.length / 9;
          for (let i = 0; i < built.positions.length; i += 3) {
            for (let axis = 0; axis < 3; axis += 1) {
              const value = built.positions[i + axis];
              if (value < min[axis]) min[axis] = value;
              if (value > max[axis]) max[axis] = value;
            }
          }
        }
      }
      for (const child of node.children || []) visit(child, world);
    };

    const scene = json.scenes && json.scenes[json.scene == null ? 0 : json.scene];
    if (scene && Array.isArray(scene.nodes) && scene.nodes.length) {
      for (const nodeIndex of scene.nodes) visit(nodeIndex, identity());
    } else if (json.nodes) {
      const children = new Set();
      for (const node of json.nodes) {
        for (const child of node.children || []) children.add(child);
      }
      for (let index = 0; index < json.nodes.length; index += 1) {
        if (!children.has(index)) visit(index, identity());
      }
    }

    if (!primitives.length) throw new Error('GLB 中没有可预览的三角形网格');
    const center = [(min[0] + max[0]) / 2, (min[1] + max[1]) / 2, (min[2] + max[2]) / 2];
    const size = [max[0] - min[0], max[1] - min[1], max[2] - min[2]];
    return {
      primitives,
      triangles: Math.round(triangles),
      materials: json.materials ? json.materials.length : 0,
      nodes: json.nodes ? json.nodes.length : 0,
      bbox: { min, max, center, size, radius: Math.hypot(size[0], size[1], size[2]) / 2 },
    };
  }

  root.SNGLB = { parse };
})(globalThis);
