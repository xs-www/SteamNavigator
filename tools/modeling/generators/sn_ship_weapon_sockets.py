# -*- coding: utf-8 -*-
# @static-doc
# 作用：M0-3「船侧武器安装点」——4 艘可玩船（明轮货轮 / 明轮客船 / 纵帆船 / 铁甲舰）的
# `SN_Socket_Weapon*` 空节点规格表 + Blender 侧就地补齐 / 实测净空 / 只读自检。
#
# ## 契约（武器装配规范 v2 的船体侧，见 WEAPON_SOCKET_CONTRACT.md）
# - 只加空节点，**不改任何几何**：本脚本前后会对 4 个集合做 mesh / 三角面快照比对。
# - BLEND 内节点名带资产前缀（`SN_PF_` / `SN_PS_` / `SN_IC_` / `SN_SF_`），避免 4 艘船并排时
#   的全局对象重名；GLB 导出后由 `glb_ship_sockets.standardize()` 归一化为
#   `SN_Socket_Weapon_*`（与武器 v2 的 BLEND 前缀 → GLB 标准名做法一致）。
# - 节点是 Root 的空子节点：+X = 武器炮口/前向；侧舷点 rotZ ±90° 让 +X 指向舷外，艏点 0°、艉点 180°。
# - 原点落在甲板安装面（down-ray 实测 deck top），因此不同船的 socket z 不同。
# - 节点 extras：`socket_class` / `clearance_r` / `clearance_h` / `clearance_x` / `clearance_y` /
#   `mount_scale` / `socket_index`；Root extras 增加 `weapon_socket_count` 与 `socket_spec`
#   （`weapon_sockets` 名字列表由 GLB 后处理写入，Blender IDProperty 不支持字符串数组）。
#
# ## clearance 语义（实测口径，声明值不得高于实测值）
# - `clearance_r`：安装面以上 0.12 m，16 向水平射线的最小自由距离（m），最坏方向净空；
# - `clearance_x` / `clearance_y`：在 socket 自身局部坐标下，+X/-X 与 +Y/-Y 两对方向自由距离的最小值；
#   侧舷点 local +X 指向舷外（炮管方向）、local Y 沿船体纵轴（炮列方向），因此侧舷炮用 cx/cy 判适配；
# - `clearance_h`：从安装面向上首个遮挡高度（m）；露天按 20 m 封顶；
# - 炮管/炮口允许越出舷外，武器 `envelope_*` 不计入 clearance。
#
# ## 规格表口径
# - 每个 socket 声明 `x/y（船体局部 m）、rot_z、socket_class` 与**保守声明**的 clearance（比实测低 0.05 m）；
# - `apply_sockets()` 实测 z 与净空，先断言「实测 >= 声明 - TOL」再写节点；不达标直接抛错，不静默降级；
# - `verify_scene()` 只读复核节点名 / 父级 / 局部坐标 / 旋转 / extras / 根 extras / 集合无害回归；
# - 纯 Python 部分（规格校验、期望 GLB 节点名）不 import bpy，供 `dryrun` / GLB 验收脚本复用。
#
# 用法：
#   Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
#   纯 Python： python tools/modeling/generators/sn_ship_weapon_sockets.py --check
# @end-static-doc

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

SOCKET_PREFIX = "SN_Socket_Weapon"
SOCKET_SPEC = "hull-sockets@1"
MOUNT_SCALE = 1.0
CLEARANCE_CAP = 20.0
Z_TOL = 0.03
CLEARANCE_TOL = 0.06
LOC_TOL = 0.01

VALID_CLASSES = {"Light", "Medium", "Heavy", "Tower", "Side"}

