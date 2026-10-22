# -*- coding: utf-8 -*-
# @static-doc
# 作用：`combat_kit` 敌舰套件（M2-1，4 艘 `SN_Enemy_*.glb`）的 **GLB 独立只读验收**
# （纯 Python，不进 Blender / 不调用 MCP）。资产真源是
# `tools/modeling/generators/combat_kit_generator.py` 的纯 Python 数据段
# （`SHIP_CONFIGS` / `WEAPON_SOCKETS` / `GUN_PORTS` / `report()`）；本脚本只读
# `assets/models/combat/` 与 `dev_mods/core/assets/models/combat/` 两处产物，逐件核对：
#
# - **结构非空**：节点 / 网格 / 图元数 > 0；网格数 = 生成器对象数
#   `report(asset)["objects"]`（每艘是多节点船，root 不是单 mesh）；
# - **三角面**：GLB accessor 实算 tri 与 `report(asset)["tris"]` 完全一致，且 ≤ tri_budget；
# - **世界 bbox**：按节点层级合成 TRS 后的 glTF Y-up 包围盒，与
#   `SHIP_CONFIGS[asset]["bbox"]`（Blender Z-up）逐轴误差 ≤ `bbox_tol`（轴序重排 x,z,y；
#   容差同样重排为 tol_x, tol_z, tol_y）；另核 glTF Y 轴 min/max = 生成器 z_min / z_max，
#   证明轴心落在水线中心而不是工作台摆位；
# - **贴图 / UV**：每个图元有 `TEXCOORD_0` 且数量等于 POSITION；所有材质名 `SN_Tex_*`、
#   `doubleSided=true`、每个材质都有 baseColorTexture；
# - **外部共享贴图**：`images[].uri` 全部形如 `shared_materials/<texture>.png`、无内嵌图、
#   文件存在且与 `docs/design/textures/shared_materials/tiles/<texture>.png` 授权 tile
#   逐字节一致；assets 与 dev_mods/core 两处 GLB / shared_materials PNG 副本一致；
# - **root extras 契约**：`asset` / `combat_kit="enemy-ships@1"` / `enemy_class` /
#   `enemy_archetype` / `weapon_sockets` / `weapon_socket_count` / `socket_spec`；铁甲舰另有
#   `gun_port_sockets` / `gun_port_socket_count` / `gun_port_socket_spec`；
# - **socket 节点**：名字与 `ck.expected_weapon_socket_names()` /
#   `ck.expected_gun_port_names()` 完全一致、无 .001 / 重名、父级是 root、无 mesh、
#   glTF translation = Blender (x, y, z) → (x, z, -y)、关键 extras 与 generator 规格一致
#   （socket_class / clearance_* / mount_scale / socket_spec；炮门为 port_class / port_w /
#   port_h / sill_z / deck_z / lid / elev_* / traverse_deg 等）。
#
# ## 判定口径
# - 甲板 socket 的水平坐标（glTF x / z）容差 `SOCKET_POS_TOL = 0.01`；垂直坐标（glTF y）
#   容差 `SOCKET_DECK_TOL = 0.03`：socket 的 z 由 Blender 侧 down-ray 实测甲板面写入，
#   与解析 `deck_top()` 在艉楼等抬高甲板处（`build_raised_deck` 的 0.85 折减拱度）
#   差 ≤ 0.015 m，口径与 `sn_ship_weapon_sockets.Z_TOL` 一致，避免把正确产物判失败；
# - 炮门 socket 原点是解析的炮门平面中心（`ck.raider_gun_port_pose()`），三轴统一
#   `SOCKET_POS_TOL`；
# - tri / bbox 用生成器纯几何期望，不写死数字；`bbox` 只比较尺寸（尺寸是工单契约），
#   轴心由 z_min / z_max 复核。
#
# ## 用法
#     python tools/modeling/generators/verify_combat_kit_glb.py
#     python tools/modeling/generators/verify_combat_kit_glb.py --asset=SN_Enemy_Gunboat
#
# 通过标准：每件 ALL OK 并输出 `verify_combat_kit_glb: 4/4 ALL OK`，否则非 0 退出。
# @end-static-doc

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import combat_kit_generator as ck  # noqa: E402
import glb_world_bounds  # noqa: E402
import sn_shared_materials as smat  # noqa: E402
from verify_cranes_glb import (  # noqa: E402
    TEX_URI_PREFIX,
    WORKDIR,
    _sha_file,
    gltf_stats,
    load_glb,
)

