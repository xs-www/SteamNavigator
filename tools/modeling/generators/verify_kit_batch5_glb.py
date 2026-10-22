# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 5（M1-2 base_kit 生产建筑，5 件）GLB 只读验收（纯 Python，
# 不进 Blender）。复用 `verify_cranes_glb.py` 的 GLB 解析辅助与
# `glb_world_bounds.py` 的世界空间几何读取，逐件核对：
# - 节点 / 网格 / 图元数 > 0；tri 由 GLB accessor 实算并打印，对照生成器纯几何
#   期望与所报 tri_budget（不写死 tri 数字）；
# - 世界 bbox 按节点 TRS 合成后与工单 dimensions / 生成器 SPECS 对照，贴地
#   min z（glTF Y）≈ 0；
# - 材质全部为 `SN_Tex_*` 共享贴图、全部 doubleSided、每个图元有 TEXCOORD_0；
# - 所有 image.uri 指向 `shared_materials/<texture>.png`，无内嵌 bufferView 图，
#   外部 PNG 与 `docs/design/textures/shared_materials/tiles/` 授权 tile 逐字节一致；
# - `assets/models/base/` 与 `dev_mods/core/assets/models/base/` 两处 GLB /
#   shared_materials 副本一致；
# - root extras 契约（含 module_grid=4.0、production；防御塔 production=false）、
#   socket 节点父级与坐标（Blender (x, y, z) → glTF (x, z, -y)）。
#
# 用法：
#     python tools/modeling/generators/verify_kit_batch5_glb.py
#
# 通过标准：每件 ALL OK 并输出 `verify_kit_batch5_glb: 5/5 ALL OK`，否则非 0 退出。
# @end-static-doc

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import glb_world_bounds  # noqa: E402
import kit_batch5_generator as gen  # noqa: E402
import sn_shared_materials as smat  # noqa: E402
from verify_cranes_glb import (  # noqa: E402
    TEX_URI_PREFIX,
    WORKDIR,
    _sha_file,
    _tile_sha,
    gltf_stats,
    load_glb,
)

CATEGORY = "base"
DIRS = {
    "assets": os.path.join(WORKDIR, "assets", "models", CATEGORY),
    "core": os.path.join(WORKDIR, "dev_mods", "core", "assets", "models",
                         CATEGORY),
}
EXPECTED_COUNT = 5
GROUND_TOLERANCE = 0.01
DEFAULT_BBOX_TOLERANCE = 0.30
GEOMETRY_TOLERANCE = 0.02
SOCKET_TOLERANCE = 0.001
MODULE_GRID = 4.0
REQUIRED_EXTRAS = {
    "asset", "version", "units", "kit_family", "part_role", "forward", "up",
    "datum", "mount_frame", "base_footprint_x", "base_footprint_y",
    "envelope_x", "envelope_y", "height", "tri_budget", "bbox_target",
    "collection", "type", "module_x", "module_y", "module_grid", "production",
}
# 工单 kit_contract.console：生产建筑 production=true，防御塔 production=false。
FALSE_PRODUCTION_ROLES = {"defense_tower"}


# ---------------------------------------------------------------- 生成器接口

def _spec_for(asset):
    """从生成器读单件 spec；兼容 `SPECS`（dict）与 `SPEC`（dict/单件）两种形态。"""
    specs = getattr(gen, "SPECS", None)
    if isinstance(specs, dict) and isinstance(specs.get(asset), dict):
        return specs[asset]
    spec = getattr(gen, "SPEC", None)
    if isinstance(spec, dict):
        entry = spec.get(asset)
        if isinstance(entry, dict):
            return entry
        if spec.get("asset") == asset:
            return spec
    return {}


