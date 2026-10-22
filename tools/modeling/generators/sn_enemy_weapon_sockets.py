# -*- coding: utf-8 -*-
# @static-doc
# 作用：`combat_kit` 敌舰（4 艘：海盗单桅 / 炮艇 / 武装商船 / 铁甲舰变体）甲板武器安装点
# `SN_<PFX>_Socket_Weapon_<suffix>` 的 Blender 就地补齐 / 实测 / 只读复核 / 纯 Python 自检。
# 数据真源是 `combat_kit_generator`（本文件不抄任何坐标 / 净空数字）：
# `SHIP_CLASS_ORDER`、`SHIP_CONFIGS[asset]`（root / collection / prefix）、`WEAPON_SOCKETS[asset]`、
# `blend_weapon_socket_name()` / `glb_weapon_socket_name()` / `expected_weapon_socket_names()`。
#
# ## 契约（WEAPON_SOCKET_CONTRACT.md §8，`hull-sockets@1`）
# - 只加空节点、不改几何：apply 前后对集合做 mesh / 三角面 / 对象名 / 材质快照比对；
# - BLEND 内节点名带资产前缀（`SN_ES_` / `SN_EG_` / `SN_EM_` / `SN_ER_`），4 艘船同场景并排时
#   不会撞 Blender 全局对象命名空间；GLB 导出后由 `glb_enemy_sockets.normalize()` 归一化为
#   `SN_Socket_Weapon_*`；
# - 节点是 Root 的空子节点（`parent = root`、`matrix_parent_inverse` 单位阵、XYZ 欧拉），
#   原点在**实测甲板安装面**：+X = 炮口/前向，侧舷点 rotZ ±90° 让 +X 指向舷外；
# - 节点 extras：`socket_spec / socket_index / socket_class / clearance_r / clearance_x /
#   clearance_y / clearance_h / mount_scale / note`；
# - Root extras：`weapon_socket_count`、`socket_spec`（`weapon_sockets` 名字数组由 GLB 后处理写，
#   Blender IDProperty 不支持字符串数组）；既有 Root extras 原样保留。
#
# ## 实测口径（声明值不得高于实测值，脚本内断言、不静默降级）
# - 安装面 z：从上方对甲板面 down-ray，跳过桅/帆索/烟囱等非甲板对象；要求与
#   `WEAPON_SOCKETS[asset][i]["deck_z"]` 的差 ≤ `Z_TOL`（0.03 m），否则记 failure；
# - 净空原点 = 安装面 + 0.12 m；
# - `clearance_r`：16 向水平射线的最小自由距离（m），单向 8 m 封顶（无命中按 8）；
# - `clearance_x` / `clearance_y`：socket 局部 +X/-X、+Y/-Y 两向距离取小（侧舷点 local +X 朝舷外，
#   local Y 沿船体纵轴）；声明值与实测差超过 `CLEARANCE_TOL`（0.06 m）记 failure；
# - `clearance_h`：从安装面向上首个遮挡高度（m），20 m 封顶。
#
# ## 幂等 / 边界
# - 重跑只删除本资产前缀（`<PFX>Socket_Weapon_`）的空节点，绝不触碰其它船的 socket、
#   炮门节点或几何；节点一律挂到 `SHIP_CONFIGS[asset]["collection"]`；
# - `verify_ship()` 只读复核节点名 / 父级 / 局部坐标 / 旋转 / extras / Root extras / 实测值；
# - 纯 Python 部分（`check()`、期望 GLB 名单）不 import bpy，供 `--check` 与 GLB 验收复用。
#
# 用法：
#   Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
#   纯 Python： python tools/modeling/generators/sn_enemy_weapon_sockets.py --check
# @end-static-doc

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import combat_kit_generator as ck  # noqa: E402

SOCKET_SPEC = ck.SOCKET_SPEC
MOUNT_SCALE = 1.0
CLEARANCE_CAP = 20.0
HORIZONTAL_CAP = 8.0
RAY_START_Z = 40.0
RAY_UP_DIST = 40.0
CLEARANCE_ORIGIN_H = 0.12
Z_TOL = 0.03
CLEARANCE_TOL = 0.06
LOC_TOL = 0.01
ROT_TOL = 0.01

VALID_CLASSES = ("Light", "Medium", "Heavy", "Tower", "Side")
REQUIRED_SPEC_KEYS = ("suffix", "x", "y", "rot_z", "socket_class", "clearance_r",
                      "clearance_x", "clearance_y", "clearance_h", "deck_z", "note")


