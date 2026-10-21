# -*- coding: utf-8 -*-
# @static-doc
# 作用：四台起重机生成器的纯 Python 干跑（不起 Blender），进 Blender 前拦几何缺陷。
#
# 对每个生成器调用 `build_all_geometry()`，逐对象核对：命名前缀、父级键、
# 三角面预算、包围盒目标、边界边 / 非流形边 / 退化面、材质白名单、空几何；
# 并检查整体落地（zmin=0）与总三角面。用法：
#
#     python tools/modeling/generators/dryrun_cranes.py
#     python tools/modeling/generators/dryrun_cranes.py sn_mega_gantry_generator.py
#
# 通过标准：每个生成器 ALL OK；任何一项失败返回非 0 退出码。
# @end-static-doc

import importlib.util
import math
import os
import sys
import types
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import sn_crane_materials as cmat
import sn_shared_materials as smat

CASES = [
    dict(module="sn_harbor_crane_generator.py", label="SN_Harbor_Crane",
         prefix="SN_Crane_", parents={"ROOT", "SLEW"},
         budget=4000, bbox=(26.5, 6.3, 21.47), tol=0.8,
         required={"SN_Crane_Slew_Pivot", "SN_Crane_Jib_Chords",
                   "SN_Crane_Tower_Braces", "SN_Crane_Hook_Block"}),
    dict(module="sn_mega_gantry_generator.py", label="SN_Mega_Gantry",
         prefix="SN_MG_", parents={"ROOT"},
         budget=12000, bbox=(39.6, 14.8, 29.65), tol=1.0,
         required={"SN_MG_Legs_Chords", "SN_MG_Bridge_Lattice",
                   "SN_MG_Hoist_Winches", "SN_MG_Spreader_Load"}),
    dict(module="sn_wooden_mast_crane_generator.py", label="SN_Wooden_Mast_Crane",
         prefix="SN_WM_", parents={"ROOT"},
         budget=4000, bbox=(14.77, 7.0, 14.25), tol=0.8,
         required={"SN_WM_Mast", "SN_WM_Jib", "SN_WM_Stays", "SN_WM_Winch",
                   "SN_WM_Hook"}),
    dict(module="sn_hand_jib_crane_generator.py", label="SN_Hand_Jib_Crane",
         prefix="SN_HJ_", parents={"ROOT"},
         budget=1500, bbox=(4.6, 1.7, 5.17), tol=0.5,
         required={"SN_HJ_Post", "SN_HJ_Jib", "SN_HJ_Winch", "SN_HJ_Rope_Hook"}),
]


