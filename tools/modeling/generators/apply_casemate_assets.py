# -*- coding: utf-8 -*-
# @static-doc
# 作用：casemate gun 模块化的 **Blender 落盘脚本**（在已连 MCP 的活体 Blender 里跑一次）：
# 1. 几何门禁：证明“现存 `SN_Ironclad` 网格 == 生成器 `with_barrels=True` 变体”
#    （顶点按**索引**逐点比对 + 面按索引比顶点集合 / 材质），再按面索引删除 12 门炮管 +
#    炮口箍（480 面 / 672 tri）；删完校验顶点/面/三角面、逐材质面数，且原炮管顶点一个都不剩
#    （1 mm 容差哈希）。幂等：已经是空炮门则跳过；
# 2. 重建独立炮模块集合 `SN_Weapon_CasemateGun_Prototype`；
# 3. 重挂 4 个甲板武器 socket + 9 个帆索 socket（几何编辑后子空节点保留，这里做幂等补齐）；
# 4. 补齐 12 个 `SN_IC_Socket_GunPort_*` 炮门 socket 并实测门内纵深 / 舷外净空；
# 5. 只读复核三套 socket + 炮模块报告。
#
# 为什么用“按面索引删除”而不是整船重建：现存资产已经过 legacy UV 迁移 B（共享贴图 + UVMap）
# 和两批 socket，整船重建会把材质/UV/空节点全部丢掉；按索引只删炮管面能保证其余几何与材质
# 逐位不变。删除前先做生成器一致性门禁，避免在“资产与生成器已漂移”时盲删。
#
# 用法（Blender 内）：
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
VERT_TOL = 1e-4        # 生成器 float64 ↔ Blender mesh float32，实测最大偏差 ~1e-6
HASH_CELL = 0.01       # 容差哈希网格（1 cm），只用于“炮管顶点是否已删干净”
HASH_TOL = 1e-3


def _reload(name):
    if name in sys.modules:
        return importlib.reload(sys.modules[name])
    return importlib.import_module(name)


def _mesh_brief(mesh):
    mesh.calc_loop_triangles()
    return {"verts": len(mesh.vertices), "faces": len(mesh.polygons),
            "tris": len(mesh.loop_triangles),
            "materials": [mat.name if mat else "" for mat in mesh.materials]}


def _face_key(part, face):
    """面身份 = 顶点坐标排序元组，float64 精确比较（同一生成器内一致）。"""
    return tuple(sorted(part.verts[i] for i in face))


def _barrel_faces(ic):
    """full / empty 两个变体做多重集差，得到 12 门炮管 + 炮口箍的面集合。"""
    full = ic.build_all_geometry(with_barrels=True)[IC_OBJECT]
    empty = ic.build_all_geometry(with_barrels=False)[IC_OBJECT]
    full_counter = Counter((mat, _face_key(full, face)) for face, mat in full.faces)
    empty_counter = Counter((mat, _face_key(empty, face)) for face, mat in empty.faces)
    return full, empty, full_counter - empty_counter


def _material_face_counts(part):
    counts = Counter()
    for _face, mat in part.faces:
        counts[mat] += 1
    return dict(counts)


def _grid(coords):
    grid = {}
    for point in coords:
        cell = tuple(int(round(point[i] / HASH_CELL)) for i in range(3))
        grid.setdefault(cell, []).append(point)
    return grid


def _point_exists(grid, point):
    base = tuple(int(round(point[i] / HASH_CELL)) for i in range(3))
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for other in grid.get((base[0] + dx, base[1] + dy, base[2] + dz), ()):
                    if max(abs(other[i] - point[i]) for i in range(3)) <= HASH_TOL:
                        return True
    return False


