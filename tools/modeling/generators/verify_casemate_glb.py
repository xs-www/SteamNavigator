# -*- coding: utf-8 -*-
# @static-doc
# 作用：casemate gun 模块化的 **GLB 独立验收**（纯 Python，不进 Blender / Godot）——
# 一次核对两个交付物：
#
# 1. `SN_Weapon_CasemateGun.glb`：节点/网格/图元/三角面、炮门平面轴心（门外 1.5407 m /
#    门内 0.95 m）、标准节点链（Mount → Pitch → Recoil → Muzzle）、`port_pitch` 装配 extras、
#    外部共享贴图（URI + 授权 PNG 逐字节）与 UV；
# 2. `SN_Ironclad.glb`：空炮门版几何不变量（8158 tri / 1 mesh / 8 图元 / 世界尺寸不变）、
#    26 个节点（1 mesh + 4 武器 socket + 9 帆索 socket + 12 炮门 socket）、每个炮门节点的
#    局部 translation / 朝向 / extras 与 `sn_ship_gun_ports` 声明值一致、Root 三套 socket 名单。
#
# 用法：
#     python tools/modeling/generators/verify_casemate_glb.py
#     python tools/modeling/generators/verify_casemate_glb.py --gun <glb> --ship <glb>
# 通过标准：两个文件都 ALL OK；否则返回非 0 退出码。
# @end-static-doc

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import sn_ship_gun_ports as gunports
import sn_shared_materials as smat
import sn_ship_rig_sockets as rigsocks
import sn_ship_weapon_sockets as socks
from verify_cranes_glb import (  # noqa: E402
    SIZE_TOL,
    TEX_URI_PREFIX,
    WORKDIR,
    _node_matrix,
    _tile_sha,
    gltf_stats,
    load_glb,
)

GUN_GLB = os.path.join(WORKDIR, "assets", "models", "weapons",
                       "SN_Weapon_CasemateGun.glb")
SHIP_GLB = os.path.join(WORKDIR, "assets", "models", "ships", "SN_Ironclad.glb")
POS_TOL = 0.02
ROT_TOL = 2e-3

GUN_EXPECT = {
    "nodes": 7,
    "meshes": 2,
    "primitives": 3,
    "tris": 108,
    "size_yup": (2.4907, 1.0000, 1.0000),   # glTF Y-up：(Blender X, Blender Z, Blender Y)
    "bbox_min_yup": (-0.9500, -0.5000, -0.5000),
    "bbox_max_yup": (1.5407, 0.5000, 0.5000),
    "materials": {"SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Brass"},
}
GUN_NODES = ["SN_Mount", "SN_Pivot_Pitch", "SN_Recoil", "SN_Muzzle"]
GUN_MESHES = ["SN_Weapon_CasemateGun_Barrel", "SN_Weapon_CasemateGun_Breech"]
GUN_ROOT = "SN_Weapon_CasemateGun_Root"
GUN_CHAIN = [("SN_Weapon_CasemateGun_Root", "SN_Mount"),
             ("SN_Mount", "SN_Pivot_Pitch"),
             ("SN_Pivot_Pitch", "SN_Recoil"),
             ("SN_Recoil", "SN_Muzzle"),
             ("SN_Recoil", "SN_Weapon_CasemateGun_Barrel"),
             ("SN_Recoil", "SN_Weapon_CasemateGun_Breech")]
GUN_ROOT_EXTRAS = {
    "assembly_spec": "weapon-assembly@2",
    "weapon_class": "Medium",
    "assembly_profile": "port_pitch",
    "socket": "SN_Socket_GunPort",
    "mount": "SN_Mount",
    "pivot_pitch": "SN_Pivot_Pitch",
    "recoil": "SN_Recoil",
    "muzzle": "SN_Muzzle",
    "has_yaw": False,
    "has_pitch": True,
    "has_recoil": True,
    "has_muzzle": True,
    "muzzle_count": 1,
    "port_spec": "gun-port@1",
    "port_class": "Medium",
    "port_w": 1.90,
    "port_h": 1.90,
    "muzzle_protrusion": 1.5407,
    "breech_depth": 0.95,
}