CATEGORY = "combat"
DIRS = {
    "assets": os.path.join(WORKDIR, "assets", "models", CATEGORY),
    "core": os.path.join(WORKDIR, "dev_mods", "core", "assets", "models",
                         CATEGORY),
}
ASSETS = list(ck.SHIP_CLASS_ORDER)
SOCKET_POS_TOL = 0.01
SOCKET_DECK_TOL = 0.03
EXTRAS_NUM_TOL = 1e-6
BBOX_AXIS_ORDER = (0, 2, 1)  # Blender (x, y, z) -> glTF (x, z, -y) 尺寸轴序
Z_EXTENT_TOL = 0.06
REQUIRED_ROOT_EXTRAS = (
    "asset", "combat_kit", "enemy_class", "enemy_archetype", "weapon_sockets",
    "weapon_socket_count", "socket_spec",
)
REQUIRED_GUN_PORT_ROOT_EXTRAS = (
    "gun_port_sockets", "gun_port_socket_count", "gun_port_socket_spec",
)
WEAPON_SOCKET_EXTRAS = (
    "socket_spec", "socket_index", "socket_class", "clearance_r", "clearance_x",
    "clearance_y", "clearance_h", "mount_scale",
)


# ---------------------------------------------------------------- 小工具

def _node_parents(nodes):
    parents = {}
    for index, node in enumerate(nodes):
        for child in node.get("children", []):
            parents[int(child)] = index
    return parents


def _node_translation(node):
    """节点局部 translation（matrix 形态取第 4 列）。"""
    if "matrix" in node:
        matrix = node["matrix"]
        return [float(matrix[12]), float(matrix[13]), float(matrix[14])]
    return [float(value) for value in node.get("translation", [0.0, 0.0, 0.0])]


def _as_float(value):
    if isinstance(value, bool):
        raise TypeError("bool 不是数值")
    return float(value)


def _extras_num(flags, name, extras, key, expected, tolerance=EXTRAS_NUM_TOL):
    """数值 extras 断言；缺 key 只报一次。"""
    if key not in extras:
        flags.append("%s.extras-missing=%s" % (name, key))
        return
    try:
        actual = _as_float(extras[key])
    except (TypeError, ValueError):
        flags.append("%s.extras.%s=%r" % (name, key, extras[key]))
        return
    if abs(actual - float(expected)) > tolerance:
        flags.append("%s.extras.%s=%.4f/exp%.4f"
                     % (name, key, actual, float(expected)))


def _extras_str(flags, name, extras, key, expected):
    if key not in extras:
        flags.append("%s.extras-missing=%s" % (name, key))
        return
    if str(extras[key]) != str(expected):
        flags.append("%s.extras.%s=%r/exp%r" % (name, key, extras[key], expected))


def _texture_of_material():
    """{SN_Tex_*: texture 名} + {texture: 授权 tile sha256}。"""
    report = smat.texture_report()
    texture_of_material = {}
    tile_sha = {}
    textures = set()
    for material, entry in report.items():
        texture = entry["texture"]
        texture_of_material[material] = texture
        textures.add(texture)
        tile_sha[texture] = _sha_file(os.path.join(WORKDIR, entry["file"]))
    return texture_of_material, tile_sha, textures


# ---------------------------------------------------------------- 检查

