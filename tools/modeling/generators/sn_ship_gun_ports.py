# -*- coding: utf-8 -*-
# @static-doc
# 作用：船体侧**炮门安装点** `SN_Socket_GunPort_*` 的规格表 + Blender 就地补齐 / 实测 / 只读自检
# —— 穿船壳炮（casemate gun）模块的挂载基准，与甲板武器 socket（`SN_Socket_Weapon_*`，
# 原点在甲板面）**语义不同**：本类 socket 的原点在**炮门平面中心**，`+X` = 炮膛轴线（舷外）。
#
# ## 当前范围
# - `SN_Ironclad`：每舷 6 个炮门、两舷共 12 个（x = ±3.5 / ±10.5 / ±17.5，z 1.30–3.20）；
# - 其它船体本轮不补：它们没有炮门开口，需要先做「炮门舱段 / port cassette」适配件，
#   否则炮管会直接从完好的船壳板里长出来（见 WEAPON_SOCKET_CONTRACT.md §9 边界）。
#
# ## 契约
# - 只加空节点、**不改几何**：apply 前后对集合做 mesh / tri / 对象名快照比对；
# - BLEND 内名字带资产前缀（`SN_IC_Socket_GunPort_Port_1`），GLB 导出后由
#   `glb_gun_ports.standardize()` 归一化为 `SN_Socket_GunPort_Port_1` 并写 Root `gun_port_sockets`；
# - 节点旋转：Blender XYZ 欧拉 `(0, rot_y, rot_z)`，把模块局部 `+X` 转到炮膛轴线
#   （`rot_z` 含 12° 前外张、`rot_y` 含 1.7° 上抬，由 `sn_ironclad_generator.gun_port_pose()` 给出）；
# - 节点 extras（机器可读）：`socket_spec / socket_index / side_index / port_class / port_w / port_h /
#   sill_z / deck_z / inboard_depth / outboard_clearance / lid / lid_hinge_z /
#   elev_min_deg / elev_max_deg / traverse_deg / mount_scale / note`；
# - 实测口径：`inboard_depth` 从炮门平面内侧 0.20 m 沿 -X 射线量门内自由纵深（封顶 8 m），
#   `outboard_clearance` 从门外 0.15 m 沿 +X 量舷外自由距离（封顶 8 m）；声明值不得高于实测。
#
# 用法：
#   Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
#   纯 Python： python tools/modeling/generators/sn_ship_gun_ports.py --check
# @end-static-doc

import importlib
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

SOCKET_PREFIX = "SN_Socket_GunPort"
SOCKET_SPEC = "hull-gunports@1"
MOUNT_SCALE = 1.0
RAY_CAP = 8.0
DEPTH_TOL = 0.10
LOC_TOL = 1e-4
ROT_TOL = 1e-3
DECLARED_INBOARD_DEPTH = 1.10
DECLARED_OUTBOARD_CLEARANCE = 6.0

PORT_CLASS = "Medium"
LID = "top"
ELEV_MIN, ELEV_MAX = -6.0, 12.0
TRAVERSE_DEG = 0.0

SHIPS = [
    {
        "asset": "SN_Ironclad",
        "glb": "assets/models/ships/SN_Ironclad.glb",
        "collection": "SN_Ironclad_Prototype",
        "root": "SN_Ironclad",
        "prefix": "SN_IC",
        "deck_z": 4.60,
    },
]


def _ironclad():
    """加载铁甲舰生成器（炮门几何唯一真源）；活体 Blender 会缓存模块，故显式 reload。"""
    if "sn_ironclad_generator" in sys.modules:
        return importlib.reload(sys.modules["sn_ironclad_generator"])
    return importlib.import_module("sn_ironclad_generator")


