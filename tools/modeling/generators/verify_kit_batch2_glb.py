# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 2（机械 / 货物 / 码头）GLB 结构与共享贴图自检（纯 Python，
# 不进 Blender）。期望值从 `kit_batch2_generator.py` 的纯几何推导；额外核对煤材质
# `SN_Tex_Coal` 已随 GLB 外部化、每个图元有 UV、根 extras 字段齐全。
#
# 用法：
#     python tools/modeling/generators/verify_kit_batch2_glb.py
# @end-static-doc

import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import kit_batch2_generator as gen  # noqa: E402
import sn_kit_materials as kmat  # noqa: E402
import sn_shared_materials as smat  # noqa: E402
from verify_cranes_glb import (  # noqa: E402
    TEX_URI_PREFIX,
    WORKDIR,
    _tile_sha,
    gltf_stats,
    load_glb,
)

SIZE_TOLERANCE = 0.02
DIRS = {
    "machinery": os.path.join(WORKDIR, "assets", "models", "machinery"),
    "cargo": os.path.join(WORKDIR, "assets", "models", "cargo"),
    "dock": os.path.join(WORKDIR, "assets", "models", "dock"),
}
TILES_DIR = os.path.join(WORKDIR, "docs", "design", "textures",
                         "shared_materials", "tiles")
REQUIRED_EXTRAS = {
    "asset", "version", "units", "kit_family", "part_role", "forward", "up",
    "datum", "mount_frame", "base_footprint_x", "base_footprint_y",
    "envelope_x", "envelope_y", "height", "tri_budget", "bbox_target",
}


def _tri_count(part):
    return sum(max(0, len(f) - 2) for f, _m in part.faces)


def _expected(asset):
    parts = gen.build_geometry(asset)
    gmin = [1e18] * 3
    gmax = [-1e18] * 3
    mats = set()
    tris = 0
    for _name, (part, _parent) in parts.items():
        tris += _tri_count(part)
        for _f, mat in part.faces:
            mats.add(mat)
        for axis in range(3):
            arr = [v[axis] for v in part.verts]
            gmin[axis] = min(gmin[axis], min(arr))
            gmax[axis] = max(gmax[axis], max(arr))
    size = tuple(gmax[i] - gmin[i] for i in range(3))
    sockets = [gen.SPECS[asset]["prefix"] + name
               for _k, name, _p, _l in gen.SOCKETS[asset]]
    return {
        "nodes": 1 + len(parts) + len(sockets),
        "meshes": len(parts),
        "tris": tris,
        "size": size,
        "bbox_min": tuple(gmin),
        "mats": mats,
        "sockets": sockets,
    }


