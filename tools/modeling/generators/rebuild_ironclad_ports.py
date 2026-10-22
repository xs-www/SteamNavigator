# -*- coding: utf-8 -*-
# @static-doc
# 作用：炮门贴合船壳弧度的**重建脚本**（Blender 内跑一次，2026-10-22 修复批次）——
# 按 `sn_ironclad_generator.build_all(with_barrels=False)` 重造船体网格（炮门框 / 深色炮口板 /
# 上翻门盖改为逐角取 `hull_surface_y()`，贴合 17 站放样壳面），再幂等复挂 4 武器 + 9 帆索 +
# 12 炮门 socket，并做只读复核。
#
# ## 为什么可以整船重建
# M0-6 批次已把生成器同步到资产真源（`SN_Tex_*` 材质 + `apply_collection(space="local")` UV +
# `with_barrels` 开关），`apply_casemate_assets.py` 的几何门禁也证明过“现存网格 = 生成器变体”。
# 本轮只改炮门件形状、三角面数不变（8158），重建后 socket 由各自脚本复原。
#
# ## 门禁与断言
# - 重建前：现存网格必须是 5133 顶点 / 4624 面 / 8158 tri，8 个材质槽，逐材质面数等于基线；
# - 重建后：三角面仍 8158、包围盒不变（60.13 × 18.00 × 28.64）、网格健康四项全 0；
# - 复挂后：`sn_ship_weapon_sockets` / `sn_ship_rig_sockets` / `sn_ship_gun_ports` 只读复核全过，
#   炮门中心与 `gun_port_pose()` 一致（误差 ≤ 1e-4）。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# @end-static-doc

import importlib
import json
import os
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

IC_OBJECT = "SN_Ironclad"
EXPECTED = {
    "verts": 5133,
    "faces": 4624,
    "tris": 8158,
    "materials": ["SN_Tex_Iron", "SN_Tex_Iron_Red", "SN_Tex_Wood_Deck", "SN_Tex_Metal",
                  "SN_Tex_Wood_Dark", "SN_Tex_Brass", "SN_Tex_Wood", "SN_Tex_Canvas_Shade"],
    "material_faces": {"SN_Tex_Iron": 650, "SN_Tex_Iron_Red": 100,
                       "SN_Tex_Wood_Deck": 22, "SN_Tex_Metal": 1806,
                       "SN_Tex_Wood_Dark": 280, "SN_Tex_Brass": 758,
                       "SN_Tex_Wood": 792, "SN_Tex_Canvas_Shade": 216},
    "bbox": [60.13, 18.00, 28.64],
}


def _reload(name):
    if name in sys.modules:
        return importlib.reload(sys.modules[name])
    return importlib.import_module(name)


def _brief(mesh):
    mesh.calc_loop_triangles()
    return {
        "verts": len(mesh.vertices),
        "faces": len(mesh.polygons),
        "tris": len(mesh.loop_triangles),
        "materials": [mat.name if mat else "" for mat in mesh.materials],
    }


def _material_faces(mesh):
    counts = Counter()
    for poly in mesh.polygons:
        counts[mesh.materials[poly.material_index].name] += 1
    return dict(counts)


def _bbox(mesh):
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    return [round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2),
            round(max(zs) - min(zs), 2)]


def rebuild():
    import bpy
    import bmesh

    ic = _reload("sn_ironclad_generator")
    _reload("sn_weapon_materials")
    socks = _reload("sn_ship_weapon_sockets")
    rigsocks = _reload("sn_ship_rig_sockets")
    gunports = _reload("sn_ship_gun_ports")

    report = {"workbench": bpy.data.filepath, "steps": []}
    obj = bpy.data.objects.get(IC_OBJECT)
    if obj is None or obj.type != "MESH":
        raise RuntimeError("找不到 %s 网格" % IC_OBJECT)

    before = _brief(obj.data)
    before_faces = _material_faces(obj.data)
    failures = []
    for key in ("verts", "faces", "tris"):
        if before[key] != EXPECTED[key]:
            failures.append("重建前 %s=%d != %d" % (key, before[key], EXPECTED[key]))
    if before["materials"] != EXPECTED["materials"]:
        failures.append("重建前材质槽 %r" % before["materials"])
    if before_faces != EXPECTED["material_faces"]:
        failures.append("重建前逐材质面数 %r" % before_faces)
    report["steps"].append({"hull_before": before, "passed": not failures,
                            "failures": failures})
    if failures:
        raise RuntimeError("重建前门禁失败：%r" % failures)

    ic.build_all(with_barrels=False)
    mesh = bpy.data.objects[IC_OBJECT].data
    after = _brief(mesh)
    report["steps"].append({"hull_after": after, "bbox": _bbox(mesh),
                            "material_faces": _material_faces(mesh)})

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.edges.ensure_lookup_table()
    health = {
        "non_manifold_edges": sum(1 for e in bm.edges if not e.is_manifold),
        "boundary_edges": sum(1 for e in bm.edges if e.is_boundary),
        "loose_verts": sum(1 for v in bm.verts if not v.link_edges),
        "degenerate_faces": sum(1 for f in bm.faces if f.calc_area() < 1e-9),
    }
    bm.free()
    bbox = _bbox(mesh)
    if after["tris"] != EXPECTED["tris"]:
        failures.append("重建后 tri=%d" % after["tris"])
    if bbox != EXPECTED["bbox"]:
        failures.append("重建后 bbox=%r" % bbox)
    if any(health.values()):
        failures.append("重建后网格健康 %r" % health)
    report["steps"].append({"health": health, "passed": not failures,
                            "failures": failures})
    if failures:
        raise RuntimeError("重建后断言失败：%r" % failures)

    ic_ship = next(ship for ship in socks.SHIPS if ship["asset"] == IC_OBJECT)
    weapon = socks.apply_ship(ic_ship)
    rig_ship = next(ship for ship in rigsocks.SHIPS if ship["asset"] == IC_OBJECT)
    rig_specs = rigsocks.build_specs()[IC_OBJECT]
    rig = rigsocks.apply_ship(rig_ship, rig_specs)
    ports = gunports.apply_all()
    report["steps"].append({
        "weapon_sockets": {"passed": weapon["passed"], "count": len(weapon["sockets"])},
        "rig_sockets": {"created": len(rig["created"]),
                        "geometry_unchanged": rig["geometry_unchanged"]},
        "gun_ports": {"passed": ports["passed"],
                      "measured": [item["ports"] for item in ports["ships"]]},
    })
    if not (weapon["passed"] and rig["geometry_unchanged"] and ports["passed"]):
        raise RuntimeError("socket 复挂失败")

    verify = {
        "weapon": socks.verify_ship(ic_ship),
        "rig": rigsocks.verify_ship(rig_ship, rig_specs),
        "gun_ports": gunports.verify_all(),
    }
    report["verify"] = {
        "weapon_passed": verify["weapon"]["passed"],
        "weapon_failures": verify["weapon"]["failures"],
        "rig_passed": verify["rig"]["passed"],
        "rig_failures": verify["rig"].get("failures", []),
        "gun_ports_passed": verify["gun_ports"]["passed"],
    }
    report["passed"] = all(report["verify"][key] for key in
                           ("weapon_passed", "rig_passed", "gun_ports_passed"))
    if not report["passed"]:
        raise RuntimeError("socket 复核失败：%r" % report["verify"])
    bpy.ops.wm.save_mainfile()
    print("PORT_CONFORMANCE_REBUILD_DONE " + json.dumps(report, ensure_ascii=False,
                                                         default=str))
    return report


if __name__ == "__main__":
    rebuild()