def build_ports(ship=None, generator=None):
    """按铁甲舰参数表生成 12 个炮门规格（纯 Python，不 import bpy）。"""
    ship = ship or SHIPS[0]
    ic = generator or _ironclad()
    ports = []
    index = 0
    for side_index, x in enumerate(ic.GUN_X, start=1):
        for side in (1, -1):
            index += 1
            pose = ic.gun_port_pose(x, side)
            suffix = ("Port_%d" if side > 0 else "Starboard_%d") % side_index
            ports.append({
                "suffix": suffix,
                "side": side,
                "side_index": side_index,
                "socket_index": index,
                "x": float(x),
                "center": tuple(round(v, 6) for v in pose["center"]),
                "rot_z": round(pose["rot_z_deg"], 6),
                "rot_y": round(pose["rot_y_deg"], 6),
                "port_class": PORT_CLASS,
                "port_w": round(ic.GUN_PORT_HALF * 2.0, 4),
                "port_h": round(ic.GUN_Z1 - ic.GUN_Z0, 4),
                "sill_z": round(ic.GUN_Z0, 4),
                "deck_z": float(ship["deck_z"]),
                "inboard_depth": DECLARED_INBOARD_DEPTH,
                "outboard_clearance": DECLARED_OUTBOARD_CLEARANCE,
                "lid": LID,
                "lid_hinge_z": round(ic.GUN_Z1 + ic.GUN_PORT_FRAME, 4),
                "elev_min_deg": ELEV_MIN,
                "elev_max_deg": ELEV_MAX,
                "traverse_deg": TRAVERSE_DEG,
                "mount_scale": MOUNT_SCALE,
                "note": "舷侧炮门：±%.1f° 外张 / 上抬 %.1f°，炮管外露 %.2f m，炮尾藏进门内"
                        % (math.degrees(math.atan2(abs(pose["bore"][0]), abs(pose["bore"][1]))),
                           math.degrees(math.asin(pose["bore"][2])), pose["protrusion"]),
            })
    return ports


def blend_name(ship, port):
    return "%s_Socket_GunPort_%s" % (ship["prefix"], port["suffix"])


def glb_name(ship, port):
    return "%s_%s" % (SOCKET_PREFIX, port["suffix"])


def expected_ports():
    """{asset: [(index, glb_name, port), ...]}，GLB 验收脚本的期望值。"""
    ship = SHIPS[0]
    return {ship["asset"]: [(p["socket_index"], glb_name(ship, p), p)
                            for p in build_ports(ship)]}


def validate_spec(ports=None):
    """规格表自检（纯 Python）：左右舷镜像、命名、尺寸、俯仰极限。"""
    ship = SHIPS[0]
    ports = ports or build_ports(ship)
    failures = []
    if len(ports) != 12:
        failures.append("炮门数量 %d != 12" % len(ports))
    seen = set()
    for port in ports:
        name = glb_name(ship, port)
        if name in seen:
            failures.append("重复炮门名 %s" % name)
        seen.add(name)
        if not name.startswith(SOCKET_PREFIX + "_"):
            failures.append("%s 前缀不符" % name)
        if not blend_name(ship, port).startswith("SN_"):
            failures.append("%s BLEND 名缺少 SN_ 前缀" % port["suffix"])
        if abs(port["port_w"] - 2.0 * 0.95) > 1e-6:
            failures.append("%s 炮门宽 %.2f 与铁甲舰口径不符" % (name, port["port_w"]))
        if abs(port["port_h"] - 1.90) > 1e-6:
            failures.append("%s 炮门高 %.2f 与铁甲舰口径不符" % (name, port["port_h"]))
        if port["elev_min_deg"] >= port["elev_max_deg"]:
            failures.append("%s 俯仰极限倒置" % name)
        if port["inboard_depth"] < 0.5 or port["outboard_clearance"] < 1.0:
            failures.append("%s 纵深/舷外净空过小" % name)
    for port in ports:
        suffix = port["suffix"]
        mirror = ("Starboard_" + suffix[len("Port_"):]) if suffix.startswith("Port_") \
            else ("Port_" + suffix[len("Starboard_"):])
        other = next((p for p in ports if p["suffix"] == mirror), None)
        if other is None:
            failures.append("%s 缺少镜像 %s" % (suffix, mirror))
            continue
        if abs(port["x"] - other["x"]) > 1e-6:
            failures.append("%s/%s 的 x 不镜像" % (suffix, mirror))
        if abs(port["center"][1] + other["center"][1]) > 1e-6:
            failures.append("%s/%s 的 y 不镜像" % (suffix, mirror))
        if abs(port["rot_z"] + other["rot_z"]) > 1e-6:
            failures.append("%s/%s 的 rot_z 不镜像" % (suffix, mirror))
    return failures


