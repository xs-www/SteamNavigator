# -*- coding: utf-8 -*-
"""SN_Schooner_Fame 生成器纯 Python 干跑：不进 Blender，先拦几何缺陷。

把 bpy / bmesh 换成空壳模块后加载生成器，跑 build_all_geometry()，逐对象核对：
三角面预算、包围盒、边界边 / 非流形边、退化面 / 孤立点、材质名、命名与父级键、
船体左右镜像误差。

用法：
    python tools/modeling/generators/dryrun_schooner_fame.py
"""

import importlib.util
import math
import os
import sys
import types
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_GEN = os.path.join(HERE, "sn_schooner_fame_generator.py")

TRI_BUDGET = 18000
# 总长（含艏斜桁/艏三角帆）/ 总宽 / 总高（龙骨到主桅顶）
SIZE_TARGET = (33.44, 6.88, 26.82)
SIZE_TOL = 0.8
# 单层曲面：甲板 / 帆 / 长旒（材质双面，允许边界边）
OPEN_ALLOWED = {
    "SN_SF_Deck", "SN_SF_Quarterdeck", "SN_SF_Sails_Fore", "SN_SF_Sails_Main",
    "SN_SF_Headsails", "SN_SF_Pennant",
}
ALLOWED_MATERIALS = {
    "SN_Hull_Black", "SN_Ochre", "SN_Wood", "SN_Wood_Dark", "SN_Wood_Deck",
    "SN_Canvas", "SN_Canvas_Shade", "SN_Metal", "SN_Brass",
    "SN_Flag_Red", "SN_Flag_White", "SN_Flag_Blue",
}
PARENT_KEYS = {"ROOT", "FORE", "MAIN"}
REQUIRED = {
    "SN_SF_Hull", "SN_SF_Deck", "SN_SF_Bulwark", "SN_SF_Wales",
    "SN_SF_Keel_Stem_Rudder", "SN_SF_Figurehead", "SN_SF_Stern_Gallery",
    "SN_SF_Bowsprit", "SN_SF_Mast_Fore", "SN_SF_Mast_Main",
    "SN_SF_Spars_Fore", "SN_SF_Spars_Main", "SN_SF_Sails_Fore",
    "SN_SF_Sails_Main", "SN_SF_Headsails", "SN_SF_Rigging_Standing",
    "SN_SF_Rigging_Running", "SN_SF_Hatches", "SN_SF_Capstan_Windlass",
    "SN_SF_Wheel_Binnacle", "SN_SF_Fife_Rails", "SN_SF_Ladders",
    "SN_SF_Pennant",
}


def load_module(path):
    sys.modules.setdefault("bpy", types.ModuleType("bpy"))
    sys.modules.setdefault("bmesh", types.ModuleType("bmesh"))
    spec = importlib.util.spec_from_file_location("schooner_gen_under_test", path)
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


def isolated_verts(part):
    used = set()
    for face, _m in part.faces:
        used.update(face)
    return sum(1 for i in range(len(part.verts)) if i not in used)


