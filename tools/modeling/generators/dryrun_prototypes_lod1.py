# -*- coding: utf-8 -*-
# @static-doc
# 作用：批次 B 第二阶段（三栋新原型 **LOD1**）的纯 Python 干跑：不进 Blender，把
# `SN_HT_<Name>_LOD1` 的 tri / 硬上限 / ≤LOD0 35% / 与 LOD0 的包围盒与轴心一致性 /
# 网格健康 / 材质槽 / §6 轮廓识别点 tag 全部收敛，并把 LOD1 计划 + 结果落盘到
# `.design/buildings/iron_harbor/b1/lod1_dryrun.json`。
#
# ## 契约与约束
# - 只用同一份参数化真源：LOD0 geometry 由 `build_all_geometry()`、LOD1 由
#   `build_all_geometry_lod1()` 生成，二者同文件、同常量、同闭合实体工具。
# - LOD1 必须保留 §6 轮廓识别点（LOD1_SPECS[*].silhouette 的 tag 必须存在）；
#   允许删除窗框/窗棂/窗台窗楣/隅石/落水管等小件。
# - 尺寸门禁：LOD1 与 LOD0 的局部 bbox 逐轴 ≤0.02 m、轴心（x/y=0）与 zmin=0；
#   硬上限 BH/WR 2 800、BT 4 900，且 ≤ 对应 LOD0 实测 tri 的 35%。
# - 不依赖 bpy：stub `bpy`/`bmesh` 后 import 生成器；只写 `.design/buildings/iron_harbor/b1/`。
#
# ## 重点逻辑
# ### `main()`
# - 逐栋：`measure_part(LOD0)` + `measure_part(LOD1)`；查 tri/cap/ratio、bbox/轴心/健康、
#   材质槽与调色板、LOD1 轮廓 tag；失败返回码 1。
# @end-static-doc

import importlib.util
import json
import os
import sys
import types

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DEFAULT_GEN = os.path.join(HERE, "sn_iron_harbor_prototypes_generator.py")
OUT_DIR = os.path.join(REPO_ROOT, ".design", "buildings", "iron_harbor", "b1")
SIZE_TOL = 0.02
RATIO_MAX = 0.35


