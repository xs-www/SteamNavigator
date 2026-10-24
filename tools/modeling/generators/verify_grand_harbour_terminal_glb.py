# -*- coding: utf-8 -*-
# @static-doc
# 作用：`SN_Grand_Harbour_Terminal` 大型航站楼 GLB 的只读验收（纯 Python，不 import
# bpy，不进 Blender）。
#
# 复用 `verify_cranes_glb.py` 的 GLB 解析 / 世界 bbox / 共享 tile 校验辅助，核对：
# - 期望值来自 `sn_grand_harbour_terminal_generator.build_geometry()` 的纯几何
#   （tri / bbox / 材质 / 部件名）与常量 `TARGET_SIZE` / `TRI_BUDGET` / `TRI_FLOOR`；
# - 节点数 / 网格数 = root + parts + 文字铭牌（`.design/terminal/build_report.json`
#   存在时以其中 Blender 只读实测为准，否则按 build_geometry 推导）；
# - tri：`build_report.json` 存在时要求 GLB 实算 == 报告实测，且 >= 几何 parts 的
#   tri；报告缺失时只校验 TRI_FLOOR..TRI_BUDGET 且 >= 几何 parts tri；
# - 世界 Y-up bbox 与 `TARGET_SIZE`（Blender X/Y/Z → glTF X/Z/Y）容差 ±0.15，
#   贴地 zmin（glTF Y）≈ 0；与 build_geometry 局部 bbox、报告 bbox 交叉核对；
# - 所有图元有 TEXCOORD_0、材质全部 doubleSided、无白名单外材质、无相机 / 灯光；
# - 每张外部贴图 URI 为 `shared_materials/<texture>.png`，字节与
#   `docs/design/textures/shared_materials/tiles/` 的授权 tile 一致，两处 runtime
#   `shared_materials/` 副本齐全；
# - `assets/models/architecture/` 与 `dev_mods/core/assets/models/architecture/`
#   的 GLB 逐字节一致；
# - root extras 关键字段（asset 必填；collection / tri_budget / tri_floor /
#   bbox_target / units 等**存在即校验**）。
#
# 用法：
#     python tools/modeling/generators/verify_grand_harbour_terminal_glb.py
#     python tools/modeling/generators/verify_grand_harbour_terminal_glb.py <GLB 路径>
#
# 通过标准：打印 ALL OK 且退出码 0；有失败项时退出码 1。
# @end-static-doc

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import sn_shared_materials as smat  # noqa: E402
from verify_cranes_glb import (  # noqa: E402
    TEX_URI_PREFIX,
    WORKDIR,
    _sha_file,
    _tile_sha,
    gltf_stats,
    load_glb,
)

CATEGORY = "architecture"
ASSET = "SN_Grand_Harbour_Terminal"
SIGN_NODE = "SN_GHT_Sign"
REPORT_PATH = os.path.join(WORKDIR, ".design", "terminal", "build_report.json")
DIRS = {
    "assets": os.path.join(WORKDIR, "assets", "models", CATEGORY),
    "core": os.path.join(WORKDIR, "dev_mods", "core", "assets", "models",
                         CATEGORY),
}

# 容差（单位：米 / 三角面）
SIZE_TOL = 0.15            # Y-up 世界尺寸 vs TARGET_SIZE（契约默认 ±0.15）
GROUND_TOL = 0.02          # zmin（glTF Y）贴地
GEOMETRY_TOL = 0.50        # GLB bbox vs build_geometry 局部 bbox（铭牌/额外构件容差）
REPORT_BBOX_TOL = 0.05     # GLB bbox vs build_report 的 Blender 实测 bbox
EXTRAS_BBOX_TOL = 0.50

TARGET_FALLBACK = (72.0, 132.0, 56.5)
TRI_BUDGET_FALLBACK = 90000
TRI_FLOOR_FALLBACK = 45000

REQUIRED_EXTRAS = frozenset({"asset"})
RECOMMENDED_EXTRAS = ("version", "units", "category", "front", "up",
                      "depth_x", "width_y", "height", "tri_budget", "datum")
KNOWN_UNITS = frozenset({"m", "metre", "metres", "meter", "meters"})


# ---------------------------------------------------------------- 生成器接口

