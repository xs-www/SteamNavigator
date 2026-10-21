# -*- coding: utf-8 -*-
# @static-doc
# 作用：舰载武器五件套 GLB 的结构与共享贴图自检（纯 Python，不进 Blender）。
#
# 复用 `verify_cranes_glb.py` 的 GLB 解析与 BBox 合成：核对节点数 / 网格数 / 三角面 /
# 材质名 / doubleSided / glTF Y-up 包围盒 / 贴图外部化 URI 与授权 PNG 字节一致 /
# 每个图元都有 TEXCOORD_0。额外核对 Yaw / Pitch Pivot 节点名与根节点。
#
# 用法：
#     python tools/modeling/generators/verify_weapon_glb.py
#     python tools/modeling/generators/verify_weapon_glb.py <GLB 目录或单文件>
# 通过标准：每件 ALL OK，否则返回非 0 退出码。
# @end-static-doc

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import sn_shared_materials as smat
from verify_cranes_glb import (  # noqa: E402
    SIZE_TOL,
    TEX_URI_PREFIX,
    WORKDIR,
    _tile_sha,
    gltf_stats,
    load_glb,
)

DEFAULT_DIR = os.path.join(WORKDIR, "assets", "models", "weapons")

# 资产 -> (节点数, 网格数, 三角面, Blender 尺寸 (x,y,z), 允许材质, 必含 Pivot 名)
EXPECTED = {
    "SN_Weapon_DeckGun": (
        10, 4, 1456, (2.81, 1.41, 1.61),
        {"SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Iron_Red", "SN_Tex_Brass"},
        {"SN_Mount", "SN_Pivot_Yaw", "SN_Pivot_Pitch", "SN_Recoil",
         "SN_Muzzle"},
    ),
    "SN_Weapon_HeavyCannon": (
        11, 5, 1768, (4.80, 2.20, 2.20),
        {"SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Iron_Red", "SN_Tex_Wood",
         "SN_Tex_Brass", "SN_Tex_Canvas_Shade"},
        {"SN_Mount", "SN_Pivot_Yaw", "SN_Pivot_Pitch", "SN_Recoil",
         "SN_Muzzle"},
    ),
    "SN_Weapon_Mortar": (
        10, 4, 1460, (3.20, 2.20, 2.62),
        {"SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Iron_Red",
         "SN_Tex_Wood_Dark", "SN_Tex_Brass", "SN_Tex_Glass_Dark"},
        {"SN_Mount", "SN_Pivot_Yaw", "SN_Pivot_Pitch", "SN_Recoil",
         "SN_Muzzle"},
    ),
    "SN_Weapon_Repeater": (
        10, 4, 1820, (2.86, 1.60, 1.86),
        {"SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Iron_Red", "SN_Tex_Brass"},
        {"SN_Mount", "SN_Pivot_Yaw", "SN_Pivot_Pitch", "SN_Recoil",
         "SN_Muzzle"},
    ),
    "SN_Weapon_Broadside": (
        24, 10, 3200, (2.23, 8.00, 2.06),
        {"SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Iron_Red", "SN_Tex_Wood",
         "SN_Tex_Wood_Dark", "SN_Tex_Brass", "SN_Tex_Canvas_Shade"},
        {"SN_Mount",
         "SN_Pivot_Pitch_1", "SN_Pivot_Pitch_2",
         "SN_Pivot_Pitch_3", "SN_Pivot_Pitch_4",
         "SN_Recoil_1", "SN_Recoil_2", "SN_Recoil_3", "SN_Recoil_4",
         "SN_Muzzle_1", "SN_Muzzle_2", "SN_Muzzle_3", "SN_Muzzle_4"},
    ),
}

SIZE_TOLERANCE = 0.10