def load_module(path, name):
    sys.modules.setdefault("bpy", types.ModuleType("bpy"))
    sys.modules.setdefault("bmesh", types.ModuleType("bmesh"))
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_GEN
    mod = load_module(path, "prototypes_lod1_under_test")
    lod0 = mod.build_all_geometry()
    lod1 = mod.build_all_geometry_lod1()

    print("generator: %s" % os.path.basename(path))
    print("%-28s %6s %6s %6s %7s %6s  %-24s %-24s %s" % (
        "object", "L0tri", "L1tri", "cap", "ratio", "zmin", "L1 size(x,y,z)",
        "target", "flags"))
    print("-" * 150)
    results = []
    failures = []
    for spec in mod.LOD1_SPECS:
        asset = spec["asset"]
        name0 = asset + "_LOD0"
        name1 = asset + "_LOD1"
        m0 = mod.measure_part(lod0[name0])
        m1 = mod.measure_part(lod1[name1])
        feats = mod.feature_report(lod1[name1])
        ratio = m1["tris"] / float(m0["tris"]) if m0["tris"] else 99.0
        target = spec["target"]
        size_delta = tuple(round(m1["size"][i] - m0["size"][i], 6) for i in range(3))
        target_delta = tuple(round(m1["size"][i] - target[i], 6) for i in range(3))
        bbox_delta = [round(m1["bbox"][0][i] - m0["bbox"][0][i], 6) for i in range(3)] + \
                     [round(m1["bbox"][1][i] - m0["bbox"][1][i], 6) for i in range(3)]
        missing = [t for t in spec["silhouette"] if t not in feats]
        flags = []
        if m1["tris"] > spec["cap"]:
            flags.append("OVER-CAP")
        if ratio > RATIO_MAX + 1e-9:
            flags.append("OVER-35%%(%.4f)" % ratio)
        if any(abs(d) > SIZE_TOL for d in size_delta) or any(abs(d) > SIZE_TOL for d in bbox_delta):
            flags.append("bbox_delta=%s" % (tuple(size_delta),))
        if any(abs(d) > SIZE_TOL for d in target_delta):
            flags.append("target_delta=%s" % (tuple(target_delta),))
        if abs(m1["zmin"]) > 1e-6:
            flags.append("zmin=%.4f" % m1["zmin"])
        if abs(m1["pivot_xy"][0]) > 1e-6 or abs(m1["pivot_xy"][1]) > 1e-6:
            flags.append("pivot=%s" % (tuple(round(v, 4) for v in m1["pivot_xy"]),))
        if m1["boundary_edges"]:
            flags.append("boundary=%d" % m1["boundary_edges"])
        if m1["non_manifold_edges"]:
            flags.append("nonmanifold=%d" % m1["non_manifold_edges"])
        if m1["degenerate_faces"]:
            flags.append("degenerate=%d" % m1["degenerate_faces"])
        if not 0 < len(m1["materials"]) <= 6:
            flags.append("slots=%d" % len(m1["materials"]))
        if not all(m.startswith("SN_Town_") for m in m1["materials"]):
            flags.append("palette")
        if missing:
            flags.append("missing_silhouette=%s" % (missing,))
        if flags:
            failures.append((name1, flags))
        print("%-28s %6d %6d %6d %7.4f %6.4f  %-24s %-24s %s" % (
            name1, m0["tris"], m1["tris"], spec["cap"], ratio, m1["zmin"],
            "%.3f,%.3f,%.3f" % tuple(m1["size"]),
            "%.3f,%.3f,%.3f" % tuple(target),
            ", ".join(flags) if flags else "ok"))
        results.append({
            "asset": asset, "object": name1, "location": list(spec["location"]),
            "lod0_tris": m0["tris"], "lod1_tris": m1["tris"], "cap": spec["cap"],
            "ratio": round(ratio, 5), "ratio_max": RATIO_MAX,
            "target": list(target), "lod0_size": m0["size"], "lod1_size": m1["size"],
            "size_delta_vs_lod0": list(size_delta),
            "size_delta_vs_target": list(target_delta),
            "bbox_delta_vs_lod0": bbox_delta,
            "zmin": m1["zmin"], "pivot_xy": m1["pivot_xy"],
            "verts": m1["verts"], "materials": m1["materials"],
            "boundary_edges": m1["boundary_edges"],
            "non_manifold_edges": m1["non_manifold_edges"],
            "degenerate_faces": m1["degenerate_faces"],
            "silhouette_features": {t: {"faces": feats[t]["faces"], "tris": feats[t]["tris"],
                                        "bbox": feats[t]["bbox"]}
                                    for t in spec["silhouette"] if t in feats},
            "missing_silhouette": missing,
            "checks": {
                "tris_within_cap": m1["tris"] <= spec["cap"],
                "ratio_within_35pct": ratio <= RATIO_MAX + 1e-9,
                "bbox_matches_lod0_0.02": all(abs(d) <= SIZE_TOL for d in size_delta) and
                                          all(abs(d) <= SIZE_TOL for d in bbox_delta),
                "size_matches_target_0.02": all(abs(d) <= SIZE_TOL for d in target_delta),
                "grounded": abs(m1["zmin"]) <= 1e-6,
                "pivot_ok": abs(m1["pivot_xy"][0]) <= 1e-6 and
                            abs(m1["pivot_xy"][1]) <= 1e-6,
                "closed": m1["boundary_edges"] == 0 and m1["non_manifold_edges"] == 0,
                "no_degenerate": m1["degenerate_faces"] == 0,
                "slots_ok": 0 < len(m1["materials"]) <= 6,
                "palette_only": all(m.startswith("SN_Town_") for m in m1["materials"]),
                "silhouette_kept": not missing,
            },
        })
    print("-" * 150)
    print("LOD1 tris total = %d" % sum(r["lod1_tris"] for r in results))

    plan = [{"asset": s["asset"], "cap": s["cap"], "location": list(s["location"]),
             "keep": s["keep"], "cut": s["cut"], "silhouette": s["silhouette"]}
            for s in mod.LOD1_SPECS]
    payload = {"generator": os.path.basename(path),
              "plan": plan, "size_tolerance_m": SIZE_TOL, "ratio_max": RATIO_MAX,
              "items": results,
              "failures": [{"object": n, "flags": f} for n, f in failures]}
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "lod1_dryrun.json"), "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=1)
    print("dryrun -> %s" % os.path.join(OUT_DIR, "lod1_dryrun.json"))

    if failures:
        print("\nFAILURES:")
        for name, flags in failures:
            print("  %s: %s" % (name, ", ".join(flags)))
        return 1
    print("\nALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