# --------------------------------------------------------------------------- #
# Blender 侧
# --------------------------------------------------------------------------- #

def _bpy():
    import bpy
    return bpy


def _root_of(bpy, ship):
    root = bpy.data.objects.get(ship["root"])
    if root is None:
        raise RuntimeError("找不到船体根 %s" % ship["root"])
    return root


def _collection_of(bpy, ship):
    collection = bpy.data.collections.get(ship["collection"])
    if collection is None:
        raise RuntimeError("找不到集合 %s" % ship["collection"])
    return collection


def mesh_snapshot(ship):
    bpy = _bpy()
    collection = _collection_of(bpy, ship)
    meshes = 0
    tris = 0
    names = []
    for obj in collection.all_objects:
        if obj.type != "MESH":
            continue
        meshes += 1
        names.append(obj.name)
        obj.data.calc_loop_triangles()
        tris += len(obj.data.loop_triangles)
    return {"meshes": meshes, "tris": tris, "names": sorted(names)}


def measure(ship, port):
    """实测门内纵深 / 舷外净空（世界射线），返回声明口径的实测值。"""
    from mathutils import Vector
    bpy = _bpy()
    deps = bpy.context.evaluated_depsgraph_get()
    scene = bpy.context.scene
    root = _root_of(bpy, ship)
    center = Vector(port["center"])
    bore = Vector((math.cos(math.radians(port["rot_z"])) * math.cos(math.radians(port["rot_y"])),
                   math.sin(math.radians(port["rot_z"])) * math.cos(math.radians(port["rot_y"])),
                   -math.sin(math.radians(port["rot_y"]))))
    inward_origin = center - bore * 0.20
    inward = scene.ray_cast(deps, inward_origin, -bore, distance=RAY_CAP)
    inboard_depth = (inward[1] - inward_origin).length if inward[0] else RAY_CAP
    outward_origin = center + bore * 0.15
    outward = scene.ray_cast(deps, outward_origin, bore, distance=RAY_CAP)
    outboard_clearance = (outward[1] - outward_origin).length if outward[0] else RAY_CAP
    return {
        "inboard_depth": inboard_depth,
        "outboard_clearance": outboard_clearance,
        "world_center": tuple(center),
        "local_center": tuple(center - root.matrix_world.translation),
    }


def _remove_existing(bpy, ship):
    prefix = ship["prefix"] + "_Socket_GunPort_"
    removed = []
    for obj in list(bpy.data.objects):
        if obj.name.startswith(prefix) or (obj.type == "EMPTY"
                                           and "Socket_GunPort" in obj.name
                                           and obj.name.startswith(ship["prefix"] + "_")):
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
    return removed