def _check_copies(asset, paths, flags):
    """assets / core 两处 GLB 与 shared_materials PNG 副本一致。"""
    for variant, path in paths.items():
        if not os.path.isfile(path):
            flags.append("missing-%s-glb" % variant)
    dev_path = paths["assets"]
    core_path = paths["core"]
    if os.path.isfile(dev_path) and os.path.isfile(core_path):
        if _sha_file(dev_path) != _sha_file(core_path):
            flags.append("core-copy-mismatch")
    dirs = {variant: os.path.dirname(path) for variant, path in paths.items()}
    shared = {variant: os.path.join(directory, "shared_materials")
              for variant, directory in dirs.items()}
    for variant, path in shared.items():
        if not os.path.isdir(path):
            flags.append("missing-%s-shared_materials" % variant)
    if not all(os.path.isdir(path) for path in shared.values()):
        return
    names = {variant: {name for name in os.listdir(path)
                       if name.lower().endswith(".png")}
             for variant, path in shared.items()}
    if names["assets"] != names["core"]:
        flags.append("shared_materials-set=%s/%s"
                     % (len(names["assets"]), len(names["core"])))
    for name in sorted(names["assets"] & names["core"]):
        if _sha_file(os.path.join(shared["assets"], name)) != _sha_file(
                os.path.join(shared["core"], name)):
            flags.append("shared-png-mismatch=%s" % name)


def _check_images(stats, paths, texture_of_material, tile_sha, textures, flags):
    """外部贴图 URI / 字节 / 内嵌检查。"""
    images = stats["images"]
    if not images:
        flags.append("no-images")
    used_textures = set()
    for image in images:
        if image.get("embedded"):
            flags.append("embedded-image=%s" % (image.get("name") or "?"))
            continue
        uri = image.get("uri") or ""
        if not uri.startswith(TEX_URI_PREFIX) or not uri.endswith(".png"):
            flags.append("bad-uri=%s" % (uri or image.get("name") or "?"))
            continue
        texture = os.path.splitext(os.path.basename(uri))[0]
        used_textures.add(texture)
        if texture not in textures:
            flags.append("unknown-texture=%s" % texture)
            continue
        if not image.get("exists"):
            flags.append("missing-png=%s" % uri)
            continue
        if image.get("sha256") != tile_sha[texture]:
            flags.append("texture-bytes-mismatch=%s" % uri)
        for variant, path in paths.items():
            copy_path = os.path.join(os.path.dirname(path),
                                     "shared_materials", texture + ".png")
            if not os.path.isfile(copy_path):
                flags.append("missing-%s-png=%s" % (variant, texture))
            elif _sha_file(copy_path) != image.get("sha256"):
                flags.append("%s-png-mismatch=%s" % (variant, texture))
    for material in stats["materials"]:
        texture = texture_of_material.get(material)
        if texture is None:
            flags.append("unknown-material=%s" % material)
        elif texture not in used_textures:
            flags.append("material-without-image=%s" % material)