# 4 艘船各 2–4 个安装点：艏/艉/两舷；class 有意混编，让船队覆盖 Light/Medium/Heavy/Side。
SHIPS = [
    {
        "asset": "SN_Paddle_Freighter",
        "glb": "assets/models/ships/SN_Paddle_Freighter.glb",
        "collection": "SN_Paddle_Freighter_Prototype",
        "root": "SN_PF_Root",
        "prefix": "SN_PF",
        "deck_objects": ["SN_PF_Deck", "SN_PF_Poop_Deck", "SN_PF_Forecastle"],
        "fixed_deck_z": None,
        "sockets": [
            {
                "suffix": "Port_1", "x": 13.0, "y": 2.3, "rot_z": 90.0, "socket_class": "Side",
                "clearance_r": 0.75, "clearance_x": 1.90, "clearance_y": 4.10, "clearance_h": 20.0,
                "note": "前甲板左舷：舷墙内 1.9 m 净空，沿船体纵轴 4.1 m 可排 4 门舷炮",
            },
            {
                "suffix": "Starboard_1", "x": 13.0, "y": -2.3, "rot_z": -90.0, "socket_class": "Side",
                "clearance_r": 0.75, "clearance_x": 1.90, "clearance_y": 4.10, "clearance_h": 20.0,
                "note": "前甲板右舷，与 Port_1 镜像",
            },
            {
                "suffix": "Port_2", "x": -14.0, "y": 2.2, "rot_z": 90.0, "socket_class": "Light",
                "clearance_r": 1.45, "clearance_x": 1.90, "clearance_y": 6.35, "clearance_h": 20.0,
                "note": "后甲板左舷（舱口与锅炉围罩之间），轻型炮位",
            },
            {
                "suffix": "Starboard_2", "x": -14.0, "y": -2.2, "rot_z": -90.0, "socket_class": "Light",
                "clearance_r": 1.45, "clearance_x": 1.90, "clearance_y": 6.35, "clearance_h": 20.0,
                "note": "后甲板右舷，与 Port_2 镜像",
            },
        ],
    },
    {
        "asset": "SN_Paddle_Steamer",
        "glb": "assets/models/ships/SN_Paddle_Steamer.glb",
        "collection": "SN_Paddle_Steamer_Prototype",
        "root": "SN_PS_Root",
        "prefix": "SN_PS",
        "deck_objects": ["SN_PS_Deck", "SN_PS_Promenade", "SN_PS_Stern_Platform"],
        "fixed_deck_z": None,
        "sockets": [
            {
                "suffix": "Port_1", "x": 9.6, "y": 0.8, "rot_z": 90.0, "socket_class": "Light",
                "clearance_r": 1.00, "clearance_x": 1.35, "clearance_y": 1.35, "clearance_h": 20.0,
                "note": "艏甲板左舷：艏属具与舷墙之间的轻型炮座",
            },
            {
                "suffix": "Starboard_1", "x": 9.6, "y": -0.8, "rot_z": -90.0, "socket_class": "Light",
                "clearance_r": 1.00, "clearance_x": 1.35, "clearance_y": 1.35, "clearance_h": 20.0,
                "note": "艏甲板右舷，与 Port_1 镜像",
            },
            {
                "suffix": "Stern", "x": -9.0, "y": 0.4, "rot_z": 180.0, "socket_class": "Medium",
                "clearance_r": 1.75, "clearance_x": 8.00, "clearance_y": 8.00, "clearance_h": 20.0,
                "note": "艉部上层甲板：后方开阔，可作中型艉炮位",
            },
        ],
    },
    {
        "asset": "SN_Schooner_Fame",
        "glb": "assets/models/ships/SN_Schooner_Fame.glb",
        "collection": "SN_Schooner_Fame_Prototype",
        "root": "SN_SF_Root",
        "prefix": "SN_SF",
        "deck_objects": ["SN_SF_Deck", "SN_SF_Quarterdeck"],
        "fixed_deck_z": None,
        "sockets": [
            {
                "suffix": "Port_1", "x": -8.6, "y": 1.4, "rot_z": 90.0, "socket_class": "Light",
                "clearance_r": 1.05, "clearance_x": 1.05, "clearance_y": 2.35, "clearance_h": 20.0,
                "note": "艉楼甲板左舷：舵轮柜与舷墙之间，轻型炮位",
            },
            {
                "suffix": "Starboard_1", "x": -8.6, "y": -1.4, "rot_z": -90.0, "socket_class": "Light",
                "clearance_r": 1.05, "clearance_x": 1.05, "clearance_y": 2.35, "clearance_h": 20.0,
                "note": "艉楼甲板右舷，与 Port_1 镜像",
            },
            {
                "suffix": "Bow", "x": 10.0, "y": 0.2, "rot_z": 0.0, "socket_class": "Medium",
                "clearance_r": 1.10, "clearance_x": 1.10, "clearance_y": 1.25, "clearance_h": 20.0,
                "note": "艏甲板中线偏右：艏炮位，+X 朝船首",
            },
        ],
    },
    {
        "asset": "SN_Ironclad",
        "glb": "assets/models/ships/SN_Ironclad.glb",
        "collection": "SN_Ironclad_Prototype",
        "root": "SN_Ironclad",
        "prefix": "SN_IC",
        "deck_objects": None,
        "fixed_deck_z": 4.6,
        "root_extras": {
            "asset": "SN_Ironclad",
            "version": "1.0",
            "units": "metres",
            "pivot": "waterline, centre of hull",
            "forward_axis": "+X",
        },
        "sockets": [
            {
                "suffix": "Port_1", "x": 13.5, "y": 3.1, "rot_z": 90.0, "socket_class": "Heavy",
                "clearance_r": 1.90, "clearance_x": 1.90, "clearance_y": 7.30, "clearance_h": 20.0,
                "note": "炮房前方左舷甲板：与舷侧炮列同层，重炮位",
            },
            {
                "suffix": "Starboard_1", "x": 13.5, "y": -3.1, "rot_z": -90.0, "socket_class": "Heavy",
                "clearance_r": 1.90, "clearance_x": 1.90, "clearance_y": 7.30, "clearance_h": 20.0,
                "note": "炮房前方右舷甲板，与 Port_1 镜像",
            },
            {
                "suffix": "Port_2", "x": -17.5, "y": 2.6, "rot_z": 90.0, "socket_class": "Medium",
                "clearance_r": 1.90, "clearance_x": 1.90, "clearance_y": 3.35, "clearance_h": 20.0,
                "note": "后甲板左舷：主桅与后桅之间，中型炮位",
            },
            {
                "suffix": "Starboard_2", "x": -17.5, "y": -2.6, "rot_z": -90.0, "socket_class": "Medium",
                "clearance_r": 1.90, "clearance_x": 1.90, "clearance_y": 3.35, "clearance_h": 20.0,
                "note": "后甲板右舷，与 Port_2 镜像",
            },
        ],
    },
]