# --------------------------------------------------------------------------- #
# 数据视图（全部来自 combat_kit_generator，不复制数字）
# --------------------------------------------------------------------------- #

def ships():
    """按 `ck.SHIP_CLASS_ORDER` 返回 4 艘敌舰的 socket 数据视图。"""
    out = []
    for asset in ck.SHIP_CLASS_ORDER:
        cfg = ck.SHIP_CONFIGS[asset]
        out.append({
            "asset": asset,
            "root": cfg["root"],
            "collection": cfg["collection"],
            "prefix": cfg["prefix"],
            "sockets": ck.WEAPON_SOCKETS[asset],
        })
    return out


SHIPS = ships()


def ship_of(asset):
    for ship in SHIPS:
        if ship["asset"] == asset:
            return ship
    raise KeyError("未知敌舰资产 %s（应属于 ck.SHIP_CLASS_ORDER）" % asset)


def blend_prefix(ship):
    """BLEND 内本资产 socket 名前缀（含资产前缀，避免全局重名）。"""
    return ship["prefix"] + "Socket_Weapon_"


def blend_name(asset, suffix):
    return ck.blend_weapon_socket_name(asset, suffix)


def glb_name(suffix):
    return ck.glb_weapon_socket_name(suffix)


def deck_object_names(ship):
    """down-ray 可接受的甲板面对象名（`Deck` + 可选 `Poop_Deck`）。"""
    return {ship["prefix"] + "Deck", ship["prefix"] + "Poop_Deck"}


def socket_entries(asset):
    return ck.weapon_socket_entries(asset)


def expected_sockets(asset):
    """[(index, glb_name, spec)]，按 socket_index 顺序。"""
    return [(index, glb_name(spec["suffix"]), spec)
            for index, spec in socket_entries(asset)]


# --------------------------------------------------------------------------- #
# 纯 Python 自检（不 import bpy）
# --------------------------------------------------------------------------- #

def check():
    """规格自检：ck.validate_specs() + 命名 / extras / 期望 GLB 名单。"""
    failures = list(ck.validate_specs())
    blend_names = {}
    report = {}
    for ship in SHIPS:
        asset = ship["asset"]
        socks = ship["sockets"]
        names = ck.expected_weapon_socket_names(asset)
        if len(names) != len(socks):
            failures.append("%s: 期望 GLB 名单 %d 个 != socket %d 个"
                            % (asset, len(names), len(socks)))
        if len(set(names)) != len(names):
            failures.append("%s: 期望 GLB 名单内部重复" % asset)
        if not ship["root"] or not ship["collection"]:
            failures.append("%s: root / collection 为空" % asset)
        for index, spec in socket_entries(asset):
            missing = [key for key in REQUIRED_SPEC_KEYS if key not in spec]
            if missing:
                failures.append("%s/%s: 规格缺字段 %s"
                                % (asset, spec.get("suffix", index), missing))
                continue
            blend = blend_name(asset, spec["suffix"])
            if blend in blend_names:
                failures.append("%s: BLEND 节点名 %s 与 %s 全局重名"
                                % (asset, blend, blend_names[blend]))
            blend_names[blend] = asset
            if not blend.startswith("SN_"):
                failures.append("%s: BLEND 名 %s 缺少 SN_ 前缀" % (asset, blend))
            if spec["socket_class"] not in VALID_CLASSES:
                failures.append("%s/%s: socket_class %r 非法"
                                % (asset, spec["suffix"], spec["socket_class"]))
            if not isinstance(spec["note"], str) or not spec["note"]:
                failures.append("%s/%s: note 为空" % (asset, spec["suffix"]))
            if not 0.0 < float(spec["deck_z"]) < RAY_START_Z:
                failures.append("%s/%s: deck_z %.2f 超出合理范围"
                                % (asset, spec["suffix"], float(spec["deck_z"])))
            for key in ("clearance_r", "clearance_x", "clearance_y"):
                if float(spec[key]) <= 0.0:
                    failures.append("%s/%s: %s 必须为正"
                                    % (asset, spec["suffix"], key))
            if not 0.0 < float(spec["clearance_h"]) <= CLEARANCE_CAP:
                failures.append("%s/%s: clearance_h %.2f 不在 (0, %.0f]"
                                % (asset, spec["suffix"],
                                   float(spec["clearance_h"]), CLEARANCE_CAP))
        report[asset] = {
            "root": ship["root"],
            "collection": ship["collection"],
            "sockets": len(socks),
            "glb_names": names,
            "blend_names": [blend_name(asset, spec["suffix"])
                            for _index, spec in socket_entries(asset)],
        }
    return {"ok": not failures, "failures": failures,
            "ships": len(SHIPS), "assets": report}


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
    """集合内 mesh 数 / 三角面 / 对象名 / 材质名，证明没有动几何。"""
    bpy = _bpy()
    collection = _collection_of(bpy, ship)
    meshes = 0
    tris = 0
    names = []
    materials = set()
    for obj in collection.all_objects:
        if obj.type != "MESH":
            continue
        meshes += 1
        names.append(obj.name)
        obj.data.calc_loop_triangles()
        tris += len(obj.data.loop_triangles)
        for slot in obj.material_slots:
            if slot.material:
                materials.add(slot.material.name)
    return {"meshes": meshes, "tris": tris, "names": sorted(names),
            "materials": sorted(materials)}


