# -*- coding: utf-8 -*-
# @static-doc
# 作用：`combat_kit` 敌舰**炮门安装点** `SN_<PFX>_Socket_GunPort_<suffix>` 的 Blender 就地补齐 /
# 实测 / 只读复核 / 纯 Python 自检。目前只有 `SN_Enemy_Ironclad_Raider`（中央炮房 + 单烟囱
# 的铁甲舰变体）有 8 个舷侧空炮门：每舷 `Port_1..4` / `Starboard_1..4`。
# 数据真源是 `combat_kit_generator`（本文件不抄坐标 / 尺寸数字）：
# `GUN_PORTS[asset]`、`gun_port_entries()`、`gun_port_pose_for()`、`blend_gun_port_socket_name()`、
# `glb_gun_port_socket_name()` / `expected_gun_port_names()`、`SHIP_CONFIGS[asset]`（root / collection / prefix）。
#
# ## 契约（WEAPON_SOCKET_CONTRACT.md §9，`hull-gunports@1`）
# - 与甲板 socket 是**两套语义**：本类原点在**炮门平面中心**（炮膛轴线 ∩ 船壳面），`+X` = 炮膛轴线
#   （含船型外张角 `rot_z` 与上抬角 `rot_y`），不是甲板面；名字前缀不同、Root 名单
#   `gun_port_sockets` 也独立于 `weapon_sockets`；
# - 只加空节点、不改几何：apply 前后对集合做 mesh / 三角面 / 对象名快照比对；
# - BLEND 内名字带资产前缀（`SN_ER_Socket_GunPort_Port_1`），GLB 后处理由
#   `glb_enemy_sockets.normalize()` 归一化为 `SN_Socket_GunPort_Port_1`；
# - Blender XYZ 欧拉 `(0, radians(rot_y_deg), radians(rot_z_deg))`，把模块局部 +X 转到炮膛轴线；
# - 节点 extras：`socket_spec / socket_index / side_index / port_class / port_w / port_h /
#   sill_z / deck_z / inboard_depth / outboard_clearance / lid / lid_hinge_z /
#   elev_min_deg / elev_max_deg / traverse_deg / mount_scale / note`；
# - Root extras（Blender 侧）：`gun_port_socket_count`、`gun_port_socket_spec`；字符串数组
#   `gun_port_sockets` 只能在 GLB JSON 层写（Blender IDProperty 不支持字符串数组）。
#
# ## 实测口径（声明值不得高于实测值，脚本内断言、不静默降级）
# - `inboard_depth`：从炮门平面中心沿 **-X（局部，门内）** 偏移 0.20 m 处向 -X 射线，8 m 封顶；
# - `outboard_clearance`：从中心沿 **+X（局部，舷外）** 偏移 0.15 m 处向 +X 射线，8 m 封顶；
# - 断言 `实测 >= 声明 - DECLARED_TOL`（0.06 m），不达标记 failure（不抛异常、不降级声明值）。
#
# ## 幂等 / 边界
# - 重跑只删除本资产前缀（`<PFX>Socket_GunPort_`）的空节点，不触碰甲板 socket / 几何；
# - 节点写进 `SHIP_CONFIGS[asset]["collection"]`，父级是该船 Root；
# - `verify_ship()` 只读复核名字 / 父级 / 位姿 / extras / Root extras / 实测值；
# - 纯 Python 部分（`check()`、期望 GLB 名单）不 import bpy。
#
# 用法：
#   Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
#   纯 Python： python tools/modeling/generators/sn_enemy_gun_ports.py --check
# @end-static-doc

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import combat_kit_generator as ck  # noqa: E402

SOCKET_SPEC = ck.GUN_PORT_SPEC
MOUNT_SCALE = 1.0
RAY_CAP = 8.0
INBOARD_OFFSET = 0.20
OUTBOARD_OFFSET = 0.15
DECLARED_TOL = 0.06
LOC_TOL = 1e-4
ROT_TOL = 1e-3

