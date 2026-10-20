// @static-doc
// 作用：执行确定性的 2D 俯视角舰队战斗，处理视野接触、货船行为、多武器冷却、炮弹飞行与战斗终局。
//
// ## 契约与约束
// - 战斗使用无限世界坐标，不存在地图边缘；镜头取景属于表现层。
// - 战斗只读取已校验装配快照，不修改装配器中的舰队配置。
// - 舰船丢失视野后会追向短时最后已知位置；直射要求当前视野，炮击可对新鲜的最后已知位置盲射。
// - 每个武器挂载拥有独立冷却；侧弦炮只在左右舷射界内以多发齐射开火；所有机动状态下均会尝试合法开火。
// - 舰船机动与目标选择读取自身 tactic 配置，状态机本身不执行任意脚本。
// - 相同 seed、装配与 tick 序列必须产生相同结果。
// @end-static-doc

import { deriveShipStats, validateShip } from "./loadout.mjs";
import { normalizeTactic, tacticalDecision } from "./tactics.mjs";

const TAU = Math.PI * 2;

function clamp(value, min, max) { return Math.max(min, Math.min(max, value)); }
function distance(a, b) { return Math.hypot(a.x - b.x, a.y - b.y); }
function angleDelta(a, b) {
  let value = a - b;
  while (value > Math.PI) value -= TAU;
  while (value < -Math.PI) value += TAU;
  return value;
}