def apply_ship(ship, ports=None):
    """就地补齐一艘船的炮门 socket；返回报告 dict。"""
    bpy = _bpy()
    ports = ports or build_ports(ship)
    root = _root_of(bpy, ship)
    collection = _collection_of(bpy, ship)
    before = mesh_snapshot(ship)
    removed = _remove_existing(bpy, ship)
    report = {"asset": ship["asset"], "root": root.name, "removed": removed,
              "ports": [], "failures": []}
    for port in ports:
        values = measure(ship, port)
        if values["inboard_depth"] < port["inboard_depth"] - DEPTH_TOL:
            report["failures"].append("%s: 门内实测纵深 %.2f < 声明 %.2f" % (
                port["suffix"], values["inboard_depth"], port["inboard_depth"]))
        if values["outboard_clearance"] < port["outboard_clearance"] - DEPTH_TOL:
            report["failures"].append("%s: 舷外实测净空 %.2f < 声明 %.2f" % (
                port["suffix"], values["outboard_clearance"], port["outboard_clearance"]))
        empty = bpy.data.objects.new(blend_name(ship, port), None)
        collection.objects.link(empty)
        empty.empty_display_type = "PLAIN_AXES"
        empty.empty_display_size = 0.6
        empty.parent = root
        empty.matrix_parent_inverse.identity()
        empty.location = port["center"]
        empty.rotation_mode = "XYZ"
        empty.rotation_euler = (0.0, math.radians(port["rot_y"]),
                                math.radians(port["rot_z"]))
        empty["socket_spec"] = SOCKET_SPEC
        empty["socket_index"] = port["socket_index"]
        empty["side_index"] = port["side_index"]
        empty["port_class"] = port["port_class"]
        empty["port_w"] = port["port_w"]
        empty["port_h"] = port["port_h"]
        empty["sill_z"] = port["sill_z"]
        empty["deck_z"] = port["deck_z"]
        empty["inboard_depth"] = port["inboard_depth"]
        empty["outboard_clearance"] = port["outboard_clearance"]
        empty["lid"] = port["lid"]
        empty["lid_hinge_z"] = port["lid_hinge_z"]
        empty["elev_min_deg"] = port["elev_min_deg"]
        empty["elev_max_deg"] = port["elev_max_deg"]
        empty["traverse_deg"] = port["traverse_deg"]
        empty["mount_scale"] = port["mount_scale"]
        empty["note"] = port["note"]
        report["ports"].append({
            "name": blend_name(ship, port),
            "glb_name": glb_name(ship, port),
            "local": [round(v, 4) for v in port["center"]],
            "rot_z": port["rot_z"],
            "rot_y": port["rot_y"],
            "measured": {
                "inboard_depth": round(values["inboard_depth"], 3),
                "outboard_clearance": round(values["outboard_clearance"], 3),
            },
        })
    root["gun_port_socket_spec"] = SOCKET_SPEC
    root["gun_port_socket_count"] = len(ports)
    after = mesh_snapshot(ship)
    report["mesh_before"] = {"meshes": before["meshes"], "tris": before["tris"]}
    report["mesh_after"] = {"meshes": after["meshes"], "tris": after["tris"]}
    if before != after:
        report["failures"].append("%s: 几何快照变化 %r → %r" % (
            ship["asset"], before, after))
    report["passed"] = not report["failures"]
    return report