REQUIRED_SPEC_KEYS = ("suffix", "side_index", "port_class", "port_w", "port_h",
                      "sill_z", "deck_z", "inboard_depth", "outboard_clearance",
                      "lid", "lid_hinge_z", "elev_min_deg", "elev_max_deg",
                      "traverse_deg", "mount_scale", "note")

# 节点 extras 白名单（顺序即写入顺序，与契约 §9 一致）
EXTRA_KEYS = ("socket_spec", "socket_index", "side_index", "port_class", "port_w",
              "port_h", "sill_z", "deck_z", "inboard_depth", "outboard_clearance",
              "lid", "lid_hinge_z", "elev_min_deg", "elev_max_deg",
              "traverse_deg", "mount_scale", "note")


# --------------------------------------------------------------------------- #
# 数据视图（全部来自 combat_kit_generator）
# --------------------------------------------------------------------------- #

def gun_port_assets():
    """有炮门规格的敌舰资产（当前只有铁甲舰变体）。"""
    return [asset for asset in ck.SHIP_CLASS_ORDER if ck.GUN_PORTS.get(asset)]


GUN_PORT_ASSETS = gun_port_assets()


def ship_of(asset):
    if asset not in GUN_PORT_ASSETS:
        raise KeyError("%s 没有炮门规格（ck.GUN_PORTS 为空）" % asset)
    cfg = ck.SHIP_CONFIGS[asset]
    return {"asset": asset, "root": cfg["root"],
            "collection": cfg["collection"], "prefix": cfg["prefix"]}


def blend_prefix(ship):
    return ship["prefix"] + "Socket_GunPort_"


def blend_name(asset, suffix):
    return ck.blend_gun_port_socket_name(asset, suffix)


def glb_name(suffix):
    return ck.glb_gun_port_socket_name(suffix)


def port_entries(asset):
    """[(index, spec)]，按 socket_index 顺序。"""
    return ck.gun_port_entries(asset)


def port_pose(asset, spec):
    """炮门平面中心 / 炮膛轴线 / 欧拉角（真源：ck.gun_port_pose_for）。"""
    return ck.gun_port_pose_for(asset, spec["suffix"])


def expected_ports(asset):
    """[(index, glb_name, spec, pose)]，GLB 验收脚本的期望值。"""
    return [(index, glb_name(spec["suffix"]), spec, port_pose(asset, spec))
            for index, spec in port_entries(asset)]


def extras_for(spec, index):
    """把 ck 规格映射为节点 extras（白名单，全部来自 ck，不抄数字）。"""
    values = {
        "socket_spec": SOCKET_SPEC,
        "socket_index": int(index),
        "side_index": int(spec["side_index"]),
        "port_class": spec["port_class"],
        "port_w": float(spec["port_w"]),
        "port_h": float(spec["port_h"]),
        "sill_z": float(spec["sill_z"]),
        "deck_z": float(spec["deck_z"]),
        "inboard_depth": float(spec["inboard_depth"]),
        "outboard_clearance": float(spec["outboard_clearance"]),
        "lid": spec["lid"],
        "lid_hinge_z": float(spec["lid_hinge_z"]),
        "elev_min_deg": float(spec["elev_min_deg"]),
        "elev_max_deg": float(spec["elev_max_deg"]),
        "traverse_deg": float(spec["traverse_deg"]),
        "mount_scale": MOUNT_SCALE,
        "note": spec["note"],
    }
    return {key: values[key] for key in EXTRA_KEYS}


# --------------------------------------------------------------------------- #
# 纯 Python 自检（不 import bpy）
# --------------------------------------------------------------------------- #