def _expected_geometry(asset):
    """生成器纯几何期望（三角面 / 世界 bbox）；接口缺失时返回 None。"""
    builder = getattr(gen, "build_geometry", None)
    if not callable(builder):
        return None
    parts = builder(asset)
    tris = 0
    gmin = [1e18] * 3
    gmax = [-1e18] * 3
    for _name, (part, _parent) in parts.items():
        tris += sum(max(0, len(face) - 2) for face, _material in part.faces)
        for axis in range(3):
            values = [vertex[axis] for vertex in part.verts]
            gmin[axis] = min(gmin[axis], min(values))
            gmax[axis] = max(gmax[axis], max(values))
    return {
        "tris": tris,
        "bbox_min": tuple(gmin),
        "bbox_size": tuple(gmax[axis] - gmin[axis] for axis in range(3)),
    }


def _target_bbox(cfg, spec):
    """Blender 世界 bbox 目标 (x, y, z) 与容差；缺数据时返回 (None, 0)。"""
    bbox = spec.get("bbox")
    tolerance = spec.get("tol")
    if not bbox:
        dimensions = spec.get("dimensions")
        if isinstance(dimensions, dict) and all(
                dimensions.get(key) is not None
                for key in ("length", "width", "height")):
            bbox = (dimensions["length"], dimensions["width"],
                    dimensions["height"])
            if tolerance is None:
                tolerance = dimensions.get("tolerance")
    if not bbox:
        props = cfg.root_props
        values = (props.get("envelope_x"), props.get("envelope_y"),
                  props.get("height"))
        bbox = values if all(value is not None for value in values) else None
    if not bbox:
        return None, 0.0
    if tolerance is None:
        tolerance = DEFAULT_BBOX_TOLERANCE
    return tuple(float(value) for value in bbox), float(tolerance)


def _expected_sockets(cfg):
    """{socket 名: Blender 世界坐标}；socket 为空节点、父级为 root。"""
    return {pivot.name: tuple(float(value) for value in pivot.location)
            for pivot in cfg.pivots}


# ---------------------------------------------------------------- 检查

def _check_shared_texture_copies(failures):
    """两处运行时 shared_materials 必须与授权 tile 逐字节一致。"""
    report = smat.texture_report()
    tile_shas = _tile_sha()
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


