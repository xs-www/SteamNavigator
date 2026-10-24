# -*- coding: utf-8 -*-
# @static-doc
# 作用：大型港口航站楼 SN_Grand_Harbour_Terminal 的纯 Python 干跑自检（不进 Blender）。
#
# 校验：对象/命名、三角面预算、世界包围盒、zmin、材质白名单、每个 mesh 的
# 边界边 / 非流形边 / 退化面 / 孤立点、共享贴图（含 SN_Tex_Copper_Green）存在、
# 关键体量与部件清单。Blender 侧的文字铭牌不计入几何预算，但会单独留 allowance。
#
# 用法：python tools/modeling/generators/dryrun_grand_harbour_terminal.py
# @end-static-doc

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import sn_grand_harbour_terminal_generator as gen  # noqa: E402
import sn_shared_materials as smat  # noqa: E402

EXPECTED_OBJECTS = {
    "SN_GHT_Quay_Base", "SN_GHT_Quay_Stairs", "SN_GHT_Quay_Balustrade",
    "SN_GHT_Plaza_Furniture", "SN_GHT_Central_Block",
    "SN_GHT_Central_Entrance", "SN_GHT_Portico", "SN_GHT_Wings",
    "SN_GHT_Wing_Arcades", "SN_GHT_Wing_Windows", "SN_GHT_Pavilions",
    "SN_GHT_Roofs", "SN_GHT_Tower", "SN_GHT_Tower_Clock", "SN_GHT_Details",
}
REQUIRED_PART_MARKERS = {
    "Quay_Base": "quay platform",
    "Quay_Stairs": "grand stairs",
    "Quay_Balustrade": "stone balustrade",
    "Central_Block": "central block",
    "Central_Entrance": "glazed entrance hall",
    "Portico": "giant portico",
    "Wing_Arcades": "arcaded wings",
    "Pavilions": "end pavilions",
    "Roofs": "copper roofs",
    "Tower": "clock tower",
    "Tower_Clock": "clock faces",
}


def _bbox(part):
    xs = [v[0] for v in part.verts]
    ys = [v[1] for v in part.verts]
    zs = [v[2] for v in part.verts]
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def main():
    failures = []
    rep = gen.geometry_report()
    print("geometry: %d objects / %d tris / bbox %s" % (
        rep["objects"], rep["tris"], rep["size"]))
    print("bbox_min=%s bbox_max=%s" % (rep["bbox_min"], rep["bbox_max"]))
    print("materials: %s" % ", ".join(rep["materials"]))

    if rep["objects"] != len(EXPECTED_OBJECTS):
        failures.append("object count %d != %d" % (rep["objects"], len(EXPECTED_OBJECTS)))
    if set(rep["per_object"]) != EXPECTED_OBJECTS:
        failures.append("object names mismatch: %s" % sorted(
            set(rep["per_object"]) ^ EXPECTED_OBJECTS))
    for name, info in rep["per_object"].items():
        if not name.startswith(gen.PREFIX):
            failures.append("%s: missing prefix" % name)
        if info["tris"] <= 0:
            failures.append("%s: empty object" % name)
        for key in ("boundary_edges", "non_manifold_edges", "degenerate_faces",
                    "loose_verts"):
            if info[key] != 0:
                failures.append("%s: %s=%d" % (name, key, info[key]))
        if not set(info["materials"]).issubset(gen.MATERIAL_WHITELIST):
            failures.append("%s: material outside whitelist" % name)

    # 关键尺寸 / 体量
    if abs(rep["bbox_min"][2]) > 0.02:
        failures.append("zmin %.3f != 0" % rep["bbox_min"][2])
    if abs(rep["bbox_max"][2] - 56.65) > 0.30:
        failures.append("height %.3f not around 56.65" % rep["bbox_max"][2])
    if abs(rep["bbox_min"][1] + rep["bbox_max"][1]) > 0.05:
        failures.append("Y symmetry broken: %s .. %s" % (
            rep["bbox_min"][1], rep["bbox_max"][1]))
    if rep["tris"] > gen.TRI_BUDGET - gen.SIGN_TRI_ALLOWANCE:
        failures.append("tri %d exceeds geometry allowance" % rep["tris"])

    # 关键部件体量
    parts = {k: v[0] for k, v in gen.build_geometry().items()}
    tower_min, tower_max = _bbox(parts["SN_GHT_Tower"])
    if abs((tower_min[0] + tower_max[0]) * 0.5 - gen.TOWER_CX) > 0.2:
        failures.append("tower not centred on x")
    if abs(tower_max[2] - gen.FLAG_TOP) > 0.6:
        failures.append("tower/flag top %.2f vs %.2f" % (tower_max[2], gen.FLAG_TOP))
    pav_min, pav_max = _bbox(parts["SN_GHT_Pavilions"])
    if pav_max[1] < gen.PAV_Y1 - 0.1:
        failures.append("pavilions do not reach wing ends")
    if pav_min[1] > -gen.PAV_Y1 + 0.1:
        failures.append("pavilions do not reach wing ends (-Y)")

    # 共享贴图
    report = smat.texture_report()
    for mat in gen.MATERIAL_WHITELIST:
        if mat not in report:
            failures.append("material %s missing from shared spec" % mat)
        elif not report[mat]["exists"]:
            failures.append("tile missing for %s" % mat)
    if "SN_Tex_Copper_Green" not in report:
        failures.append("SN_Tex_Copper_Green missing from shared spec")
    else:
        print("copper tile: %s (%s bytes) tile_m=%s" % (
            report["SN_Tex_Copper_Green"]["file"],
            report["SN_Tex_Copper_Green"]["bytes"],
            report["SN_Tex_Copper_Green"]["tile_m"]))

    # 材质分区检查：主楼/屋面/塔必须有铜、石、玻璃、黄铜
    def mats(name):
        return set(rep["per_object"][name]["materials"])
    for name, required in {
        "SN_GHT_Roofs": {"SN_Tex_Copper_Green", "SN_Tex_Iron"},
        "SN_GHT_Tower": {"SN_Tex_Copper_Green", "SN_Tex_Stone"},
        "SN_GHT_Tower_Clock": {"SN_Tex_Canvas_Shade", "SN_Tex_Brass"},
        "SN_GHT_Central_Entrance": {"SN_Tex_Glass_Dark", "SN_Tex_Brass"},
    }.items():
        missing = required - mats(name)
        if missing:
            failures.append("%s missing materials %s" % (name, sorted(missing)))

    print("-" * 78)
    print("%-30s %7s %8s %8s" % ("object", "tris", "faces", "health"))
    for name in sorted(rep["per_object"]):
        info = rep["per_object"][name]
        health = "ok" if (info["boundary_edges"] == 0 and
                          info["non_manifold_edges"] == 0 and
                          info["degenerate_faces"] == 0 and
                          info["loose_verts"] == 0) else "FAIL"
        print("%-30s %7d %8d %8s" % (name, info["tris"], info["faces"], health))
    print("-" * 78)
    print("TOTAL tris=%d / budget=%d (sign allowance %d)  floor=%d" % (
        rep["tris"], gen.TRI_BUDGET, gen.SIGN_TRI_ALLOWANCE, gen.TRI_FLOOR))
    if failures:
        for f in failures:
            print("FAIL", f)
        return 1
    print("ALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