def _deck_hit(bpy, deps, root, world_xy, ship):
    """从上方逐层 down-ray，返回 (甲板安装面世界 z, 甲板对象名)。"""
    from mathutils import Vector
    scene = bpy.context.scene
    point = Vector((world_xy[0], world_xy[1], RAY_START_Z))
    deck_names = deck_object_names(ship)
    for _attempt in range(18):
        hit = scene.ray_cast(deps, point, (0.0, 0.0, -1.0), distance=RAY_START_Z)
        if not hit[0]:
            break
        obj = hit[4]
        if obj is not None and obj.name in deck_names:
            return hit[1].z, obj.name
        point = Vector((hit[1].x, hit[1].y, hit[1].z - 0.01))
    raise RuntimeError("%s: 在 (%.2f, %.2f) 找不到甲板面（可接受对象 %s）"
                       % (ship["root"], world_xy[0], world_xy[1],
                          sorted(deck_names)))


def measure(asset, spec):
    """实测安装面 z 与 16 向净空（世界射线），返回声明口径的实测值。"""
    from mathutils import Vector
    bpy = _bpy()
    ship = ship_of(asset)
    deps = bpy.context.evaluated_depsgraph_get()
    scene = bpy.context.scene
    root = _root_of(bpy, ship)
    world = root.matrix_world @ Vector((float(spec["x"]), float(spec["y"]), 0.0))
    deck_z, deck_obj = _deck_hit(bpy, deps, root, world, ship)
    origin = Vector((world.x, world.y, deck_z + CLEARANCE_ORIGIN_H))
    dist = {}
    for k in range(16):
        angle = int(k * 22.5)
        radians = math.radians(angle)
        hit = scene.ray_cast(deps, origin,
                             (math.cos(radians), math.sin(radians), 0.0),
                             distance=HORIZONTAL_CAP)
        dist[angle] = (hit[1] - origin).length if hit[0] else HORIZONTAL_CAP

    def local_min(base):
        angle = int(round(base)) % 360
        return min(dist[angle], dist[(angle + 180) % 360])

    up = scene.ray_cast(deps, origin, (0.0, 0.0, 1.0), distance=RAY_UP_DIST)
    clearance_h = (up[1].z - deck_z) if up[0] else CLEARANCE_CAP
    local = root.matrix_world.inverted() @ Vector((world.x, world.y, deck_z))
    return {
        "deck_z": deck_z,
        "deck_object": deck_obj,
        "local_z": local.z,
        "clearance_r": min(dist.values()),
        "clearance_x": local_min(float(spec["rot_z"])),
        "clearance_y": local_min(float(spec["rot_z"]) + 90.0),
        "clearance_h": min(clearance_h, CLEARANCE_CAP),
    }


def _check_measured(asset, spec, values):
    """实测 vs 声明：z 差与净空下限，返回 failure 列表（不静默降级）。"""
    failures = []
    name = glb_name(spec["suffix"])
    if abs(float(values["local_z"]) - float(spec["deck_z"])) > Z_TOL:
        failures.append("%s/%s: 甲板面实测 %.3f != 声明 %.3f（容差 %.2f）"
                        % (asset, name, float(values["local_z"]),
                           float(spec["deck_z"]), Z_TOL))
    for key in ("clearance_r", "clearance_x", "clearance_y", "clearance_h"):
        declared = float(spec[key])
        measured = float(values[key])
        if measured < declared - CLEARANCE_TOL:
            failures.append("%s/%s: %s 声明 %.2f 高于实测 %.2f（容差 %.2f）"
                            % (asset, name, key, declared, measured, CLEARANCE_TOL))
    return failures


def _remove_existing(bpy, ship):
    """幂等重跑：只删除本资产前缀的 Weapon socket 空节点（覆盖 .001 后缀）。"""
    prefix = blend_prefix(ship)
    removed = []
    for obj in list(bpy.data.objects):
        if obj.name.startswith(prefix):
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
    return removed