def _load_generator():
    try:
        import sn_grand_harbour_terminal_generator as generator
        return generator, None
    except Exception as error:  # 生成器缺失 / 纯 Python 侧 import 失败
        return None, "%s: %s" % (type(error).__name__, error)


GEN, GEN_ERROR = _load_generator()
ASSET = getattr(GEN, "ASSET", ASSET) if GEN is not None else ASSET
COLLECTION = (getattr(GEN, "COLLECTION", "SN_GHT_Grand_Harbour_Terminal_Prototype")
              if GEN is not None else "SN_GHT_Grand_Harbour_Terminal_Prototype")
ROOT_NAME = (getattr(GEN, "ROOT_NAME", "SN_GHT_Root")
             if GEN is not None else "SN_GHT_Root")
TARGET_SIZE = tuple(float(v) for v in getattr(GEN, "TARGET_SIZE",
                                              TARGET_FALLBACK))
TRI_BUDGET = int(getattr(GEN, "TRI_BUDGET", TRI_BUDGET_FALLBACK))
TRI_FLOOR = int(getattr(GEN, "TRI_FLOOR", TRI_FLOOR_FALLBACK))
MATERIAL_WHITELIST = getattr(GEN, "MATERIAL_WHITELIST", None)
# 生成器若显式声明 bbox 容差（`BBOX_TOL` / `SIZE_TOL`），验收跟随该契约；
# 否则按接口契约的 ±0.15 判定。
SIZE_TOL = float(getattr(GEN, "BBOX_TOL",
                         getattr(GEN, "SIZE_TOL", SIZE_TOL)))


def _load_build_report():
    if not os.path.isfile(REPORT_PATH):
        return None, None
    try:
        with open(REPORT_PATH, "r", encoding="utf-8") as handle:
            return json.load(handle), None
    except Exception as error:
        return None, "%s: %s" % (type(error).__name__, error)


def _is_sign_name(name):
    return name == SIGN_NODE or name.startswith(SIGN_NODE + ".")


def _expected_geometry():
    """build_geometry() 的纯几何期望；生成器接口不可用时返回 None。"""
    builder = getattr(GEN, "build_geometry", None)
    if not callable(builder):
        return None
    parts = builder()
    if not isinstance(parts, dict) or not parts:
        raise TypeError("build_geometry() 必须返回非空 dict")
    tris = 0
    sign_part_tris = 0
    sign_in_parts = False
    names = []
    materials = set()
    lo = [1e18] * 3
    hi = [-1e18] * 3
    has_verts = False
    for name, entry in parts.items():
        if not isinstance(entry, (tuple, list)) or len(entry) < 2:
            raise TypeError("build_geometry()[%r] 不是 (Part, parent_key)" % name)
        part = entry[0]
        names.append(name)
        part_tris = 0
        for item in getattr(part, "faces", []):
            face = item[0]
            material = item[1] if len(item) > 1 else None
            part_tris += max(0, len(face) - 2)
            if material is not None:
                materials.add(str(material))
        tris += part_tris
        if _is_sign_name(name):
            sign_in_parts = True
            sign_part_tris += part_tris
        for vertex in getattr(part, "verts", []):
            has_verts = True
            for axis in range(3):
                lo[axis] = min(lo[axis], vertex[axis])
                hi[axis] = max(hi[axis], vertex[axis])
    return {
        "parts": parts,
        "part_names": names,
        "parts_tris": tris,
        "geometry_tris": tris - sign_part_tris,
        "sign_in_parts": sign_in_parts,
        "sign_part_tris": sign_part_tris,
        "materials": sorted(materials),
        "bbox_min": tuple(lo) if has_verts else (0.0, 0.0, 0.0),
        "bbox_size": (tuple(hi[i] - lo[i] for i in range(3))
                      if has_verts else (0.0, 0.0, 0.0)),
    }


# ---------------------------------------------------------------- 单项检查

def _check_shared_copies(failures):
    """两处 runtime shared_materials 必须与授权 tile 逐字节一致。"""
    report = smat.texture_report()
    try:
        tile_shas = _tile_sha()
    except Exception as error:
        failures.append("tile-sha-unavailable: %s: %s"
                        % (type(error).__name__, error))
        return
    for variant, directory in DIRS.items():
        shared = os.path.join(directory, "shared_materials")
        if not os.path.isdir(shared):
            failures.append("%s: missing shared_materials" % variant)
            continue
        for material in sorted(report):
            texture = report[material]["texture"] + ".png"
            path = os.path.join(shared, texture)
            if not os.path.isfile(path):
                failures.append("%s: missing %s" % (variant, texture))
            elif _sha_file(path) != tile_shas[material]:
                failures.append("%s: %s bytes mismatch" % (variant, texture))


