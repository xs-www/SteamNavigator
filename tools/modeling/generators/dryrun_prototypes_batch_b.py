# -*- coding: utf-8 -*-
# @static-doc
# 作用：批次 B 第一阶段（三栋新原型 LOD0）的**纯 Python 干跑**：不进 Blender，先收敛
# Boiler House / Workshop Row / Brick Tenement 的 tri 目标区间 / 硬上限 / 尺寸 ±0.10 /
# 网格健康 / 材质槽 / 必须包含项 tag，并把结果落盘到
# `.design/buildings/iron_harbor/b1/dryrun_prototypes.json`。
#
# ## 契约与约束
# - 不依赖 bpy：stub `bpy` / `bmesh` 后 import 生成器，只调用 `build_all_geometry()` 与
#   纯 Python 度量函数；任何 Blender 入口都不得在干跑路径被调用。
# - 只读仓库：除 `.design/buildings/iron_harbor/b1/dryrun_prototypes.json` 外不写文件。
# - 门禁：BH/WR tri ∈ [6000, 7500] 且 ≤8000；BT tri ∈ [9000, 12000] 且 ≤14000；
#   尺寸与 `PROTOTYPES.target` 差 ≤0.10；zmin=0；轴心 x/y=0；边界边/非流形/退化面=0；
#   材质槽 ≤6 且全 `SN_Town_*`。
#
# ## 重点逻辑
# ### `main()`
# - 逐栋 `measure(part)` + `feature_report(part)`：tri/尺寸/bbox/健康 + 必须项 tag 证据
#   （如 chimney 的 bbox 顶 z、fire_escape 的 bbox、sawtooth_roof 的面数），失败返回码 1。
# @end-static-doc

import importlib.util
import json
import os
import sys
import types
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DEFAULT_GEN = os.path.join(HERE, "sn_iron_harbor_prototypes_generator.py")
OUT_DIR = os.path.join(REPO_ROOT, ".design", "buildings", "iron_harbor", "b1")

SIZE_TOL = 0.10


def load_module(path, name):
    sys.modules.setdefault("bpy", types.ModuleType("bpy"))
    sys.modules.setdefault("bmesh", types.ModuleType("bmesh"))
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_GEN
    mod = load_module(path, "prototypes_under_test")
    geo = mod.build_all_geometry()

    print("generator: %s" % os.path.basename(path))
    print("%-28s %6s %-14s %6s %7s  %-24s %-24s %s" % (
        "object", "tris", "band", "cap", "zmin", "size(x,y,z)", "target", "flags"))
    print("-" * 140)
    results = []
    failures = []
    total = 0
    for spec in mod.PROTOTYPES:
        name = spec["asset"] + "_LOD0"
        part = geo[name]
        met = mod.measure_part(part)
        feats = mod.feature_report(part)
        total += met["tris"]
        lo, hi = spec["tris_band"]
        target = spec["target"]
        delta = tuple(met["size"][i] - target[i] for i in range(3))
        missing = [t for t in mod.REQUIRED_FEATURES[spec["asset"]] if t not in feats]
        flags = []
        if met["tris"] > spec["cap"]:
            flags.append("OVER-CAP")
        if not lo <= met["tris"] <= hi:
            flags.append("OUT-OF-BAND")
        if any(abs(d) > SIZE_TOL for d in delta):
            flags.append("size_delta=%s" % (tuple(round(d, 3) for d in delta),))
        if abs(met["zmin"]) > 1e-6:
            flags.append("zmin=%.4f" % met["zmin"])
        if abs(met["pivot_xy"][0]) > 1e-6 or abs(met["pivot_xy"][1]) > 1e-6:
            flags.append("pivot=%s" % (tuple(round(v, 4) for v in met["pivot_xy"]),))
        if met["boundary_edges"]:
            flags.append("boundary=%d" % met["boundary_edges"])
        if met["non_manifold_edges"]:
            flags.append("nonmanifold=%d" % met["non_manifold_edges"])
        if met["degenerate_faces"]:
            flags.append("degenerate=%d" % met["degenerate_faces"])
        if not 0 < len(met["materials"]) <= 6:
            flags.append("slots=%d" % len(met["materials"]))
        if not all(m.startswith("SN_Town_") for m in met["materials"]):
            flags.append("palette")
        if missing:
            flags.append("missing_features=%s" % (missing,))
        if flags:
            failures.append((name, flags))
        _s = "%.3f,%.3f,%.3f" % tuple(float(v) for v in met["size"])
        _t = "%.3f,%.3f,%.3f" % tuple(float(v) for v in target)
        print("%-28s %6d %-14s %6d %7.4f  %-24s %-24s %s" % (
            name, met["tris"], "%d-%d" % (lo, hi), spec["cap"], met["zmin"],
            _s, _t, ", ".join(flags) if flags else "ok"))
        results.append({
            "asset": spec["asset"], "object": name, "location": list(spec["location"]),
            "target": list(target), "tris_band": [lo, hi], "cap": spec["cap"],
            "tris": met["tris"], "verts": met["verts"], "size": met["size"],
            "size_delta": list(delta), "bbox": met["bbox"], "zmin": met["zmin"],
            "pivot_xy": met["pivot_xy"], "materials": met["materials"],
            "boundary_edges": met["boundary_edges"],
            "non_manifold_edges": met["non_manifold_edges"],
            "degenerate_faces": met["degenerate_faces"],
            "features": feats, "missing_features": missing,
            "checks": {
                "tris_in_band": lo <= met["tris"] <= hi,
                "tris_within_cap": met["tris"] <= spec["cap"],
                "size_ok": all(abs(d) <= SIZE_TOL for d in delta),
                "grounded": abs(met["zmin"]) <= 1e-6,
                "pivot_ok": abs(met["pivot_xy"][0]) <= 1e-6 and
                            abs(met["pivot_xy"][1]) <= 1e-6,
                "closed": met["boundary_edges"] == 0 and met["non_manifold_edges"] == 0,
                "no_degenerate": met["degenerate_faces"] == 0,
                "slots_ok": 0 < len(met["materials"]) <= 6,
                "palette_only": all(m.startswith("SN_Town_") for m in met["materials"]),
                "required_features_present": not missing,
            },
        })
    print("-" * 140)
    print("tris total = %d / %d" % (total, mod.TOTAL_BUDGET))

    payload = {"generator": os.path.basename(path),
               "tris_total": total, "tris_budget": mod.TOTAL_BUDGET,
               "size_tolerance_m": SIZE_TOL,
               "items": results,
               "failures": [{"object": n, "flags": f} for n, f in failures]}
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "dryrun_prototypes.json"), "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=1)
    print("dryrun -> %s" % os.path.join(OUT_DIR, "dryrun_prototypes.json"))

    if failures:
        print("\nFAILURES:")
        for name, flags in failures:
            print("  %s: %s" % (name, ", ".join(flags)))
        return 1
    print("\nALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
