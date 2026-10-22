# -*- coding: utf-8 -*-
# @static-doc
# 作用：M0-3 / M0-4 船侧 socket 的 **GLB 独立验收**（纯 Python，不进 Blender/Godot）——
# 核对 4 艘船 GLB 的几何不变量（节点/网格/图元/三角面/世界尺寸/材质/UV/外部贴图），
# 以及新增 socket 空节点（标准名、Root 子级、extras、局部坐标/朝向、Root
# `weapon_sockets` 与 `rig_sockets` 列表）。
#
# ## 判定口径
# - 几何必须与「迁移后基线」逐项一致：三角面 / 网格数 / 图元数 / 世界尺寸取自
#   `verify_legacy_uv_b_glb.EXPECTED`（批次 B 已验收值）；socket 只允许新增**无 mesh 的空节点**，
#   因此节点数 = 基线节点数 + socket 数，mesh 数不变；
# - 外部贴图：每个 `images[].uri` 必须是 `shared_materials/<texture>.png`、文件存在且与
#   `docs/design/textures/shared_materials/tiles/<texture>.png` 逐字节一致；Core 副本与 assets 一致；
# - socket 节点：标准名 `SN_Socket_Weapon_*`、无 mesh、是 Root 直接子节点；
#   extras 必须与 `sn_ship_weapon_sockets.SHIPS` 声明值完全一致；
#   glTF 局部 translation 必须等于 (x, deck_z, -y)（Blender Z-up → glTF Y-up）；
#   +X 朝向必须等于 Blender rot_z 旋转后的艏向/舷向；
# - Root extras：`weapon_sockets` 列表顺序 = 规格 socket_index 顺序，数量与 `weapon_socket_count` 一致。
#
# 用法：`python tools/modeling/generators/verify_ship_weapon_sockets_glb.py [--asset NAME]`
# 通过标准：每艘船 `ALL OK`；否则返回非 0 退出码。
# @end-static-doc

import hashlib
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import sn_ship_weapon_sockets as socks
import sn_ship_rig_sockets as rigsocks
import sn_ship_gun_ports as gunports
import verify_legacy_uv_b_glb as base

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
TILES_DIR = os.path.join(WORKDIR, "docs", "design", "textures", "shared_materials", "tiles")
CORE_SHIPS_DIR = os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", "ships")
SIZE_TOL = 0.05
POS_TOL = 0.02
QUAT_TOL = 1e-3
TEX_PREFIX = "shared_materials/"

# 批次 B 迁移后、M0-3 加武器 socket 前的 GLB 节点基线。当前节点数 =
# 基线 + 武器 socket 数 + M0-4 帆索 socket 数（PF 6 / PS 0 / SF 7 / IC 9）；
# 网格 / 图元 / tri / 世界尺寸 / 材质仍以 verify_legacy_uv_b_glb.EXPECTED 为准。
BASELINE_NODES = {
    "SN_Ironclad": 1,
    "SN_Paddle_Freighter": 46,
    "SN_Paddle_Steamer": 35,
    "SN_Schooner_Fame": 32,
}


def _sha_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _ship_of(asset):
    for ship in socks.SHIPS:
        if ship["asset"] == asset:
            return ship
    raise KeyError(asset)


def _node_translation(node):
    if "matrix" in node:
        matrix = node["matrix"]
        return [float(matrix[12]), float(matrix[13]), float(matrix[14])]
    return [float(v) for v in node.get("translation", [0.0, 0.0, 0.0])]


def _node_forward(node):
    """节点局部 +X 轴（glTF 坐标）。"""
    matrix = base._node_matrix(node)
    vec = [matrix[0], matrix[4], matrix[8]]
    length = (vec[0] ** 2 + vec[1] ** 2 + vec[2] ** 2) ** 0.5
    if length < 1e-9:
        return [1.0, 0.0, 0.0]
    return [v / length for v in vec]


