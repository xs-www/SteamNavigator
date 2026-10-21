# -*- coding: utf-8 -*-
# @static-doc
# 作用：舰载特殊武器三件套（弩炮 / 箭塔 / 蒸汽鱼叉）生成器的纯 Python 干跑；核对
# 命名、父级、tri、包围盒、落地、网格健康、材质白名单、共享贴图，以及 Mount /
# Anchor / Yaw / Pitch 的 socket 契约。
#
# 用法：
#     python tools/modeling/generators/dryrun_weapon_batch2.py
#     python tools/modeling/generators/dryrun_weapon_batch2.py SN_Weapon_Ballista
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

import sn_shared_materials as smat
from sn_weapon_materials import ASSET_MATERIALS, colors_for

GENERATOR = os.path.join(HERE, "sn_weapon_batch2_generator.py")


def load_generator():
    for name in ("bpy", "bmesh", "mathutils"):
        sys.modules.setdefault(name, types.ModuleType(name))
    spec = importlib.util.spec_from_file_location("weapon_batch2_gen", GENERATOR)
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


def check_texture_library():
    failures = []
    for name, entry in sorted(smat.texture_report().items()):
        if not entry["exists"]:
            failures.append((name, "texture missing: %s" % entry["file"]))
        if entry["tile_m"] <= 0.0:
            failures.append((name, "bad tile_m"))
        if not entry["uri"].startswith("shared_materials/"):
            failures.append((name, "bad uri"))
    return failures


