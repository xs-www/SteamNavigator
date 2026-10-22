# -*- coding: utf-8 -*-
"""SN_Ironclad 生成器纯 Python 干跑：不进 Blender，先拦几何缺陷。

把 bpy / bmesh 换成空壳模块后加载生成器，跑 build_all_geometry()，核对：
三角面预算、包围盒（水线轴心）、z 范围、边界边 / 非流形边、退化面、孤立点、
材质名与命名。

用法：
    python tools/modeling/generators/dryrun_ironclad.py
    python tools/modeling/generators/dryrun_ironclad.py <生成器路径>
"""

import importlib.util
import math
import os
import sys
import types
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_GEN = os.path.join(HERE, "sn_ironclad_generator.py")

SIZE_TOL = 0.5


def load_module(path):
    sys.modules.setdefault("bpy", types.ModuleType("bpy"))
    sys.modules.setdefault("bmesh", types.ModuleType("bmesh"))
    spec = importlib.util.spec_from_file_location("ironclad_gen_under_test", path)
    mod = importlib.util.module_from_spec(spec)
    # 生成器内部用 sys.modules[__name__] 把自身传给 rig_kit（部件库复用），
    # 因此必须在 exec 前登记到 sys.modules，否则 build_masts 会 KeyError。
    sys.modules[spec.name] = mod
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
            cx, cy, cz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
            if math.sqrt(cx * cx + cy * cy + cz * cz) * 0.5 < 1e-9:
                bad += 1
                break
    return bad


def island_report(part, gap=0.08):
    """按共享顶点拆连通岛，用包围盒膨胀 gap 检查是否有"完全脱开"的部件。"""
    n = len(part.verts)
    parent = list(range(n))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    for face, _m in part.faces:
        for i in range(1, len(face)):
            union(face[0], face[i])

    boxes = {}
    for face, mat in part.faces:
        root = find(face[0])
        rec = boxes.setdefault(root, [1e18, 1e18, 1e18, -1e18, -1e18, -1e18])
        for idx in face:
            x, y, z = part.verts[idx]
            rec[0] = min(rec[0], x)
            rec[1] = min(rec[1], y)
            rec[2] = min(rec[2], z)
            rec[3] = max(rec[3], x)
            rec[4] = max(rec[4], y)
            rec[5] = max(rec[5], z)
    roots = list(boxes.keys())
    floating = []
    for i, root in enumerate(roots):
        a = boxes[root]
        ax0, ay0, az0, ax1, ay1, az1 = a[0] - gap, a[1] - gap, a[2] - gap, a[3] + gap, a[4] + gap, a[5] + gap
        touched = False
        for j, other in enumerate(roots):
            if i == j:
                continue
            b = boxes[other]
            if ax0 <= b[3] and ax1 >= b[0] and ay0 <= b[4] and ay1 >= b[1] and az0 <= b[5] and az1 >= b[2]:
                touched = True
                break
        if not touched:
            cx = (a[0] + a[3]) / 2.0
            cy = (a[1] + a[4]) / 2.0
            cz = (a[2] + a[5]) / 2.0
            floating.append((round(cx, 2), round(cy, 2), round(cz, 2)))
    return len(roots), floating


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_GEN
    mod = load_module(path)
    parts = mod.build_all_geometry()
    failures = []

    print("generator: %s" % os.path.basename(path))
    print("%-16s %7s %-24s %-24s %s" % ("object", "tris", "bbox(x,y,z)", "target", "flags"))
    print("-" * 100)

    total = 0
    gmin = [1e18] * 3
    gmax = [-1e18] * 3
    used_mats = set()

    for name, part in parts.items():
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
        if not name.startswith("SN_"):
            flags.append("bad_prefix")
        if name != mod.OBJECT:
            flags.append("unexpected_name")
        bad_mats = set(mats) - mod.ALLOWED_MATERIALS
        if bad_mats:
            flags.append("mat=%s" % ",".join(sorted(bad_mats)))
        if boundary:
            flags.append("boundary=%d" % boundary)
        if nonman:
            flags.append("nonmanifold=%d" % nonman)
        if degen:
            flags.append("degenerate=%d" % degen)
        used = set()
        for face, _m in part.faces:
            used.update(face)
        loose = len(part.verts) - len(used)
        if loose:
            flags.append("loose_verts=%d" % loose)
        if flags:
            failures.append((name, flags))
        print("%-16s %7d %-24s %-24s %s" % (
            name, tris,
            "%.2f,%.2f,%.2f" % size,
            "%.2f,%.2f,%.2f" % tuple(mod.TARGET_SIZE),
            ", ".join(flags) if flags else "ok"))
        islands, floating = island_report(part)
        if floating:
            failures.append((name, ["floating_islands=%d %s" % (len(floating), floating[:8])]))
        print("  islands=%d floating=%d %s" % (islands, len(floating), floating[:8] if floating else ""))
        for i in range(3):
            if abs(size[i] - mod.TARGET_SIZE[i]) > SIZE_TOL:
                failures.append((name, ["size_%s=%.2f" % ("xyz"[i], size[i])]))

    size = tuple(gmax[i] - gmin[i] for i in range(3))
    print("-" * 100)
    print("tris total = %d / %d" % (total, mod.TRI_BUDGET))
    print("bbox = %.2f x %.2f x %.2f m  (target %.2f x %.2f x %.2f, tol %.1f)" % (
        size[0], size[1], size[2], mod.TARGET_SIZE[0], mod.TARGET_SIZE[1], mod.TARGET_SIZE[2], SIZE_TOL))
    print("z range = %.2f .. %.2f (expect %.2f .. %.2f)" % (gmin[2], gmax[2], mod.Z_MIN, mod.Z_MAX))
    print("materials = %s" % ", ".join(sorted(used_mats)))

    if total > mod.TRI_BUDGET:
        failures.append(("TOTAL", ["over tri budget"]))
    if abs(gmin[2] - mod.Z_MIN) > 0.2 or abs(gmax[2] - mod.Z_MAX) > 0.4:
        failures.append(("Z", ["waterline/height out of tolerance"]))

    if failures:
        print("\nFAILURES:")
        for name, flags in failures:
            print("  %s: %s" % (name, ", ".join(flags)))
        return 1
    print("\nALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