def check():
    """规格自检：ck.validate_specs() + 炮门命名 / 位姿 / 镜像 / 声明口径。"""
    failures = list(ck.validate_specs())
    report = {}
    if not GUN_PORT_ASSETS:
        failures.append("ck.GUN_PORTS 没有任何炮门资产")
    for asset in GUN_PORT_ASSETS:
        ship = ship_of(asset)
        entries = expected_ports(asset)
        names = [name for _index, name, _spec, _pose in entries]
        if names != ck.expected_gun_port_names(asset):
            failures.append("%s: 期望 GLB 名单与 ck.expected_gun_port_names() 不一致"
                            % asset)
        if len(set(names)) != len(names):
            failures.append("%s: 期望 GLB 名单内部重复" % asset)
        if not ship["root"] or not ship["collection"]:
            failures.append("%s: root / collection 为空" % asset)
        for index, spec, pose in ((i, s, p) for i, _n, s, p in entries):
            missing = [key for key in REQUIRED_SPEC_KEYS if key not in spec]
            if missing:
                failures.append("%s/%s: 规格缺字段 %s"
                                % (asset, spec.get("suffix", index), missing))
                continue
            center = pose.get("center")
            bore = pose.get("bore")
            if not center or len(center) != 3 or not all(
                    isinstance(v, (int, float)) and math.isfinite(v) for v in center):
                failures.append("%s/%s: pose.center 非法 %r"
                                % (asset, spec["suffix"], center))
                continue
            if not bore or len(bore) != 3 or not all(
                    isinstance(v, (int, float)) and math.isfinite(v) for v in bore):
                failures.append("%s/%s: pose.bore 非法 %r"
                                % (asset, spec["suffix"], bore))
                continue
            if abs(math.sqrt(sum(v * v for v in bore)) - 1.0) > 1e-6:
                failures.append("%s/%s: bore 不是单位向量" % (asset, spec["suffix"]))
            if abs(center[2] - (float(spec["sill_z"]) + float(spec["port_h"]) * 0.5)) > 1e-3:
                failures.append("%s/%s: 中心 z 与 sill_z+port_h/2 不符"
                                % (asset, spec["suffix"]))
            if float(spec["deck_z"]) <= float(spec["sill_z"]):
                failures.append("%s/%s: deck_z 不高于 sill_z"
                                % (asset, spec["suffix"]))
            if float(spec["elev_min_deg"]) >= float(spec["elev_max_deg"]):
                failures.append("%s/%s: 俯仰极限倒置" % (asset, spec["suffix"]))
            if spec["lid"] != "top":
                failures.append("%s/%s: lid %r != top"
                                % (asset, spec["suffix"], spec["lid"]))
            for key in ("inboard_depth", "outboard_clearance"):
                if not 0.0 < float(spec[key]) <= RAY_CAP:
                    failures.append("%s/%s: %s %.2f 超出 (0, %.0f]"
                                    % (asset, spec["suffix"], key,
                                       float(spec[key]), RAY_CAP))
            if not isinstance(spec["note"], str) or not spec["note"]:
                failures.append("%s/%s: note 为空" % (asset, spec["suffix"]))
            if spec["port_class"] == "":
                failures.append("%s/%s: port_class 为空" % (asset, spec["suffix"]))
        by_suffix = {spec["suffix"]: (spec, pose)
                     for _i, _n, spec, pose in entries}
        for suffix, (spec, pose) in by_suffix.items():
            if suffix.startswith("Port_"):
                mirror = "Starboard_" + suffix[len("Port_"):]
            elif suffix.startswith("Starboard_"):
                mirror = "Port_" + suffix[len("Starboard_"):]
            else:
                continue
            other = by_suffix.get(mirror)
            if other is None:
                failures.append("%s: %s 缺少镜像 %s" % (asset, suffix, mirror))
                continue
            other_spec, other_pose = other
            if abs(pose["center"][0] - other_pose["center"][0]) > 1e-6:
                failures.append("%s: %s/%s 中心 x 不镜像" % (asset, suffix, mirror))
            if abs(pose["center"][1] + other_pose["center"][1]) > 1e-6:
                failures.append("%s: %s/%s 中心 y 不镜像" % (asset, suffix, mirror))
            if abs(pose["center"][2] - other_pose["center"][2]) > 1e-6:
                failures.append("%s: %s/%s 中心 z 不镜像" % (asset, suffix, mirror))
            if abs(pose["rot_z_deg"] + other_pose["rot_z_deg"]) > 1e-6:
                failures.append("%s: %s/%s rot_z 不镜像" % (asset, suffix, mirror))
            if abs(pose["rot_y_deg"] - other_pose["rot_y_deg"]) > 1e-6:
                failures.append("%s: %s/%s rot_y 不镜像" % (asset, suffix, mirror))
            if spec["side_index"] != other_spec["side_index"]:
                failures.append("%s: %s/%s side_index 不一致" % (asset, suffix, mirror))
        report[asset] = {
            "root": ship["root"],
            "collection": ship["collection"],
            "ports": len(entries),
            "glb_names": names,
            "blend_names": [blend_name(asset, spec["suffix"])
                            for _i, spec in port_entries(asset)],
            "declared": {spec["suffix"]: {
                "inboard_depth": float(spec["inboard_depth"]),
                "outboard_clearance": float(spec["outboard_clearance"]),
            } for _i, spec in port_entries(asset)},
        }
    return {"ok": not failures, "failures": failures,
            "assets": len(GUN_PORT_ASSETS), "ships": report}


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