def _check_images(stats, variant, flags):
    """外部 PNG：URI 前缀 / 文件存在 / 字节与授权 tile 一致。"""
    report = smat.texture_report()
    tile_shas = _tile_sha()
    texture_sha = {entry["texture"]: tile_shas[material]
                   for material, entry in report.items()}
    images = stats["images"]
    if not images:
        flags.append("%s: no-images" % variant)
        return
    if any(image.get("embedded") for image in images):
        flags.append("%s: embedded-images" % variant)
    for image in images:
        image_uri = image.get("uri") or ""
        if not image_uri.startswith(TEX_URI_PREFIX):
            flags.append("%s: bad-uri=%s"
                         % (variant, image_uri or image.get("name")))
            continue
        texture = os.path.splitext(os.path.basename(image_uri))[0]
        expected_uri = TEX_URI_PREFIX + texture + ".png"
        if image_uri != expected_uri or texture not in texture_sha:
            flags.append("%s: bad-uri=%s" % (variant, image_uri))
            continue
        if not image.get("exists"):
            flags.append("%s: missing-png=%s" % (variant, image_uri))
        elif image.get("sha256") != texture_sha[texture]:
            flags.append("%s: texture-bytes-mismatch=%s" % (variant, image_uri))


def _ancestors(index, parents):
    out = set()
    cursor = index
    while cursor in parents:
        cursor = parents[cursor]
        out.add(cursor)
    return out


def _check_root(gltf, sign_node, flags, warnings):
    """root 节点 / 层级 / extras 关键字段。"""
    nodes = gltf.get("nodes", [])
    names = {}
    for index, node in enumerate(nodes):
        name = node.get("name")
        if name is not None:
            names.setdefault(name, index)
    root_index = names.get(ROOT_NAME)
    if root_index is None:
        flags.append("missing-root=%s" % ROOT_NAME)
        return {"root": None, "extras": {}}
    parents = {}
    for index, node in enumerate(nodes):
        for child in node.get("children", []):
            parents[int(child)] = index
    if root_index in parents:
        flags.append("root-not-top-level")
    mesh_nodes = [index for index, node in enumerate(nodes) if "mesh" in node]
    orphans = [nodes[index].get("name") for index in mesh_nodes
               if root_index not in _ancestors(index, parents)]
    if orphans:
        flags.append("mesh-not-under-root=%s" % ",".join(orphans[:3]))
    sign_index = names.get(sign_node)
    if sign_index is None:
        flags.append("missing-sign=%s" % sign_node)
    else:
        if "mesh" not in nodes[sign_index]:
            flags.append("sign-not-mesh")
        if root_index not in _ancestors(sign_index, parents):
            flags.append("sign-not-under-root")

    extras = nodes[root_index].get("extras") or {}
    if not isinstance(extras, dict) or not extras:
        flags.append("root-extras-missing")
        return {"root": ROOT_NAME, "extras": {}}
    missing = REQUIRED_EXTRAS - set(extras)
    if missing:
        flags.append("extras-missing=%s" % ",".join(sorted(missing)))
    absent = [key for key in RECOMMENDED_EXTRAS if key not in extras]
    if absent:
        warnings.append("extras-recommended-missing=%s" % ",".join(absent))

    asset = extras.get("asset")
    if asset is not None and asset != ASSET:
        flags.append("extras-asset=%r" % (asset,))
    collection = extras.get("collection")
    if collection is not None and collection != COLLECTION:
        flags.append("extras-collection=%r" % (collection,))
    tri_budget = extras.get("tri_budget")
    if tri_budget is not None:
        try:
            if int(tri_budget) != TRI_BUDGET:
                flags.append("extras-tri_budget=%r" % (tri_budget,))
        except (TypeError, ValueError):
            flags.append("extras-tri_budget=%r" % (tri_budget,))
    tri_floor = extras.get("tri_floor")
    if tri_floor is not None:
        try:
            if int(tri_floor) != TRI_FLOOR:
                flags.append("extras-tri_floor=%r" % (tri_floor,))
        except (TypeError, ValueError):
            flags.append("extras-tri_floor=%r" % (tri_floor,))
    bbox_target = extras.get("bbox_target")
    if isinstance(bbox_target, (list, tuple)) and len(bbox_target) == 3:
        try:
            actual = sorted(float(value) for value in bbox_target)
            expected = sorted(float(value) for value in TARGET_SIZE)
            if any(abs(actual[i] - expected[i]) > EXTRAS_BBOX_TOL
                   for i in range(3)):
                flags.append("extras-bbox_target=%r" % (bbox_target,))
        except (TypeError, ValueError):
            flags.append("extras-bbox_target=%r" % (bbox_target,))
    units = extras.get("units")
    if units is not None and str(units).strip().lower() not in KNOWN_UNITS:
        flags.append("extras-units=%r" % (units,))
    axis_targets = {"depth_x": TARGET_SIZE[0], "width_y": TARGET_SIZE[1],
                    "height": TARGET_SIZE[2]}
    for key, expected in axis_targets.items():
        value = extras.get(key)
        if value is None:
            continue
        try:
            if abs(float(value) - float(expected)) > EXTRAS_BBOX_TOL:
                flags.append("extras-%s=%r" % (key, value))
        except (TypeError, ValueError):
            flags.append("extras-%s=%r" % (key, value))
    front = extras.get("front")
    if front is not None and "+X" not in str(front).upper():
        flags.append("extras-front=%r" % (front,))
    return {"root": ROOT_NAME, "extras": extras}