def _sha(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def _check_node_names(path, asset, expected, failures):
    gltf = load_glb(path)
    names = {node.get("name", "") for node in gltf.get("nodes", [])}
    prefix = gen.SPECS[asset]["prefix"]
    if prefix + "Root" not in names:
        failures.append("missing root node")
    for socket in expected["sockets"]:
        if socket not in names:
            failures.append("missing socket node %s" % socket)
    root = next((n for n in gltf.get("nodes", [])
                 if n.get("name", "") == prefix + "Root"), None)
    if root is None:
        return
    extras = root.get("extras") or {}
    missing = REQUIRED_EXTRAS - set(extras)
    if missing:
        failures.append("root extras missing %s" % ",".join(sorted(missing)))


def _check_shared_textures():
    failures = []
    for category in DIRS:
        for variant in ("assets", os.path.join("dev_mods", "core", "assets")):
            shared = os.path.join(WORKDIR, variant, "models", category,
                                  "shared_materials")
            if not os.path.isdir(shared):
                failures.append("%s/%s: missing shared_materials" % (
                    variant, category))
                continue
            coal = os.path.join(shared, "coal.png")
            if not os.path.isfile(coal):
                failures.append("%s/%s: missing coal.png" % (variant, category))
            elif _sha(coal) != _sha(os.path.join(TILES_DIR, "coal.png")):
                failures.append("%s/%s: coal bytes mismatch" % (
                    variant, category))
    return failures


def main():
    failures = _check_shared_textures()
    print("%-28s %5s %5s %6s %-24s %-14s %s" % (
        "glb", "nodes", "mesh", "tris", "size(Y-up x,y,z)", "textures", "flags"))
    print("-" * 120)
    texture_report = smat.texture_report()
    texture_by_material = {m: r["texture"] for m, r in texture_report.items()}
    tile_shas = _tile_sha()
    for category, directory in DIRS.items():
        for asset in gen.ASSETS:
            if kmat.ASSET_MATERIALS[asset] is None:
                continue
            prefix = gen.SPECS[asset]["prefix"]
            if gen.SPECS[asset]["family"] != "%s_kit" % category:
                continue
            path = os.path.join(directory, "%s.glb" % asset)
            flags = []
            if not os.path.isfile(path):
                failures.append("%s: missing GLB" % asset)
                print("%-28s MISSING" % asset)
                continue
            stats = gltf_stats(path)
            expected = _expected(asset)
            if stats["nodes"] != expected["nodes"]:
                flags.append("nodes=%d/%d" % (stats["nodes"], expected["nodes"]))
            if stats["meshes"] != expected["meshes"]:
                flags.append("meshes=%d/%d" % (
                    stats["meshes"], expected["meshes"]))
            if stats["tris"] != expected["tris"]:
                flags.append("tris=%d/%d" % (stats["tris"], expected["tris"]))
            expect_yup = (expected["size"][0], expected["size"][2],
                          expected["size"][1])
            for i in range(3):
                if abs(stats["size_yup"][i] - expect_yup[i]) > SIZE_TOLERANCE:
                    flags.append("size[%s]=%.3f!=%.3f" % (
                        "xyz"[i], stats["size_yup"][i], expect_yup[i]))
            extra = set(stats["materials"]) - expected["mats"]
            missing = expected["mats"] - set(stats["materials"])
            if extra:
                flags.append("mat+=%s" % ",".join(sorted(extra)))
            if missing:
                flags.append("mat-=%s" % ",".join(sorted(missing)))
            if "SN_Tex_Coal" in expected["mats"]:
                coal = os.path.join(directory, "shared_materials", "coal.png")
                if not os.path.isfile(coal):
                    flags.append("missing-coal-png")
            if not stats["double_sided"]:
                flags.append("not-all-doubleSided")
            if stats["has_cameras"]:
                flags.append("has-camera")
            expect_min_y = expected["bbox_min"][2]
            if abs(stats["bbox_min"][1] - expect_min_y) > SIZE_TOLERANCE:
                flags.append("groundY=%.3f!=%.3f" % (
                    stats["bbox_min"][1], expect_min_y))
            if stats["prims_without_uv"]:
                flags.append("prims_without_uv=%d" % stats["prims_without_uv"])
            images = stats["images"]
            if not images:
                flags.append("no-images")
            if any(image.get("embedded") for image in images):
                flags.append("embedded-images")
            for image in images:
                uri = image.get("uri") or ""
                if not uri.startswith(TEX_URI_PREFIX) or not image["exists"]:
                    flags.append("bad-uri=%s" % (uri or image.get("name")))
                    continue
                texture = os.path.splitext(os.path.basename(uri))[0]
                material = next((m for m, t in texture_by_material.items()
                                 if t == texture), None)
                if material is None or tile_shas.get(material) != image["sha256"]:
                    flags.append("texture-bytes-mismatch=%s" % uri)
            if any(uri is None for uri in stats["texture_uris"]):
                flags.append("material-without-texture")
            before = len(failures)
            _check_node_names(path, asset, expected, failures)
            if len(failures) > before:
                flags.append("contract")
            if flags:
                failures.append("%s: %s" % (asset, ", ".join(flags)))
            print("%-28s %5d %5d %6d %-24s %-14s %s" % (
                asset, stats["nodes"], stats["meshes"], stats["tris"],
                "%.2f,%.2f,%.2f" % tuple(stats["size_yup"]),
                "%d external" % len(images),
                ", ".join(flags) if flags else "ok"))
    print("-" * 120)
    print("failures = %d" % len(failures))
    if failures:
        for item in failures:
            print("  FAIL " + item)
        return 1
    print("ALL KIT BATCH 2 GLB OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