def strip_barrels(ic):
    """把烘进船体的 12 门炮管 / 炮口箍删掉；返回报告。"""
    import bpy
    import bmesh

    obj = bpy.data.objects.get(IC_OBJECT)
    if obj is None or obj.type != "MESH":
        raise RuntimeError("找不到网格对象 %s" % IC_OBJECT)
    mesh = obj.data
    before = _mesh_brief(mesh)
    full, empty, barrel_counter = _barrel_faces(ic)
    empty_counts = _material_face_counts(empty)
    report = {"object": IC_OBJECT, "before": before,
              "barrel_faces": sum(barrel_counter.values()),
              "barrel_verts": len({p for _m, key in barrel_counter for p in key}),
              "expected_after": {"verts": len(empty.verts), "faces": len(empty.faces),
                                 "tris": sum(max(0, len(f) - 2) for f, _m in empty.faces),
                                 "material_faces": empty_counts}}

    # 幂等：已经是空炮门变体（顶点数 / 面数 / 逐材质面数都吻合）就直接返回
    live_counts = Counter()
    for poly in mesh.polygons:
        live_counts[mesh.materials[poly.material_index].name] += 1
    if (len(mesh.vertices) == len(empty.verts)
            and len(mesh.polygons) == len(empty.faces)
            and dict(live_counts) == empty_counts):
        report["action"] = "already_empty"
        report["after"] = before
        report["passed"] = True
        return report

    # ---- 门禁：现存网格必须与生成器 full 变体逐索引一致 ----
    if len(mesh.vertices) != len(full.verts) or len(mesh.polygons) != len(full.faces):
        raise RuntimeError("现存网格 %d/%d 与生成器 full 变体 %d/%d 数量不一致，拒绝改资产"
                           % (len(mesh.vertices), len(mesh.polygons),
                              len(full.verts), len(full.faces)))
    slots = [mat.name if mat else "" for mat in mesh.materials]
    worst = 0.0
    for index, vertex in enumerate(mesh.vertices):
        point = full.verts[index]
        deviation = max(abs(vertex.co[i] - point[i]) for i in range(3))
        worst = max(worst, deviation)
        if deviation > VERT_TOL:
            raise RuntimeError("顶点 %d 偏差 %.2e 超过容差，生成器与资产已漂移"
                               % (index, deviation))
    for index, poly in enumerate(mesh.polygons):
        face, material = full.faces[index]
        if set(poly.vertices) != set(face) or slots[poly.material_index] != material:
            raise RuntimeError("面 %d 与生成器不一致（顶点集合或材质），拒绝改资产" % index)

    barrel_keys = {(mat, key) for (mat, key) in barrel_counter}
    barrel_faces = [index for index, (face, material) in enumerate(full.faces)
                    if (material, _face_key(full, face)) in barrel_keys]
    if len(barrel_faces) != sum(barrel_counter.values()):
        raise RuntimeError("按索引定位到 %d 个炮管面，期望 %d"
                           % (len(barrel_faces), sum(barrel_counter.values())))

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.faces.ensure_lookup_table()
    dead = [bm.faces[index] for index in barrel_faces]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    after = _mesh_brief(mesh)
    live_counts = Counter()
    for poly in mesh.polygons:
        live_counts[mesh.materials[poly.material_index].name] += 1
    grid = _grid([(v.co.x, v.co.y, v.co.z) for v in mesh.vertices])
    barrel_verts = {p for _m, key in barrel_counter for p in key}
    leaked = [p for p in barrel_verts if _point_exists(grid, p)]

    report.update({"action": "stripped", "after": after,
                   "removed_faces": len(barrel_faces),
                   "removed_tris": before["tris"] - after["tris"],
                   "vertex_max_deviation": round(worst, 9),
                   "material_faces": dict(live_counts),
                   "leaked_barrel_verts": len(leaked)})
    failures = []
    if after["verts"] != len(empty.verts):
        failures.append("顶点数 %d != %d" % (after["verts"], len(empty.verts)))
    if after["faces"] != len(empty.faces):
        failures.append("面数 %d != %d" % (after["faces"], len(empty.faces)))
    if after["tris"] != report["expected_after"]["tris"]:
        failures.append("三角面 %d != %d" % (after["tris"],
                                            report["expected_after"]["tris"]))
    if dict(live_counts) != empty_counts:
        failures.append("逐材质面数 %r != %r" % (dict(live_counts), empty_counts))
    if leaked:
        failures.append("仍有 %d 个炮管顶点残留" % len(leaked))
    report["failures"] = failures
    report["passed"] = not failures
    return report


def apply_all():
    import bpy

    report = {"workbench": bpy.data.filepath, "steps": []}
    ic = _reload("sn_ironclad_generator")
    # 活体 Blender 会缓存纯 Python 模块：材质白名单模块必须先刷新，炮生成器才能拿到新键
    _reload("sn_weapon_materials")
    gun = _reload("sn_casemate_gun_generator")
    gunports = _reload("sn_ship_gun_ports")
    socks = _reload("sn_ship_weapon_sockets")
    rigsocks = _reload("sn_ship_rig_sockets")

    strip = strip_barrels(ic)
    report["steps"].append({"hull": strip})
    if not strip.get("passed"):
        raise RuntimeError("船体去炮管失败：%r" % strip.get("failures"))

    gun.build_all()
    gun_info = gun.report(verbose=False)
    report["steps"].append({"gun": {"tris": gun_info["tris"], "bbox": gun_info["bbox"],
                                    "objects": gun_info["objects"]}})

    ic_ship = next(ship for ship in socks.SHIPS if ship["asset"] == IC_OBJECT)
    weapon = socks.apply_ship(ic_ship)
    report["steps"].append({"weapon_sockets": {
        "passed": weapon["passed"], "count": len(weapon["sockets"]),
        "mesh": [weapon["mesh_before"], weapon["mesh_after"]],
        "failures": weapon["failures"]}})
    if not weapon["passed"]:
        raise RuntimeError("甲板武器 socket 补齐失败：%r" % weapon["failures"])

    rig_ship = next(ship for ship in rigsocks.SHIPS if ship["asset"] == IC_OBJECT)
    rig_specs = rigsocks.build_specs()[IC_OBJECT]
    rig = rigsocks.apply_ship(rig_ship, rig_specs)
    report["steps"].append({"rig_sockets": {"created": len(rig["created"]),
                                            "geometry_unchanged": rig["geometry_unchanged"]}})
    if not rig["geometry_unchanged"]:
        raise RuntimeError("帆索 socket 补齐后几何变化")

    ports = gunports.apply_all()
    report["steps"].append({"gun_ports": {
        "passed": ports["passed"],
        "failures": [failure for item in ports["ships"] for failure in item["failures"]],
        "measured": [item["ports"] for item in ports["ships"]]}})
    if not ports["passed"]:
        raise RuntimeError("炮门 socket 补齐失败：%r" % ports["spec_failures"])

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
    report["passed"] = (strip["passed"] and weapon["passed"] and rig["geometry_unchanged"]
                        and ports["passed"] and verify["weapon"]["passed"]
                        and verify["rig"]["passed"] and verify["gun_ports"]["passed"])
    print("CASEMATE_APPLY_DONE " + json.dumps(report, ensure_ascii=False, default=str))
    return report


if __name__ == "__main__":
    apply_all()
