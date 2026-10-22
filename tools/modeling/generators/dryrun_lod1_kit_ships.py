# -*- coding: utf-8 -*-
# @static-doc
# 作用：LOD1 基础套件（M0-5）的纯 Python 干跑/计划生成：不进 Blender，读取 30 件
# LOD0 GLB 的真实世界包围盒与三角面，套用生成器的预算表（kit 30% / 船 25%，硬上限
# 35% / 30%）算出逐件 target / cap / big_ratio，并把计划落盘到
# `.design/lod1_kit_ships/plan.json`；同时校验 LOD0 资产齐全、kit 三角面与
# `kit_catalog.json` 一致、船体合计与既有迁移基线一致。
#
# ## 契约与约束
# - 只读：只写 `.design/lod1_kit_ships/plan.json`，不改 GLB / 工作台 / 内容 JSON。
# - LOD0 tri 以 GLB 的 indices 为准（与 `glb_world_bounds.world_bounds` 同源），
#   不信任 catalog 手写值；catalog 只用于交叉校验。
# - 计划失败（缺资产 / tri 不符 / 预算不可行）返回码 1；成功返回 0。
#
# ## 重点逻辑
# ### `main()`
# - 逐件 `world_bounds(lod0_path)` → `budget_plan()`；kit 与 catalog tri 对账，
#   ships 与 45 296 合计对账（铁甲舰 LOD0 于 2026-10-22 casemate 批次 8 830 → 8 158）；最后打印逐件表与分组预算。
# @end-static-doc

import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_DIR = os.path.join(REPO_ROOT, ".design", "lod1_kit_ships")
PLAN_PATH = os.path.join(OUT_DIR, "plan.json")
CATALOG_PATH = os.path.join(REPO_ROOT, "tools", "modeling", "kit_catalog.json")
SHIP_LOD0_BASELINE = 45296


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    generator = _load(os.path.join(HERE, "sn_lod1_kit_ships_generator.py"),
                       "sn_lod1_kit_ships_generator")
    bounds = _load(os.path.join(HERE, "glb_world_bounds.py"), "glb_world_bounds")
    catalog = json.load(open(CATALOG_PATH, encoding="utf-8"))["assets"]

    failures = []
    rows = []
    lod0_by_asset = {}
    for entry in generator.PLAN:
        asset = entry["asset"]
        path = generator.lod0_path(asset)
        if not os.path.exists(path):
            failures.append("%s: missing LOD0 %s" % (asset, os.path.relpath(path, REPO_ROOT)))
            continue
        geometry = bounds.world_bounds(path)
        lod0_tris = int(geometry["stats"]["tris"])
        lod0_by_asset[asset] = lod0_tris
        plan = generator.budget_plan(lod0_tris, kind=entry["kind"])
        if plan["cap_tris"] <= 0:
            failures.append("%s: infeasible cap" % asset)
        if plan["big_ratio"] < generator.MIN_RATIO - 1e-9:
            failures.append("%s: big ratio floor hit (%.3f)" % (asset, plan["big_ratio"]))
        if entry["kind"] == "kit":
            expected = int(catalog[asset]["tri_count"])
            if expected != lod0_tris:
                failures.append("%s: catalog tri %d != glb tri %d"
                                % (asset, expected, lod0_tris))
        if entry["kind"] == "ship" and geometry["stats"]["root_nodes"] is None:
            failures.append("%s: no root node" % asset)
        rows.append({
            "asset": asset, "kind": entry["kind"], "family": entry["family"],
            "category": entry["category"], "lod0_tris": lod0_tris,
            "lod0_bbox_size": geometry["size"], "lod0_bbox_min": geometry["min"],
            **plan,
        })

    ship_tris = sum(row["lod0_tris"] for row in rows if row["kind"] == "ship")
    if ship_tris != SHIP_LOD0_BASELINE:
        failures.append("ship LOD0 total %d != baseline %d" % (ship_tris, SHIP_LOD0_BASELINE))
    expected_kit_assets = 26
    if len([row for row in rows if row["kind"] == "kit"]) != expected_kit_assets:
        failures.append("kit asset count %d != %d" % (
            len([row for row in rows if row["kind"] == "kit"]), expected_kit_assets))

    summary = generator.summarise_plan(lod0_by_asset)
    payload = {"plan": rows, "summary": summary, "failures": failures,
               "passed": not failures,
               "baselines": {"ship_lod0_tris": SHIP_LOD0_BASELINE,
                             "kit_assets": expected_kit_assets}}
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(PLAN_PATH, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)

    print("%-26s %-5s %6s %6s %6s %7s" % ("asset", "kind", "L0tri", "target", "cap", "ratio"))
    print("-" * 64)
    for row in rows:
        print("%-26s %-5s %6d %6d %6d %7.3f" % (
            row["asset"], row["kind"], row["lod0_tris"], row["target_tris"],
            row["cap_tris"], row["big_ratio"]))
    print("-" * 64)
    print("summary: " + json.dumps(summary["groups"], ensure_ascii=False))
    print("totals: lod0=%d target=%d cap=%d" % (
        summary["total_lod0_tris"], summary["total_target_tris"],
        summary["total_cap_tris"]))
    print("plan: %s" % os.path.relpath(PLAN_PATH, REPO_ROOT))
    if failures:
        print("FAILURES:")
        for failure in failures:
            print("  " + failure)
        return 1
    print("DRYRUN OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
