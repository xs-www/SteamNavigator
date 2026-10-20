// @static-doc
// 作用：把战斗中单个武器挂载的冷却数据转换为舰船头顶装填条可直接使用的显示状态。
//
// ## 契约与约束
// - 冷却为零时返回“就绪”；装填中按一位小数显示剩余秒数。
// - progress 表示从刚开火的 0 到装填完成的 1，并始终限制在 0–1。
// @end-static-doc

function clamp(value, min, max) { return Math.max(min, Math.min(max, value)); }

export function mountReloadState(mount) {
  const duration = Math.max(0.001, Number(mount?.weapon?.cooldown) || 0.001);
  const remaining = Math.max(0, Number(mount?.cooldown) || 0);
  const ready = remaining <= 0.005;
  return {
    ready,
    remaining,
    progress: ready ? 1 : clamp(1 - remaining / duration, 0, 1),
    label: ready ? "就绪" : remaining.toFixed(1),
  };
}
