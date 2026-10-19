# -*- coding: utf-8 -*-
"""SN_Paddle_Freighter 生成器纯 Python 干跑：不进 Blender，先拦几何缺陷。

把 bpy / bmesh 换成空壳模块后加载生成器，跑 build_all_geometry()，逐对象核对：
三角面预算、包围盒、边界边 / 非流形边、退化面、材质名、命名与父级键。

用法：
    python tools/modeling/generators/dryrun_ship.py
    python tools/modeling/generators/dryrun_ship.py <生成器路径>
"""

import importlib.util
import math
import os
import sys
import types
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_GEN = os.path.join(HERE, "sn_paddle_freighter_generator.py")

TRI_BUDGET = 14000
SIZE_TARGET = (59.4, 14.0, 19.3)   # 总长 / 总宽 / 总高（含艏斜桁与主桅顶）
SIZE_TOL = 1.0
# 允许有边界边的单层曲面（甲板、旗面）：材质双面，不要求水密
OPEN_ALLOWED = {"SN_PF_Deck", "SN_PF_Forecastle", "SN_PF_Poop_Deck", "SN_PF_Flag"}
ALLOWED_MATERIALS = {
    "SN_Iron_Hull", "SN_Iron_Red", "SN_Wood_Deck", "SN_Wood", "SN_Metal", "SN_Brass",
}
PARENT_KEYS = {"ROOT", "PADDLE_PORT", "PADDLE_STARBOARD"}


def load_module(path):
    sys.modules.setdefault("bpy", types.ModuleType("bpy"))
    sys.modules.setdefault("bmesh", types.ModuleType("bmesh"))
    spec = importlib.util.spec_from_file_location("ship_gen_under_test", path)
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


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_GEN
    mod = load_module(path)
    parts = mod.build_all_geometry()

    print("generator: %s" % os.path.basename(path))
    print("%-28s %6s %-14s %-20s %-18s %s" % (
        "object", "tris", "bbox(x,y,z)", "materials", "parent", "flags"))
    print("-" * 118)

    failures = []
    total = 0
    gmin = [1e18] * 3
    gmax = [-1e18] * 3
    seen_names = set()
    used_mats = set()

    for name, (part, parent) in parts.items():
        tris = tri_count(part)
        total += tris
        xs = [v[0] for v in part.verts]
        ys = [v[1] for v in part.verts]
        zs = [v[2] for v in part.verts]
        size = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
        for i, arr in enumerate((xs, ys, zs)):
            gmin[i] = min(gmin[i], min(arr))
            gmax[i] = max(gmax[i], max(arr))
        boundary, nonman = edge_stats(part)
        degen = degenerate_faces(part)
        mats = sorted({m for _f, m in part.faces})
        used_mats.update(mats)

        flags = []
        if not name.startswith("SN_PF_"):
            flags.append("bad_prefix")
        if name in seen_names:
            flags.append("duplicate_name")
        seen_names.add(name)
        if parent not in PARENT_KEYS:
            flags.append("bad_parent")
        if boundary and name not in OPEN_ALLOWED:
            flags.append("boundary=%d" % boundary)
        if nonman:
            flags.append("nonmanifold=%d" % nonman)
        if degen:
            flags.append("degenerate=%d" % degen)
        bad_mats = set(mats) - ALLOWED_MATERIALS
        if bad_mats:
            flags.append("mat=%s" % ",".join(sorted(bad_mats)))
        if any(abs(v) > 1e6 for v in (xs[0], ys[0], zs[0])):
            flags.append("bad_vert")
        if flags:
            failures.append((name, flags))

        print("%-28s %6d %-14s %-20s %-18s %s" % (
            name, tris,
            "%.2f,%.2f,%.2f" % size,
            ",".join(m.replace("SN_", "") for m in mats)[:20],
            parent,
            ", ".join(flags) if flags else "ok"))

    print("-" * 118)
    size = tuple(gmax[i] - gmin[i] for i in range(3))
    print("tris total = %d / %d" % (total, TRI_BUDGET))
    print("bbox = %.2f x %.2f x %.2f m  (target %s, tol %.1f)" % (
        size[0], size[1], size[2],
        "%.1f x %.1f x %.1f" % SIZE_TARGET, SIZE_TOL))
    print("z range = %.2f .. %.2f" % (gmin[2], gmax[2]))
    print("materials = %s" % ", ".join(sorted(used_mats)))

    if total > TRI_BUDGET:
        failures.append(("TOTAL", ["over tri budget"]))
    for i, axis in enumerate("xyz"):
        if abs(size[i] - SIZE_TARGET[i]) > SIZE_TOL:
            failures.append(("BBOX", ["%s %.2f vs %.2f" % (axis, size[i], SIZE_TARGET[i])]))
    for name in OPEN_ALLOWED:
        if name not in parts:
            failures.append((name, ["missing open-surface object"]))
    for name in ("SN_PF_Paddle_Port", "SN_PF_Paddle_Starboard"):
        if name not in parts:
            failures.append((name, ["missing paddle mesh"]))
        elif parts[name][1] not in ("PADDLE_PORT", "PADDLE_STARBOARD"):
            failures.append((name, ["wrong paddle parent"]))

    if failures:
        print("\nFAILURES:")
        for name, flags in failures:
            print("  %s: %s" % (name, ", ".join(flags)))
        return 1
    print("\nALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
