# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 1（武器套件 + 船体部件 8 件）生成器的纯 Python 干跑；核对
# 命名、父级、tri、包围盒、落地/基准面、网格健康、材质白名单、共享贴图，以及
# Mount / Socket / Trunnion / Pivot 的拼装契约。
#
# 用法：
#     python tools/modeling/generators/dryrun_kit_batch1.py
#     python tools/modeling/generators/dryrun_kit_batch1.py SN_Weapon_Cannon
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

GENERATOR = os.path.join(HERE, "kit_batch1_generator.py")


def load_generator():
    for name in ("bpy", "bmesh", "mathutils"):
        sys.modules.setdefault(name, types.ModuleType(name))
    spec = importlib.util.spec_from_file_location("kit_batch1_gen", GENERATOR)
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


def _socket_map(mod, asset):
    return {key: {"key": key, "name": name, "parent": parent,
                  "location": location}
            for key, name, parent, location in mod.SOCKETS[asset]}


def _check_contract(asset, spec, cfg, sock, failures):
    """Mount / socket 命名、位置与父子关系。"""
    prefix = spec["prefix"]
    keys = set(sock)
    pivots = {p.key: p for p in cfg.pivots}
    names = [p.name for p in cfg.pivots]
    if len(names) != len(set(names)):
        failures.append("duplicate socket names")
    for key, entry in sock.items():
        if key not in pivots:
            failures.append("missing socket %s" % key)
            continue
        pivot = pivots[key]
        expected_name = (entry["name"] if entry["name"].startswith("SN_")
                         else prefix + entry["name"])
        if pivot.name != expected_name:
            failures.append("%s name %r != %r" % (key, pivot.name, expected_name))
        if not pivot.name.startswith("SN_"):
            failures.append("%s bad prefix" % pivot.name)
        for i in range(3):
            if abs(pivot.location[i] - entry["location"][i]) > 1e-6:
                failures.append("%s location drift" % pivot.name)
        if pivot.parent != entry["parent"]:
            failures.append("%s parent %r != %r" % (
                pivot.name, pivot.parent, entry["parent"]))
    # Mount 必须在原点
    if "MOUNT" in pivots:
        if max(abs(v) for v in pivots["MOUNT"].location) > 1e-6:
            failures.append("Mount not at origin")
    else:
        failures.append("missing Mount")
    # 先建父级再建子级
    seen = set()
    for pivot in cfg.pivots:
        if pivot.parent != "ROOT" and pivot.parent not in seen:
            failures.append("%s parent %s not created earlier" % (
                pivot.name, pivot.parent))
        seen.add(pivot.key)
    # 根节点 extras
    required = {"asset", "version", "units", "kit_family", "part_role",
                "forward", "up", "datum", "mount_frame", "base_footprint_x",
                "base_footprint_y", "envelope_x", "envelope_y", "height",
                "tri_budget"}
    missing = required - set(cfg.root_props)
    if missing:
        failures.append("root_props missing %s" % ",".join(sorted(missing)))
    if cfg.root_props.get("asset") != asset:
        failures.append("root asset mismatch")
    if cfg.root_props.get("kit_family") != spec["family"]:
        failures.append("root kit_family mismatch")


def _check_symmetry(asset, sock, failures):
    """左右耳轴 / 尾座类接口的镜像对称。"""
    if "TRUNNION_L" in sock and "TRUNNION_R" in sock:
        left = sock["TRUNNION_L"]["location"]
        right = sock["TRUNNION_R"]["location"]
        if abs(left[0] - right[0]) > 1e-6 or abs(left[2] - right[2]) > 1e-6:
            failures.append("trunnion L/R not mirrored in X/Z")
        if abs(left[1] + right[1]) > 1e-6:
            failures.append("trunnion L/R not mirrored in Y")
    if "LID_FWD" in sock and "LID_AFT" in sock:
        fwd = sock["LID_FWD"]["location"]
        aft = sock["LID_AFT"]["location"]
        if abs(fwd[0] + aft[0]) > 1e-6 or abs(fwd[1] - aft[1]) > 1e-6:
            failures.append("hatch lid pivots not mirrored in X")


