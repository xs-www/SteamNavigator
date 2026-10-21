# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 2（机械 / 货物 / 码头 10 件）生成器的纯 Python 干跑；核对
# 命名、父级、tri、包围盒、基准面、网格健康、材质白名单、共享贴图（含 SN_Tex_Coal），
# 以及 Mount / Shaft / Drum / Stack / Module / Mooring 接口契约。
#
# 用法：
#     python tools/modeling/generators/dryrun_kit_batch2.py
#     python tools/modeling/generators/dryrun_kit_batch2.py SN_Dock_Jetty
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
from sn_kit_materials import ASSET_MATERIALS, colors_for

GENERATOR = os.path.join(HERE, "kit_batch2_generator.py")


def load_generator():
    for name in ("bpy", "bmesh", "mathutils"):
        sys.modules.setdefault(name, types.ModuleType(name))
    spec = importlib.util.spec_from_file_location("kit_batch2_gen", GENERATOR)
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
    facts = smat.texture_report()
    if "SN_Tex_Coal" not in facts:
        failures.append(("SN_Tex_Coal", "coal material missing from spec"))
    for name, entry in sorted(facts.items()):
        if not entry["exists"]:
            failures.append((name, "texture missing: %s" % entry["file"]))
        if entry["tile_m"] <= 0.0:
            failures.append((name, "bad tile_m"))
        if not entry["uri"].startswith("shared_materials/"):
            failures.append((name, "bad uri"))
    return failures


def _socket_map(mod, asset):
    return {key: {"key": key, "name": name, "parent": parent,
                  "location": location}
            for key, name, parent, location in mod.SOCKETS[asset]}


def _check_contract(asset, spec, cfg, sock, failures):
    prefix = spec["prefix"]
    pivots = {p.key: p for p in cfg.pivots}
    names = [p.name for p in cfg.pivots]
    if len(names) != len(set(names)):
        failures.append("duplicate socket names")
    for key, entry in sock.items():
        if key not in pivots:
            failures.append("missing socket %s" % key)
            continue
        pivot = pivots[key]
        expected_name = prefix + entry["name"]
        if pivot.name != expected_name:
            failures.append("%s name %r != %r" % (key, pivot.name,
                                                  expected_name))
        if not pivot.name.startswith(prefix):
            failures.append("%s bad prefix" % pivot.name)
        for i in range(3):
            if abs(pivot.location[i] - entry["location"][i]) > 1e-6:
                failures.append("%s location drift" % pivot.name)
        if pivot.parent != entry["parent"]:
            failures.append("%s parent %r != %r" % (
                pivot.name, pivot.parent, entry["parent"]))
    if "MOUNT" not in pivots:
        failures.append("missing Mount")
    elif max(abs(v) for v in pivots["MOUNT"].location) > 1e-6:
        failures.append("Mount not at origin")
    seen = set()
    for pivot in cfg.pivots:
        if pivot.parent != "ROOT" and pivot.parent not in seen:
            failures.append("%s parent %s not created earlier" % (
                pivot.name, pivot.parent))
        seen.add(pivot.key)
    required = {"asset", "version", "units", "kit_family", "part_role",
                "forward", "up", "datum", "mount_frame", "base_footprint_x",
                "base_footprint_y", "envelope_x", "envelope_y", "height",
                "tri_budget"}
    missing = required - set(cfg.root_props)
    if missing:
        failures.append("root_props missing %s" % ",".join(sorted(missing)))


def _check_symmetry(asset, sock, failures):
    if "BITT_PORT" in sock and "BITT_STARBOARD" in sock:
        a = sock["BITT_PORT"]["location"]
        b = sock["BITT_STARBOARD"]["location"]
        if abs(a[0] + b[0]) > 1e-6 or abs(a[2] - b[2]) > 1e-6:
            failures.append("Bitt_Port/Starboard not mirrored in X/Z")
    if "LIFT_L" in sock and "LIFT_R" in sock:
        a = sock["LIFT_L"]["location"]
        b = sock["LIFT_R"]["location"]
        if abs(a[1] + b[1]) > 1e-6:
            failures.append("Lift_L/R not mirrored in Y")