def _check_geometry_bbox(stats, geometry, flags):
    """GLB Y-up 世界尺寸 / 贴地，与 TARGET_SIZE、build_geometry 交叉核对。"""
    size_yup = stats["size_yup"]
    expected_yup = (TARGET_SIZE[0], TARGET_SIZE[2], TARGET_SIZE[1])
    for axis in range(3):
        if abs(size_yup[axis] - expected_yup[axis]) > SIZE_TOL:
            flags.append("size[%s]=%.3f!=%.3f"
                         % ("xyz"[axis], size_yup[axis], expected_yup[axis]))
    if abs(stats["bbox_min"][1]) > GROUND_TOL:
        flags.append("groundY=%.3f" % stats["bbox_min"][1])
    if geometry is None:
        return
    geo_size = geometry["bbox_size"]
    geo_yup = (geo_size[0], geo_size[2], geo_size[1])
    for axis in range(3):
        if abs(size_yup[axis] - geo_yup[axis]) > GEOMETRY_TOL:
            flags.append("geom-size[%s]=%.3f!=%.3f"
                         % ("xyz"[axis], size_yup[axis], geo_yup[axis]))
    if abs(stats["bbox_min"][1] - geometry["bbox_min"][2]) > GEOMETRY_TOL:
        flags.append("geom-minY=%.3f!=%.3f"
                     % (stats["bbox_min"][1], geometry["bbox_min"][2]))


def _check_report_bbox(stats, report, flags):
    bbox = (report or {}).get("bbox_root") or {}
    size = bbox.get("size")
    if not isinstance(size, (list, tuple)) or len(size) != 3:
        return
    expected = (float(size[0]), float(size[2]), float(size[1]))
    for axis in range(3):
        if abs(stats["size_yup"][axis] - expected[axis]) > REPORT_BBOX_TOL:
            flags.append("report-size[%s]=%.3f!=%.3f"
                         % ("xyz"[axis], stats["size_yup"][axis],
                            expected[axis]))
    bbox_min = bbox.get("min")
    if isinstance(bbox_min, (list, tuple)) and len(bbox_min) == 3:
        if abs(stats["bbox_min"][1] - float(bbox_min[2])) > REPORT_BBOX_TOL:
            flags.append("report-minY=%.3f!=%.3f"
                         % (stats["bbox_min"][1], float(bbox_min[2])))