def _check_datum(asset, spec, sock, gmin, gmax, failures):
    """各件的基准面 / 接口高度断言。"""
    if asset == "SN_Weapon_Cannon":
        # 俯仰子件：根 = 耳轴轴心，几何允许伸到 z=0 以下
        if not (-0.50 <= gmin[2] <= -0.15):
            failures.append("cannon zmin=%.3f not in trunnion-datum range" % gmin[2])
        pitch = sock.get("PITCH")
        if pitch is None or max(abs(v) for v in pitch["location"]) > 1e-6:
            failures.append("Cannon Pitch_Pivot must be at origin")
    else:
        if abs(gmin[2]) > 1e-6:
            failures.append("GROUND: zmin=%.4f" % gmin[2])
    if asset == "SN_Weapon_GunCarriage":
        for key in ("TRUNNION_L", "TRUNNION_R"):
            if abs(sock[key]["location"][2] - 0.62) > 1e-6:
                failures.append("%s must sit at z=0.62" % key)
    if asset == "SN_Weapon_Turret":
        if abs(sock["YAW"]["location"][2] - 0.22) > 1e-6:
            failures.append("Turret Yaw_Pivot must be at z=0.22")
        # GunPort / Muzzle / Hatch 是 Yaw 子节点：world z = 0.22 + local z
        for key, world_z in (("GUN_PORT", 1.34), ("MUZZLE", 1.34),
                             ("HATCH", 2.80)):
            local_z = sock[key]["location"][2]
            if abs(local_z + 0.22 - world_z) > 1e-6:
                failures.append("%s world z %.3f != %.3f" % (
                    key, local_z + 0.22, world_z))
        if abs(sock["GUN_PORT"]["location"][1]) > 1e-6:
            failures.append("GunPort must be on +X centreline")
        for i in range(1, 5):
            x, y, _z = sock["ANCHOR_%d" % i]["location"]
            if abs(math.hypot(x, y) - 1.50) > 0.02:
                failures.append("Anchor_%d must sit on the base ring (r=1.5)" % i)
    if asset == "SN_Weapon_Pedestal":
        if abs(sock["COLLAR"]["location"][2] - 1.10) > 1e-6:
            failures.append("Collar must be at z=1.10")
    if asset == "SN_ShipPart_Deck":
        deck_h = spec["deck_height"]
        for key in ("SOCKET_MAST", "SOCKET_FUNNEL", "SOCKET_HATCH",
                    "SOCKET_WEAPON_PORT", "SOCKET_WEAPON_STARBOARD"):
            if abs(sock[key]["location"][2] - deck_h) > 1e-6:
                failures.append("%s must sit on deck height" % key)
            x, y = sock[key]["location"][0], sock[key]["location"][1]
            if abs(x) > 4.2 or abs(y) > 3.0:
                failures.append("%s outside deck rectangle" % key)
        # Heavy 炮塔（底座半 1.72）放到 weapon socket 上不能超出甲板边缘
        for key in ("SOCKET_WEAPON_PORT", "SOCKET_WEAPON_STARBOARD"):
            x, y = sock[key]["location"][0], sock[key]["location"][1]
            if abs(x) + 1.72 > 4.2 + 1e-6 or abs(y) + 1.72 > 3.0 + 1e-6:
                failures.append("%s cannot carry a Heavy turret on deck" % key)
    if asset == "SN_ShipPart_Mast":
        if abs(sock["TOP"]["location"][2] - 12.60) > 1e-6:
            failures.append("Mast Top must be at z=12.60")
        if abs(sock["LOOKOUT"]["location"][2] - 12.16) > 1e-6:
            failures.append("Mast Lookout platform must be at z=12.16")
        for key in ("YARD_LOWER", "YARD_UPPER"):
            if abs(sock[key]["location"][0]) > 1e-6:
                failures.append("%s must be on the mast axis" % key)
    if asset == "SN_ShipPart_Funnel":
        if abs(sock["EXHAUST"]["location"][2] - 4.55) > 1e-6:
            failures.append("Funnel Exhaust must be at z=4.55")
        if abs(sock["EXHAUST"]["location"][0] - 0.35) > 1e-6:
            failures.append("Funnel Exhaust x must follow rake (0.35)")


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
    sock_for_check = {key: {"location": p.location, "name": p.name,
                            "parent": p.parent}
                      for key, p in ((p.key, p) for p in cfg.pivots)}

    if set(colors) != set(materials):
        failures.append("COLORS/MATERIALS mismatch")
    for name in sorted(materials):
        if name not in facts:
            failures.append("%s: material missing from texture library" % name)
        elif not facts[name]["exists"]:
            failures.append("%s: texture file missing" % name)

    _check_contract(asset, spec, cfg, sock, failures)
    _check_symmetry(asset, sock_for_check, failures)
    for part_name in parts:
        if part_name in pivot_names:
            failures.append("%s: mesh name collides with socket name" % part_name)

    allowed_parents = {"ROOT"} | pivot_keys
    total = 0
    gmin = [1e18] * 3
    gmax = [-1e18] * 3
    used_mats = set()

    print("=" * 104)
    print("asset: %s  (%s)  family=%s role=%s" % (
        asset, spec["type"], spec["family"], spec["role"]))
    print("%-38s %6s %-18s %-22s %-10s %s" % (
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
        print("%-38s %6d %-18s %-22s %-10s %s" % (
            name, tris, "%.2f,%.2f,%.2f" % tuple(sizes),
            ",".join(m.replace("SN_Tex_", "") for m in mats)[:22],
            parent, ", ".join(flags) if flags else "ok"))

    size = tuple(gmax[i] - gmin[i] for i in range(3))
    print("-" * 104)
    print("tris = %d / %d" % (total, spec["tri_budget"]))
    print("bbox = %.2f x %.2f x %.2f m  (target %.2f x %.2f x %.2f, tol %.2f)" % (
        size[0], size[1], size[2], spec["bbox"][0], spec["bbox"][1],
        spec["bbox"][2], spec["tol"]))
    print("z range = %.3f .. %.3f" % (gmin[2], gmax[2]))
    print("meshes = %d, sockets = %d (%s)" % (
        len(parts), len(pivot_names), ", ".join(pivot_names)))

    if total > spec["tri_budget"]:
        failures.append("TOTAL: over tri budget")
    _check_datum(asset, spec, sock_for_check, gmin, gmax, failures)
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
    print("\n" + ("ALL KIT ASSETS OK  (total tris %d)" % total
                  if ok else "KIT DRYRUN FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
