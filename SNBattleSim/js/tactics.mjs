// @static-doc
// 作用：定义可随舰船配置保存的声明式战术状态机，并把战场量测转换为侦索、接近、交战、脱离或规避状态。
//
// ## 契约与约束
// - 战术配置只包含受限枚举、布尔值和限幅数值，不执行用户脚本。
// - 脱离状态使用进入/退出双阈值；低耐久仅在首次跌破阈值时触发，避免永久锁定。
// - 状态判定保持确定性；同一战场量测、前态与配置必须得到相同状态。
// - 旧配置缺少 tactic 时由 normalizeTactic 补齐默认战术。
// @end-static-doc

const clamp = (value, min, max, fallback) => Math.max(min, Math.min(max, Number.isFinite(Number(value)) ? Number(value) : fallback));

export const DEFAULT_TACTIC = Object.freeze({
  targetPriority: "cargo",
  chaseLastKnown: true,
  searchAction: "advance",
  preferredRange: 0.72,
  approachThreshold: 1.12,
  withdrawThreshold: 0.65,
  resumeThreshold: 0.92,
  retreatHull: 0.18,
  engageSpeed: 0.42,
  strafeSide: "auto",
  cargoBehavior: "flee",
});

export const TACTICAL_STATE_LABELS = Object.freeze({
  search: "侦索", approach: "接近", engage: "交战", withdraw: "脱离", evade: "规避",
});

export function normalizeTactic(value = {}) {
  const source = value || {};
  return {
    targetPriority: ["nearest", "cargo", "weakest"].includes(source.targetPriority) ? source.targetPriority : DEFAULT_TACTIC.targetPriority,
    chaseLastKnown: source.chaseLastKnown !== false,
    searchAction: ["advance", "hold"].includes(source.searchAction) ? source.searchAction : DEFAULT_TACTIC.searchAction,
    preferredRange: clamp(source.preferredRange, 0.4, 1, DEFAULT_TACTIC.preferredRange),
    approachThreshold: clamp(source.approachThreshold, 1.02, 1.5, DEFAULT_TACTIC.approachThreshold),
    withdrawThreshold: clamp(source.withdrawThreshold, 0.35, 0.9, DEFAULT_TACTIC.withdrawThreshold),
    resumeThreshold: clamp(source.resumeThreshold, 0.7, 1.3, DEFAULT_TACTIC.resumeThreshold),
    retreatHull: clamp(source.retreatHull, 0, 0.7, DEFAULT_TACTIC.retreatHull),
    engageSpeed: clamp(source.engageSpeed, 0, 0.8, DEFAULT_TACTIC.engageSpeed),
    strafeSide: ["auto", "port", "starboard"].includes(source.strafeSide) ? source.strafeSide : DEFAULT_TACTIC.strafeSide,
    cargoBehavior: ["flee", "escort"].includes(source.cargoBehavior) ? source.cargoBehavior : DEFAULT_TACTIC.cargoBehavior,
  };
}

export function tacticalDecision({ tactic: rawTactic, role, hullRatio, hasTarget, targetDistance = Infinity, maxRange = 120, threatened = false, wasThreatened = false, previousState = "search", previousReason = "", lowHullCrossed = false }) {
  const tactic = normalizeTactic(rawTactic);
  if (role === "cargo" && tactic.cargoBehavior === "flee" && (threatened || wasThreatened)) return { state: "evade", reason: "货船受威胁，驶离最近敌舰" };
  if (!hasTarget) return { state: "search", reason: tactic.searchAction === "advance" ? "无接触，向敌方搜索" : "无接触，原地待命" };
  const preferred = Math.max(60, maxRange * tactic.preferredRange);
  if (previousState === "withdraw" && targetDistance < preferred * tactic.resumeThreshold) {
    return { state: "withdraw", reason: previousReason.includes("耐久") ? "低耐久脱离至安全距离" : "近距脱离至恢复距离" };
  }
  if (lowHullCrossed && hullRatio <= tactic.retreatHull) return { state: "withdraw", reason: "耐久首次跌破阈值" };
  if (targetDistance < preferred * tactic.withdrawThreshold) return { state: "withdraw", reason: "目标进入近距脱离线" };
  if (targetDistance > preferred * tactic.approachThreshold) return { state: "approach", reason: "目标超出接近线" };
  return { state: "engage", reason: previousState === "withdraw" ? "已达到脱离退出距离" : "目标处于交战距离带" };
}

export function tacticalState(input) {
  return tacticalDecision(input).state;
}