def _check_geometry(asset, stats, bounds, info, flags):
    """tri / 网格数 / 世界 bbox / UV / 材质。"""
    cfg = ck.SHIP_CONFIGS[asset]
    if stats["nodes"] <= 0 or stats["meshes"] <= 0 or stats["primitives"] <= 0:
        flags.append("empty-structure")
    if stats["meshes"] != info["objects"]:
        flags.append("meshes=%d/exp%d" % (stats["meshes"], info["objects"]))
    if stats["primitives"] < stats["meshes"]:
        flags.append("prims=%d<meshes%d" % (stats["primitives"],
                                            stats["meshes"]))
    if stats["tris"] != info["tris"]:
        flags.append("tris=%d/exp%d" % (stats["tris"], info["tris"]))
    if stats["tris"] > int(info["budget"]):
        flags.append("over-budget=%d/%d" % (stats["tris"], info["budget"]))
    if bounds.get("size"):
        target = cfg["bbox"]
        tolerance = cfg["bbox_tol"]
        for index, blender_axis in enumerate(BBOX_AXIS_ORDER):
            expected = float(target[blender_axis])
            allowed = float(tolerance[blender_axis])
            if abs(bounds["size"][index] - expected) > allowed:
                flags.append("size[%s]=%.3f!=%.3f(tol%.2f)"
                             % ("xyz"[index], bounds["size"][index],
                                expected, allowed))
        # 轴心：glTF Y = Blender Z（水线），min/max 必须等于生成器纯几何 z 范围。
        if abs(bounds["min"][1] - info["z_min"]) > Z_EXTENT_TOL:
            flags.append("zmin=%.3f/exp%.3f" % (bounds["min"][1],
                                                info["z_min"]))
        if abs(bounds["max"][1] - info["z_max"]) > Z_EXTENT_TOL:
            flags.append("zmax=%.3f/exp%.3f" % (bounds["max"][1],
                                                info["z_max"]))
    else:
        flags.append("no-world-bbox")
    if stats["prims_without_uv"]:
        flags.append("prims_without_uv=%d" % stats["prims_without_uv"])
    geom_stats = bounds.get("stats", {})
    if geom_stats.get("uv_missing"):
        flags.append("uv_missing=%d" % geom_stats["uv_missing"])
    if geom_stats.get("uv_count_mismatch"):
        flags.append("uv_count_mismatch=%d" % geom_stats["uv_count_mismatch"])
    if not stats["materials"]:
        flags.append("no-materials")
    for name in stats["materials"]:
        if not name.startswith("SN_Tex_"):
            flags.append("bad-material=%s" % name)
    if set(stats["materials"]) != set(info["materials"]):
        flags.append("material-set=%s" % ",".join(sorted(
            set(stats["materials"]) ^ set(info["materials"]))))
    if not stats["double_sided"]:
        flags.append("not-all-doubleSided")
    if any(uri is None for uri in stats["texture_uris"]):
        flags.append("material-without-texture")
    if stats.get("has_cameras"):
        flags.append("has-camera")


def _check_root_extras(asset, nodes, root_index, flags):
    cfg = ck.SHIP_CONFIGS[asset]
    root = nodes[root_index]
    extras = root.get("extras") or {}
    for key in REQUIRED_ROOT_EXTRAS:
        if key not in extras:
            flags.append("root.extras-missing=%s" % key)
    _extras_str(flags, "root", extras, "asset", asset)
    _extras_str(flags, "root", extras, "combat_kit", ck.COMBAT_KIT_SPEC)
    _extras_str(flags, "root", extras, "enemy_class", cfg["enemy_class"])
    _extras_str(flags, "root", extras, "enemy_archetype",
                cfg["enemy_archetype"])
    _extras_str(flags, "root", extras, "socket_spec", ck.SOCKET_SPEC)
    expected_weapon = ck.expected_weapon_socket_names(asset)
    if extras.get("weapon_sockets") != expected_weapon:
        flags.append("root.weapon_sockets=%r" % (extras.get("weapon_sockets"),))
    if int(extras.get("weapon_socket_count", -1)) != len(expected_weapon):
        flags.append("root.weapon_socket_count=%r"
                     % (extras.get("weapon_socket_count"),))
    expected_ports = ck.expected_gun_port_names(asset)
    if expected_ports:
        for key in REQUIRED_GUN_PORT_ROOT_EXTRAS:
            if key not in extras:
                flags.append("root.extras-missing=%s" % key)
        _extras_str(flags, "root", extras, "gun_port_socket_spec",
                    ck.GUN_PORT_SPEC)
        if extras.get("gun_port_sockets") != expected_ports:
            flags.append("root.gun_port_sockets=%r"
                         % (extras.get("gun_port_sockets"),))
        if int(extras.get("gun_port_socket_count", -1)) != len(expected_ports):
            flags.append("root.gun_port_socket_count=%r"
                         % (extras.get("gun_port_socket_count"),))
    else:
        # 非铁甲舰的 root 不应声明炮门名单（有也必须是空）
        if extras.get("gun_port_sockets"):
            flags.append("root.gun_port_sockets-unexpected")


