# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 4（M1-1 architecture_kit 扩展 6 件）生成器的纯 Python 干跑；
# 核对命名、父级、tri、包围盒、zmin=0、网格健康（边界 / 非流形 / 退化面）、材质
# 白名单、共享贴图，以及 Mount / Module_Next/Prev/Left/Right / Wall_Top / Gateway /
# Door_Hinge / Hoist / Dock_Edge / Stair_Foot / Drive_Shaft / Chimney / Coal_Hatch
# 等接口契约与地面基准。
#
# 用法：
#     python tools/modeling/generators/dryrun_kit_batch4.py
#     python tools/modeling/generators/dryrun_kit_batch4.py SN_Arch_Gate
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

import sn_shared_materials as smat  # noqa: E402
from sn_kit_materials import ASSET_MATERIALS, colors_for  # noqa: E402

GENERATOR = os.path.join(HERE, "kit_batch4_generator.py")


def load_generator():
    for name in ("bpy", "bmesh", "mathutils"):
        sys.modules.setdefault(name, types.ModuleType(name))
    spec = importlib.util.spec_from_file_location("kit_batch4_gen", GENERATOR)
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
                "tri_budget", "module_x", "module_y", "module_grid",
                "enclosure"}
    missing = required - set(cfg.root_props)
    if missing:
        failures.append("root_props missing %s" % ",".join(sorted(missing)))
    if abs(cfg.root_props.get("module_grid", 0.0) - 4.0) > 1e-9:
        failures.append("module_grid must be 4.0")
    if "waterline" in cfg.root_props:
        failures.append("batch 4 assets are ground-only; waterline must be absent")