def apply_ship(asset):
    """就地补齐一艘敌舰的甲板武器 socket 空节点；返回报告 dict。"""
    bpy = _bpy()
    ship = ship_of(asset)
    root = _root_of(bpy, ship)
    collection = _collection_of(bpy, ship)
    before = mesh_snapshot(ship)
    removed = _remove_existing(bpy, ship)
    report = {"asset": asset, "root": root.name, "collection": collection.name,
              "removed": removed, "sockets": [], "failures": []}
    for index, spec in socket_entries(asset):
        name = blend_name(asset, spec["suffix"])
        try:
            values = measure(asset, spec)
        except RuntimeError as error:
            report["failures"].append(str(error))
            continue
        report["failures"].extend(_check_measured(asset, spec, values))
        empty = bpy.data.objects.new(name, None)
        collection.objects.link(empty)
        empty.empty_display_type = "PLAIN_AXES"
        empty.empty_display_size = 0.8
        empty.parent = root
        empty.matrix_parent_inverse.identity()
        empty.location = (float(spec["x"]), float(spec["y"]), float(values["local_z"]))
        empty.rotation_mode = "XYZ"
        empty.rotation_euler = (0.0, 0.0, math.radians(float(spec["rot_z"])))
        empty["socket_spec"] = SOCKET_SPEC
        empty["socket_index"] = int(index)
        empty["socket_class"] = spec["socket_class"]
        empty["clearance_r"] = round(float(spec["clearance_r"]), 2)
        empty["clearance_x"] = round(float(spec["clearance_x"]), 2)
        empty["clearance_y"] = round(float(spec["clearance_y"]), 2)
        empty["clearance_h"] = round(float(spec["clearance_h"]), 2)
        empty["mount_scale"] = MOUNT_SCALE
        empty["note"] = spec["note"]
        report["sockets"].append({
            "name": name,
            "glb_name": glb_name(spec["suffix"]),
            "socket_index": int(index),
            "socket_class": spec["socket_class"],
            "local": [round(float(spec["x"]), 4), round(float(spec["y"]), 4),
                      round(float(values["local_z"]), 4)],
            "rot_z": float(spec["rot_z"]),
            "measured": {key: round(float(values[key]), 3) for key in
                         ("deck_z", "local_z", "clearance_r", "clearance_x",
                          "clearance_y", "clearance_h")},
            "declared": {key: float(spec[key]) for key in
                         ("clearance_r", "clearance_x", "clearance_y", "clearance_h")},
        })
    root["socket_spec"] = SOCKET_SPEC
    root["weapon_socket_count"] = len(ship["sockets"])
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
    if before["materials"] != after["materials"]:
        report["failures"].append("%s: 材质集合变化" % asset)
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
    """只读复核一艘敌舰：名字 / 父级 / 坐标 / 旋转 / extras / Root extras / 实测值。"""
    bpy = _bpy()
    ship = ship_of(asset)
    root = _root_of(bpy, ship)
    collection = _collection_of(bpy, ship)
    report = {"asset": asset, "root": root.name, "failures": [], "sockets": []}
    prefix = blend_prefix(ship)
    found = sorted(obj.name for obj in collection.all_objects
                   if obj.type == "EMPTY" and obj.name.startswith(prefix))
    expected_names = sorted(blend_name(asset, spec["suffix"])
                            for _index, spec in socket_entries(asset))
    if found != expected_names:
        extra = [name for name in found if name not in expected_names]
        missing = [name for name in expected_names if name not in found]
        if missing:
            report["failures"].append("%s: 缺少节点 %s" % (asset, missing))
        if extra:
            report["failures"].append("%s: 集合内多出本前缀节点 %s" % (asset, extra))
    for index, spec in socket_entries(asset):
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
        if _collection_of(bpy, ship) not in list(obj.users_collection):
            report["failures"].append("%s: %s 不在集合 %s"
                                      % (asset, name, collection.name))
        if not _matrix_is_identity(obj.matrix_parent_inverse):
            report["failures"].append("%s: %s matrix_parent_inverse 非单位阵"
                                      % (asset, name))
        if abs(obj.location.x - float(spec["x"])) > LOC_TOL:
            report["failures"].append("%s: %s local x %.3f != %.3f"
                                      % (asset, name, obj.location.x, float(spec["x"])))
        if abs(obj.location.y - float(spec["y"])) > LOC_TOL:
            report["failures"].append("%s: %s local y %.3f != %.3f"
                                      % (asset, name, obj.location.y, float(spec["y"])))
        if obj.rotation_mode != "XYZ":
            report["failures"].append("%s: %s rotation_mode %s != XYZ"
                                      % (asset, name, obj.rotation_mode))
        for axis in (0, 1):
            if abs(obj.rotation_euler[axis]) > ROT_TOL:
                report["failures"].append("%s: %s rot_%s 应为 0"
                                          % (asset, name, "xyz"[axis]))
        yaw = math.degrees(obj.rotation_euler.z) % 360.0
        want_yaw = float(spec["rot_z"]) % 360.0
        if abs(yaw - want_yaw) > ROT_TOL:
            report["failures"].append("%s: %s yaw %.3f != %.3f"
                                      % (asset, name, yaw, want_yaw))
        expected_extras = {
            "socket_spec": SOCKET_SPEC,
            "socket_index": int(index),
            "socket_class": spec["socket_class"],
            "clearance_r": round(float(spec["clearance_r"]), 2),
            "clearance_x": round(float(spec["clearance_x"]), 2),
            "clearance_y": round(float(spec["clearance_y"]), 2),
            "clearance_h": round(float(spec["clearance_h"]), 2),
            "mount_scale": MOUNT_SCALE,
            "note": spec["note"],
        }
        for key, expected in expected_extras.items():
            if key not in obj.keys():
                report["failures"].append("%s: %s 缺 extras.%s"
                                          % (asset, name, key))
                continue
            actual = obj[key]
            if isinstance(expected, float):
                if abs(float(actual) - expected) > 1e-6:
                    report["failures"].append(
                        "%s: %s extras.%s %.3f != %.3f"
                        % (asset, name, key, float(actual), expected))
            elif actual != expected:
                report["failures"].append("%s: %s extras.%s %r != %r"
                                          % (asset, name, key, actual, expected))
        try:
            values = measure(asset, spec)
        except RuntimeError as error:
            report["failures"].append(str(error))
            continue
        report["failures"].extend(_check_measured(asset, spec, values))
        if abs(obj.location.z - float(values["local_z"])) > LOC_TOL:
            report["failures"].append(
                "%s: %s local z %.3f != 实测安装面 %.3f"
                % (asset, name, obj.location.z, float(values["local_z"])))
        report["sockets"].append({
            "name": name,
            "glb_name": glb_name(spec["suffix"]),
            "measured": {key: round(float(values[key]), 3) for key in
                         ("deck_z", "local_z", "clearance_r", "clearance_x",
                          "clearance_y", "clearance_h")},
        })
    if int(root.get("weapon_socket_count", -1)) != len(ship["sockets"]):
        report["failures"].append("%s: Root weapon_socket_count %r != %d"
                                  % (asset, root.get("weapon_socket_count"),
                                     len(ship["sockets"])))
    if root.get("socket_spec") != SOCKET_SPEC:
        report["failures"].append("%s: Root socket_spec %r != %r"
                                  % (asset, root.get("socket_spec"), SOCKET_SPEC))
    report["passed"] = not report["failures"]
    return report