def _check_datum(asset, spec, sock, gmin, gmax, failures):
    zmin = gmin[2]
    if asset == "SN_Dock_Jetty":
        if not (-1.36 <= zmin <= -1.24):
            failures.append("jetty zmin=%.3f not in [-1.36,-1.24]" % zmin)
        if abs(sock["MODULE_NEXT"]["location"][2] - 1.30) > 1e-6:
            failures.append("jetty Module_Next must be at deck z=1.30")
        if abs(sock["MODULE_NEXT"]["location"][0] - 4.00) > 1e-6:
            failures.append("jetty Module_Next must be at x=4.00")
    elif abs(zmin) > 1e-6:
        failures.append("GROUND: zmin=%.4f" % zmin)
    if asset in ("SN_Dock_Structure", "SN_Dock_Jetty"):
        if spec.get("deck_height") is not None:
            top = gmax[2]
            if top + 0.14 < spec["deck_height"]:
                failures.append("deck top %.3f below deck_height %.3f" % (
                    top, spec["deck_height"]))
    if asset == "SN_Dock_Structure":
        for key, x in (("MODULE_NEXT", 4.20), ("MODULE_PREV", -4.20)):
            loc = sock[key]["location"]
            if abs(loc[0] - x) > 1e-6 or abs(loc[2] - 3.02) > 1e-6:
                failures.append("%s must be at (%.2f, 0, 3.02)" % (key, x))
        for key in ("MOORING_1", "MOORING_2"):
            if abs(sock[key]["location"][2] - 3.02) > 1e-6:
                failures.append("%s must be on quay top" % key)
    if asset == "SN_Machinery_Winch":
        if abs(sock["DRUM"]["location"][2] - 0.95) > 1e-6:
            failures.append("Drum_Pivot must be at z=0.95")
    if asset == "SN_Machinery_PowerUnit":
        if abs(sock["SHAFT_OUT"]["location"][0] - 1.25) > 1e-6:
            failures.append("Shaft_Out must be at flywheel x=1.25")
        if abs(sock["SHAFT_OUT"]["location"][2] - 0.95) > 1e-6:
            failures.append("Shaft_Out must be at flywheel z=0.95")
    if asset == "SN_Cargo_Crate":
        if abs(sock["STACK_TOP"]["location"][2] - 1.035) > 1e-6:
            failures.append("Crate Stack_Top must be at z=1.035")
    if asset == "SN_Cargo_CoalScuttle":
        if abs(sock["FILL_TOP"]["location"][2] - 0.95) > 1e-6:
            failures.append("CoalScuttle Fill_Top must be at z=0.95")
    if asset == "SN_Cargo_Tank":
        if abs(sock["OUTLET"]["location"][0] - 1.76) > 1e-6:
            failures.append("Tank Outlet must be at x=1.76")
    if asset == "SN_Cargo_Pallet":
        if abs(sock["STACK_TOP"]["location"][2] - 0.18) > 1e-6:
            failures.append("Pallet Stack_Top must be at z=0.18")


def check_asset(mod, asset):
    spec = mod.SPECS[asset]
    prefix = spec["prefix"]
    materials = ASSET_MATERIALS[asset]
    colors = colors_for(asset)
    facts = smat.texture_report()
    failures = []

    parts = mod.build_geometry(asset)
    cfg = mod.build_config(asset, origin=(0.0, 0.0, 0.0))
    pivot_keys = {p.key for p in cfg.pivots}
    pivot_names = [p.name for p in cfg.pivots]
    sock = _socket_map(mod, asset)
    sock_check = {k: {"location": v["location"], "name": v["name"],
                      "parent": v["parent"]} for k, v in sock.items()}

    if set(colors) != set(materials):
        failures.append("COLORS/MATERIALS mismatch")
    for name in sorted(materials):
        if name not in facts:
            failures.append("%s: material missing from texture library" % name)
        elif not facts[name]["exists"]:
            failures.append("%s: texture file missing" % name)

    _check_contract(asset, spec, cfg, sock, failures)
    _check_symmetry(asset, sock_check, failures)
    for part_name in parts:
        if part_name in pivot_names:
            failures.append("%s: mesh name collides with socket name" % part_name)

    allowed_parents = {"ROOT"} | pivot_keys
    tol = float(spec.get("tol", 0.12))
    total = 0
    gmin = [1e18] * 3
    gmax = [-1e18] * 3
    used_mats = set()

    print("=" * 104)
    print("asset: %s  (%s)  family=%s role=%s" % (
        asset, spec["type"], spec["family"], spec["role"]))
    print("%-40s %6s %-18s %-22s %-10s %s" % (
        "object", "tris", "size(x,y,z)", "materials", "parent", "flags"))
    print("-" * 104)

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
        print("%-40s %6d %-18s %-22s %-10s %s" % (
            name, tris, "%.2f,%.2f,%.2f" % tuple(sizes),
            ",".join(m.replace("SN_Tex_", "") for m in mats)[:22],
            parent, ", ".join(flags) if flags else "ok"))

    size = tuple(gmax[i] - gmin[i] for i in range(3))
    print("-" * 104)
    print("tris = %d / %d" % (total, spec["tri_budget"]))
    print("bbox = %.2f x %.2f x %.2f m  (target %.2f x %.2f x %.2f, tol %.2f)" % (
        size[0], size[1], size[2], spec["bbox"][0], spec["bbox"][1],
        spec["bbox"][2], tol))
    print("z range = %.3f .. %.3f" % (gmin[2], gmax[2]))
    print("meshes = %d, sockets = %d" % (len(parts), len(pivot_names)))

    if total > spec["tri_budget"]:
        failures.append("TOTAL: over tri budget")
    _check_datum(asset, spec, sock_check, gmin, gmax, failures)
    for i, axis in enumerate("xyz"):
        if abs(size[i] - spec["bbox"][i]) > tol:
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
    print("\n" + ("ALL KIT BATCH 2 ASSETS OK  (total tris %d)" % total
                  if ok else "KIT BATCH 2 DRYRUN FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