def mirror_error(part):
    """检查左右镜像：每个顶点 (x,y,z) 都存在 (x,-y,z) 对应点。"""
    if not part.verts:
        return 0.0
    pts = {(round(v[0], 4), round(v[1], 4), round(v[2], 4)) for v in part.verts}
    worst = 0.0
    for x, y, z in part.verts:
        key = (round(x, 4), round(-y, 4), round(z, 4))
        if key in pts:
            continue
        # 精确匹配失败时找最近点
        best = 1e18
        for px, py, pz in part.verts:
            if abs(px - x) < 0.05 and abs(pz - z) < 0.05:
                d = abs(py + y)
                if d < best:
                    best = d
        worst = max(worst, best)
    return worst


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_GEN
    mod = load_module(path)
    parts = mod.build_all_geometry()

    print("generator: %s" % os.path.basename(path))
    print("%-30s %6s %-16s %-26s %-18s %s" % (
        "object", "tris", "bbox(x,y,z)", "materials", "parent", "flags"))
    print("-" * 132)

    failures = []
    total = 0
    gmin = [1e18] * 3
    gmax = [-1e18] * 3
    seen_names = set()
    used_mats = set()

    for name, (part, parent) in parts.items():
        tris = tri_count(part)
        total += tris
        # 桅/帆/桁是 Pivot 局部坐标；干跑必须施加 pivot 位移 + 后倾，
        # 否则全局 bbox 与桅杆世界位置都会算错（历史 P0 漏检点）。
        if parent == "FORE":
            wverts = [mod.mast_to_world("Fore", v) for v in part.verts]
        elif parent == "MAIN":
            wverts = [mod.mast_to_world("Main", v) for v in part.verts]
        else:
            wverts = part.verts
        xs = [v[0] for v in wverts]
        ys = [v[1] for v in wverts]
        zs = [v[2] for v in wverts]
        size = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
        for i, arr in enumerate((xs, ys, zs)):
            gmin[i] = min(gmin[i], min(arr))
            gmax[i] = max(gmax[i], max(arr))
        boundary, nonman = edge_stats(part)
        degen = degenerate_faces(part)
        iso = isolated_verts(part)
        mats = sorted({m for _f, m in part.faces})
        used_mats.update(mats)

        flags = []
        if not name.startswith("SN_SF_"):
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
        if iso:
            flags.append("isolated=%d" % iso)
        bad_mats = set(mats) - ALLOWED_MATERIALS
        if bad_mats:
            flags.append("mat=%s" % ",".join(sorted(bad_mats)))
        if not mats:
            flags.append("no_material")
        if flags:
            failures.append((name, flags))

        print("%-30s %6d %-16s %-26s %-18s %s" % (
            name, tris,
            "%.2f,%.2f,%.2f" % size,
            ",".join(m.replace("SN_", "") for m in mats)[:26],
            parent,
            ", ".join(flags) if flags else "ok"))

    print("-" * 132)
    size = tuple(gmax[i] - gmin[i] for i in range(3))
    print("tris total = %d / %d" % (total, TRI_BUDGET))
    print("bbox = %.2f x %.2f x %.2f m  (target %.1f x %.1f x %.1f, tol %.1f)" % (
        size[0], size[1], size[2], SIZE_TARGET[0], SIZE_TARGET[1],
        SIZE_TARGET[2], SIZE_TOL))
    print("z range = %.2f .. %.2f" % (gmin[2], gmax[2]))
    print("materials = %s" % ", ".join(sorted(used_mats)))

    if total > TRI_BUDGET:
        failures.append(("TOTAL", ["over tri budget"]))
    for i, axis in enumerate("xyz"):
        if abs(size[i] - SIZE_TARGET[i]) > SIZE_TOL:
            failures.append(("BBOX", ["%s %.2f vs %.2f" % (
                axis, size[i], SIZE_TARGET[i])]))
    for name in sorted(REQUIRED):
        if name not in parts:
            failures.append((name, ["missing required object"]))
    hull_part = parts["SN_SF_Hull"][0] if "SN_SF_Hull" in parts else None
    hull_err = mirror_error(hull_part) if hull_part is not None else 1.0
    print("hull mirror error = %.6f m (limit 0.002)" % hull_err)
    if hull_err > 0.002:
        failures.append(("SN_SF_Hull", ["mirror error %.4f" % hull_err]))

    # 桅杆世界轴线 / 后倾断言（R1 P0 的回归护栏）
    fore_x = mod.MASTS["Fore"]["x"]
    main_x = mod.MASTS["Main"]["x"]
    fore_top = mod.mast_world("Fore", mod.MASTS["Fore"]["gallant"] + 0.20)
    main_top = mod.mast_world("Main", mod.MASTS["Main"]["gallant"] + 0.20)
    axis_gap = abs(fore_x - main_x)
    print("mast axis gap = %.3f m (expect 6.400)" % axis_gap)
    print("mast tops = Fore %s / Main %s" % (
        tuple(round(v, 3) for v in fore_top),
        tuple(round(v, 3) for v in main_top)))
    if abs(axis_gap - 6.4) > 0.05:
        failures.append(("MASTS", ["axis gap %.3f != 6.400" % axis_gap]))
    if not (fore_top[0] < fore_x - 0.10 and main_top[0] < main_x - 0.10):
        failures.append(("MASTS", ["rake not leaning aft"]))
    if abs(fore_top[2] - (mod.FORE_DECK_Z +
                          (mod.MASTS["Fore"]["gallant"] + 0.20) *
                          math.cos(math.radians(mod.MASTS["Fore"]["rake"])))) > 0.05:
        failures.append(("MASTS", ["Fore top z transform mismatch"]))
    if not (main_top[2] > fore_top[2] + 0.50):
        failures.append(("MASTS", ["Main mast should be taller than Fore"]))

    if failures:
        print("\nFAILURES:")
        for name, flags in failures:
            print("  %s: %s" % (name, ", ".join(flags)))
        return 1
    print("\nALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
