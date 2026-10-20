// @static-doc
// 作用：定义开发者模式 FSM 的状态动作、模块化条件、AND/OR 聚合转移和确定性状态转换。
//
// ## 契约与约束
// - 状态动作和条件来自稳定枚举；状态定义可导出供后续开发读取，但不执行用户脚本。
// - 每条转移包含 conditions 数组与 all/any 聚合方式；旧 condition 字段自动迁移为单条件数组。
// - 同一状态的转移按数组顺序判定，第一条满足者生效；图上限 20 状态、80 转移。
// @end-static-doc

const clamp = (value, min, max, fallback) => Math.max(min, Math.min(max, Number.isFinite(Number(value)) ? Number(value) : fallback));

export const FSM_ACTIONS = Object.freeze({
  recon: "侦察", cruise: "巡航", approach: "接近", flank: "迂回", evade: "规避",
  maneuver: "机动", withdraw: "脱离", flee: "逃跑", engage: "交火", focus: "集火",
});

export const FSM_ACTION_DESCRIPTIONS = Object.freeze({
  recon: "向最近敌人的最后消失位置移动",
  cruise: "沿己方默认方向巡航（蓝向右、红向左）",
  approach: "向视野内最近敌人移动",
  flank: "侧向绕开最近敌人，并远离敌方集群中心",
  evade: "背离近距离威胁",
  maneuver: "沿最近敌人的切向以最高速度机动",
  withdraw: "拉开与目标的距离",
  flee: "持续退出交战区域并离场",
  engage: "使用武器攻击；侧弦炮可用时优先调整舷侧",
  focus: "攻击指挥官指定目标；需要舰队指挥官",
});

export const FSM_STATE_DEFINITIONS = Object.freeze(Object.entries(FSM_ACTIONS).map(([id, name]) => Object.freeze({ id, name, description: FSM_ACTION_DESCRIPTIONS[id], runtimeAction: id })));

export const FSM_CONDITIONS = Object.freeze({
  cargo_threatened: "货船受到威胁", no_target: "没有任何目标", visible_target: "存在可见目标",
  last_known_target: "仅有最后已知目标", withdraw_trigger: "过近或首次低耐久",
  withdraw_recovered: "达到脱离退出线", enemy_in_range: "敌人在武器射程内",
  enemy_out_of_range: "敌人在武器射程外", weapon_ready: "任意武器已装填",
  broadside_ready: "侧弦炮已装填且目标在射程内", commander_present: "舰队存在指挥官",
  hull_below: "耐久低于撤退线", has_target: "存在目标", target_far: "目标超过接近线",
  target_band: "目标处于交战带", always: "始终",
});

export const DEFAULT_FSM_REVISION = 2;
const DEFAULT_NODES = [
  ["cruise", "巡航", "cruise", 0.14, 0.24], ["approach", "接近", "approach", 0.42, 0.24],
  ["engage", "交火", "engage", 0.73, 0.32], ["withdraw", "脱离", "withdraw", 0.63, 0.74],
  ["evade", "规避", "evade", 0.28, 0.74],
];
const DEFAULT_EDGES = [
  ["cruise", "evade", "cargo_threatened"], ["cruise", "approach", "has_target"],
  ["approach", "evade", "cargo_threatened"], ["approach", "withdraw", "withdraw_trigger"],
  ["approach", "engage", "enemy_in_range"], ["approach", "cruise", "no_target"], ["engage", "evade", "cargo_threatened"],
  ["engage", "withdraw", "withdraw_trigger"], ["engage", "approach", "enemy_out_of_range"],
  ["engage", "cruise", "no_target"], ["withdraw", "engage", "withdraw_recovered"], ["withdraw", "cruise", "no_target"],
  ["withdraw", "evade", "cargo_threatened"], ["evade", "cruise", "no_target"],
];

export function defaultFsm() {
  return {
    initial: "cruise",
    nodes: DEFAULT_NODES.map(([id, name, action, x, y]) => ({ id, name, action, x, y })),
    transitions: DEFAULT_EDGES.map(([from, to, condition], index) => ({ id: `edge_${index + 1}`, from, to, logic: "all", conditions: [condition] })),
  };
}

export function normalizeFsm(value) {
  if (!value || !Array.isArray(value.nodes) || !value.nodes.length) return defaultFsm();
  const ids = new Set();
  const nodes = value.nodes.slice(0, 20).map((node, index) => {
    let id = String(node?.id || `state_${index + 1}`).replace(/[^a-zA-Z0-9_-]/g, "_");
    while (ids.has(id)) id = `${id}_${index + 1}`;
    ids.add(id);
    const legacyAction = node?.action === "search" ? "cruise" : node?.action;
    const action = Object.hasOwn(FSM_ACTIONS, legacyAction) ? legacyAction : "engage";
    return { id, name: String(node?.name || FSM_ACTIONS[action]).slice(0, 24), action, x: clamp(node?.x, 0.08, 0.92, 0.5), y: clamp(node?.y, 0.08, 0.92, 0.5) };
  });
  const edgeIds = new Set();
  const transitions = (Array.isArray(value.transitions) ? value.transitions : []).slice(0, 80).flatMap((edge, index) => {
    if (!ids.has(edge?.from) || !ids.has(edge?.to)) return [];
    let id = String(edge?.id || `edge_${index + 1}`).replace(/[^a-zA-Z0-9_-]/g, "_");
    while (edgeIds.has(id)) id = `${id}_${index + 1}`;
    edgeIds.add(id);
    const rawConditions = Array.isArray(edge.conditions) ? edge.conditions : [edge.condition || "always"];
    const conditions = rawConditions.filter((condition) => Object.hasOwn(FSM_CONDITIONS, condition)).slice(0, 8);
    return [{ id, from: edge.from, to: edge.to, logic: edge.logic === "any" ? "any" : "all", conditions: conditions.length ? conditions : ["always"] }];
  });
  return { initial: ids.has(value.initial) ? value.initial : nodes[0].id, nodes, transitions };
}

