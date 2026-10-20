# -*- coding: utf-8 -*-
# @static-doc
# 作用：批次 A（5 栋建筑 LOD1）的**纯 Python 干跑**：不进 Blender，先把 LOD1 的 tri / 上限 /
# LOD0 35% 比例 / 包围盒 / zmin / 轴心 / 边界边 / 非流形边 / 退化面 / 材质槽全部收敛到门禁内，
# 并把结果落盘到 `.design/buildings/iron_harbor/a1/dryrun_lod1.json`。
#
# ## 契约与约束
# - 与 `dryrun_props.py` 的分工：后者按 `ITEMS` 做通用单件检查；本脚本额外用**同一份参数化
#   真源重建 LOD0**，用 LOD0 的实测 tri 计算 35% 门禁，并逐轴比较包围盒（容差 0.02 m）。
# - 只能用纯 Python：stub `bpy` / `bmesh` 后 import LOD1 生成器；任何需要 Blender 的入口
#   （build_all/report/render_previews）都不得在干跑路径被调用。
# - 只读仓库：除 `.design/buildings/iron_harbor/a1/dryrun_lod1.json` 外不写任何文件。
#
# ## 重点逻辑
# ### `main()`
# - 逐栋：`measure(LOD1 part)` + 用 `mod.lod0(asset)` 重建 LOD0 part 再 `measure`，比较
#   `tris / size / zmin / 轴心 / boundary / non-manifold / degenerate / materials`；
#   任一失败返回码 1，并在 `failures` 中列出对象与失败项。
# @end-static-doc

import importlib.util
import json
import os
import sys
import types
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DEFAULT_GEN = os.path.join(HERE, "sn_iron_harbor_architecture_lod1_generator.py")
OUT_DIR = os.path.join(REPO_ROOT, ".design", "buildings", "iron_harbor", "a1")

SIZE_TOL = 0.02          # LOD0↔LOD1 目标尺寸容差（任务门禁 ±0.02 m）
LOD1_RATIO = 0.35


def load_module(path, name):
    sys.modules.setdefault("bpy", types.ModuleType("bpy"))
    sys.modules.setdefault("bmesh", types.ModuleType("bmesh"))
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def tri_count(faces):
    return sum(max(0, len(f) - 2) for f, _m in faces)


def edge_stats(faces):
    counter = Counter()
    for face, _m in faces:
        n = len(face)
        for i in range(n):
            a, b = face[i], face[(i + 1) % n]
            counter[(min(a, b), max(a, b))] += 1
    return (sum(1 for c in counter.values() if c == 1),
            sum(1 for c in counter.values() if c > 2))


def degenerate_faces(verts, faces):
    bad = 0
    for face, _m in faces:
        if len(set(face)) != len(face):
            bad += 1
            continue
        p0 = verts[face[0]]
        for i in range(1, len(face) - 1):
            p1, p2 = verts[face[i]], verts[face[i + 1]]
            ux, uy, uz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
            vx, vy, vz = p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2]
            cx, cy, cz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
            if (cx * cx + cy * cy + cz * cz) ** 0.5 * 0.5 < 1e-9:
                bad += 1
                break
    return bad