def _check_glb(asset, stats, bounds, expected, cfg, spec):
    """逐件断言；flags 以字符串列表返回用于表格输出。"""
    flags = []
    prefix = spec.get("prefix") or cfg.prefix
    root_name = spec.get("root") or cfg.root_name

    # --- 结构非空
    if stats["nodes"] <= 0 or stats["meshes"] <= 0 or stats["primitives"] <= 0:
        flags.append("empty-structure")

    # --- tri（GLB accessor 实算）对照生成器纯几何期望与预算
    if stats["tris"] <= 0:
        flags.append("tris=0")
    if expected is not None and stats["tris"] != expected["tris"]:
        flags.append("tris=%d/exp%d" % (stats["tris"], expected["tris"]))
    tri_budget = int(spec.get("tri_budget") or cfg.tri_budget or 0)
    if tri_budget and stats["tris"] > tri_budget:
        flags.append("over-budget=%d/%d" % (stats["tris"], tri_budget))

    # --- 世界 bbox（节点 TRS 合成）与贴地
    if not bounds.get("size"):
        flags.append("no-world-bbox")
    else:
        target, tolerance = _target_bbox(cfg, spec)
        if target is None:
            flags.append("no-bbox-target")
        else:
            expect_yup = (target[0], target[2], target[1])
            for axis in range(3):
                if abs(bounds["size"][axis] - expect_yup[axis]) > tolerance:
                    flags.append("size[%s]=%.3f!=%.3f" % (
                        "xyz"[axis], bounds["size"][axis], expect_yup[axis]))
        if abs(bounds["min"][1]) > GROUND_TOLERANCE:
            flags.append("groundY=%.3f" % bounds["min"][1])
        if expected is not None:
            geo_size = expected["bbox_size"]
            expect_geo = (geo_size[0], geo_size[2], geo_size[1])
            for axis in range(3):
                if abs(bounds["size"][axis] - expect_geo[axis]) \
                        > GEOMETRY_TOLERANCE:
                    flags.append("geom-size[%s]=%.3f!=%.3f" % (
                        "xyz"[axis], bounds["size"][axis], expect_geo[axis]))
            if abs(bounds["min"][1] - expected["bbox_min"][2]) \
                    > GEOMETRY_TOLERANCE:
                flags.append("geom-minY=%.3f!=%.3f" % (
                    bounds["min"][1], expected["bbox_min"][2]))

    # --- 材质 / 双面 / UV
    materials = stats["materials"]
    if not materials:
        flags.append("no-materials")
    for name in materials:
        if not name.startswith("SN_Tex_"):
            flags.append("bad-material=%s" % name)
    if any(uri is None for uri in stats["texture_uris"]):
        flags.append("material-without-texture")
    if not stats["double_sided"]:
        flags.append("not-all-doubleSided")
    if stats["prims_without_uv"]:
        flags.append("prims_without_uv=%d" % stats["prims_without_uv"])
    if bounds.get("stats", {}).get("uv_missing"):
        flags.append("uv_missing=%d" % bounds["stats"]["uv_missing"])
    if bounds.get("stats", {}).get("uv_count_mismatch"):
        flags.append("uv_count_mismatch=%d"
                     % bounds["stats"]["uv_count_mismatch"])

    # --- 外部共享贴图：无内嵌图、URI 正确、字节与授权 tile 一致
    images = stats["images"]
    if not images:
        flags.append("no-images")
    if any(image.get("embedded") for image in images):
        flags.append("embedded-images")
    report = smat.texture_report()
    tile_shas = _tile_sha()
    texture_sha = {entry["texture"]: tile_shas[material]
                   for material, entry in report.items()}
    for image in images:
        image_uri = image.get("uri") or ""
        if not image_uri.startswith(TEX_URI_PREFIX):
            flags.append("bad-uri=%s" % (image_uri or image.get("name")))
            continue
        texture = os.path.splitext(os.path.basename(image_uri))[0]
        expected_uri = TEX_URI_PREFIX + texture + ".png"
        if image_uri != expected_uri or texture not in texture_sha:
            flags.append("bad-uri=%s" % image_uri)
            continue
        if not image.get("exists"):
            flags.append("missing-png=%s" % image_uri)
        elif image.get("sha256") != texture_sha[texture]:
            flags.append("texture-bytes-mismatch=%s" % image_uri)

    # --- root extras / socket 节点
    gltf = load_glb(os.path.join(DIRS["assets"], "%s.glb" % asset))
    nodes = gltf.get("nodes", [])
    names = {node.get("name", ""): index for index, node in enumerate(nodes)}
    root_index = names.get(root_name)
    if root_index is None:
        flags.append("missing-root=%s" % root_name)
    else:
        extras = nodes[root_index].get("extras") or {}
        missing = REQUIRED_EXTRAS - set(extras)
        if missing:
            flags.append("extras-missing=%s" % ",".join(sorted(missing)))

        # module_grid=4.0（base 沿 X 平铺网格）；kit_family=base_kit（新类别）
        module_grid = extras.get("module_grid")
        if module_grid is not None and abs(
                float(module_grid) - MODULE_GRID) > 1e-6:
            flags.append("module_grid=%r" % (module_grid,))
        family = extras.get("kit_family")
        if family is not None and family != "base_kit":
            flags.append("kit_family=%r" % (family,))

        # production 布尔契约：仅防御塔为 false
        role = extras.get("part_role") or spec.get("role") or ""
        expected_production = role not in FALSE_PRODUCTION_ROLES
        production = extras.get("production")
        if production is not None and not isinstance(production, bool):
            flags.append("production=%r" % (production,))
        elif production is not None and production is not expected_production:
            flags.append("production=%r/exp%r" % (production,
                                                  expected_production))

        parents = {}
        for index, node in enumerate(nodes):
            for child in node.get("children", []):
                parents[int(child)] = index
        world = glb_world_bounds.node_world_matrices(
            os.path.join(DIRS["assets"], "%s.glb" % asset))
        for socket_name, blender_loc in _expected_sockets(cfg).items():
            socket_index = names.get(socket_name)
            if socket_index is None:
                flags.append("missing-socket=%s" % socket_name)
                continue
            if parents.get(socket_index) != root_index:
                flags.append("socket-parent=%s" % socket_name)
            matrix = world.get(socket_index)
            if matrix is None:
                flags.append("socket-unplaced=%s" % socket_name)
                continue
            # glTF 默认 +Y up / -Z forward：Blender (x, y, z) → glTF (x, z, -y)
            expected_gltf = (blender_loc[0], blender_loc[2], -blender_loc[1])
            actual = (matrix[0][3], matrix[1][3], matrix[2][3])
            if any(abs(actual[i] - expected_gltf[i]) > SOCKET_TOLERANCE
                   for i in range(3)):
                flags.append("socket-pos=%s" % socket_name)
        if prefix + "Mount" not in names:
            flags.append("missing-Mount")

    return flags