def _check_weapon_sockets(asset, nodes, by_name, parents, root_index, flags):
    expected = ck.expected_weapon_socket_names(asset)
    specs = ck.WEAPON_SOCKETS.get(asset, [])
    present = sorted(name for name in by_name
                     if name.startswith("SN_Socket_Weapon_"))
    if present != sorted(expected):
        flags.append("weapon-socket-set=%s" % present)
    for index, (spec, name) in enumerate(zip(specs, expected), start=1):
        node_index = by_name.get(name)
        if node_index is None:
            flags.append("missing-socket=%s" % name)
            continue
        node = nodes[node_index]
        if "mesh" in node:
            flags.append("%s-has-mesh" % name)
        if parents.get(node_index) != root_index:
            flags.append("%s-parent" % name)
        extra = node.get("extras") or {}
        for key in WEAPON_SOCKET_EXTRAS:
            if key not in extra:
                flags.append("%s.extras-missing=%s" % (name, key))
        _extras_str(flags, name, extra, "socket_spec", ck.SOCKET_SPEC)
        _extras_num(flags, name, extra, "socket_index", index)
        _extras_str(flags, name, extra, "socket_class", spec["socket_class"])
        for key in ("clearance_r", "clearance_x", "clearance_y",
                    "clearance_h"):
            _extras_num(flags, name, extra, key, spec[key])
        _extras_num(flags, name, extra, "mount_scale", 1.0)
        # Blender world (x, y, deck_z) -> glTF (x, deck_z, -y)
        expected_translation = (float(spec["x"]), float(spec["deck_z"]),
                               -float(spec["y"]))
        actual = _node_translation(node)
        for axis in (0, 2):
            if abs(actual[axis] - expected_translation[axis]) > SOCKET_POS_TOL:
                flags.append("%s-t[%d]=%.3f!=%.3f" % (
                    name, axis, actual[axis], expected_translation[axis]))
        if abs(actual[1] - expected_translation[1]) > SOCKET_DECK_TOL:
            flags.append("%s-t[1]=%.3f!=%.3f" % (
                name, actual[1], expected_translation[1]))


def _check_gun_ports(asset, nodes, by_name, parents, root_index, flags):
    specs = ck.GUN_PORTS.get(asset, [])
    expected = ck.expected_gun_port_names(asset)
    present = sorted(name for name in by_name
                     if name.startswith("SN_Socket_GunPort_"))
    if present != sorted(expected):
        flags.append("gun-port-set=%s" % present)
    for index, (spec, name) in enumerate(zip(specs, expected), start=1):
        node_index = by_name.get(name)
        if node_index is None:
            flags.append("missing-gun-port=%s" % name)
            continue
        node = nodes[node_index]
        if "mesh" in node:
            flags.append("%s-has-mesh" % name)
        if parents.get(node_index) != root_index:
            flags.append("%s-parent" % name)
        extra = node.get("extras") or {}
        _extras_str(flags, name, extra, "socket_spec", ck.GUN_PORT_SPEC)
        _extras_num(flags, name, extra, "socket_index", index)
        _extras_num(flags, name, extra, "side_index", spec["side_index"])
        _extras_str(flags, name, extra, "port_class", spec["port_class"])
        for key in ("port_w", "port_h", "sill_z", "deck_z", "inboard_depth",
                    "outboard_clearance", "lid_hinge_z", "elev_min_deg",
                    "elev_max_deg", "traverse_deg", "mount_scale"):
            _extras_num(flags, name, extra, key, spec[key])
        _extras_str(flags, name, extra, "lid", spec["lid"])
        # 原点 = 炮门平面中心（解析真源）；Blender -> glTF (x, z, -y)
        pose = ck.raider_gun_port_pose(spec["x"], spec["side"])
        center = pose["center"]
        expected_translation = (float(center[0]), float(center[2]),
                               -float(center[1]))
        actual = _node_translation(node)
        for axis in range(3):
            if abs(actual[axis] - expected_translation[axis]) > SOCKET_POS_TOL:
                flags.append("%s-t[%d]=%.3f!=%.3f" % (
                    name, axis, actual[axis], expected_translation[axis]))


