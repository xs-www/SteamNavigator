# -*- coding: utf-8 -*-
# @static-doc
# 作用：`combat_kit` 敌舰套件（M2-1，4 艘）生成器的纯 Python 干跑 —— 不进 Blender，
# 直接加载 `combat_kit_generator.py` 的几何与规格表，核对：
# - 命名 / 对象前缀 / 父级键（ROOT 或 Pivot key）/ 集合内无重名；
# - 每艘 tri 预算、包围盒（含 target ± tol）、吃水（zmin）/ 桅顶（zmax）合理；
# - 网格健康：非流形边 / 退化面 / 孤立点全 0；闭合件边界边 0；开放件（甲板 / 帆面）
#   允许边界边但必须 > 0（确实是单层面）；
# - 材质白名单：全部是 `SN_Tex_*` 共享贴图材质，无旧纯色 / 未声明材质；
# - socket 规格：class 合法、左右镜像、y 在甲板内、clearance 口径；
# - 炮门规格：8 个 / port_class 与开口能接 `SN_Weapon_CasemateGun`（Medium 1.9×1.9）。
#
# 用法：
#     python tools/modeling/generators/dryrun_combat_kit.py
#     python tools/modeling/generators/dryrun_combat_kit.py SN_Enemy_Gunboat
# @end-static-doc

import json
import math
import os
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import combat_kit_generator as ck  # noqa: E402

OPEN_PART_MARKERS = ("_Deck", "_Sails", "_Headsails")


def is_open_part(name):
    return name.endswith("_Deck") or "_Sails" in name or name.endswith("_Headsails")


def transform_parts(parts, cfg):
    """复刻 Blender 装配：Pivot 子件按 Pivot 的旋转 + 位移变换到根坐标。"""
    pivots = {pivot.key: pivot for pivot in cfg["pivots"]}
    out = {}
    for name, (part, parent) in parts.items():
        if parent == "ROOT" or parent not in pivots:
            out[name] = part
            continue
        pivot = pivots[parent]
        rotation = pivot.rotation
        location = pivot.location
        assert abs(rotation[0]) < 1e-9 and abs(rotation[2]) < 1e-9, \
            "干跑只支持绕 Y 的 Pivot 旋转"
        angle = rotation[1]
        ca, sa = math.cos(angle), math.sin(angle)
        moved = type(part)()
        moved.faces = part.faces
        moved.recalc = part.recalc
        moved.verts = [
            (location[0] + x * ca + z * sa,
             location[1] + y,
             location[2] - x * sa + z * ca)
            for (x, y, z) in part.verts
        ]
        out[name] = moved
    return out


def tri_count(part):
    return sum(max(0, len(f) - 2) for f, _m in part.faces)


def edge_stats(part):
    counter = Counter()
    for face, _m in part.faces:
        n = len(face)
        for i in range(n):
            a, b = face[i], face[(i + 1) % n]
            counter[(min(a, b), max(a, b))] += 1
    return (sum(1 for c in counter.values() if c == 1),
            sum(1 for c in counter.values() if c > 2))


def loose_verts(part):
    used = set()
    for face, _m in part.faces:
        used.update(face)
    return len(part.verts) - len(used)


def degenerate_faces(part):
    bad = 0
    verts = part.verts
    for face, _m in part.faces:
        if len(set(face)) != len(face):
            bad += 1
            continue
        p0 = verts[face[0]]
        for i in range(1, len(face) - 1):
            p1 = verts[face[i]]
            p2 = verts[face[i + 1]]
            ux, uy, uz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
            vx, vy, vz = p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2]
            cx = uy * vz - uz * vy
            cy = uz * vx - ux * vz
            cz = ux * vy - uy * vx
            if math.sqrt(cx * cx + cy * cy + cz * cz) * 0.5 < 1e-9:
                bad += 1
                break
    return bad