def _check_materials(stats, geometry, flags):
    materials = stats["materials"]
    if not materials:
        flags.append("no-materials")
        return
    whitelist = MATERIAL_WHITELIST
    if whitelist:
        extra = set(materials) - set(whitelist)
        if extra:
            flags.append("material-not-whitelisted=%s"
                         % ",".join(sorted(extra)))
    bad = [name for name in materials if not name.startswith("SN_Tex_")]
    if bad:
        flags.append("bad-material=%s" % ",".join(sorted(bad)))
    if any(uri is None for uri in stats["texture_uris"]):
        flags.append("material-without-texture")
    if not stats["double_sided"]:
        flags.append("not-all-doubleSided")
    if stats["prims_without_uv"]:
        flags.append("prims_without_uv=%d" % stats["prims_without_uv"])
    if stats["has_cameras"]:
        flags.append("has-camera")

    # build_geometry 的材质必须全部出现在 GLB 里（贴图化后材质名 = SN_Tex_*）。
    if geometry is not None:
        missing = set(geometry["materials"]) - set(materials)
        missing = {name for name in missing if name.startswith("SN_Tex_")}
        if missing:
            flags.append("geometry-material-missing=%s"
                         % ",".join(sorted(missing)))


def _check_part_nodes(gltf, geometry, warnings):
    """build_geometry 的部件名应出现在 glTF 节点名里（诊断用，不作为硬失败）。"""
    if geometry is None:
        return
    names = {node.get("name") for node in gltf.get("nodes", [])}
    absent = [name for name in geometry["part_names"] if name not in names]
    if absent:
        warnings.append("part-node-names-missing=%s" % ",".join(absent[:6]))


# ---------------------------------------------------------------- 主流程