SHIP_EXPECT = {
    "nodes": 26,
    "meshes": 1,
    "primitives": 8,
    "tris": 8158,
    "size_yup": (60.1346, 28.64, 18.0),
    "materials": {"SN_Tex_Brass", "SN_Tex_Canvas_Shade", "SN_Tex_Iron",
                  "SN_Tex_Iron_Red", "SN_Tex_Metal", "SN_Tex_Wood",
                  "SN_Tex_Wood_Dark", "SN_Tex_Wood_Deck"},
}


def _node_index(nodes, name):
    return next((i for i, node in enumerate(nodes) if node.get("name") == name), None)


def _children_map(nodes):
    parent = {}
    for index, node in enumerate(nodes):
        for child in node.get("children", []):
            parent[child] = index
    return parent


def _forward(node):
    matrix = _node_matrix(node)
    vec = [matrix[0], matrix[4], matrix[8]]
    length = math.sqrt(sum(v * v for v in vec)) or 1.0
    return [v / length for v in vec]


def _check_textures(stats, flags):
    images = stats["images"]
    if not images:
        flags.append("no-images")
        return
    if any(image.get("embedded") for image in images):
        flags.append("embedded-images")
    tile_shas = _tile_sha()
    for image in images:
        uri = image.get("uri") or ""
        if not uri.startswith(TEX_URI_PREFIX) or not image.get("exists"):
            flags.append("bad-uri=%s" % uri)
            continue
        texture = os.path.splitext(os.path.basename(uri))[0]
        material = next((name for name, row in smat.texture_report().items()
                         if row["texture"] == texture), None)
        if material is None or tile_shas.get(material) != image.get("sha256"):
            flags.append("texture-bytes-mismatch=%s" % uri)
    if any(uri is None for uri in stats["texture_uris"]):
        flags.append("material-without-texture")


def check_gun(path):
    flags = []
    if not os.path.isfile(path):
        return ["GLB 不存在"], {}
    stats = gltf_stats(path)
    gltf = load_glb(path)
    nodes = gltf.get("nodes", [])
    names = [node.get("name", "") for node in nodes]
    for key in ("nodes", "meshes", "primitives", "tris"):
        if stats[key] != GUN_EXPECT[key]:
            flags.append("%s=%s/%s" % (key, stats[key], GUN_EXPECT[key]))
    for i, axis in enumerate("xyz"):
        if abs(stats["size_yup"][i] - GUN_EXPECT["size_yup"][i]) > SIZE_TOL:
            flags.append("size_%s=%.3f!=%.3f" % (axis, stats["size_yup"][i],
                                                 GUN_EXPECT["size_yup"][i]))
        if abs(stats["bbox_min"][i] - GUN_EXPECT["bbox_min_yup"][i]) > SIZE_TOL:
            flags.append("min_%s=%.3f!=%.3f" % (axis, stats["bbox_min"][i],
                                                GUN_EXPECT["bbox_min_yup"][i]))
        if abs(stats["bbox_max"][i] - GUN_EXPECT["bbox_max_yup"][i]) > SIZE_TOL:
            flags.append("max_%s=%.3f!=%.3f" % (axis, stats["bbox_max"][i],
                                                GUN_EXPECT["bbox_max_yup"][i]))
    if set(stats["materials"]) != GUN_EXPECT["materials"]:
        flags.append("materials=%s" % sorted(stats["materials"]))
    if not stats["double_sided"]:
        flags.append("not-all-doubleSided")
    if stats["prims_without_uv"]:
        flags.append("prims_without_uv=%d" % stats["prims_without_uv"])
    if stats["has_cameras"]:
        flags.append("has-camera")
    _check_textures(stats, flags)

    for name in GUN_NODES + GUN_MESHES + [GUN_ROOT]:
        if name not in names:
            flags.append("missing_node=%s" % name)
    parent = _children_map(nodes)
    for parent_name, child_name in GUN_CHAIN:
        p = _node_index(nodes, parent_name)
        c = _node_index(nodes, child_name)
        if p is None or c is None:
            continue
        if parent.get(c) != p:
            flags.append("bad_parent=%s<%s" % (child_name, parent_name))
    root_index = _node_index(nodes, GUN_ROOT)
    if root_index is not None:
        extras = nodes[root_index].get("extras") or {}
        for key, expected in GUN_ROOT_EXTRAS.items():
            if key not in extras:
                flags.append("root_extras_missing=%s" % key)
            elif isinstance(expected, bool):
                if bool(extras[key]) != expected:
                    flags.append("root_extras.%s=%r" % (key, extras[key]))
            elif isinstance(expected, float):
                if abs(float(extras[key]) - expected) > 1e-6:
                    flags.append("root_extras.%s=%r" % (key, extras[key]))
            elif extras[key] != expected:
                flags.append("root_extras.%s=%r!=%r" % (key, extras[key], expected))
        if extras.get("pivot_yaw"):
            flags.append("fixed broadside gun should not declare yaw")
        matrix = _node_matrix(nodes[root_index])
        if max(abs(matrix[i] - (1.0 if i in (0, 5, 10, 15) else 0.0)) for i in range(16)) > 1e-6:
            flags.append("root transform not identity")
    pitch = _node_index(nodes, "SN_Pivot_Pitch")
    if pitch is not None:
        translation = nodes[pitch].get("translation", [0, 0, 0])
        if abs(float(translation[0]) - (-0.15)) > POS_TOL:
            flags.append("pitch_x=%.3f" % float(translation[0]))
    muzzle = _node_index(nodes, "SN_Muzzle")
    if muzzle is not None:
        translation = nodes[muzzle].get("translation", [0, 0, 0])
        if abs(float(translation[0]) - 1.6907) > POS_TOL:
            flags.append("muzzle_x=%.3f" % float(translation[0]))
    info = {"nodes": stats["nodes"], "meshes": stats["meshes"],
            "prims": stats["primitives"], "tris": stats["tris"],
            "size": tuple(round(v, 4) for v in stats["size_yup"])}
    return flags, info