def _check_node_names(nodes, flags):
    seen = set()
    for node in nodes:
        name = node.get("name", "")
        if not name:
            flags.append("unnamed-node")
            continue
        if name in seen:
            flags.append("duplicate-node=%s" % name)
        seen.add(name)
        if ".001" in name:
            flags.append("node-001=%s" % name)


# ---------------------------------------------------------------- 主流程

def check_asset(asset, texture_of_material, tile_sha, textures):
    """单件资产的全部断言；返回 (flags, stats, bounds)。"""
    flags = []
    info = ck.report(asset, verbose=False)
    paths = {variant: os.path.join(directory, "%s.glb" % asset)
             for variant, directory in DIRS.items()}
    _check_copies(asset, paths, flags)
    dev_path = paths["assets"]
    if not os.path.isfile(dev_path):
        return flags, None, None
    stats = gltf_stats(dev_path)
    bounds = glb_world_bounds.world_bounds(dev_path)
    gltf = load_glb(dev_path)
    nodes = gltf.get("nodes", [])
    _check_geometry(asset, stats, bounds, info, flags)
    _check_images(stats, paths, texture_of_material, tile_sha, textures, flags)
    _check_node_names(nodes, flags)
    by_name = {node.get("name", ""): index for index, node in enumerate(nodes)}
    root_name = ck.SHIP_CONFIGS[asset]["root"]
    root_index = by_name.get(root_name)
    if root_index is None:
        flags.append("missing-root=%s" % root_name)
        return flags, stats, bounds
    parents = _node_parents(nodes)
    _check_root_extras(asset, nodes, root_index, flags)
    _check_weapon_sockets(asset, nodes, by_name, parents, root_index, flags)
    _check_gun_ports(asset, nodes, by_name, parents, root_index, flags)
    expected_nodes = (1 + len(ck.SHIP_CONFIGS[asset]["pivots"])
                      + int(info["objects"])
                      + len(ck.expected_weapon_socket_names(asset))
                      + len(ck.expected_gun_port_names(asset)))
    if stats["nodes"] != expected_nodes:
        flags.append("nodes=%d/exp%d" % (stats["nodes"], expected_nodes))
    return flags, stats, bounds


def main(argv):
    only = None
    for arg in argv:
        if arg.startswith("--asset="):
            only = arg.split("=", 1)[1]
    assets = [asset for asset in ASSETS if not only or asset == only]
    if not assets:
        print("未知资产 %r；可选：%s" % (only, ", ".join(ASSETS)))
        return 2
    texture_of_material, tile_sha, textures = _texture_of_material()
    print("%-28s %5s %5s %5s %7s %7s %-26s %s"
          % ("glb", "nodes", "mesh", "prims", "tris", "budget",
             "size(Y-up x,y,z)", "flags"))
    print("-" * 138)
    failures = []
    passed = 0
    for asset in assets:
        flags, stats, bounds = check_asset(asset, texture_of_material, tile_sha,
                                           textures)
        if stats is None:
            failures.append("%s: %s" % (asset, ", ".join(flags)))
            print("%-28s MISSING  %s" % (asset, "; ".join(flags)))
            continue
        size = bounds.get("size") or (0.0, 0.0, 0.0)
        budget = int(ck.SHIP_CONFIGS[asset]["tri_budget"])
        if flags:
            failures.append("%s: %s" % (asset, ", ".join(flags)))
        else:
            passed += 1
        print("%-28s %5d %5d %5d %7d %7d %-26s %s"
              % (asset, stats["nodes"], stats["meshes"],
                 stats["primitives"], stats["tris"], budget,
                 "%.2f,%.2f,%.2f" % tuple(size),
                 ", ".join(flags) if flags else "ok"))
    print("-" * 138)
    print("shared textures: %d tiles x %d runtime dirs"
          % (len(textures), len(DIRS)))
    print("failures = %d" % len(failures))
    if failures:
        for item in failures:
            print("  FAIL " + item)
        print("verify_combat_kit_glb: %d/%d FAILED" % (passed, len(assets)))
        return 1
    print("verify_combat_kit_glb: %d/%d ALL OK" % (passed, len(assets)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