def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    target = argv[0] if argv else DIRS["assets"]
    if os.path.isdir(target):
        dev_path = os.path.join(target, "%s.glb" % ASSET)
    else:
        dev_path = target
    core_path = os.path.join(DIRS["core"], "%s.glb" % ASSET)

    failures = []
    warnings = []
    info = {}

    if GEN_ERROR is not None:
        failures.append("generator-unavailable: %s" % GEN_ERROR)
    report, report_error = _load_build_report()
    if report_error is not None:
        failures.append("build-report-invalid: %s" % report_error)
    sign_node = (report or {}).get("sign_node") or SIGN_NODE
    geometry = None
    if GEN is not None and callable(getattr(GEN, "build_geometry", None)):
        try:
            geometry = _expected_geometry()
        except Exception as error:
            failures.append("geometry-error: %s: %s"
                            % (type(error).__name__, error))
    else:
        warnings.append("build_geometry() unavailable")

    report_tris = (report or {}).get("tris")
    report_sign_tris = (report or {}).get("sign_tris")
    sign_tris = None
    if geometry is not None and geometry["sign_in_parts"]:
        sign_tris = geometry["sign_part_tris"]
    elif report_sign_tris is not None:
        sign_tris = int(report_sign_tris)
    if (geometry is not None and geometry["sign_in_parts"]
            and report_sign_tris is not None
            and int(report_sign_tris) != geometry["sign_part_tris"]):
        failures.append("sign-tris-mismatch=%d/report%d"
                        % (geometry["sign_part_tris"], int(report_sign_tris)))

    # 期望结构：root + parts + sign。
    derived_nodes = derived_meshes = None
    if geometry is not None:
        derived_meshes = (len(geometry["parts"])
                          + (0 if geometry["sign_in_parts"] else 1))
        derived_nodes = derived_meshes + 1
    expected_nodes = (report or {}).get("nodes", derived_nodes)
    expected_meshes = (report or {}).get("meshes", derived_meshes)
    structure_source = "build_report" if report else "build_geometry"

    print("verify_grand_harbour_terminal_glb")
    print("glb      = %s" % os.path.relpath(dev_path, WORKDIR).replace("\\", "/"))
    print("expected = nodes=%r meshes=%r tris=%r source=%s"
          % (expected_nodes, expected_meshes, report_tris or "range",
             structure_source))
    if geometry is not None:
        print("geometry = tris=%d (parts) bbox=%.2f x %.2f x %.2f mats=%d"
              % (geometry["geometry_tris"], geometry["bbox_size"][0],
                 geometry["bbox_size"][1], geometry["bbox_size"][2],
                 len(geometry["materials"])))
    print("sign     = node=%s tris=%r" % (sign_node, sign_tris))

    if not os.path.isfile(dev_path):
        failures.append("missing-glb=%s"
                        % os.path.relpath(dev_path, WORKDIR).replace("\\", "/"))
        _report_failures(failures, warnings)
        return 1

    stats = gltf_stats(dev_path)
    flags = []

    # --- 节点 / 网格
    if expected_nodes is not None and stats["nodes"] != int(expected_nodes):
        flags.append("nodes=%d/%d" % (stats["nodes"], int(expected_nodes)))
    if expected_meshes is not None and stats["meshes"] != int(expected_meshes):
        flags.append("meshes=%d/%d" % (stats["meshes"], int(expected_meshes)))
    if derived_meshes is not None and stats["meshes"] < derived_meshes:
        flags.append("meshes<geometry(%d)" % derived_meshes)
    if stats["nodes"] <= 0 or stats["meshes"] <= 0 or stats["primitives"] <= 0:
        flags.append("empty-structure")

    # --- tri
    if stats["tris"] <= 0:
        flags.append("tris=0")
    if not (TRI_FLOOR <= stats["tris"] <= TRI_BUDGET):
        flags.append("tris=%d outside %d..%d"
                     % (stats["tris"], TRI_FLOOR, TRI_BUDGET))
    if geometry is not None and stats["tris"] < geometry["parts_tris"]:
        flags.append("tris=%d<geometry%d"
                     % (stats["tris"], geometry["parts_tris"]))
    if report_tris is not None and stats["tris"] != int(report_tris):
        flags.append("tris=%d/report%d" % (stats["tris"], int(report_tris)))
    if (report_tris is not None and geometry is not None
            and sign_tris is not None):
        baseline = geometry["geometry_tris"] + sign_tris
        extra = int(report_tris) - baseline
        if extra < 0:
            flags.append("report-tris<parts+sign(%d)" % baseline)
        elif extra > 0:
            warnings.append("extra-mesh-tris=%d (parts+sign=%d)"
                            % (extra, baseline))

    # --- bbox / 贴地 / 材质 / UV
    _check_geometry_bbox(stats, geometry, flags)
    _check_report_bbox(stats, report, flags)
    _check_materials(stats, geometry, flags)
    gltf = load_glb(dev_path)
    extensions = gltf.get("extensions", {}) or {}
    if "KHR_lights_punctual" in extensions:
        flags.append("has-lights")
    _check_part_nodes(gltf, geometry, warnings)
    info.update(_check_root(gltf, sign_node, flags, warnings))
    _check_images(stats, "assets", flags)

    # --- core 副本
    if not os.path.isfile(core_path):
        flags.append("missing-core-copy")
    else:
        if _sha_file(dev_path) != _sha_file(core_path):
            flags.append("core-copy-mismatch")
        core_stats = gltf_stats(core_path)
        if core_stats["tris"] != stats["tris"]:
            flags.append("core-tris=%d/%d" % (core_stats["tris"], stats["tris"]))
        _check_images(core_stats, "core", flags)

    _check_shared_copies(failures)
    failures.extend(flags)

    # ------------------------------------------------------------ 输出
    print("-" * 132)
    print("%-30s %5s %5s %5s %6s %6s %-24s %-12s %s" % (
        "glb", "nodes", "mesh", "prims", "tris", "budget",
        "size(Y-up x,y,z)", "textures", "flags"))
    print("%-30s %5d %5d %5d %6d %6d %-24s %-12s %s" % (
        ASSET, stats["nodes"], stats["meshes"], stats["primitives"],
        stats["tris"], TRI_BUDGET,
        "%.2f,%.2f,%.2f" % tuple(stats["size_yup"]),
        "%d external" % len(stats["images"]),
        ", ".join(flags) if flags else "ok"))
    print("-" * 132)
    print("bbox(Y-up) min=%s max=%s"
          % (tuple(stats["bbox_min"]), tuple(stats["bbox_max"])))
    extras = info.get("extras") or {}
    if extras:
        print("root extras keys = %s" % ",".join(sorted(extras)))
    print("shared textures = %d x 2 runtime dirs" % len(smat.texture_report()))
    _report_failures(failures, warnings)
    if failures:
        return 1
    print("ALL OK")
    return 0


def _report_failures(failures, warnings):
    for warning in warnings:
        print("  WARN " + warning)
    print("failures = %d" % len(failures))
    for item in failures:
        print("  FAIL " + item)


if __name__ == "__main__":
    sys.exit(main())