def check_ship(path):
    flags = []
    if not os.path.isfile(path):
        return ["GLB 不存在"], {}
    stats = gltf_stats(path)
    gltf = load_glb(path)
    nodes = gltf.get("nodes", [])
    names = [node.get("name", "") for node in nodes]
    for key in ("nodes", "meshes", "primitives", "tris"):
        if stats[key] != SHIP_EXPECT[key]:
            flags.append("%s=%s/%s" % (key, stats[key], SHIP_EXPECT[key]))
    for i, axis in enumerate("xyz"):
        if abs(stats["size_yup"][i] - SHIP_EXPECT["size_yup"][i]) > SIZE_TOL:
            flags.append("size_%s=%.3f!=%.3f" % (axis, stats["size_yup"][i],
                                                 SHIP_EXPECT["size_yup"][i]))
    if set(stats["materials"]) != SHIP_EXPECT["materials"]:
        flags.append("materials=%s" % sorted(stats["materials"]))
    if stats["prims_without_uv"]:
        flags.append("prims_without_uv=%d" % stats["prims_without_uv"])
    _check_textures(stats, flags)

    ship = gunports.SHIPS[0]
    expected = gunports.build_ports(ship)
    parent = _children_map(nodes)
    root_index = _node_index(nodes, ship["root"])
    if root_index is None:
        flags.append("missing_root")
        return flags, {}
    root_extras = nodes[root_index].get("extras") or {}
    rig_names = [row["glb_name"] for row in rigsocks.build_specs()[ship["asset"]]]
    weapon_names = [row[1] for row in socks.expected_sockets()[ship["asset"]]]
    port_names = [gunports.glb_name(ship, port) for port in expected]
    for key, expected_list in (("weapon_sockets", weapon_names),
                               ("rig_sockets", rig_names),
                               ("gun_port_sockets", port_names)):
        if root_extras.get(key) != expected_list:
            flags.append("%s=%r/%d" % (key, root_extras.get(key), len(expected_list)))
    if int(root_extras.get("gun_port_socket_count", -1)) != len(expected):
        flags.append("gun_port_socket_count=%r" % root_extras.get("gun_port_socket_count"))
    if root_extras.get("gun_port_socket_spec") != gunports.SOCKET_SPEC:
        flags.append("gun_port_socket_spec=%r" % root_extras.get("gun_port_socket_spec"))
    if int(root_extras.get("weapon_socket_count", -1)) != len(weapon_names):
        flags.append("weapon_socket_count=%r" % root_extras.get("weapon_socket_count"))
    if int(root_extras.get("rig_socket_count", -1)) != len(rig_names):
        flags.append("rig_socket_count=%r" % root_extras.get("rig_socket_count"))

    for port in expected:
        name = gunports.glb_name(ship, port)
        index = _node_index(nodes, name)
        if index is None:
            flags.append("missing_port=%s" % name)
            continue
        node = nodes[index]
        if "mesh" in node:
            flags.append("%s 带 mesh" % name)
        if parent.get(index) != root_index:
            flags.append("%s 不是 Root 子节点" % name)
        # Blender (x,y,z) → glTF (x, z, -y)
        translation = node.get("translation", [0.0, 0.0, 0.0])
        want = [port["center"][0], port["center"][2], -port["center"][1]]
        for axis in range(3):
            if abs(float(translation[axis]) - want[axis]) > POS_TOL:
                flags.append("%s t[%d]=%.4f!=%.4f" % (name, axis,
                                                      float(translation[axis]), want[axis]))
        bore = port_bore(port)
        want_forward = [bore[0], bore[2], -bore[1]]
        forward = _forward(node)
        for axis in range(3):
            if abs(forward[axis] - want_forward[axis]) > ROT_TOL:
                flags.append("%s +X[%d]=%.4f!=%.4f" % (name, axis, forward[axis],
                                                       want_forward[axis]))
        extras = node.get("extras") or {}
        expected_extras = {
            "socket_spec": gunports.SOCKET_SPEC,
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
        for key, value in expected_extras.items():
            if key not in extras:
                flags.append("%s extras_missing=%s" % (name, key))
                continue
            got = extras[key]
            if isinstance(value, float):
                if abs(float(got) - value) > 1e-6:
                    flags.append("%s extras.%s=%r" % (name, key, got))
            elif got != value:
                flags.append("%s extras.%s=%r!=%r" % (name, key, got, value))
    info = {"nodes": stats["nodes"], "meshes": stats["meshes"],
            "prims": stats["primitives"], "tris": stats["tris"],
            "size": tuple(round(v, 4) for v in stats["size_yup"]),
            "ports": len(port_names)}
    return flags, info


def port_bore(port):
    rot_z, rot_y = math.radians(port["rot_z"]), math.radians(port["rot_y"])
    return (math.cos(rot_y) * math.cos(rot_z),
            math.cos(rot_y) * math.sin(rot_z),
            -math.sin(rot_y))


def main():
    gun_path, ship_path = GUN_GLB, SHIP_GLB
    if "--gun" in sys.argv:
        gun_path = os.path.abspath(sys.argv[sys.argv.index("--gun") + 1])
    if "--ship" in sys.argv:
        ship_path = os.path.abspath(sys.argv[sys.argv.index("--ship") + 1])
    failures = []
    print("%-14s %5s %5s %6s %-26s %s" % ("glb", "nodes", "mesh", "tris",
                                          "size(Y-up)", "flags"))
    print("-" * 118)
    for label, path, checker in (("casemate gun", gun_path, check_gun),
                                 ("ironclad", ship_path, check_ship)):
        flags, info = checker(path)
        print("%-14s %5s %5s %6s %-26s %s" % (
            label, info.get("nodes", "-"), info.get("meshes", "-"),
            info.get("tris", "-"),
            "%.3f,%.3f,%.3f" % info["size"] if info.get("size") else "-",
            ", ".join(flags) if flags else "ok"))
        if flags:
            failures.append((label, flags))
    print("-" * 118)
    if failures:
        for label, flags in failures:
            print("  FAIL %s: %s" % (label, ", ".join(flags)))
        print("CASEMATE GLB VERIFY FAILED")
        return 1
    print("ALL CASEMATE GLB OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