export function seededRandom(seed = 1) {
  let state = seed >>> 0;
  return () => {
    state += 0x6d2b79f5;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

function runtimeShip(config, faction, index, weaponCatalog, sensorCatalog) {
  const stats = deriveShipStats(config, weaponCatalog, sensorCatalog);
  const tactic = normalizeTactic(config.tactic);
  const initialNode = tactic.fsm.nodes.find((node) => node.id === tactic.fsm.initial) || tactic.fsm.nodes[0];
  const left = faction === 0;
  return {
    uid: `${faction}:${config.id}:${index}`, config, faction, stats,
    x: left ? -260 - index * 22 : 260 + index * 22,
    y: -90 + index * 118,
    vx: 0, vy: 0, heading: left ? 0 : Math.PI,
    velocityHeading: left ? 0 : Math.PI, speedCurrent: 0, angularVelocity: 0,
    hull: stats.hullMax, escaped: false, disabled: false, targetUid: null,
    tactic, tacticalNodeId: initialNode.id, tacticalNodeName: initialNode.name,
    tacticalState: initialNode.action, tacticalReason: "初始状态",
    lowHullRetreatTriggered: false,
    mounts: stats.weapons.map((weapon, mountIndex) => ({ weapon, mountIndex, cooldown: mountIndex * 0.18 })),
    shots: 0, hits: 0, damage: 0, detected: false, wasThreatened: false, threatenedUntil: 0,
  };
}

export class BattleSimulation {
  constructor({ fleets, weaponCatalog, sensorCatalog, seed = 5201 }) {
    this.weaponCatalog = weaponCatalog;
    this.sensorCatalog = sensorCatalog;
    this.rng = seededRandom(seed);
    this.time = 0;
    this.state = "engaging";
    this.winner = null;
    this.events = [];
    this.projectiles = [];
    this.contacts = [new Map(), new Map()];
    this.ships = [];
    fleets.forEach((fleet, faction) => fleet.forEach((config, index) => {
      const errors = validateShip(config, weaponCatalog, sensorCatalog);
      if (errors.length) throw new Error(`${config.name}：${errors.join("；")}`);
      this.ships.push(runtimeShip(config, faction, index, weaponCatalog, sensorCatalog));
    }));
    this._scanContacts();
  }

  living(faction = null) {
    return this.ships.filter((ship) => !ship.disabled && !ship.escaped && (faction === null || ship.faction === faction));
  }

  contactFor(viewerFaction, targetUid) {
    return this.contacts[viewerFaction].get(targetUid) || null;
  }

  _scanContacts() {
    for (let faction = 0; faction < 2; faction += 1) {
      const observers = this.living(faction);
      const enemies = this.living(1 - faction);
      const seenNow = new Set();
      for (const enemy of enemies) {
        let best = Infinity;
        let spotted = false;
        for (const observer of observers) {
          const d = distance(observer, enemy);
          const effectiveRange = observer.stats.vision / Math.max(0.65, enemy.stats.signature);
          if (d <= effectiveRange) { spotted = true; best = Math.min(best, d); }
        }
        if (spotted) {
          seenNow.add(enemy.uid);
          this.contacts[faction].set(enemy.uid, { visible: true, x: enemy.x, y: enemy.y, seenAt: this.time, distance: best });
        }
      }
      for (const [uid, contact] of this.contacts[faction]) {
        if (seenNow.has(uid)) continue;
        const age = this.time - contact.seenAt;
        if (age > 7) this.contacts[faction].delete(uid);
        else contact.visible = false;
      }
    }
  }

  _chooseTarget(ship, options = {}) {
    const candidates = this.living(1 - ship.faction).map((enemy) => {
      const contact = this.contactFor(ship.faction, enemy.uid);
      if (!contact || (!contact.visible && !ship.tactic.chaseLastKnown)) return null;
      if (options.visibleOnly && !contact.visible) return null;
      if (options.lastKnownOnly && contact.visible) return null;
      return { ship: enemy, contact, visible: contact.visible, x: contact.visible ? enemy.x : contact.x, y: contact.visible ? enemy.y : contact.y };
    }).filter(Boolean);
    if (!candidates.length) return null;
    if (options.uid) {
      const assigned = candidates.find((candidate) => candidate.ship.uid === options.uid);
      if (assigned) return assigned;
    }
    candidates.sort((a, b) => {
      const score = (candidate) => distance(ship, candidate) * (ship.tactic.targetPriority === "weakest" ? 0.35 : 1)
        + (ship.tactic.targetPriority === "cargo" && candidate.ship.config.role === "cargo" ? -240 : 0)
        + (ship.tactic.targetPriority === "weakest" ? candidate.ship.hull / candidate.ship.stats.hullMax * 220 : 0)
        + (candidate.visible ? 0 : 65)
        + (candidate.ship.uid === ship.targetUid ? -45 : 0);
      return score(a) - score(b);
    });
    return candidates[0];
  }

  _steer(ship, target, dt) {
    let desiredHeading = ship.heading;
    let desiredSpeed = 0;
    const enemies = this.living(1 - ship.faction);
    const threats = enemies.filter((enemy) => distance(ship, enemy) < ship.stats.vision * 0.9);
    if (threats.length) ship.threatenedUntil = this.time + 3;
    ship.wasThreatened = this.time < ship.threatenedUntil;
    const maxRange = Math.max(...ship.stats.weapons.map((weapon) => weapon.range), 120);
    const targetDistance = target ? distance(ship, target) : Infinity;
    const hullRatio = ship.hull / ship.stats.hullMax;
    const lowHullCrossed = !ship.lowHullRetreatTriggered && hullRatio <= ship.tactic.retreatHull;
    const weaponReady = ship.mounts.some((mount) => mount.cooldown <= 0);
    const broadsideReady = Boolean(target && ship.mounts.some((mount) => mount.cooldown <= 0 && mount.weapon.kind === "broadside" && targetDistance >= mount.weapon.minRange && targetDistance <= mount.weapon.range));
    const commanderPresent = this.living(ship.faction).some((ally) => ally.config.isCommander);
    const decision = tacticalDecision({
      tactic: ship.tactic, role: ship.config.role, hullRatio: ship.hull / ship.stats.hullMax,
      hasTarget: Boolean(target), targetDistance, maxRange, threatened: threats.length > 0, wasThreatened: ship.wasThreatened,
      targetVisible: Boolean(target?.visible), hasLastKnown: Boolean(target && !target.visible),
      previousState: ship.tacticalState, previousNodeId: ship.tacticalNodeId, previousReason: ship.tacticalReason, lowHullCrossed,
      weaponReady, broadsideReady, commanderPresent,
    });
    ship.tacticalState = decision.state;
    ship.tacticalNodeId = decision.nodeId;
    ship.tacticalNodeName = decision.nodeName;
    ship.tacticalReason = decision.reason;
    if (lowHullCrossed && decision.trigger === "withdraw_trigger") ship.lowHullRetreatTriggered = true;

    if (ship.tacticalState === "evade" || ship.tacticalState === "flee") {
      const nearest = [...enemies].sort((a, b) => distance(ship, a) - distance(ship, b))[0];
      if (nearest) {
        const separation = distance(ship, nearest);
        if (ship.tacticalState === "flee" && separation > Math.max(560, ship.stats.vision * 1.08)) {
          ship.escaped = true;
          this.events.push({ type: "escaped", time: this.time, ship });
          return;
        }
        desiredHeading = Math.atan2(ship.y - nearest.y, ship.x - nearest.x);
        desiredSpeed = ship.stats.speed;
      }
    } else if ((ship.tacticalState === "approach" || ship.tacticalState === "recon") && target) {
      desiredHeading = Math.atan2(target.y - ship.y, target.x - ship.x);
      desiredSpeed = ship.stats.speed * (ship.tacticalState === "recon" ? 0.72 : 1);
    } else if (ship.tacticalState === "flank" && target) {
      const center = enemies.reduce((sum, enemy) => ({ x: sum.x + enemy.x / enemies.length, y: sum.y + enemy.y / enemies.length }), { x: 0, y: 0 });
      const bearing = Math.atan2(target.y - ship.y, target.x - ship.x);
      const side = Math.sin(angleDelta(Math.atan2(ship.y - center.y, ship.x - center.x), bearing)) >= 0 ? 1 : -1;
      const tangent = bearing + side * Math.PI / 2;
      const away = Math.atan2(ship.y - center.y, ship.x - center.x);
      desiredHeading = Math.atan2(Math.sin(tangent) * 0.72 + Math.sin(away) * 0.28, Math.cos(tangent) * 0.72 + Math.cos(away) * 0.28);
      desiredSpeed = ship.stats.speed * 0.9;
    } else if (ship.tacticalState === "maneuver" && target) {
      const bearing = Math.atan2(target.y - ship.y, target.x - ship.x);
      const side = ship.tactic.strafeSide === "port" ? -1 : ship.tactic.strafeSide === "starboard" ? 1 : (ship.faction ? -1 : 1);
      desiredHeading = bearing + side * Math.PI / 2;
      desiredSpeed = ship.stats.speed;
    } else if (ship.tacticalState === "withdraw" && target) {
      desiredHeading = Math.atan2(target.y - ship.y, target.x - ship.x) + Math.PI;
      desiredSpeed = ship.stats.speed * 0.72;
    } else if ((ship.tacticalState === "engage" || ship.tacticalState === "focus") && target) {
      const angle = Math.atan2(target.y - ship.y, target.x - ship.x);
      const side = ship.tactic.strafeSide === "port" ? -1 : ship.tactic.strafeSide === "starboard" ? 1 : (ship.faction ? -1 : 1);
      const hasReadyBroadside = ship.mounts.some((mount) => mount.cooldown <= 0 && mount.weapon.kind === "broadside" && targetDistance >= mount.weapon.minRange && targetDistance <= mount.weapon.range);
      desiredHeading = hasReadyBroadside ? angle + side * Math.PI / 2 : angle;
      desiredSpeed = ship.stats.speed * ship.tactic.engageSpeed;
    } else {
      desiredHeading = ship.faction === 0 ? 0 : Math.PI;
      desiredSpeed = ship.tactic.searchAction === "advance" ? ship.stats.speed * 0.58 : 0;
    }

    const headingError = angleDelta(desiredHeading, ship.heading);
    const speedRatio = clamp(ship.speedCurrent / Math.max(1, ship.stats.speed), 0, 1);
    const turnAuthority = 0.32 + speedRatio * 0.68;
    const desiredAngularVelocity = clamp(headingError * 0.55, -ship.stats.turnRate * turnAuthority, ship.stats.turnRate * turnAuthority);
    const angularStep = ship.stats.rudderResponse * dt;
    ship.angularVelocity += clamp(desiredAngularVelocity - ship.angularVelocity, -angularStep, angularStep);
    ship.heading += ship.angularVelocity * dt;

    const alignment = Math.max(0, Math.cos(angleDelta(desiredHeading, ship.velocityHeading)));
    const alignedDesiredSpeed = desiredSpeed * alignment;
    const speedStep = ship.stats.acceleration * (alignedDesiredSpeed < ship.speedCurrent ? 0.8 : 1) * dt;
    ship.speedCurrent += clamp(alignedDesiredSpeed - ship.speedCurrent, -speedStep, speedStep);
    const velocityTurn = ship.stats.turnRate * (0.22 + speedRatio * 0.28) * dt;
    ship.velocityHeading += clamp(angleDelta(ship.heading, ship.velocityHeading), -velocityTurn, velocityTurn);
    const slip = angleDelta(ship.heading, ship.velocityHeading);
    const maxSlip = 78 * Math.PI / 180;
    if (Math.abs(slip) > maxSlip) ship.velocityHeading = ship.heading - Math.sign(slip) * maxSlip;
    ship.vx = Math.cos(ship.velocityHeading) * ship.speedCurrent;
    ship.vy = Math.sin(ship.velocityHeading) * ship.speedCurrent;
    ship.x += ship.vx * dt;
    ship.y += ship.vy * dt;
  }

  _fire(ship, target) {
    if (!target) return;
    const d = distance(ship, target);
    const bearing = Math.atan2(target.y - ship.y, target.x - ship.x);
    for (const mount of ship.mounts) {
      if (mount.cooldown > 0) continue;
      const weapon = mount.weapon;
      const contactAge = this.time - target.contact.seenAt;
      const canBlindFire = weapon.kind === "artillery" && contactAge <= 3.5;
      if (!target.visible && !canBlindFire) continue;
      if (d < weapon.minRange || d > weapon.range) continue;
      const relativeBearing = Math.abs(angleDelta(bearing, ship.heading));
      const inArc = weapon.kind === "broadside"
        ? Math.abs(relativeBearing - Math.PI / 2) <= weapon.arc * Math.PI / 360
        : relativeBearing <= weapon.arc * Math.PI / 360;
      if (!inArc) continue;
      mount.cooldown = weapon.cooldown;
      const flightTime = Math.max(0.08, d / weapon.projectileSpeed);
      const salvo = weapon.salvo || 1;
      ship.shots += salvo;
      for (let shot = 0; shot < salvo; shot += 1) {
        const spread = (shot - (salvo - 1) / 2) * (weapon.kind === "broadside" ? 3.2 : 0);
        this.projectiles.push({
          faction: ship.faction, source: ship, targetUid: target.ship.uid, weapon,
          x: ship.x, y: ship.y, startX: ship.x, startY: ship.y,
          targetX: target.x + (target.visible ? target.ship.vx : 0) * flightTime * (weapon.kind === "artillery" ? 0.62 : 0.25) + spread,
          targetY: target.y + (target.visible ? target.ship.vy : 0) * flightTime * (weapon.kind === "artillery" ? 0.62 : 0.25) - spread,
          age: -shot * 0.045, flightTime, blindFire: !target.visible,
        });
      }
      this.events.push({ type: "fired", time: this.time, ship, target: target.ship, weapon });
    }
  }

  _resolveProjectile(projectile) {
    const weapon = projectile.weapon;
    const target = this.ships.find((ship) => ship.uid === projectile.targetUid);
    const candidates = this.living(1 - projectile.faction).filter((ship) => {
      const missRadius = weapon.splash > 0 ? weapon.splash + ship.stats.radius : ship.stats.radius * 1.35;
      return Math.hypot(ship.x - projectile.targetX, ship.y - projectile.targetY) <= missRadius;
    });
    const intended = candidates.includes(target) ? target : candidates[0];
    if (!intended) {
      this.events.push({ type: "missed", time: this.time, projectile });
      return;
    }
    const travel = Math.hypot(projectile.targetX - projectile.startX, projectile.targetY - projectile.startY);
    const rangePenalty = clamp(travel / weapon.range, 0, 1) * 0.22;
    const evasion = Math.hypot(intended.vx, intended.vy) / Math.max(1, intended.stats.speed) * 0.2;
    const chance = clamp(weapon.accuracy + projectile.source.stats.accuracyBonus - rangePenalty - evasion - (projectile.blindFire ? 0.2 : 0), 0.08, 0.96);
    if (this.rng() > chance) {
      this.events.push({ type: "missed", time: this.time, projectile });
      return;
    }
    const armorFactor = 100 / (100 + intended.stats.armor);
    const splashFactor = weapon.splash > 0
      ? clamp(1 - distance(intended, { x: projectile.targetX, y: projectile.targetY }) / (weapon.splash + intended.stats.radius), 0.35, 1)
      : 1;
    const damage = weapon.damage * armorFactor * splashFactor;
    intended.hull = Math.max(0, intended.hull - damage);
    projectile.source.hits += 1;
    projectile.source.damage += damage;
    if (intended.hull <= 0) {
      intended.disabled = true;
      intended.vx = 0; intended.vy = 0;
      this.events.push({ type: "disabled", time: this.time, ship: intended, attacker: projectile.source });
    } else this.events.push({ type: "hit", time: this.time, ship: intended, attacker: projectile.source, weapon, damage });
  }

  _tickProjectiles(dt) {
    const remaining = [];
    for (const projectile of this.projectiles) {
      projectile.age += dt;
      if (projectile.age < 0) { remaining.push(projectile); continue; }
      const progress = clamp(projectile.age / projectile.flightTime, 0, 1);
      projectile.x = projectile.startX + (projectile.targetX - projectile.startX) * progress;
      projectile.y = projectile.startY + (projectile.targetY - projectile.startY) * progress;
      if (progress >= 1) this._resolveProjectile(projectile);
      else remaining.push(projectile);
    }
    this.projectiles = remaining;
  }

  _checkEnd() {
    const able = [0, 1].map((faction) => this.living(faction).filter((ship) => ship.config.role === "combat"));
    if (able[0].length && able[1].length && this.time < 240) return;
    this.state = "finalized";
    if (able[0].length === able[1].length) this.winner = null;
    else this.winner = able[0].length > able[1].length ? 0 : 1;
    this.events.push({ type: "finalized", time: this.time, winner: this.winner });
  }

  tick(dt) {
    if (this.state !== "engaging") return;
    const step = clamp(dt, 0, 0.1);
    this.time += step;
    this._scanContacts();
    this.focusTargets = [0, 1].map((faction) => {
      const commander = this.living(faction).find((ship) => ship.config.isCommander);
      return commander ? this._chooseTarget(commander, { visibleOnly: true })?.ship.uid || null : null;
    });
    for (const ship of this.living()) {
      for (const mount of ship.mounts) mount.cooldown = Math.max(0, mount.cooldown - step);
      const options = ship.tacticalState === "focus" ? { visibleOnly: true, uid: this.focusTargets[ship.faction] } : {};
      const target = this._chooseTarget(ship, options);
      ship.targetUid = target?.ship.uid || null;
      this._steer(ship, target, step);
      // 状态只决定机动；任何状态下只要存在合法射界和可用武器就继续开火。
      this._fire(ship, target);
    }
    this._tickProjectiles(step);
    this._scanContacts();
    this._checkEnd();
  }

  summary() {
    return [0, 1].map((faction) => {
      const ships = this.ships.filter((ship) => ship.faction === faction);
      return {
        faction,
        afloat: ships.filter((ship) => !ship.disabled && !ship.escaped).length,
        disabled: ships.filter((ship) => ship.disabled).length,
        escapedCargo: ships.filter((ship) => ship.escaped && ship.config.role === "cargo").length,
        cargoSaved: ships.filter((ship) => !ship.disabled && (ship.escaped || this.state === "finalized") && ship.config.role === "cargo")
          .reduce((sum, ship) => sum + ship.config.cargoValue, 0),
        damage: ships.reduce((sum, ship) => sum + ship.damage, 0),
      };
    });
  }
}
