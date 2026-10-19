/*
 * GLB thumbnail renderer for the Mod Maker asset cards.
 *
 * Renders one auto-framed, lit view of a parsed GLB with WebGL into an
 * offscreen canvas and returns a PNG data URL. One shared canvas/context is
 * reused and results are cached per asset so re-rendering the page is cheap.
 * This is intentionally not an interactive viewer: no orbit, animation or
 * texture decoding.
 *
 * Exposes `globalThis.SNModelThumb = { render, cached, forget }`.
 */
(function (root) {
  'use strict';

  const WIDTH = 480;
  const HEIGHT = 360;
  const CACHE = new Map();
  const UP = [0, 1, 0];
  const VIEW_DIRECTION = normalize([0.95, 0.62, 1.15]);

  let canvas = null;
  let gl = null;
  let program = null;
  let uniforms = null;
  let attributes = null;
  let supportsUint32 = false;

  function normalize(vector) {
    const length = Math.hypot(vector[0], vector[1], vector[2]) || 1;
    return [vector[0] / length, vector[1] / length, vector[2] / length];
  }

  function subtract(a, b) {
    return [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  }

  function cross(a, b) {
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  }

  function dot(a, b) {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  }

  function lookAt(eye, target, up) {
    const z = normalize(subtract(eye, target));
    const x = normalize(cross(up, z));
    const y = cross(z, x);
    return [
      x[0], y[0], z[0], 0,
      x[1], y[1], z[1], 0,
      x[2], y[2], z[2], 0,
      -dot(x, eye), -dot(y, eye), -dot(z, eye), 1,
    ];
  }

  function perspective(fieldOfView, aspect, near, far) {
    const f = 1 / Math.tan(fieldOfView / 2);
    return [
      f / aspect, 0, 0, 0,
      0, f, 0, 0,
      0, 0, (far + near) / (near - far), -1,
      0, 0, (2 * far * near) / (near - far), 0,
    ];
  }

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

  function compile(vertexSource, fragmentSource) {
    const vertex = gl.createShader(gl.VERTEX_SHADER);
    gl.shaderSource(vertex, vertexSource);
    gl.compileShader(vertex);
    if (!gl.getShaderParameter(vertex, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(vertex) || '顶点着色器编译失败');
    const fragment = gl.createShader(gl.FRAGMENT_SHADER);
    gl.shaderSource(fragment, fragmentSource);
    gl.compileShader(fragment);
    if (!gl.getShaderParameter(fragment, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(fragment) || '片元着色器编译失败');
    const shaderProgram = gl.createProgram();
    gl.attachShader(shaderProgram, vertex);
    gl.attachShader(shaderProgram, fragment);
    gl.linkProgram(shaderProgram);
    gl.deleteShader(vertex);
    gl.deleteShader(fragment);
    if (!gl.getProgramParameter(shaderProgram, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(shaderProgram) || '着色器链接失败');
    return shaderProgram;
  }

  function ensureContext() {
    if (gl) return true;
    if (typeof document === 'undefined') return false;
    canvas = document.createElement('canvas');
    canvas.width = WIDTH;
    canvas.height = HEIGHT;
    const options = { alpha: true, antialias: true, depth: true, preserveDrawingBuffer: true };
    gl = canvas.getContext('webgl2', options) || canvas.getContext('webgl', options) || canvas.getContext('experimental-webgl', options);
    if (!gl) return false;
    supportsUint32 = (typeof WebGL2RenderingContext !== 'undefined' && gl instanceof WebGL2RenderingContext)
      || Boolean(gl.getExtension('OES_element_index_uint'));
    program = compile(
      `attribute vec3 aPosition;
       attribute vec3 aNormal;
       uniform mat4 uMvp;
       varying vec3 vNormal;
       void main() {
         vNormal = aNormal;
         gl_Position = uMvp * vec4(aPosition, 1.0);
       }`,
      `precision mediump float;
       varying vec3 vNormal;
       uniform vec3 uColor;
       void main() {
         vec3 normal = normalize(vNormal);
         vec3 key = normalize(vec3(0.45, 0.8, 0.6));
         vec3 fill = normalize(vec3(-0.7, 0.3, -0.5));
         float light = 0.34 + max(dot(normal, key), 0.0) * 0.72 + max(dot(normal, fill), 0.0) * 0.32;
         vec3 base = pow(max(uColor, vec3(0.0)), vec3(0.35));
         vec3 color = pow(base * light, vec3(0.4545));
         gl_FragColor = vec4(color, 1.0);
       }`,
    );
    uniforms = { mvp: gl.getUniformLocation(program, 'uMvp'), color: gl.getUniformLocation(program, 'uColor') };
    attributes = {
      position: gl.getAttribLocation(program, 'aPosition'),
      normal: gl.getAttribLocation(program, 'aNormal'),
    };
    return true;
  }

  function drawPrimitive(primitive, mvp) {
    const positionBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, primitive.positions, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(attributes.position);
    gl.vertexAttribPointer(attributes.position, 3, gl.FLOAT, false, 0, 0);

    const normalBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, normalBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, primitive.normals, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(attributes.normal);
    gl.vertexAttribPointer(attributes.normal, 3, gl.FLOAT, false, 0, 0);

    gl.uniform3fv(uniforms.color, primitive.color);
    if (primitive.indices) {
      const indexBuffer = gl.createBuffer();
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer);
      gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, primitive.indices, gl.STATIC_DRAW);
      const wide = primitive.indices instanceof Uint32Array;
      if (wide && !supportsUint32) {
        gl.deleteBuffer(indexBuffer);
        gl.deleteBuffer(positionBuffer);
        gl.deleteBuffer(normalBuffer);
        return;
      }
      gl.drawElements(gl.TRIANGLES, primitive.indices.length, wide ? gl.UNSIGNED_INT : gl.UNSIGNED_SHORT, 0);
      gl.deleteBuffer(indexBuffer);
    } else {
      gl.drawArrays(gl.TRIANGLES, 0, primitive.positions.length / 3);
    }
    gl.deleteBuffer(positionBuffer);
    gl.deleteBuffer(normalBuffer);
  }

  function draw(model) {
    if (!ensureContext()) return null;
    gl.viewport(0, 0, WIDTH, HEIGHT);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.enable(gl.DEPTH_TEST);
    gl.disable(gl.CULL_FACE);
    gl.useProgram(program);

    const center = model.bbox.center;
    const radius = Math.max(model.bbox.radius, 0.001);
    const distance = radius / Math.tan((32 * Math.PI) / 360) * 1.18;
    const eye = [
      center[0] + VIEW_DIRECTION[0] * distance,
      center[1] + VIEW_DIRECTION[1] * distance,
      center[2] + VIEW_DIRECTION[2] * distance,
    ];
    const near = Math.max(radius * 0.02, 0.0001);
    const far = distance + radius * 12;
    const view = lookAt(eye, center, UP);
    const projection = perspective((32 * Math.PI) / 180, WIDTH / HEIGHT, near, far);
    const mvp = multiply(projection, view);
    gl.uniformMatrix4fv(uniforms.mvp, false, new Float32Array(mvp));

    for (const primitive of model.primitives) drawPrimitive(primitive, mvp);
    return canvas.toDataURL('image/png');
  }

  function cacheKey(asset) {
    const data = String(asset.dataUrl || '');
    return `${asset.path}|${data.length}|${data.slice(0, 48)}|${data.slice(-48)}`;
  }

  function cached(asset) {
    if (!asset) return null;
    return CACHE.get(cacheKey(asset)) || null;
  }

  function forget(path) {
    for (const key of [...CACHE.keys()]) {
      if (key.startsWith(`${path}|`)) CACHE.delete(key);
    }
  }

  function render(asset) {
    if (!asset || !asset.dataUrl) return null;
    const key = cacheKey(asset);
    if (CACHE.has(key)) return CACHE.get(key);
    if (!root.SNGLB) return null;
    const model = root.SNGLB.parse(root.SNStore.dataUrlToBytes(asset.dataUrl));
    const url = draw(model);
    if (url) CACHE.set(key, url);
    return url;
  }

  root.SNModelThumb = { render, cached, forget };
})(globalThis);