# ---------------------------------------------------------------- 主流程

def main():
    failures = []
    _check_shared_texture_copies(failures)

    assets = list(gen.ASSETS)
    if len(assets) != EXPECTED_COUNT:
        failures.append("expected %d assets, generator exposes %d" % (
            EXPECTED_COUNT, len(assets)))
    paths = {}
    for asset in assets:
        paths[asset] = {
            variant: os.path.join(directory, "%s.glb" % asset)
            for variant, directory in DIRS.items()
        }

    print("%-30s %5s %5s %5s %6s %6s %-24s %-12s %s" % (
        "glb", "nodes", "mesh", "prims", "tris", "budget",
        "size(Y-up x,y,z)", "textures", "flags"))
    print("-" * 140)
    passed = 0
    for asset in assets:
        dev_path = paths[asset]["assets"]
        core_path = paths[asset]["core"]
        flags = []
        if not os.path.isfile(dev_path):
            failures.append("%s: missing GLB %s" % (
                asset, os.path.relpath(dev_path, WORKDIR).replace("\\", "/")))
            print("%-30s MISSING" % asset)
            continue
        if not os.path.isfile(core_path):
            flags.append("missing-core-copy")
        elif _sha_file(dev_path) != _sha_file(core_path):
            flags.append("core-copy-mismatch")

        stats = gltf_stats(dev_path)
        bounds = glb_world_bounds.world_bounds(dev_path)
        cfg = gen.build_config(asset)
        spec = _spec_for(asset)
        try:
            expected = _expected_geometry(asset)
        except Exception as error:  # 生成器未提供纯几何接口时降级
            expected = None
            print("WARN %s: expected geometry unavailable (%s)" % (
                asset, error))
        flags.extend(_check_glb(asset, stats, bounds, expected, cfg, spec))

        tri_budget = int(spec.get("tri_budget") or cfg.tri_budget or 0)
        size = bounds.get("size") or (0.0, 0.0, 0.0)
        images = stats["images"]
        if flags:
            failures.append("%s: %s" % (asset, ", ".join(flags)))
        else:
            passed += 1
        print("%-30s %5d %5d %5d %6d %6d %-24s %-12s %s" % (
            asset, stats["nodes"], stats["meshes"], stats["primitives"],
            stats["tris"], tri_budget,
            "%.2f,%.2f,%.2f" % tuple(size),
            "%d external" % len(images),
            ", ".join(flags) if flags else "ok"))

    print("-" * 140)
    print("shared textures: %d x 2 runtime dirs" % len(smat.texture_report()))
    print("failures = %d" % len(failures))
    if failures:
        for item in failures:
            print("  FAIL " + item)
        print("verify_kit_batch5_glb: %d/%d FAILED" % (passed, len(assets)))
        return 1
    print("verify_kit_batch5_glb: %d/%d ALL OK" % (passed, len(assets)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