def measure(asset, spec, pose):
    """实测门内纵深 / 舷外净空（世界射线），返回声明口径的实测值。"""
    from mathutils import Vector
    bpy = _bpy()
    deps = bpy.context.evaluated_depsgraph_get()
    scene = bpy.context.scene
    center = Vector(pose["center"])
    bore = Vector(pose["bore"]).normalized()
    inward_origin = center - bore * INBOARD_OFFSET
    inward = scene.ray_cast(deps, inward_origin, -bore, distance=RAY_CAP)
    inboard_depth = (inward[1] - inward_origin).length if inward[0] else RAY_CAP
    outward_origin = center + bore * OUTBOARD_OFFSET
    outward = scene.ray_cast(deps, outward_origin, bore, distance=RAY_CAP)
    outboard_clearance = (outward[1] - outward_origin).length if outward[0] else RAY_CAP
    return {
        "inboard_depth": inboard_depth,
        "outboard_clearance": outboard_clearance,
        "world_center": tuple(center),
        "local_center": tuple(center - _root_of(bpy, ship_of(asset))
                              .matrix_world.translation),
    }


def _check_measured(asset, spec, values):
    """实测 vs 声明：声明不得高于实测 - 容差，返回 failure 列表（不静默降级）。"""
    failures = []
    name = glb_name(spec["suffix"])
    for key in ("inboard_depth", "outboard_clearance"):
        declared = float(spec[key])
        measured = float(values[key])
        if measured < declared - DECLARED_TOL:
            failures.append("%s/%s: %s 声明 %.2f 高于实测 %.2f（容差 %.2f）"
                            % (asset, name, key, declared, measured, DECLARED_TOL))
    return failures


def _remove_existing(bpy, ship):
    """幂等重跑：只删除本资产前缀的 GunPort 空节点（覆盖 .001 后缀）。"""
    prefix = blend_prefix(ship)
    removed = []
    for obj in list(bpy.data.objects):
        if obj.name.startswith(prefix):
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
    return removed


