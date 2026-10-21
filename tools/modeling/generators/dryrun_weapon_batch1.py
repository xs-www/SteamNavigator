# -*- coding: utf-8 -*-
# @static-doc
# 作用：舰载武器五件套生成器的纯 Python 干跑（不起 Blender），在进 Blender 之前拦住
# 几何 / 命名 / 材质 / Pivot 契约错误。
#
# 逐件核对：对象命名前缀、父级键、三角面预算、包围盒目标、落地（zmin = 0）、
# 边界边 / 非流形边 / 退化面、材质白名单、共享贴图存在性、Pivot 父子关系与原点。
# 用法：
#     python tools/modeling/generators/dryrun_weapon_batch1.py
#     python tools/modeling/generators/dryrun_weapon_batch1.py SN_Weapon_Mortar
# 通过标准：每件 ALL OK；任何一项失败返回非 0 退出码。
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

GENERATOR = os.path.join(HERE, "sn_weapon_batch1_generator.py")


def load_generator():
    for name in ("bpy", "bmesh", "mathutils"):
        sys.modules.setdefault(name, types.ModuleType(name))
    spec = importlib.util.spec_from_file_location("weapon_gen_under_test", GENERATOR)
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
    facts = smat.texture_report()
    failures = []
    for name, entry in sorted(facts.items()):
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
    pivot_names = [p.name for p in cfg.pivots]
    pivot_keys = [p.key for p in cfg.pivots]

    if not materials:
        failures.append("no material whitelist")
    if set(colors) != set(materials):
        failures.append("COLORS/MATERIALS mismatch")
    for name in sorted(materials):
        if name not in facts:
            failures.append("%s: material missing from texture library" % name)
        elif not facts[name]["exists"]:
            failures.append("%s: texture file missing" % name)

    # Pivot 契约：parent 合法、rotation 是三元组、origin 与 location 一致。
    seen_keys = set()
    for pivot in cfg.pivots:
        if pivot.key in seen_keys:
            failures.append("%s: duplicate pivot key" % pivot.key)
        seen_keys.add(pivot.key)
        if not pivot.name.startswith("SN_"):
            failures.append("%s: pivot name bad prefix" % pivot.name)
        if not (isinstance(pivot.rotation, (tuple, list))
                and len(pivot.rotation) == 3):
            failures.append("%s: pivot rotation not triple" % pivot.name)
        if pivot.parent != "ROOT" and pivot.parent not in seen_keys:
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
    if asset != "SN_Weapon_Broadside" and not any(p.key == "YAW" for p in cfg.pivots):
        failures.append("missing YAW pivot")
    if asset == "SN_Weapon_Broadside" and any(p.key == "YAW" for p in cfg.pivots):
        failures.append("broadside should be pitch_only (no YAW)")
    if not any(p.key.startswith("PITCH") for p in cfg.pivots):
        failures.append("missing PITCH pivot")
    if not any(p.key.startswith("RECOIL") for p in cfg.pivots):
        failures.append("missing RECOIL node")
    if not any(p.key.startswith("MUZZLE") for p in cfg.pivots):
        failures.append("missing MUZZLE node")

    allowed_parents = {"ROOT"} | set(pivot_keys)
    total = 0
    gmin = [1e18] * 3
    gmax = [-1e18] * 3
    seen = set()
    used_mats = set()

    print("=" * 100)
    print("asset: %s  (%s)  collection=%s" % (asset, spec["type"],
                                             spec["collection"]))
    print("%-34s %6s %-18s %-24s %-8s %s" % (
        "object", "tris", "size(x,y,z)", "materials", "parent", "flags"))
    print("-" * 100)

    for name, (part, parent) in parts.items():
        if name in seen:
            failures.append("%s: duplicate_name" % name)
        seen.add(name)
        if not name.startswith(prefix):
            failures.append("%s: bad_prefix" % name)
        if parent not in allowed_parents:
            failures.append("%s: bad_parent:%s" % (name, parent))
        if not part.verts or not part.faces:
            failures.append("%s: empty_geometry" % name)
            continue
        tris = tri_count(part)
        total += tris
        for arr, idx in zip(zip(*part.verts), range(3)):
            gmin[idx] = min(gmin[idx], min(arr))
            gmax[idx] = max(gmax[idx], max(arr))
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
        xs = [v[0] for v in part.verts]
        ys = [v[1] for v in part.verts]
        zs = [v[2] for v in part.verts]
        print("%-34s %6d %-18s %-24s %-8s %s" % (
            name, tris,
            "%.2f,%.2f,%.2f" % (max(xs) - min(xs), max(ys) - min(ys),
                                max(zs) - min(zs)),
            ",".join(m.replace("SN_Tex_", "") for m in mats)[:24],
            parent, ", ".join(flags) if flags else "ok"))

    size = tuple(gmax[i] - gmin[i] for i in range(3))
    print("-" * 100)
    print("tris = %d / %d" % (total, spec["tri_budget"]))
    print("bbox = %.2f x %.2f x %.2f m  (target %.2f x %.2f x %.2f, tol %.2f)" % (
        size[0], size[1], size[2], spec["bbox"][0], spec["bbox"][1],
        spec["bbox"][2], spec["tol"]))
    print("z range = %.3f .. %.3f" % (gmin[2], gmax[2]))
    print("objects = %d (meshes) + %d pivots" % (len(parts), len(pivot_names)))

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
    if len(parts) < 3:
        failures.append("too few mesh objects")

    if failures:
        print("\nFAILURES:")
        for item in failures:
            print("  " + item)
        return False, total, size
    print("\n%s: ALL OK" % asset)
    return True, total, size


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
        passed, tris, _size = check_asset(mod, asset)
        ok = passed and ok
        total += tris
    print("\n" + ("ALL WEAPONS OK  (total tris %d)" % total
                  if ok else "WEAPON DRYRUN FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