# 甲板安装面期望高度（船体局部 z，m）。apply 实测 z 必须与之一致（±Z_TOL），
# GLB 验收也读同一真源，避免声明值与导出结果两套数字。
DECK_Z_EXPECTED = {
    "SN_Paddle_Freighter": {"Port_1": 3.34, "Starboard_1": 3.34,
                            "Port_2": 3.25, "Starboard_2": 3.25},
    "SN_Paddle_Steamer": {"Port_1": 1.91, "Starboard_1": 1.91, "Stern": 3.42},
    "SN_Schooner_Fame": {"Port_1": 3.08, "Starboard_1": 3.08, "Bow": 2.89},
    "SN_Ironclad": {"Port_1": 4.60, "Starboard_1": 4.60,
                    "Port_2": 4.60, "Starboard_2": 4.60},
}


def deck_z_expected(ship, sock):
    table = DECK_Z_EXPECTED.get(ship["asset"], {})
    if sock["suffix"] not in table:
        raise KeyError("%s/%s 缺少甲板高度期望值" % (ship["asset"], sock["suffix"]))
    return float(table[sock["suffix"]])


# --------------------------------------------------------------------------- #
# 纯 Python：规格校验 / 期望 GLB 节点（dryrun 与 GLB 验收共用）
# --------------------------------------------------------------------------- #

def blend_name(ship, sock):
    return "%s_Socket_Weapon_%s" % (ship["prefix"], sock["suffix"])


def glb_name(ship, sock):
    return "%s_%s" % (SOCKET_PREFIX, sock["suffix"])


def ship_sockets(ship):
    """按 socket_index 顺序返回 (index, sock) 列表。"""
    return list(enumerate(ship["sockets"], start=1))


