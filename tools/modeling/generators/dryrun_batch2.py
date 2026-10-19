# -*- coding: utf-8 -*-
"""铁港第二批几何干跑：不起 Blender，只校验几何本身。

做法：把 bpy / bmesh 替换成空壳模块，再加载生成器里的纯几何函数，
逐件算三角面、包围盒、边界边 / 非流形边、退化面、底面 z。

用法：python tools/modeling/generators/dryrun_batch2.py
"""

import importlib.util
import os
import sys
import types
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
GEN = os.path.join(HERE, "sn_iron_harbor_batch2_generator.py")


def load_module():
    # 生成器顶部只 import math；bpy/bmesh 只在函数内部 import，这里直接加载即可
    sys.modules.setdefault("bpy", types.ModuleType("bpy"))
    sys.modules.setdefault("bmesh", types.ModuleType("bmesh"))
    spec = importlib.util.spec_from_file_location("batch2_gen", GEN)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def tri_count(faces):
    return sum(max(0, len(f) - 2) for f, _ in faces)


def edge_stats(faces):
    counter = Counter()
    for face, _mat in faces:
        n = len(face)
        for i in range(n):
            a, b = face[i], face[(i + 1) % n]
            counter[(min(a, b), max(a, b))] += 1
    boundary = sum(1 for c in counter.values() if c == 1)
    nonmanifold = sum(1 for c in counter.values() if c > 2)
    return boundary, nonmanifold


def degenerate_faces(verts, faces):
    bad = 0
    for face, _mat in faces:
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
            if (cx * cx + cy * cy + cz * cz) ** 0.5 * 0.5 < 1e-9:
                bad += 1
                break
    return bad


def main():
    mod = load_module()
    geometry = mod.build_all_geometry()
    total = 0
    failures = []

    print("%-18s %6s %6s %8s   %-22s %-22s %s" % (
        "item", "tris", "budget", "limit", "size(x,y,z)", "target", "flags"))
    print("-" * 118)

    for name, pos, budget, target in mod.ITEMS:
        part = geometry[name]
        tris = tri_count(part.faces)
        total += tris
        xs = [v[0] for v in part.verts]
        ys = [v[1] for v in part.verts]
        zs = [v[2] for v in part.verts]
        size = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
        boundary, nonman = edge_stats(part.faces)
        degen = degenerate_faces(part.verts, part.faces)
        zmin = min(zs)
        delta = tuple(size[i] - target[i] for i in range(3))

        flags = []
        if tris > budget * 1.5:
            flags.append("OVER-1.5x")
        if boundary:
            flags.append("boundary=%d" % boundary)
        if nonman:
            flags.append("nonmanifold=%d" % nonman)
        if degen:
            flags.append("degenerate=%d" % degen)
        if abs(zmin) > 1e-6:
            flags.append("zmin=%.4f" % zmin)
        if any(abs(d) > 0.1 for d in delta):
            flags.append("size_delta=%s" % (tuple(round(d, 3) for d in delta),))
        if flags:
            failures.append((name, flags))

        print("%-18s %6d %6d %8d   %-22s %-22s %s" % (
            name, tris, budget, int(budget * 1.5),
            "%.3f,%.3f,%.3f" % size,
            "%.3f,%.3f,%.3f" % target,
            ", ".join(flags) if flags else "ok"))

    print("-" * 118)
    print("tris total = %d / %d" % (total, mod.TOTAL_BUDGET))
    if total > mod.TOTAL_BUDGET:
        failures.append(("TOTAL", ["over budget"]))

    if failures:
        print("\nFAILURES:")
        for name, flags in failures:
            print("  %s: %s" % (name, ", ".join(flags)))
        return 1
    print("\nALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