def check_ship(asset, failures, summary):
    cfg = ck.SHIP_CONFIGS[asset]
    parts = ck.build_all_geometry(asset)
    prefix = cfg["prefix"]
    pivot_keys = {pivot.key for pivot in cfg["pivots"]} | {"ROOT"}
    tris = 0
    materials = set()
    names = set()
    for name, (part, parent) in parts.items():
        if not name.startswith(prefix):
            failures.append("%s: 对象名 %s 缺前缀 %s" % (asset, name, prefix))
        if name in names:
            failures.append("%s: 对象名重复 %s" % (asset, name))
        names.add(name)
        if parent not in pivot_keys:
            failures.append("%s: %s 父级键 %r 非法" % (asset, name, parent))
        if not part.verts or not part.faces:
            failures.append("%s: %s 空几何" % (asset, name))
            continue
        part_tris = tri_count(part)
        tris += part_tris
        boundary, nonmanifold = edge_stats(part)
        loose = loose_verts(part)
        degen = degenerate_faces(part)
        materials.update(m for _f, m in part.faces)
        if nonmanifold:
            failures.append("%s: %s 非流形边 %d" % (asset, name, nonmanifold))
        if loose:
            failures.append("%s: %s 孤立点 %d" % (asset, name, loose))
        if degen:
            failures.append("%s: %s 退化面 %d" % (asset, name, degen))
        is_open = is_open_part(name)
        if is_open:
            if boundary == 0:
                failures.append("%s: %s 标为开放件但无边界边" % (asset, name))
        elif boundary:
            failures.append("%s: %s 闭合件有边界边 %d" % (asset, name, boundary))
        if part_tris > cfg["tri_budget"]:
            failures.append("%s: %s tri %d 超预算" % (asset, name, part_tris))
        summary.setdefault(asset, {}).setdefault("parts", {})[name] = {
            "tris": part_tris, "parent": parent, "boundary": boundary,
            "open": is_open,
        }
    # 世界 bbox：Pivot 子件必须先复刻 Blender 装配变换
    world_parts = transform_parts(parts, cfg)
    mn = [1e18] * 3
    mx = [-1e18] * 3
    for part in world_parts.values():
        for axis in range(3):
            values = [v[axis] for v in part.verts]
            mn[axis] = min(mn[axis], min(values))
            mx[axis] = max(mx[axis], max(values))
    size = [mx[i] - mn[i] for i in range(3)]
    budget = cfg["tri_budget"]
    if tris > budget:
        failures.append("%s: 总 tri %d > 预算 %d" % (asset, tris, budget))
    target = cfg["bbox"]
    tol = cfg["bbox_tol"]
    for i in range(3):
        if abs(size[i] - target[i]) > tol[i]:
            failures.append("%s: bbox[%d] %.2f != %.2f ± %.2f"
                            % (asset, i, size[i], target[i], tol[i]))
    unknown = sorted(materials - ck.ALLOWED_MATERIALS)
    if unknown:
        failures.append("%s: 非白名单材质 %r" % (asset, unknown))
    if not materials:
        failures.append("%s: 无材质" % asset)
    summary[asset]["tris"] = tris
    summary[asset]["budget"] = budget
    summary[asset]["bbox"] = [round(v, 3) for v in size]
    summary[asset]["z_range"] = [round(mn[2], 3), round(mx[2], 3)]
    summary[asset]["materials"] = sorted(materials)
    summary[asset]["objects"] = len(parts)
    summary[asset]["enemy_class"] = cfg["enemy_class"]
    summary[asset]["weapon_sockets"] = len(ck.WEAPON_SOCKETS.get(asset, []))
    summary[asset]["gun_ports"] = len(ck.GUN_PORTS.get(asset, []))
    # 吃水：龙骨最低点在 keel_z - 0.22 以内；桅顶为正
    if mn[2] > -0.8:
        failures.append("%s: zmin %.2f 太浅（没有水下船体）" % (asset, mn[2]))
    if mx[2] < 6.0:
        failures.append("%s: zmax %.2f 太低（没有桅 / 烟囱）" % (asset, mx[2]))


def check_sockets(failures, summary):
    failures.extend(ck.validate_specs())
    for asset in ck.SHIP_CLASS_ORDER:
        socks = ck.WEAPON_SOCKETS.get(asset, [])
        top = ck.SHIP_CONFIGS[asset]["deck_top"]
        for spec in socks:
            expected = round(top(spec["x"], spec["y"]), 4)
            if abs(expected - spec["deck_z"]) > 1e-6:
                failures.append("%s/%s: deck_z 计算不一致" % (asset,
                                                             spec["suffix"]))
            if spec["clearance_h"] > 20.0:
                failures.append("%s/%s: clearance_h 超上限" % (asset,
                                                              spec["suffix"]))
        summary.setdefault(asset, {})["socket_names"] = \
            ck.expected_weapon_socket_names(asset)
        summary.setdefault(asset, {})["gun_port_names"] = \
            ck.expected_gun_port_names(asset)


def main(argv):
    selected = [item for item in argv if item.startswith("SN_")]
    assets = selected or ck.SHIP_CLASS_ORDER
    failures = []
    summary = {}
    for asset in assets:
        if asset not in ck.SHIP_CONFIGS:
            failures.append("未知资产 %s" % asset)
            continue
        check_ship(asset, failures, summary)
    check_sockets(failures, summary)
    classes = sorted({ck.SHIP_CONFIGS[a]["enemy_class"] for a in assets})
    result = {
        "assets": len(assets),
        "enemy_classes": classes,
        "expected_classes": 3,
        "total_tris": sum(summary[a]["tris"] for a in summary),
        "total_budget": sum(summary[a]["budget"] for a in summary),
        "ships": summary,
        "failures": failures,
        "ok": not failures,
    }
    print(json.dumps(result, ensure_ascii=False, indent=1))
    if failures:
        print("dryrun_combat_kit: %d FAILURE(S)" % len(failures))
        return 1
    if len(classes) < 3:
        print("dryrun_combat_kit: enemy classes %r < 3" % (classes,))
        return 1
    print("dryrun_combat_kit: %d ships / %d tri / classes %r ALL OK"
          % (len(assets), result["total_tris"], classes))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