def expected_sockets():
    """{glb asset: [(index, glb_name, sock), ...]}，GLB 验收脚本的期望值。"""
    return {
        ship["asset"]: [(i, glb_name(ship, s), s) for i, s in ship_sockets(ship)]
        for ship in SHIPS
    }


def validate_spec():
    """规格表自检（纯 Python）：返回 failures 列表。"""
    failures = []
    assets = set()
    for ship in SHIPS:
        asset = ship["asset"]
        if asset in assets:
            failures.append("%s: 资产重复" % asset)
        assets.add(asset)
        socks = ship["sockets"]
        if not 2 <= len(socks) <= 4:
            failures.append("%s: socket 数量 %d 不在 2–4" % (asset, len(socks)))
        names = set()
        for index, sock in ship_sockets(ship):
            name = glb_name(ship, sock)
            blend = blend_name(ship, sock)
            if name in names:
                failures.append("%s: GLB 节点名重复 %s" % (asset, name))
            names.add(name)
            if not name.startswith(SOCKET_PREFIX + "_"):
                failures.append("%s: %s 前缀不符" % (asset, name))
            if not blend.startswith("SN_") or "Socket_Weapon" not in blend:
                failures.append("%s: BLEND 节点名 %s 含前缀/角色检查失败" % (asset, blend))
            if sock["socket_class"] not in VALID_CLASSES:
                failures.append("%s/%s: socket_class %r 非法" % (asset, name, sock["socket_class"]))
            for key in ("clearance_r", "clearance_x", "clearance_y", "clearance_h"):
                value = float(sock[key])
                if value < 0.5:
                    failures.append("%s/%s: %s=%.2f 过小" % (asset, name, key, value))
                if key == "clearance_h" and value > CLEARANCE_CAP:
                    failures.append("%s/%s: clearance_h 超过 %.0f 上限" % (asset, name, CLEARANCE_CAP))
            if sock["clearance_r"] > min(sock["clearance_x"], sock["clearance_y"]) + 1e-6:
                failures.append("%s/%s: clearance_r 大于 cx/cy，不符合最坏方向口径" % (asset, name))
            if abs(float(sock["rot_z"]) % 360.0) not in (0.0, 90.0, 180.0, 270.0):
                failures.append("%s/%s: rot_z %.1f 不是 90° 倍数" % (asset, name, sock["rot_z"]))
            if ship["fixed_deck_z"] is None and not ship["deck_objects"]:
                failures.append("%s: 既无 deck_objects 也无 fixed_deck_z" % asset)
            try:
                deck_z = deck_z_expected(ship, sock)
            except KeyError as error:
                failures.append(str(error))
                continue
            if not 0.0 < deck_z < 40.0:
                failures.append("%s/%s: deck_z %.2f 超出合理范围" % (asset, name, deck_z))
        # 左/右舷镜像：同名尾巴 _Port_N / _Starboard_N 必须同 x、同 z、y 相反
        by_suffix = {sock["suffix"]: sock for sock in socks}
        for sock in socks:
            if sock["suffix"].startswith("Port_"):
                mirror = "Starboard_" + sock["suffix"][len("Port_"):]
            elif sock["suffix"].startswith("Starboard_"):
                mirror = "Port_" + sock["suffix"][len("Starboard_"):]
            else:
                continue
            other = by_suffix.get(mirror)
            if other is None:
                failures.append("%s: %s 缺少镜像 %s" % (asset, sock["suffix"], mirror))
                continue
            if abs(sock["x"] - other["x"]) > 1e-6 or abs(sock["y"] + other["y"]) > 1e-6:
                failures.append("%s: %s/%s 不镜像" % (asset, sock["suffix"], mirror))
            if abs(float(sock["rot_z"]) + float(other["rot_z"])) not in (0.0, 180.0):
                # ±90 互为相反数；0 与 180 也允许同时出现（艏/艉）
                failures.append("%s: %s/%s rot_z 不镜像" % (asset, sock["suffix"], mirror))
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
    """集合内 mesh 对象数 / 三角面 / 材质名集合，用来证明没有动几何。"""
    bpy = _bpy()
    collection = _collection_of(bpy, ship)
    meshes = 0
    tris = 0
    materials = set()
    names = []
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
    return {"meshes": meshes, "tris": tris, "materials": sorted(materials),
            "names": sorted(names)}