def verify_ship(ship, ports=None):
    """只读复核：节点数 / 名字 / 父级 / 位姿 / extras / 根 extras / 实测值。"""
    bpy = _bpy()
    ports = ports or build_ports(ship)
    root = _root_of(bpy, ship)
    report = {"asset": ship["asset"], "failures": [], "ports": []}
    prefix = ship["prefix"] + "_Socket_GunPort_"
    found = sorted(obj.name for obj in bpy.data.objects if obj.name.startswith(prefix))
    if len(found) != len(ports):
        report["failures"].append("%s: 炮门节点数 %d != %d" % (
            ship["asset"], len(found), len(ports)))
    for port in ports:
        name = blend_name(ship, port)
        obj = bpy.data.objects.get(name)
        if obj is None:
            report["failures"].append("缺少节点 %s" % name)
            continue
        if obj.type != "EMPTY":
            report["failures"].append("%s 不是空节点" % name)
        if obj.parent is not root:
            report["failures"].append("%s 父级不是根" % name)
        for axis in range(3):
            if abs(obj.location[axis] - port["center"][axis]) > LOC_TOL:
                report["failures"].append("%s 局部 %s %.4f != %.4f" % (
                    name, "xyz"[axis], obj.location[axis], port["center"][axis]))
        if abs(obj.rotation_euler[0]) > ROT_TOL:
            report["failures"].append("%s rot_x 应为 0" % name)
        if abs(math.degrees(obj.rotation_euler[1]) - port["rot_y"]) > ROT_TOL:
            report["failures"].append("%s rot_y 不符" % name)
        if abs(math.degrees(obj.rotation_euler[2]) - port["rot_z"]) > ROT_TOL:
            report["failures"].append("%s rot_z 不符" % name)
        expected = {
            "socket_spec": SOCKET_SPEC,
            "socket_index": port["socket_index"],
            "side_index": port["side_index"],
            "port_class": port["port_class"],
            "port_w": port["port_w"],
            "port_h": port["port_h"],
            "sill_z": port["sill_z"],
            "deck_z": port["deck_z"],
            "inboard_depth": port["inboard_depth"],
            "outboard_clearance": port["outboard_clearance"],
            "lid": port["lid"],
            "lid_hinge_z": port["lid_hinge_z"],
            "elev_min_deg": port["elev_min_deg"],
            "elev_max_deg": port["elev_max_deg"],
            "traverse_deg": port["traverse_deg"],
            "mount_scale": port["mount_scale"],
        }
        for key, want in expected.items():
            if key not in obj.keys():
                report["failures"].append("%s 缺 extras.%s" % (name, key))
                continue
            got = obj[key]
            if isinstance(want, float):
                if abs(float(got) - want) > 1e-6:
                    report["failures"].append("%s extras.%s %.3f != %.3f" % (
                        name, key, float(got), want))
            elif got != want:
                report["failures"].append("%s extras.%s %r != %r" % (name, key, got, want))
        values = measure(ship, port)
        if values["inboard_depth"] < port["inboard_depth"] - DEPTH_TOL:
            report["failures"].append("%s 门内实测纵深不足" % name)
        if values["outboard_clearance"] < port["outboard_clearance"] - DEPTH_TOL:
            report["failures"].append("%s 舷外实测净空不足" % name)
        report["ports"].append({"name": name, "glb_name": glb_name(ship, port),
                                "measured": {
                                    "inboard_depth": round(values["inboard_depth"], 3),
                                    "outboard_clearance": round(values["outboard_clearance"], 3)}})
    dupes = [obj.name for obj in bpy.data.objects
             if obj.name.endswith(".001") and "Socket_GunPort" in obj.name]
    if dupes:
        report["failures"].append("出现 .001 后缀节点 %s" % dupes)
    if int(root.get("gun_port_socket_count", -1)) != len(ports):
        report["failures"].append("根 gun_port_socket_count 不符")
    if root.get("gun_port_socket_spec") != SOCKET_SPEC:
        report["failures"].append("根 gun_port_socket_spec 不符")
    report["passed"] = not report["failures"]
    return report


def apply_all():
    failures = validate_spec()
    result = {"spec_failures": failures, "ships": [], "passed": False}
    if failures:
        result["error"] = "规格表自检失败，拒绝写场景"
        print(json.dumps(result, ensure_ascii=False, indent=1))
        return result
    for ship in SHIPS:
        result["ships"].append(apply_ship(ship))
    result["passed"] = all(item["passed"] for item in result["ships"])
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return result


def verify_all():
    result = {"spec_failures": validate_spec(), "ships": [], "passed": False}
    for ship in SHIPS:
        result["ships"].append(verify_ship(ship))
    result["passed"] = (all(item["passed"] for item in result["ships"])
                        and not result["spec_failures"])
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return result


if __name__ == "__main__":
    if "--check" in sys.argv:
        ports = build_ports()
        failures = validate_spec(ports)
        print(json.dumps({"ships": len(SHIPS), "ports": len(ports),
                          "per_side": {p["suffix"]: list(p["center"]) for p in ports},
                          "failures": failures, "ok": not failures},
                         ensure_ascii=False, indent=1))
    else:
        apply_all()
