// @static-doc
// 作用：为无限 2D 战场计算能容纳全部在场舰船的跟随镜头，并提供世界坐标到画布坐标的转换。
//
// ## 契约与约束
// - 镜头只改变表现，不参与战斗物理或逃脱判定。
// - 取景范围来自全部未脱离战场的舰船；失能船仍属于战场并保留在画面中。
// - 镜头中心与缩放平滑追随目标包围盒，初次取景可以直接吸附。
// @end-static-doc

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

export function createCamera() {
  return { x: 0, y: 0, zoom: 1, initialized: false };
}

export function cameraTarget(ships, width, height, padding = 86) {
  const visible = ships.filter((ship) => !ship.escaped);
  if (!visible.length) return { x: 0, y: 0, zoom: 1 };
  const xs = visible.map((ship) => ship.x);
  const ys = visible.map((ship) => ship.y);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);
  const spanX = Math.max(80, maxX - minX);
  const spanY = Math.max(80, maxY - minY);
  const usableWidth = Math.max(80, width - padding * 2);
  const usableHeight = Math.max(80, height - padding * 2);
  return {
    x: (minX + maxX) / 2,
    y: (minY + maxY) / 2,
    zoom: clamp(Math.min(usableWidth / spanX, usableHeight / spanY), 0.18, 1.45),
  };
}

export function updateCamera(camera, ships, width, height, smoothing = 0.09) {
  const target = cameraTarget(ships, width, height);
  if (!camera.initialized) {
    Object.assign(camera, target, { initialized: true });
    return camera;
  }
  const alpha = clamp(smoothing, 0, 1);
  camera.x += (target.x - camera.x) * alpha;
  camera.y += (target.y - camera.y) * alpha;
  camera.zoom += (target.zoom - camera.zoom) * alpha;
  return camera;
}

export function worldToScreen(camera, point, width, height) {
  return {
    x: width / 2 + (point.x - camera.x) * camera.zoom,
    y: height / 2 + (point.y - camera.y) * camera.zoom,
  };
}

export function screenWorldBounds(camera, width, height) {
  return {
    minX: camera.x - width / (2 * camera.zoom),
    maxX: camera.x + width / (2 * camera.zoom),
    minY: camera.y - height / (2 * camera.zoom),
    maxY: camera.y + height / (2 * camera.zoom),
  };
}