def apply_all():
    """4 艘敌舰依次就地补齐；规格自检失败时拒绝写场景。"""
    spec_failures = ck.validate_specs()
    result = {"spec_failures": spec_failures, "ships": [], "passed": False}
    if spec_failures:
        result["error"] = "ck.validate_specs() 失败，拒绝写场景"
        print(json.dumps(result, ensure_ascii=False, indent=1))
        return result
    for asset in ck.SHIP_CLASS_ORDER:
        try:
            result["ships"].append(apply_ship(asset))
        except RuntimeError as error:
            # 单船缺失（未建 / 集合缺失）只记 failure，不阻断其余 3 艘
            result["ships"].append({"asset": asset, "failures": [str(error)],
                                    "passed": False})
    result["passed"] = all(item["passed"] for item in result["ships"])
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return result


def verify_all():
    """4 艘敌舰只读复核。"""
    result = {"spec_failures": ck.validate_specs(), "ships": [], "passed": False}
    for asset in ck.SHIP_CLASS_ORDER:
        try:
            result["ships"].append(verify_ship(asset))
        except RuntimeError as error:
            result["ships"].append({"asset": asset, "failures": [str(error)],
                                    "passed": False})
    result["passed"] = (all(item["passed"] for item in result["ships"])
                        and not result["spec_failures"])
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return result


if __name__ == "__main__":
    if "--check" in sys.argv:
        print(json.dumps(check(), ensure_ascii=False, indent=1))
    else:
        apply_all()