export const DEFAULT_TACTIC = Object.freeze({ targetPriority: "cargo", chaseLastKnown: true, searchAction: "advance", preferredRange: 0.72, approachThreshold: 1.12, withdrawThreshold: 0.65, resumeThreshold: 0.92, retreatHull: 0.18, engageSpeed: 0.42, strafeSide: "auto", cargoBehavior: "flee" });
export const TACTICAL_STATE_LABELS = FSM_ACTIONS;

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
    fsm: normalizeFsm(source.fsm),
  };
}

function conditionResult(condition, context) {
  const { tactic, role, hasTarget, targetVisible, hasLastKnown, targetDistance, preferred, threatened, wasThreatened, lowHullCrossed, hullRatio, weaponReady, broadsideReady, commanderPresent } = context;
  if (condition === "cargo_threatened") return role === "cargo" && tactic.cargoBehavior === "flee" && (threatened || wasThreatened);
  if (condition === "no_target") return !hasTarget;
  if (condition === "has_target") return hasTarget;
  if (condition === "visible_target") return hasTarget && targetVisible;
  if (condition === "last_known_target") return hasTarget && !targetVisible && hasLastKnown;
  if (condition === "withdraw_trigger") return hasTarget && (lowHullCrossed || targetDistance < preferred * tactic.withdrawThreshold);
  if (condition === "withdraw_recovered") return hasTarget && targetDistance >= preferred * tactic.resumeThreshold;
  if (condition === "enemy_in_range" || condition === "target_band") return hasTarget && targetDistance >= preferred * tactic.withdrawThreshold && targetDistance <= preferred * tactic.approachThreshold;
  if (condition === "enemy_out_of_range" || condition === "target_far") return hasTarget && targetDistance > preferred * tactic.approachThreshold;
  if (condition === "weapon_ready") return weaponReady;
  if (condition === "broadside_ready") return broadsideReady;
  if (condition === "commander_present") return commanderPresent;
  if (condition === "hull_below") return hullRatio <= tactic.retreatHull;
  return condition === "always";
}

const CONDITION_REASONS = Object.freeze({ cargo_threatened: "货船受威胁", no_target: "没有可追踪目标", visible_target: "发现可见目标", last_known_target: "追踪最后已知位置", withdraw_trigger: "距离过近或首次跌破耐久阈值", withdraw_recovered: "已达到脱离退出距离", enemy_in_range: "敌人进入交火带", enemy_out_of_range: "敌人离开交火带", weapon_ready: "武器装填完成", broadside_ready: "侧弦炮具备攻击条件", commander_present: "舰队存在指挥官", hull_below: "耐久低于撤退线", has_target: "存在目标", target_far: "目标超过接近线", target_band: "目标处于交战带", always: "无条件" });

export function tacticalDecision({ tactic: rawTactic, role, hullRatio, hasTarget, targetVisible = hasTarget, hasLastKnown = false, targetDistance = Infinity, maxRange = 120, threatened = false, wasThreatened = false, previousState = "cruise", previousNodeId = "", lowHullCrossed = false, weaponReady = false, broadsideReady = false, commanderPresent = false }) {
  const tactic = normalizeTactic(rawTactic);
  const fsm = tactic.fsm;
  const legacyState = previousState === "search" ? "cruise" : previousState;
  const current = fsm.nodes.find((node) => node.id === previousNodeId) || fsm.nodes.find((node) => node.action === legacyState) || fsm.nodes.find((node) => node.id === fsm.initial) || fsm.nodes[0];
  const preferred = Math.max(60, maxRange * tactic.preferredRange);
  const context = { tactic, role, hasTarget, targetVisible, hasLastKnown, targetDistance, preferred, threatened, wasThreatened, lowHullCrossed, hullRatio, weaponReady, broadsideReady, commanderPresent };
  const edge = fsm.transitions.find((transition) => {
    if (transition.from !== current.id) return false;
    const results = transition.conditions.map((condition) => conditionResult(condition, context));
    return transition.logic === "any" ? results.some(Boolean) : results.every(Boolean);
  });
  const next = edge ? fsm.nodes.find((node) => node.id === edge.to) || current : current;
  const joiner = edge?.logic === "any" ? " 或 " : " 且 ";
  const reason = edge ? edge.conditions.map((condition) => CONDITION_REASONS[condition]).join(joiner) : `保持${current.name}`;
  return { state: next.action, nodeId: next.id, nodeName: next.name, reason, trigger: edge?.conditions[0] || null, triggers: edge?.conditions || [] };
}

export function tacticalState(input) {
  if (input.previousState || input.previousNodeId) return tacticalDecision(input).state;
  const tactic = normalizeTactic(input.tactic);
  const preferred = Math.max(60, (input.maxRange || 120) * tactic.preferredRange);
  const hasTarget = Boolean(input.hasTarget);
  if (input.role === "cargo" && tactic.cargoBehavior === "flee" && (input.threatened || input.wasThreatened)) return "evade";
  if (hasTarget && (input.lowHullCrossed || input.targetDistance < preferred * tactic.withdrawThreshold)) return "withdraw";
  if (!hasTarget) return "cruise";
  if (input.targetVisible === false) return "recon";
  return input.targetDistance > preferred * tactic.approachThreshold ? "approach" : "engage";
}