def load_module(path):
    for name in ("bpy", "bmesh", "mathutils"):
        sys.modules.setdefault(name, types.ModuleType(name))
    spec = importlib.util.spec_from_file_location("crane_gen_under_test", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


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


def check_case(case):
    path = os.path.join(HERE, case["module"])
    mod = load_module(path)
    parts = mod.build_all_geometry()
    cfg = mod.build_config()
    pivot_names = {p.name for p in cfg.pivots}
    materials = set(getattr(mod, "MATERIALS", ()))
    texture_facts = smat.texture_report()
    failures = []
    if not materials:
        failures.append(("MATERIALS", ["generator has no MATERIALS set"]))
    else:
        if set(getattr(mod, "COLORS", {})) != materials:
            failures.append(("MATERIALS", ["COLORS/MATERIALS mismatch"]))
        for name in sorted(materials):
            if name not in cmat.PALETTE:
                failures.append((name, ["material missing from shared palette"]))
            else:
                spec = tuple(getattr(mod, "COLORS", {}).get(name, ()))
                if spec and spec != tuple(cmat.PALETTE[name]):
                    failures.append((name, ["material spec drift vs shared palette"]))
                tex = texture_facts.get(name)
                if tex is None:
                    failures.append((name, ["material missing from texture library"]))
                elif not tex["exists"]:
                    failures.append((name, ["texture file missing: %s" % tex["file"]]))
                elif tex["tile_m"] <= 0.0:
                    failures.append((name, ["bad tile_m"]))
    # PivotSpec 契约：rotation 必须是三元组、location 必须与 origins 一致
    # （双重减原点 / 把 float 传进 rotation 的 P0 都靠这两条在干跑阶段拦住）。
    for spec in cfg.pivots:
        if not (isinstance(spec.rotation, (tuple, list))
                and len(spec.rotation) == 3):
            failures.append((spec.name, ["pivot_rotation_not_triple"]))
        origin = cfg.origins.get(spec.key)
        if origin is None:
            failures.append((spec.name, ["pivot_missing_origin"]))
        else:
            distance = max(abs(origin[i] - spec.location[i]) for i in range(3))
            if distance > 1e-6:
                failures.append((spec.name, [
                    "pivot_origin_mismatch=%.3f" % distance]))
    allowed_parents = {"ROOT"} | {spec.key for spec in cfg.pivots}
    total = 0
    gmin = [1e18] * 3
    gmax = [-1e18] * 3
    seen = set()
    used_mats = set()

    print("=" * 96)
    print("generator: %s  (%s)" % (case["module"], case["label"]))
    print("%-30s %6s %-18s %-20s %-8s %s" % (
        "object", "tris", "size(x,y,z)", "materials", "parent", "flags"))
    print("-" * 96)

    for name, (part, parent) in parts.items():
        if name in seen:
            failures.append((name, ["duplicate_name"]))
        seen.add(name)
        if not name.startswith(case["prefix"]):
            failures.append((name, ["bad_prefix"]))
        if parent not in case["parents"]:
            failures.append((name, ["bad_parent:%s" % parent]))
        if not part.verts or not part.faces:
            failures.append((name, ["empty_geometry"]))
            continue
        tris = tri_count(part)
        total += tris
        xs = [v[0] for v in part.verts]
        ys = [v[1] for v in part.verts]
        zs = [v[2] for v in part.verts]
        for i, arr in enumerate((xs, ys, zs)):
            gmin[i] = min(gmin[i], min(arr))
            gmax[i] = max(gmax[i], max(arr))
        boundary, nonman = edge_stats(part)
        degen = degenerate_faces(part)
        mats = sorted({m for _f, m in part.faces})
        used_mats.update(mats)
        flags = []
        if boundary:
            flags.append("boundary=%d" % boundary)
        if nonman:
            flags.append("nonmanifold=%d" % nonman)
        if degen:
            flags.append("degenerate=%d" % degen)
        bad_mats = set(mats) - materials
        if bad_mats:
            flags.append("mat=%s" % ",".join(sorted(bad_mats)))
        if flags:
            failures.append((name, flags))
        print("%-30s %6d %-18s %-20s %-8s %s" % (
            name, tris,
            "%.2f,%.2f,%.2f" % (max(xs) - min(xs), max(ys) - min(ys),
                                max(zs) - min(zs)),
            ",".join(m.replace("SN_", "") for m in mats)[:20],
            parent, ", ".join(flags) if flags else "ok"))

    size = tuple(gmax[i] - gmin[i] for i in range(3))
    print("-" * 96)
    print("tris = %d / %d" % (total, case["budget"]))
    print("bbox = %.2f x %.2f x %.2f m  (target %s, tol %.1f)" % (
        size[0], size[1], size[2],
        "%.2f x %.2f x %.2f" % case["bbox"], case["tol"]))
    print("z range = %.3f .. %.3f" % (gmin[2], gmax[2]))
    print("objects = %d (meshes + pivots %d)" % (len(parts), len(pivot_names)))

    if total > case["budget"]:
        failures.append(("TOTAL", ["over tri budget"]))
    if abs(gmin[2]) > 1e-6:
        failures.append(("GROUND", ["zmin=%.4f" % gmin[2]]))
    for i, axis in enumerate("xyz"):
        if abs(size[i] - case["bbox"][i]) > case["tol"]:
            failures.append(("BBOX", ["%s %.2f vs %.2f" % (
                axis, size[i], case["bbox"][i])]))
    for name in case["required"]:
        if name not in parts and name not in pivot_names:
            failures.append((name, ["missing required object"]))
    if not materials >= used_mats:
        failures.append(("MATS", ["undeclared: %s" % (
            ",".join(sorted(used_mats - materials)),)]))

    if failures:
        print("\nFAILURES:")
        for name, flags in failures:
            print("  %s: %s" % (name, ", ".join(flags)))
        return False
    print("\n%s: ALL OK" % case["label"])
    return True


def check_texture_library():
    """共享材质贴图库：10 张 tile 存在、tile_m/px_per_m 合理、运行时副本一致。"""
    facts = smat.texture_report()
    specs = smat.material_specs()
    failures = []
    print("%-22s %-12s %8s %7s %8s %s" % (
        "material", "texture", "bytes", "tile_m", "px/m", "flags"))
    print("-" * 84)
    for name in sorted(specs):
        entry = facts[name]
        flags = []
        if not entry["exists"]:
            flags.append("MISSING")
        if entry["tile_m"] <= 0.0:
            flags.append("bad tile_m")
        if not entry["uri"].startswith("shared_materials/"):
            flags.append("bad uri")
        if flags:
            failures.append((name, flags))
        print("%-22s %-12s %8s %7.2f %8.1f %s" % (
            name, entry["texture"],
            entry["bytes"] if entry["bytes"] is not None else "-",
            entry["tile_m"], entry["px_per_m"],
            ", ".join(flags) if flags else "ok"))
    print("-" * 84)
    print("texture library: %d materials / %d bytes" % (
        len(specs), sum(v["bytes"] or 0 for v in facts.values())))
    return failures


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    cases = [c for c in CASES if only is None or c["module"] == only]
    if not cases:
        print("no case matches %r" % only)
        return 2
    print("=" * 96)
    texture_failures = check_texture_library()
    ok = not texture_failures
    if texture_failures:
        print("\nTEXTURE FAILURES:")
        for name, flags in texture_failures:
            print("  %s: %s" % (name, ", ".join(flags)))
    for case in cases:
        ok = check_case(case) and ok
    print("\n" + ("ALL CRANES OK" if ok else "CRANE DRYRUN FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