def _deck_hit(bpy, deps, root, world_xy, ship):
    """从上方逐层下射线，返回甲板安装面世界 z；遇非甲板对象继续往下。"""
    scene = bpy.context.scene
    point = (world_xy[0], world_xy[1], 40.0)
    for _ in range(18):
        hit = scene.ray_cast(deps, point, (0.0, 0.0, -1.0), distance=40.0)
        if not hit[0]:
            break
        obj = hit[4]
        if ship["fixed_deck_z"] is not None:
            ok = (abs(hit[1].z - root.matrix_world.translation.z - ship["fixed_deck_z"]) < 0.1
                  and hit[2].z > 0.85)
        else:
            ok = obj is not None and obj.name in ship["deck_objects"]
        if ok:
            return hit[1].z, obj.name
        point = (hit[1].x, hit[1].y, hit[1].z - 0.01)
    raise RuntimeError("%s: 在 (%.2f, %.2f) 找不到甲板面" % (ship["root"], world_xy[0], world_xy[1]))


def measure(ship, sock):
    """实测 deck z 与 16 向净空（世界射线），返回声明口径的实测值。"""
    from mathutils import Vector
    bpy = _bpy()
    deps = bpy.context.evaluated_depsgraph_get()
    scene = bpy.context.scene
    root = _root_of(bpy, ship)
    world = root.matrix_world @ Vector((sock["x"], sock["y"], 0.0))
    deck_z, deck_obj = _deck_hit(bpy, deps, root, world, ship)
    origin = Vector((world.x, world.y, deck_z + 0.12))
    dist = {}
    for k in range(16):
        angle = k * 22.5
        rad = math.radians(angle)
        direction = Vector((math.cos(rad), math.sin(rad), 0.0))
        hit = scene.ray_cast(deps, origin, direction, distance=8.0)
        dist[int(angle) % 360] = (hit[1] - origin).length if hit[0] else 8.0

    def local_min(base):
        a = int(round(base)) % 360
        return min(dist[a], dist[(a + 180) % 360])

    up = scene.ray_cast(deps, origin, (0.0, 0.0, 1.0), distance=40.0)
    clearance_h = (up[1].z - deck_z) if up[0] else CLEARANCE_CAP
    local_z = deck_z - root.matrix_world.translation.z
    values = {
        "deck_z": deck_z,
        "local_z": local_z,
        "deck_object": deck_obj,
        "clearance_r": min(dist.values()),
        "clearance_x": local_min(sock["rot_z"]),
        "clearance_y": local_min(sock["rot_z"] + 90.0),
        "clearance_h": min(clearance_h, CLEARANCE_CAP),
    }
    return values


def _check_declared(ship, sock, values):
    failures = []
    name = glb_name(ship, sock)
    for key in ("clearance_r", "clearance_x", "clearance_y", "clearance_h"):
        declared = float(sock[key])
        measured = float(values[key])
        if measured < declared - CLEARANCE_TOL:
            failures.append("%s: %s 声明 %.2f 高于实测 %.2f" % (name, key, declared, measured))
    expected_z = deck_z_expected(ship, sock)
    if abs(values["local_z"] - expected_z) > Z_TOL:
        failures.append("%s: 甲板面 %.3f != 期望 %.3f" % (name, values["local_z"], expected_z))
    return failures


def _remove_existing(bpy, ship):
    root = _root_of(bpy, ship)
    prefix = ship["prefix"] + "_Socket_Weapon_"
    removed = []
    for obj in list(bpy.data.objects):
        if obj.name.startswith(prefix):
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
    # 若历史重跑留下 .001 后缀（不属于本前缀但包含 Socket_Weapon），一并清掉本资产集合内的空节点
    collection = _collection_of(bpy, ship)
    for obj in list(collection.all_objects):
        if obj.type == "EMPTY" and "Socket_Weapon" in obj.name:
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
    return removed