def measure(part):
    xs = [v[0] for v in part.verts]
    ys = [v[1] for v in part.verts]
    zs = [v[2] for v in part.verts]
    boundary, nonman = edge_stats(part.faces)
    mats = []
    for _f, mat in part.faces:
        if mat not in mats:
            mats.append(mat)
    return {
        "tris": tri_count(part.faces), "verts": len(part.verts),
        "size": (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)),
        "zmin": min(zs),
        "pivot_xy": (0.5 * (min(xs) + max(xs)), 0.5 * (min(ys) + max(ys))),
        "boundary": boundary, "nonmanifold": nonman,
        "degenerate": degenerate_faces(part.verts, part.faces),
        "materials": mats,
    }


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_GEN
    mod = load_module(path, "lod1_under_test")
    lod1_geo = mod.build_all_geometry()

    print("generator: %s" % os.path.basename(path))
    print("%-30s %6s %6s %6s %7s  %-24s %-24s %s" % (
        "item", "tris", "cap", "ratio", "zmin", "size(x,y,z)", "target", "flags"))
    print("-" * 132)
    results = []
    failures = []
    total = 0
    for spec in mod.LOD1_SPECS:
        asset = spec["asset"]
        name = asset + "_LOD1"
        part = lod1_geo[name]
        lod1 = measure(part)
        total += lod1["tris"]
        # LOD0：用同一份参数化真源重建，实测 35% 门禁与包围盒
        G = mod.lod0(asset)
        if asset == "SN_HT_Warehouse_Long":
            lod0_part = G.build_warehouse_long()
        else:
            lod0_part = G.build_all_geometry()[G.NAME]
        lod0 = measure(lod0_part)
        ratio = lod1["tris"] / float(lod0["tris"]) if lod0["tris"] else 0.0
        target = spec["target"]
        delta = tuple(lod1["size"][i] - target[i] for i in range(3))
        flags = []
        if lod1["tris"] > spec["cap"]:
            flags.append("OVER-CAP")
        if ratio > LOD1_RATIO:
            flags.append("OVER-35%%(%.3f)" % ratio)
        if any(abs(d) > SIZE_TOL for d in delta):
            flags.append("size_delta=%s" % (tuple(round(d, 3) for d in delta),))
        if abs(lod1["zmin"]) > 1e-6:
            flags.append("zmin=%.4f" % lod1["zmin"])
        if abs(lod1["pivot_xy"][0]) > 1e-6 or abs(lod1["pivot_xy"][1]) > 1e-6:
            flags.append("pivot=%s" % (tuple(round(v, 4) for v in lod1["pivot_xy"]),))
        if lod1["boundary"]:
            flags.append("boundary=%d" % lod1["boundary"])
        if lod1["nonmanifold"]:
            flags.append("nonmanifold=%d" % lod1["nonmanifold"])
        if lod1["degenerate"]:
            flags.append("degenerate=%d" % lod1["degenerate"])
        if not 0 < len(lod1["materials"]) <= 6:
            flags.append("slots=%d" % len(lod1["materials"]))
        if flags:
            failures.append((name, flags))
        print("%-30s %6d %6d %6.3f %7.4f  %-24s %-24s %s" % (
            name, lod1["tris"], spec["cap"], ratio, lod1["zmin"],
            "%.3f,%.3f,%.3f" % lod1["size"], "%.3f,%.3f,%.3f" % tuple(target),
            ", ".join(flags) if flags else "ok"))
        results.append({
            "asset": asset, "object": name, "location": list(spec["location"]),
            "lod0_tris": lod0["tris"], "lod0_size": list(lod0["size"]),
            "lod1_tris": lod1["tris"], "lod1_cap": spec["cap"],
            "lod1_ratio": round(ratio, 5), "target": list(target),
            "lod1_size": list(lod1["size"]), "size_delta": list(delta),
            "zmin": round(lod1["zmin"], 9),
            "pivot_xy": [round(v, 9) for v in lod1["pivot_xy"]],
            "verts": lod1["verts"], "boundary_edges": lod1["boundary"],
            "non_manifold_edges": lod1["nonmanifold"],
            "degenerate_faces": lod1["degenerate"],
            "materials": lod1["materials"],
            "checks": {
                "cap_ok": lod1["tris"] <= spec["cap"],
                "ratio_ok": ratio <= LOD1_RATIO + 1e-12,
                "size_ok": all(abs(d) <= SIZE_TOL for d in delta),
                "grounded": abs(lod1["zmin"]) <= 1e-6,
                "pivot_ok": abs(lod1["pivot_xy"][0]) <= 1e-6 and
                            abs(lod1["pivot_xy"][1]) <= 1e-6,
                "closed": lod1["boundary"] == 0 and lod1["nonmanifold"] == 0,
                "no_degenerate": lod1["degenerate"] == 0,
                "slots_ok": 0 < len(lod1["materials"]) <= 6,
                "palette_only": all(m.startswith("SN_Town_") for m in lod1["materials"]),
            },
        })
    print("-" * 132)
    print("tris total = %d / %d  (LOD0 total = %d)"
          % (total, mod.TOTAL_BUDGET, sum(r["lod0_tris"] for r in results)))

    payload = {"generator": os.path.basename(path),
               "lod1_total_tris": total, "lod1_total_budget": mod.TOTAL_BUDGET,
               "lod0_total_tris": sum(r["lod0_tris"] for r in results),
               "size_tolerance_m": SIZE_TOL, "lod1_ratio_max": LOD1_RATIO,
               "items": results,
               "failures": [{"object": n, "flags": f} for n, f in failures]}
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "dryrun_lod1.json"), "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=1)
    print("dryrun -> %s" % os.path.join(OUT_DIR, "dryrun_lod1.json"))

    if failures:
        print("\nFAILURES:")
        for name, flags in failures:
            print("  %s: %s" % (name, ", ".join(flags)))
        return 1
    print("\nALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