def check_asset(mod, asset):
    spec = mod.SPECS[asset]
    prefix = spec["prefix"]
    materials = ASSET_MATERIALS[asset]
    colors = colors_for(asset)
    facts = smat.texture_report()
    failures = []

    parts = mod.build_geometry(asset)
    cfg = mod.build_config(asset, origin=(0.0, 0.0, 0.0))
    pivot_keys = [p.key for p in cfg.pivots]
    pivot_names = [p.name for p in cfg.pivots]

    if set(colors) != set(materials):
        failures.append("COLORS/MATERIALS mismatch")
    for name in sorted(materials):
        if name not in facts:
            failures.append("%s: material missing from texture library" % name)
        elif not facts[name]["exists"]:
            failures.append("%s: texture file missing" % name)

    if "MOUNT" not in pivot_keys:
        failures.append("missing MOUNT marker")
    if "MOUNT" in pivot_keys:
        mount = next(p for p in cfg.pivots if p.key == "MOUNT")
        if max(abs(v) for v in mount.location) > 1e-6:
            failures.append("MOUNT must be at base centre")
    for i in range(1, 5):
        if "ANCHOR_%d" % i not in pivot_keys:
            failures.append("missing ANCHOR_%d" % i)
    if spec["pivot_profile"] == "yaw_pitch":
        if "YAW" not in pivot_keys:
            failures.append("missing YAW pivot")
        if "PITCH" not in pivot_keys:
            failures.append("missing PITCH pivot")
        if "PITCH" in pivot_keys:
            pitch = next(p for p in cfg.pivots if p.key == "PITCH")
            if pitch.parent != "YAW":
                failures.append("PITCH parent is not YAW")
    else:
        if "YAW" in pivot_keys or "PITCH" in pivot_keys:
            failures.append("fixed tower must not have YAW/PITCH")

    seen = set()
    for pivot in cfg.pivots:
        if pivot.key in seen:
            failures.append("%s: duplicate pivot key" % pivot.key)
        seen.add(pivot.key)
        if not pivot.name.startswith("SN_"):
            failures.append("%s: pivot name bad prefix" % pivot.name)
        if pivot.parent != "ROOT" and pivot.parent not in seen:
            failures.append("%s: pivot parent %s not created earlier" % (
                pivot.name, pivot.parent))
        origin = cfg.origins.get(pivot.key)
        if origin is None:
            failures.append("%s: pivot missing origin" % pivot.name)
        elif not pivot.key.startswith("RECOIL"):
            # RECOIL 的 mesh origin 是父级 Pitch 的世界位置，pivot 本身是局部原点
            distance = max(abs(origin[i] - pivot.location[i]) for i in range(3))
            if distance > 1e-6:
                failures.append("%s: pivot origin mismatch %.3f" % (
                    pivot.name, distance))

    allowed_parents = {"ROOT"} | set(pivot_keys)
    total = 0
    gmin = [1e18] * 3
    gmax = [-1e18] * 3
    used_mats = set()

    print("=" * 100)
    print("asset: %s  (%s)  mount=%s profile=%s" % (
        asset, spec["type"], spec["mount_class"], spec["pivot_profile"]))
    print("%-36s %6s %-18s %-24s %-8s %s" % (
        "object", "tris", "size(x,y,z)", "materials", "parent", "flags"))
    print("-" * 100)

    for name, (part, parent) in parts.items():
        if not name.startswith(prefix):
            failures.append("%s: bad_prefix" % name)
        if parent not in allowed_parents:
            failures.append("%s: bad_parent:%s" % (name, parent))
        if not part.verts or not part.faces:
            failures.append("%s: empty_geometry" % name)
            continue
        tris = tri_count(part)
        total += tris
        for axis in range(3):
            arr = [v[axis] for v in part.verts]
            gmin[axis] = min(gmin[axis], min(arr))
            gmax[axis] = max(gmax[axis], max(arr))
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
            failures.append("%s: %s" % (name, ", ".join(flags)))
        sizes = [max(v[i] for v in part.verts) - min(v[i] for v in part.verts)
                 for i in range(3)]
        print("%-36s %6d %-18s %-24s %-8s %s" % (
            name, tris, "%.2f,%.2f,%.2f" % tuple(sizes),
            ",".join(m.replace("SN_Tex_", "") for m in mats)[:24],
            parent, ", ".join(flags) if flags else "ok"))

    size = tuple(gmax[i] - gmin[i] for i in range(3))
    print("-" * 100)
    print("tris = %d / %d" % (total, spec["tri_budget"]))
    print("bbox = %.2f x %.2f x %.2f m  (target %.2f x %.2f x %.2f, tol %.2f)" % (
        size[0], size[1], size[2], spec["bbox"][0], spec["bbox"][1],
        spec["bbox"][2], spec["tol"]))
    print("z range = %.3f .. %.3f" % (gmin[2], gmax[2]))
    print("meshes = %d, pivots/markers = %d" % (len(parts), len(pivot_names)))

    if total > spec["tri_budget"]:
        failures.append("TOTAL: over tri budget")
    if abs(gmin[2]) > 1e-6:
        failures.append("GROUND: zmin=%.4f" % gmin[2])
    for i, axis in enumerate("xyz"):
        if abs(size[i] - spec["bbox"][i]) > spec["tol"]:
            failures.append("BBOX: %s %.2f vs %.2f" % (
                axis, size[i], spec["bbox"][i]))
    for suffix in spec["required"]:
        if prefix + suffix not in parts:
            failures.append("missing required object: %s" % (prefix + suffix))
    if not materials >= used_mats:
        failures.append("MATS: undeclared %s" % (
            ",".join(sorted(used_mats - materials)),))

    if failures:
        print("\nFAILURES:")
        for item in failures:
            print("  " + item)
        return False, total
    print("\n%s: ALL OK" % asset)
    return True, total


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    mod = load_generator()
    assets = [a for a in mod.ASSETS if only is None or a == only]
    if not assets:
        print("no asset matches %r" % only)
        return 2
    texture_failures = check_texture_library()
    if texture_failures:
        print("TEXTURE LIBRARY FAILURES:")
        for name, flag in texture_failures:
            print("  %s: %s" % (name, flag))
    ok = not texture_failures
    total = 0
    for asset in assets:
        passed, tris = check_asset(mod, asset)
        ok = passed and ok
        total += tris
    print("\n" + ("ALL WEAPONS OK  (total tris %d)" % total
                  if ok else "WEAPON DRYRUN FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