def apply_ship(asset):
    """就地补齐一艘敌舰的炮门 socket 空节点；返回报告 dict。"""
    bpy = _bpy()
    ship = ship_of(asset)
    root = _root_of(bpy, ship)
    collection = _collection_of(bpy, ship)
    before = mesh_snapshot(ship)
    removed = _remove_existing(bpy, ship)
    report = {"asset": asset, "root": root.name, "collection": collection.name,
              "removed": removed, "ports": [], "failures": []}
    for index, spec in port_entries(asset):
        pose = port_pose(asset, spec)
        values = measure(asset, spec, pose)
        report["failures"].extend(_check_measured(asset, spec, values))
        empty = bpy.data.objects.new(blend_name(asset, spec["suffix"]), None)
        collection.objects.link(empty)
        empty.empty_display_type = "PLAIN_AXES"
        empty.empty_display_size = 0.6
        empty.parent = root
        empty.matrix_parent_inverse.identity()
        empty.location = (float(pose["center"][0]), float(pose["center"][1]),
                          float(pose["center"][2]))
        empty.rotation_mode = "XYZ"
        empty.rotation_euler = (0.0, math.radians(float(pose["rot_y_deg"])),
                                math.radians(float(pose["rot_z_deg"])))
        for key, value in extras_for(spec, index).items():
            empty[key] = value
        report["ports"].append({
            "name": blend_name(asset, spec["suffix"]),
            "glb_name": glb_name(spec["suffix"]),
            "socket_index": int(index),
            "side_index": int(spec["side_index"]),
            "center": [round(float(v), 4) for v in pose["center"]],
            "rot_z_deg": float(pose["rot_z_deg"]),
            "rot_y_deg": float(pose["rot_y_deg"]),
            "measured": {
                "inboard_depth": round(float(values["inboard_depth"]), 3),
                "outboard_clearance": round(float(values["outboard_clearance"]), 3),
            },
            "declared": {
                "inboard_depth": float(spec["inboard_depth"]),
                "outboard_clearance": float(spec["outboard_clearance"]),
            },
        })
    root["gun_port_socket_spec"] = SOCKET_SPEC
    root["gun_port_socket_count"] = len(port_entries(asset))
    after = mesh_snapshot(ship)
    report["mesh_before"] = {"meshes": before["meshes"], "tris": before["tris"]}
    report["mesh_after"] = {"meshes": after["meshes"], "tris": after["tris"]}
    if before["meshes"] != after["meshes"] or before["tris"] != after["tris"]:
        report["failures"].append(
            "%s: 几何快照变化 meshes %d→%d tris %d→%d"
            % (asset, before["meshes"], after["meshes"],
               before["tris"], after["tris"]))
    if before["names"] != after["names"]:
        report["failures"].append("%s: 集合对象名清单变化" % asset)
    report["passed"] = not report["failures"]
    return report


def _matrix_is_identity(matrix):
    for i in range(4):
        for j in range(4):
            expected = 1.0 if i == j else 0.0
            if abs(matrix[i][j] - expected) > 1e-6:
                return False
    return True