def apply_ship(ship):
    """就地补齐一艘船的 socket 空节点；返回报告 dict。"""
    bpy = _bpy()
    root = _root_of(bpy, ship)
    collection = _collection_of(bpy, ship)
    before = mesh_snapshot(ship)
    removed = _remove_existing(bpy, ship)
    report = {"asset": ship["asset"], "root": root.name, "removed": removed, "sockets": [],
             "failures": []}
    for index, sock in ship_sockets(ship):
        values = measure(ship, sock)
        report["failures"].extend(_check_declared(ship, sock, values))
        empty = bpy.data.objects.new(blend_name(ship, sock), None)
        collection.objects.link(empty)
        empty.empty_display_type = "PLAIN_AXES"
        empty.empty_display_size = 0.8
        empty.parent = root
        # 根节点无旋转/缩放，父级逆矩阵保持单位阵；local = 船体局部坐标。
        empty.matrix_parent_inverse.identity()
        empty.location = (float(sock["x"]), float(sock["y"]), float(values["local_z"]))
        empty.rotation_mode = "XYZ"
        empty.rotation_euler = (0.0, 0.0, math.radians(float(sock["rot_z"])))
        empty["socket_spec"] = SOCKET_SPEC
        empty["socket_index"] = index
        empty["socket_class"] = sock["socket_class"]
        empty["clearance_r"] = round(float(sock["clearance_r"]), 2)
        empty["clearance_x"] = round(float(sock["clearance_x"]), 2)
        empty["clearance_y"] = round(float(sock["clearance_y"]), 2)
        empty["clearance_h"] = round(float(sock["clearance_h"]), 2)
        empty["mount_scale"] = MOUNT_SCALE
        empty["note"] = sock["note"]
        report["sockets"].append({
            "name": blend_name(ship, sock),
            "glb_name": glb_name(ship, sock),
            "socket_class": sock["socket_class"],
            "local": [round(empty.location.x, 4), round(empty.location.y, 4),
                      round(empty.location.z, 4)],
            "rot_z": float(sock["rot_z"]),
            "measured": {key: round(values[key], 3) for key in
                         ("deck_z", "local_z", "clearance_r", "clearance_x",
                          "clearance_y", "clearance_h")},
            "declared": {key: float(sock[key]) for key in
                         ("clearance_r", "clearance_x", "clearance_y", "clearance_h")},
        })
    for key, value in ship.get("root_extras", {}).items():
        root[key] = value
    root["socket_spec"] = SOCKET_SPEC
    root["weapon_socket_count"] = len(ship["sockets"])
    after = mesh_snapshot(ship)
    report["mesh_before"] = {"meshes": before["meshes"], "tris": before["tris"]}
    report["mesh_after"] = {"meshes": after["meshes"], "tris": after["tris"]}
    if (before["meshes"], before["tris"], before["names"]) != \
            (after["meshes"], after["tris"], after["names"]):
        report["failures"].append(
            "%s: 几何快照变化 meshes %d→%d tris %d→%d" % (
                ship["asset"], before["meshes"], after["meshes"],
                before["tris"], after["tris"]))
    if before["materials"] != after["materials"]:
        report["failures"].append("%s: 材质集合变化" % ship["asset"])
    report["passed"] = not report["failures"]
    return report