def _check_datum(asset, spec, sock, parts, gmin, gmax, failures):
    """批次 4 全部为地面件：zmin 必须为 0，且每个 socket 高度与几何一致。"""
    prefix = spec["prefix"]
    zmin = gmin[2]
    if abs(zmin) > 1e-6:
        failures.append("GROUND: zmin=%.4f" % zmin)
    for key in ("MODULE_NEXT", "MODULE_PREV"):
        if asset == "SN_Arch_Road":
            if abs(sock[key]["location"][2] - 0.06) > 1e-6:
                failures.append("%s must sit on the paving surface" % key)
        elif abs(sock[key]["location"][2]) > 1e-6:
            failures.append("%s must sit on the ground datum" % key)
    if asset == "SN_Arch_Perimeter_Wall":
        if abs(sock["WALL_TOP"]["location"][2] - gmax[2]) > 0.06:
            failures.append("Wall_Top must reach the coping top")
        if sock["LANTERN"]["location"][1] > -0.4:
            failures.append("Lantern must hang off the -Y face")
    if asset == "SN_Arch_Gate":
        if abs(sock["GATEWAY"]["location"][2]) > 1e-6:
            failures.append("Gateway must be at ground level")
        for key in ("DOOR_HINGE_L", "DOOR_HINGE_R"):
            if abs(sock[key]["location"][1]) > 1e-6:
                failures.append("%s must be on the door plane y=0" % key)
        if sock["HOIST"]["location"][2] < 4.3:
            failures.append("Gate Hoist must be under the lintel beam")
    if asset == "SN_Arch_Road":
        for key, sign in (("MODULE_NEXT", 1.0), ("MODULE_PREV", -1.0)):
            if abs(sock[key]["location"][0] - sign * 4.0) > 1e-6:
                failures.append("%s must be at x=%+.1f" % (key, sign * 4.0))
        for key, sign in (("MODULE_LEFT", 1.0), ("MODULE_RIGHT", -1.0)):
            if abs(sock[key]["location"][1] - sign * 4.0) > 1e-6:
                failures.append("%s must be at y=%+.1f" % (key, sign * 4.0))
    if asset == "SN_Arch_Loading_Platform":
        if abs(sock["DOCK_EDGE"]["location"][2] - 1.25) > 0.03:
            failures.append("Dock_Edge must be at deck level 1.25 m")
        deck_part = parts[prefix + "Deck"][0]
        walking = max(v[2] for v in deck_part.verts)
        if not (1.24 <= walking <= 1.30):
            failures.append("deck walking surface %.3f not at 1.25 m" % walking)
        if sock["HOIST"]["location"][2] < 4.3:
            failures.append("Platform Hoist must be at the beam/pulley height")
        if sock["STAIR_FOOT"]["location"][0] > -5.4:
            failures.append("Stair_Foot must be at the bottom step")
    if asset == "SN_Arch_Warehouse_Variant":
        if sock["HOIST"]["location"][2] < 5.5:
            failures.append("Warehouse_Variant Hoist must be on the gable beam")
        if sock["SIGN"]["location"][0] < 4.9:
            failures.append("Sign must hang on the +X upper facade")
        if sock["STAIR_FOOT"]["location"][2] > 1e-6:
            failures.append("Stair_Foot must stand on the ground")
        stair_top = max(v[2] for v in parts[prefix + "ExternalStair"][0].verts)
        if stair_top < 3.40:
            failures.append("external stair must reach the upper floor 3.48")
        stair_top = max(v[2] for v in parts[prefix + "ExternalStair"][0].verts)
        if stair_top < 3.40:
            failures.append("external stair must reach the upper floor 3.48")
    if asset == "SN_Arch_Gate":
        door_outer = max(v[0] for v in parts[prefix + "Doors"][0].verts)
        pier_inner = min(v[0] for v in parts[prefix + "Piers"][0].verts
                         if v[0] > 0.0)
        gap = pier_inner - door_outer
        if not (0.02 <= gap <= 0.10):
            failures.append("gate door leaf gap %.3f not in [0.02,0.10]" % gap)
        door_top = max(v[2] for v in parts[prefix + "Doors"][0].verts)
        gate_min = min(v[2] for v in parts[prefix + "Portcullis"][0].verts)
        if gate_min < door_top - 0.01:
            failures.append("portcullis intersects closed door tops")
    if asset == "SN_Arch_Workshop_Annex":
        if sock["DRIVE_SHAFT"]["location"][1] < 2.3:
            failures.append("Drive_Shaft must protrude from the +Y wall")
        if abs(sock["DRIVE_SHAFT"]["location"][2] - 1.45) > 0.03:
            failures.append("Drive_Shaft must be at z=1.45 (workshop coupling)")
        if sock["CHIMNEY"]["location"][2] < 6.9:
            failures.append("Chimney socket must be at the stack top")
        if sock["COAL_HATCH"]["location"][1] > -1.9:
            failures.append("Coal_Hatch must be on the -Y wall")


def _check_support(asset, parts, failures):
    """地面件必须有落地支撑：统计最底面几何是否覆盖原点附近（防整体悬空）。"""
    zmin = min(v[2] for part, _p in parts.values() for v in part.verts)
    near = [(v[0], v[1]) for part, _p in parts.values() for v in part.verts
            if abs(v[2] - zmin) < 1e-6]
    if not near:
        failures.append("no vertex at zmin plane")
        return
    spread_x = max(x for x, _y in near) - min(x for x, _y in near)
    spread_y = max(y for _x, y in near) - min(y for x, y in near)
    if spread_x < 0.5 or spread_y < 0.5:
        failures.append("ground contact patch too small (%.2f x %.2f)" % (
            spread_x, spread_y))


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
    print("%-42s %6s %-20s %-24s %-8s %s" % (
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
        print("%-42s %6d %-20s %-24s %-8s %s" % (
            name, tris, "%.2f,%.2f,%.2f" % tuple(sizes),
            ",".join(m.replace("SN_Tex_", "") for m in mats)[:24],
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
    _check_datum(asset, spec, sock_check, parts, gmin, gmax, failures)
    _check_support(asset, parts, failures)
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
    print("\n" + ("ALL KIT BATCH 4 ASSETS OK  (total tris %d)" % total
                  if ok else "KIT BATCH 4 DRYRUN FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