def verify_ship(asset):
    """只读复核一艘敌舰：名字 / 父级 / 位姿 / extras / Root extras / 实测值。"""
    bpy = _bpy()
    ship = ship_of(asset)
    root = _root_of(bpy, ship)
    collection = _collection_of(bpy, ship)
    report = {"asset": asset, "root": root.name, "failures": [], "ports": []}
    prefix = blend_prefix(ship)
    found = sorted(obj.name for obj in collection.all_objects
                   if obj.type == "EMPTY" and obj.name.startswith(prefix))
    expected_names = sorted(blend_name(asset, spec["suffix"])
                            for _index, spec in port_entries(asset))
    if found != expected_names:
        missing = [name for name in expected_names if name not in found]
        extra = [name for name in found if name not in expected_names]
        if missing:
            report["failures"].append("%s: 缺少节点 %s" % (asset, missing))
        if extra:
            report["failures"].append("%s: 集合内多出本前缀节点 %s" % (asset, extra))
    for index, spec in port_entries(asset):
        pose = port_pose(asset, spec)
        name = blend_name(asset, spec["suffix"])
        obj = bpy.data.objects.get(name)
        if obj is None:
            report["failures"].append("%s: 缺少节点 %s" % (asset, name))
            continue
        if obj.type != "EMPTY":
            report["failures"].append("%s: %s 不是空节点" % (asset, name))
        if obj.parent is not root:
            report["failures"].append("%s: %s 父级不是根 %s"
                                      % (asset, name, root.name))
        if collection not in list(obj.users_collection):
            report["failures"].append("%s: %s 不在集合 %s"
                                      % (asset, name, collection.name))
        if not _matrix_is_identity(obj.matrix_parent_inverse):
            report["failures"].append("%s: %s matrix_parent_inverse 非单位阵"
                                      % (asset, name))
        for axis in range(3):
            if abs(obj.location[axis] - float(pose["center"][axis])) > LOC_TOL:
                report["failures"].append(
                    "%s: %s local %s %.5f != %.5f"
                    % (asset, name, "xyz"[axis], obj.location[axis],
                       float(pose["center"][axis])))
        if obj.rotation_mode != "XYZ":
            report["failures"].append("%s: %s rotation_mode %s != XYZ"
                                      % (asset, name, obj.rotation_mode))
        if abs(obj.rotation_euler[0]) > ROT_TOL:
            report["failures"].append("%s: %s rot_x 应为 0" % (asset, name))
        if abs(math.degrees(obj.rotation_euler[1])
               - float(pose["rot_y_deg"])) > ROT_TOL:
            report["failures"].append("%s: %s rot_y %.4f != %.4f"
                                      % (asset, name,
                                         math.degrees(obj.rotation_euler[1]),
                                         float(pose["rot_y_deg"])))
        if abs(math.degrees(obj.rotation_euler[2])
               - float(pose["rot_z_deg"])) > ROT_TOL:
            report["failures"].append("%s: %s rot_z %.4f != %.4f"
                                      % (asset, name,
                                         math.degrees(obj.rotation_euler[2]),
                                         float(pose["rot_z_deg"])))
        for key, expected in extras_for(spec, index).items():
            if key not in obj.keys():
                report["failures"].append("%s: %s 缺 extras.%s"
                                          % (asset, name, key))
                continue
            actual = obj[key]
            if isinstance(expected, float):
                if abs(float(actual) - expected) > 1e-6:
                    report["failures"].append(
                        "%s: %s extras.%s %.4f != %.4f"
                        % (asset, name, key, float(actual), expected))
            elif actual != expected:
                report["failures"].append("%s: %s extras.%s %r != %r"
                                          % (asset, name, key, actual, expected))
        values = measure(asset, spec, pose)
        report["failures"].extend(_check_measured(asset, spec, values))
        report["ports"].append({
            "name": name,
            "glb_name": glb_name(spec["suffix"]),
            "measured": {
                "inboard_depth": round(float(values["inboard_depth"]), 3),
                "outboard_clearance": round(float(values["outboard_clearance"]), 3),
            },
        })
    if int(root.get("gun_port_socket_count", -1)) != len(port_entries(asset)):
        report["failures"].append(
            "%s: Root gun_port_socket_count %r != %d"
            % (asset, root.get("gun_port_socket_count"), len(port_entries(asset))))
    if root.get("gun_port_socket_spec") != SOCKET_SPEC:
        report["failures"].append("%s: Root gun_port_socket_spec %r != %r"
                                  % (asset, root.get("gun_port_socket_spec"),
                                     SOCKET_SPEC))
    report["passed"] = not report["failures"]
    return report


def apply_all():
    """所有有炮门的敌舰依次就地补齐；规格自检失败时拒绝写场景。"""
    spec_failures = ck.validate_specs()
    result = {"spec_failures": spec_failures, "ships": [], "passed": False}
    if spec_failures:
        result["error"] = "ck.validate_specs() 失败，拒绝写场景"
        print(json.dumps(result, ensure_ascii=False, indent=1))
        return result
    for asset in GUN_PORT_ASSETS:
        try:
            result["ships"].append(apply_ship(asset))
        except RuntimeError as error:
            result["ships"].append({"asset": asset, "failures": [str(error)],
                                    "passed": False})
    result["passed"] = all(item["passed"] for item in result["ships"])
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return result


def apply():
    """兼容任务命名的单入口：补齐全部有炮门的敌舰。"""
    return apply_all()


def verify_all():
    """所有有炮门的敌舰只读复核。"""
    result = {"spec_failures": ck.validate_specs(), "ships": [], "passed": False}
    for asset in GUN_PORT_ASSETS:
        try:
            result["ships"].append(verify_ship(asset))
        except RuntimeError as error:
            result["ships"].append({"asset": asset, "failures": [str(error)],
                                    "passed": False})
    result["passed"] = (all(item["passed"] for item in result["ships"])
                        and not result["spec_failures"])
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return result


def verify():
    """兼容任务命名的单入口：只读复核全部有炮门的敌舰。"""
    return verify_all()


if __name__ == "__main__":
    if "--check" in sys.argv:
        print(json.dumps(check(), ensure_ascii=False, indent=1))
    else:
        apply_all()
