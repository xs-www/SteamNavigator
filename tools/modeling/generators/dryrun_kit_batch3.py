# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 3（建筑 / 环境 8 件）生成器的纯 Python 干跑；核对命名、
# 父级、tri、包围盒、基准面（建筑 zmin=0 / 环境水线）、网格健康、材质白名单、
# 共享贴图，以及 Mount / Module / Door / Hoist / Drive_Shaft / Gantry / Top /
# Deck / Lamp 等接口契约与「无浮空」落地假设。
#
# 用法：
#     python tools/modeling/generators/dryrun_kit_batch3.py
#     python tools/modeling/generators/dryrun_kit_batch3.py SN_Env_Lighthouse
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

GENERATOR = os.path.join(HERE, "kit_batch3_generator.py")


def load_generator():
    for name in ("bpy", "bmesh", "mathutils"):
        sys.modules.setdefault(name, types.ModuleType(name))
    spec = importlib.util.spec_from_file_location("kit_batch3_gen", GENERATOR)
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
    if len(facts) < 11:
        failures.append(("library", "expected 11 shared textures, got %d" % len(facts)))
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
    if spec["family"] == "architecture_kit":
        required |= {"module_x", "module_y"}
    if spec["family"] == "environment_kit":
        required.add("waterline")
    missing = required - set(cfg.root_props)
    if missing:
        failures.append("root_props missing %s" % ",".join(sorted(missing)))


def _check_datum(asset, spec, sock, gmin, gmax, failures):
    """建筑 zmin=0；环境件按水线基准；并检查 floats（有水下部分的件不上浮）。"""
    zmin = gmin[2]
    family = spec["family"]
    if family == "architecture_kit":
        if abs(zmin) > 1e-6:
            failures.append("GROUND: zmin=%.4f" % zmin)
    elif asset == "SN_Env_Reef":
        if not (-3.10 <= zmin <= -2.90):
            failures.append("reef zmin=%.3f not in [-3.10,-2.90]" % zmin)
        if not (2.42 <= gmax[2] <= 2.58):
            failures.append("reef zmax=%.3f not in [2.42,2.58]" % gmax[2])
        if abs(sock["TOP"]["location"][2] - 2.50) > 0.06:
            failures.append("Reef Top must be at the rock pad top (~2.50)")
    elif asset == "SN_Env_Wreck":
        if not (-1.75 <= zmin <= -1.45):
            failures.append("wreck zmin=%.3f not in [-1.75,-1.45]" % zmin)
    elif asset == "SN_Env_Lighthouse":
        if abs(zmin) > 1e-6:
            failures.append("lighthouse base zmin=%.4f" % zmin)
        for key, z in (("LAMP", 10.60), ("GALLERY", 9.80), ("DOOR", 0.90)):
            if abs(sock[key]["location"][2] - z) > 1e-6:
                failures.append("lighthouse %s must be at z=%.2f" % (key, z))
    elif asset == "SN_Env_Buoy":
        if not (-0.80 <= zmin <= -0.60):
            failures.append("buoy zmin=%.3f not in [-0.80,-0.60]" % zmin)
        if not (3.00 <= gmax[2] <= 3.20):
            failures.append("buoy zmax=%.3f not in [3.00,3.20]" % gmax[2])
        if abs(sock["LAMP"]["location"][2] - 2.65) > 1e-6:
            failures.append("buoy Lamp must be at z=2.65")
    if asset == "SN_Arch_Warehouse":
        for key, x in (("MODULE_NEXT", 4.00), ("MODULE_PREV", -4.00)):
            loc = sock[key]["location"]
            if abs(loc[0] - x) > 1e-6 or abs(loc[2]) > 1e-6:
                failures.append("%s must be at (%.2f,0,0)" % (key, x))
        if abs(sock["DOOR_FRONT"]["location"][2]) > 1e-6:
            failures.append("Warehouse Door_Front must be at ground z=0")
        if sock["HOIST"]["location"][2] < 3.5:
            failures.append("Warehouse Hoist must be at canopy beam height")
    if asset == "SN_Arch_Workshop":
        if abs(sock["DRIVE_SHAFT"]["location"][1] + 3.08) > 0.10:
            failures.append("Workshop Drive_Shaft must be on -Y wall")
        if sock["CHIMNEY"]["location"][2] < 6.5:
            failures.append("Workshop Chimney socket must be at chimney top")
    if asset == "SN_Arch_Tavern":
        if abs(sock["MODULE_NEXT"]["location"][0] - 3.00) > 1e-6:
            failures.append("Tavern Module_Next must be at body edge x=3.00")
        if sock["SIGN"]["location"][0] < 4.5:
            failures.append("Tavern Sign must hang off the porch")
    if asset == "SN_Arch_Factory":
        if abs(sock["MODULE_NEXT"]["location"][0] - 6.00) > 1e-6:
            failures.append("Factory Module_Next must be at body edge x=6.00")
        if sock["GANTRY"]["location"][2] < 6.5:
            failures.append("Factory Gantry must be under the crane beam")


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
    for part_name in parts:
        if part_name in pivot_names:
            failures.append("%s: mesh name collides with socket name" % part_name)

    allowed_parents = {"ROOT"} | pivot_keys
    tol = float(spec.get("tol", 0.15))
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
    print("\n" + ("ALL KIT BATCH 3 ASSETS OK  (total tris %d)" % total
                  if ok else "KIT BATCH 3 DRYRUN FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