def verify_ship(ship):
    """只读复核一艘船：BLEND 前缀名、父级、局部坐标、旋转、extras、根 extras。"""
    bpy = _bpy()
    root = _root_of(bpy, ship)
    report = {"asset": ship["asset"], "failures": [], "sockets": []}
    prefix = ship["prefix"] + "_Socket_Weapon_"
    found = [obj for obj in bpy.data.objects if obj.name.startswith(prefix)]
    if len(found) != len(ship["sockets"]):
        report["failures"].append("%s: 节点数 %d != %d" % (ship["asset"], len(found), len(ship["sockets"])))
    for index, sock in ship_sockets(ship):
        name = blend_name(ship, sock)
        obj = bpy.data.objects.get(name)
        if obj is None:
            report["failures"].append("%s: 缺少节点 %s" % (ship["asset"], name))
            continue
        if obj.type != "EMPTY":
            report["failures"].append("%s: %s 不是空节点" % (ship["asset"], name))
        if obj.parent is not root:
            report["failures"].append("%s: %s 父级不是根" % (ship["asset"], name))
        if abs(obj.location.x - sock["x"]) > LOC_TOL:
            report["failures"].append("%s: %s local x %.3f != %.3f" % (ship["asset"], name, obj.location.x, sock["x"]))
        if abs(obj.location.y - sock["y"]) > LOC_TOL:
            report["failures"].append("%s: %s local y %.3f != %.3f" % (ship["asset"], name, obj.location.y, sock["y"]))
        yaw = math.degrees(obj.rotation_euler.z) % 360.0
        if abs(yaw - (float(sock["rot_z"]) % 360.0)) > 0.01:
            report["failures"].append("%s: %s yaw %.2f != %.2f" % (ship["asset"], name, yaw, sock["rot_z"]))
        expected_extras = {
            "socket_class": sock["socket_class"],
            "clearance_r": round(float(sock["clearance_r"]), 2),
            "clearance_x": round(float(sock["clearance_x"]), 2),
            "clearance_y": round(float(sock["clearance_y"]), 2),
            "clearance_h": round(float(sock["clearance_h"]), 2),
            "mount_scale": MOUNT_SCALE,
            "socket_index": index,
            "socket_spec": SOCKET_SPEC,
        }
        for key, expected in expected_extras.items():
            if key not in obj.keys():
                report["failures"].append("%s: %s 缺 extras.%s" % (ship["asset"], name, key))
                continue
            actual = obj[key]
            if isinstance(expected, float):
                if abs(float(actual) - expected) > 1e-6:
                    report["failures"].append("%s: %s extras.%s %.3f != %.3f" % (ship["asset"], name, key, float(actual), expected))
            elif actual != expected:
                report["failures"].append("%s: %s extras.%s %r != %r" % (ship["asset"], name, key, actual, expected))
        values = measure(ship, sock)
        report["failures"].extend(_check_declared(ship, sock, values))
        report["sockets"].append({"name": name, "glb_name": glb_name(ship, sock),
                                  "measured": {k: round(values[k], 3) for k in
                                               ("local_z", "clearance_r", "clearance_x",
                                                "clearance_y", "clearance_h")}})
    dupes = [obj.name for obj in bpy.data.objects if obj.name.endswith(".001")
             and "Socket_Weapon" in obj.name]
    if dupes:
        report["failures"].append("%s: Socket 节点出现 .001 后缀 %s" % (ship["asset"], dupes))
    if int(root.get("weapon_socket_count", -1)) != len(ship["sockets"]):
        report["failures"].append("%s: 根 weapon_socket_count 不符" % ship["asset"])
    if root.get("socket_spec") != SOCKET_SPEC:
        report["failures"].append("%s: 根 socket_spec 不符" % ship["asset"])
    for key, value in ship.get("root_extras", {}).items():
        if root.get(key) != value:
            report["failures"].append("%s: 根 extras.%s %r != %r"
                                      % (ship["asset"], key, root.get(key), value))
    report["passed"] = not report["failures"]
    return report


def apply_all():
    spec_failures = validate_spec()
    result = {"spec_failures": spec_failures, "ships": [], "passed": False}
    if spec_failures:
        result["error"] = "规格表自检失败，拒绝写场景"
        print(json.dumps(result, ensure_ascii=False, indent=1))
        return result
    for ship in SHIPS:
        result["ships"].append(apply_ship(ship))
    result["passed"] = all(item["passed"] for item in result["ships"]) and not spec_failures
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return result


def verify_all():
    result = {"spec_failures": validate_spec(), "ships": [], "passed": False}
    for ship in SHIPS:
        result["ships"].append(verify_ship(ship))
    result["passed"] = all(item["passed"] for item in result["ships"]) and not result["spec_failures"]
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return result


if __name__ == "__main__":
    if "--check" in sys.argv:
        failures = validate_spec()
        sockets = sum(len(ship["sockets"]) for ship in SHIPS)
        print(json.dumps({"ships": len(SHIPS), "sockets": sockets,
                          "per_ship": {ship["asset"]: len(ship["sockets"]) for ship in SHIPS},
                          "failures": failures, "ok": not failures},
                         ensure_ascii=False, indent=1))
    else:
        apply_all()