def node_names(path):
    gltf = load_glb(path)
    return [node.get("name", "") for node in gltf.get("nodes", [])]


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DIR
    if os.path.isdir(target):
        files = [os.path.join(target, n) for n in sorted(os.listdir(target))
                 if os.path.splitext(n)[0] in EXPECTED]
    else:
        files = [target]
    failures = []
    print("%-24s %5s %5s %6s %-26s %-22s %s" % (
        "glb", "nodes", "mesh", "tris", "size(Y-up x,y,z)", "textures",
        "flags"))
    print("-" * 126)
    for path in files:
        name = os.path.splitext(os.path.basename(path))[0]
        stats = gltf_stats(path)
        expected = EXPECTED.get(name)
        flags = []
        names = node_names(path)
        if expected is not None:
            exp_nodes, exp_meshes, exp_tris, exp_bbox, exp_mats, exp_pivots = expected
            if stats["nodes"] != exp_nodes:
                flags.append("nodes=%d/%d" % (stats["nodes"], exp_nodes))
            if stats["meshes"] != exp_meshes:
                flags.append("meshes=%d/%d" % (stats["meshes"], exp_meshes))
            if stats["tris"] != exp_tris:
                flags.append("tris=%d/%d" % (stats["tris"], exp_tris))
            expect_yup = (exp_bbox[0], exp_bbox[2], exp_bbox[1])
            for i in range(3):
                if abs(stats["size_yup"][i] - expect_yup[i]) > SIZE_TOLERANCE:
                    flags.append("size[%s]=%.3f!=%.3f" % (
                        "xyz"[i], stats["size_yup"][i], expect_yup[i]))
            extra = set(stats["materials"]) - exp_mats
            missing = exp_mats - set(stats["materials"])
            if extra:
                flags.append("mat+=%s" % ",".join(sorted(extra)))
            if missing:
                flags.append("mat-=%s" % ",".join(sorted(missing)))
            for pivot in sorted(exp_pivots):
                if pivot not in names:
                    flags.append("missing_pivot=%s" % pivot)
        if not stats["double_sided"]:
            flags.append("not-all-doubleSided")
        if stats["has_cameras"]:
            flags.append("has-camera")
        if abs(stats["bbox_min"][1]) > SIZE_TOL:
            flags.append("groundY=%.3f" % stats["bbox_min"][1])
        if stats["prims_without_uv"]:
            flags.append("prims_without_uv=%d" % stats["prims_without_uv"])

        images = stats["images"]
        if not images:
            flags.append("no-images")
        if any(image.get("embedded") for image in images):
            flags.append("embedded-images")
        tile_shas = _tile_sha()
        bad_uris = []
        bad_bytes = []
        for image in images:
            uri = image.get("uri") or ""
            if not uri.startswith(TEX_URI_PREFIX) or not image["exists"]:
                bad_uris.append(uri or image.get("name"))
                continue
            texture = os.path.splitext(os.path.basename(uri))[0]
            material = next((m for m, r in smat.texture_report().items()
                             if r["texture"] == texture), None)
            if material is None or tile_shas.get(material) != image["sha256"]:
                bad_bytes.append(uri)
        if bad_uris:
            flags.append("bad-uri=%s" % ",".join(bad_uris[:3]))
        if bad_bytes:
            flags.append("texture-bytes-mismatch=%s" % ",".join(bad_bytes[:3]))
        if any(uri is None for uri in stats["texture_uris"]):
            flags.append("material-without-texture")

        if flags:
            failures.append((name, flags))
        print("%-24s %5d %5d %6d %-26s %-22s %s" % (
            name, stats["nodes"], stats["meshes"], stats["tris"],
            "%.2f,%.2f,%.2f" % tuple(stats["size_yup"]),
            "%d external" % len(images),
            ", ".join(flags) if flags else "ok"))
    print("-" * 126)
    print("files = %d, failures = %d" % (len(files), len(failures)))
    if failures:
        for name, flags in failures:
            print("  FAIL %s: %s" % (name, ", ".join(flags)))
        return 1
    print("ALL WEAPON GLB OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