def _parent_index(nodes, child_index):
    for index, node in enumerate(nodes):
        if child_index in node.get("children", []):
            return index
    return None


def check_ship(asset):
    ship = _ship_of(asset)
    path = os.path.join(WORKDIR, ship["glb"])
    flags = []
    report = {"asset": asset, "glb": ship["glb"], "flags": flags}
    if not os.path.isfile(path):
        flags.append("GLB 不存在")
        report["passed"] = False
        return report
    stats = base.gltf_stats(path)
    gltf = base.load_glb(path)
    nodes = gltf.get("nodes", [])
    baseline = base.EXPECTED[asset]
    _category, _base_nodes, base_meshes, base_prims, base_tris, base_size, base_mats = baseline
    baseline_nodes = BASELINE_NODES[asset]
    expected = socks.expected_sockets()[asset]
    expected_names = [name for _index, name, _sock in expected]
    rig_required = asset in {ship["asset"] for ship in rigsocks.SHIPS}
    rig_expected = []
    rig_by_name = {}
    if rig_required:
        rig_specs = rigsocks.build_specs()[asset]
        rig_expected = [sock["glb_name"] for sock in rig_specs]
        rig_by_name = {sock["glb_name"]: sock for sock in rig_specs}

    # 2026-10-22 casemate：铁甲舰另有 12 个炮门 socket（其余 3 艘为空）
    gunport_count = len(gunports.expected_ports().get(asset, []))
    if stats["nodes"] != baseline_nodes + len(expected) + len(rig_expected) + gunport_count:
        flags.append("节点数 %d != %d" % (
            stats["nodes"],
            baseline_nodes + len(expected) + len(rig_expected) + gunport_count))
    if stats["meshes"] != base_meshes:
        flags.append("网格数 %d != %d" % (stats["meshes"], base_meshes))
    if stats["primitives"] > base_prims or stats["primitives"] < stats["meshes"]:
        flags.append("图元数 %d（基线上限 %d）" % (stats["primitives"], base_prims))
    if stats["tris"] != base_tris:
        flags.append("三角面 %d != %d" % (stats["tris"], base_tris))
    for axis in range(3):
        if abs(stats["size_yup"][axis] - base_size[axis]) > SIZE_TOL:
            flags.append("世界尺寸[%s] %.3f != %.3f"
                         % ("xyz"[axis], stats["size_yup"][axis], base_size[axis]))
    if stats["prims_without_uv"]:
        flags.append("图元缺 UV %d" % stats["prims_without_uv"])
    if any(pos != uv for pos, uv in stats["uv_counts"]):
        flags.append("UV 数量与顶点不一致")
    if not stats["double_sided"]:
        flags.append("存在非 doubleSided 材质")
    if stats["has_camera"]:
        flags.append("GLB 含相机")
    if set(stats["materials"]) != set(base_mats):
        flags.append("材质集合不符")
    for material, uri in stats["texture_of_material"].items():
        if uri is None:
            flags.append("材质 %s 缺 albedo 贴图" % material)
            continue
        if not uri.startswith(TEX_PREFIX):
            flags.append("材质 %s 贴图未外部化：%s" % (material, uri))

    # 外部贴图字节与授权 tile / Core 副本一致
    for image in stats["images"]:
        if image["embedded"]:
            flags.append("存在内嵌贴图")
            continue
        uri = image["uri"] or ""
        if not uri.startswith(TEX_PREFIX):
            flags.append("贴图 URI 非 shared_materials：%s" % uri)
            continue
        texture = os.path.basename(uri)[:-len(".png")]
        authored = os.path.join(TILES_DIR, texture + ".png")
        resolved = os.path.join(WORKDIR, "assets", "models", "ships", uri)
        core = os.path.join(CORE_SHIPS_DIR, uri)
        if not os.path.isfile(resolved):
            flags.append("缺少贴图文件 %s" % uri)
            continue
        if not os.path.isfile(authored) or _sha_file(resolved) != _sha_file(authored):
            flags.append("贴图 %s 与授权 tile 不一致" % uri)
        if not os.path.isfile(core) or _sha_file(core) != _sha_file(resolved):
            flags.append("Core 贴图副本不一致 %s" % uri)

    core_glb = os.path.join(CORE_SHIPS_DIR, asset + ".glb")
    if not os.path.isfile(core_glb) or _sha_file(core_glb) != _sha_file(path):
        flags.append("Core GLB 副本不一致")

    # 节点名唯一性 / 无 .001
    seen = set()
    for node in nodes:
        name = node.get("name", "")
        if name in seen:
            flags.append("节点名重复 %s" % name)
        seen.add(name)
        if ".001" in name:
            flags.append("出现 .001 后缀：%s" % name)

    # Root 与 socket 节点
    root_index = None
    for index, node in enumerate(nodes):
        if node.get("name") == ship["root"]:
            root_index = index
            break
    if root_index is None:
        flags.append("找不到 Root 节点 %s" % ship["root"])
    socket_indices = {}
    rig_indices = {}
    for index, node in enumerate(nodes):
        name = node.get("name", "")
        if name.startswith(socks.SOCKET_PREFIX + "_"):
            socket_indices[name] = index
        elif name.startswith(("SN_Socket_Mast_", "SN_Socket_Yard_",
                              "SN_Socket_Sail_")):
            rig_indices[name] = index
    if sorted(socket_indices) != sorted(expected_names):
        flags.append("socket 节点集合不符：%s" % sorted(socket_indices))
    if sorted(rig_indices) != sorted(rig_expected):
        flags.append("rig socket 节点集合不符：%s" % sorted(rig_indices))
    if root_index is not None:
        root = nodes[root_index]
        extras = root.get("extras", {})
        if extras.get("weapon_sockets") != expected_names:
            flags.append("Root weapon_sockets 不符：%s" % extras.get("weapon_sockets"))
        if int(extras.get("weapon_socket_count", -1)) != len(expected_names):
            flags.append("Root weapon_socket_count 不符")
        if extras.get("socket_spec") != socks.SOCKET_SPEC:
            flags.append("Root socket_spec 不符")
        if rig_required:
            if extras.get("rig_sockets") != rig_expected:
                flags.append("Root rig_sockets 不符：%s" % extras.get("rig_sockets"))
            if int(extras.get("rig_socket_count", -1)) != len(rig_expected):
                flags.append("Root rig_socket_count 不符")
            if extras.get("rig_socket_spec") != rigsocks.SOCKET_SPEC:
                flags.append("Root rig_socket_spec 不符")
        children = root.get("children", [])
        for name in expected_names:
            index = socket_indices.get(name)
            if index is not None and index not in children:
                flags.append("%s 不是 Root 子节点" % name)
        for name in rig_expected:
            index = rig_indices.get(name)
            if index is not None and index not in children:
                flags.append("%s 不是 Root 子节点" % name)

    details = []
    for index, name, sock in expected:
        node_index = socket_indices.get(name)
        if node_index is None:
            continue
        node = nodes[node_index]
        if "mesh" in node:
            flags.append("%s 带 mesh（应为空节点）" % name)
        parent = _parent_index(nodes, node_index)
        if root_index is not None and parent != root_index:
            flags.append("%s 父级不是 Root" % name)
        extras = node.get("extras", {})
        expected_extras = {
            "socket_class": sock["socket_class"],
            "clearance_r": round(float(sock["clearance_r"]), 2),
            "clearance_x": round(float(sock["clearance_x"]), 2),
            "clearance_y": round(float(sock["clearance_y"]), 2),
            "clearance_h": round(float(sock["clearance_h"]), 2),
            "mount_scale": socks.MOUNT_SCALE,
            "socket_index": index,
            "socket_spec": socks.SOCKET_SPEC,
        }
        for key, value in expected_extras.items():
            actual = extras.get(key)
            if isinstance(value, float):
                if actual is None or abs(float(actual) - value) > 1e-6:
                    flags.append("%s extras.%s %r != %r" % (name, key, actual, value))
            elif actual != value:
                flags.append("%s extras.%s %r != %r" % (name, key, actual, value))
        expected_z = socks.deck_z_expected(ship, sock)
        translation = _node_translation(node)
        expected_translation = [float(sock["x"]), expected_z, -float(sock["y"])]
        for axis in range(3):
            if abs(translation[axis] - expected_translation[axis]) > POS_TOL:
                flags.append("%s translation[%d] %.3f != %.3f"
                             % (name, axis, translation[axis], expected_translation[axis]))
        angle = float(sock["rot_z"]) % 360.0
        rad = math.radians(angle)
        expected_forward = [math.cos(rad), 0.0, -math.sin(rad)]
        forward = _node_forward(node)
        if max(abs(forward[i] - expected_forward[i]) for i in range(3)) > QUAT_TOL:
            flags.append("%s 朝向 %.3f ≠ 期望 %.3f"
                         % (name, forward, expected_forward))
        details.append({
            "name": name,
            "socket_class": sock["socket_class"],
            "translation": [round(v, 3) for v in translation],
            "clearance": [extras.get("clearance_r"), extras.get("clearance_x"),
                          extras.get("clearance_y"), extras.get("clearance_h")],
        })

    rig_details = []
    for name, sock in rig_by_name.items():
        node_index = rig_indices.get(name)
        if node_index is None:
            continue
        node = nodes[node_index]
        if "mesh" in node:
            flags.append("%s 带 mesh（应为空节点）" % name)
        parent = _parent_index(nodes, node_index)
        if root_index is not None and parent != root_index:
            flags.append("%s 父级不是 Root" % name)
        extras = node.get("extras", {})
        if extras.get("socket_kind") != sock["kind"]:
            flags.append("%s extras.socket_kind %r != %r"
                         % (name, extras.get("socket_kind"), sock["kind"]))
        if extras.get("mast_key") != sock["mast_key"]:
            flags.append("%s extras.mast_key %r != %r"
                         % (name, extras.get("mast_key"), sock["mast_key"]))
        if extras.get("socket_spec") != rigsocks.SOCKET_SPEC:
            flags.append("%s extras.socket_spec 不符" % name)
        translation = _node_translation(node)
        expected_translation = [float(sock["local"][0]), float(sock["local"][2]),
                                -float(sock["local"][1])]
        for axis in range(3):
            if abs(translation[axis] - expected_translation[axis]) > POS_TOL:
                flags.append("%s translation[%d] %.3f != %.3f"
                             % (name, axis, translation[axis],
                                expected_translation[axis]))
        rig_details.append({
            "name": name,
            "kind": sock["kind"],
            "mast_key": sock["mast_key"],
            "translation": [round(v, 3) for v in translation],
        })

    report.update({
        "nodes": stats["nodes"],
        "meshes": stats["meshes"],
        "tris": stats["tris"],
        "size": stats["size_yup"],
        "sockets": details,
        "rig_sockets": rig_details,
        "passed": not flags,
    })
    return report


def main(argv):
    only = None
    for arg in argv:
        if arg.startswith("--asset="):
            only = arg.split("=", 1)[1]
    assets = [ship["asset"] for ship in socks.SHIPS]
    if only:
        assets = [only]
    failures = 0
    for asset in assets:
        report = check_ship(asset)
        if report["passed"]:
            print("ALL OK  %-22s nodes=%-3d sockets=%-2d rig=%-2d tris=%-6d size=%s"
                  % (asset, report["nodes"], len(report["sockets"]),
                     len(report["rig_sockets"]), report["tris"], report["size"]))
        else:
            failures += 1
            print("FAIL    %-22s %d 项" % (asset, len(report["flags"])))
            for flag in report["flags"]:
                print("   - " + flag)
    print("=== 结果：%d/%d 艘通过 ===" % (len(assets) - failures, len(assets)))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
